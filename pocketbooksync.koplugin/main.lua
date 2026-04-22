local Device = require("device")

if not Device:isPocketBook() then
    return { disabled = true }
end

local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")
local util = require("util")
local SQ3 = require("lua-ljsqlite3/init")
local ffi = require("ffi")
local inkview = ffi.load("inkview")
local FileManagerBookInfo = require("apps/filemanager/filemanagerbookinfo")
local Screen = require("device").screen
local RenderImage = require("ui/renderimage")
local bookIds = {}

local function openPocketbookDB()
    for version = 2, 3 do
        local dbPath = "/mnt/ext1/system/explorer-" .. version .. "/explorer-" .. version .. ".db"
        if util.pathExists(dbPath) then
            logger.dbg("Pocketbook Sync: Using database version " .. version)
            return SQ3.open(dbPath), version
        end
    end
end

local pocketbookDbConn, pocketbookDbVersion = openPocketbookDB()
if pocketbookDbConn == nil then
    logger.error("Pocketbook Sync: Could not find or open PocketBook database - aborting")
    return { disabled = true }
end

-- wait for database locks for up to 1 second before raising an error
pocketbookDbConn:set_busy_timeout(1000)

local function GetCurrentProfileId()
    local profile_name = inkview.GetCurrentProfile()
    if profile_name == nil then
        return 1
    else
        local stmt = pocketbookDbConn:prepare("SELECT id FROM profiles WHERE name = ?")
        local profile_id = stmt:reset():bind(ffi.string(profile_name)):step()
        stmt:close()
        return profile_id[1]
    end
end

local profile_id = GetCurrentProfileId()

local PocketbookSync = WidgetContainer:extend{
    name = "pocketbooksync",
    is_doc_only = false,
}

function PocketbookSync:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)

    self.settings = G_reader_settings:readSetting("pocketbooksync", {
        hide_finished = false,
        update_cover = false,
    })
end

function PocketbookSync:onDispatcherRegisterActions()
    Dispatcher:registerAction("pocketbook_scan_home_dir", {
        category = "none",
        event = "PocketBookScanHomeDir",
        title = "PocketBook Sync: Scan home dir",
        device = true,
    })
end

function PocketbookSync:addToMainMenu(menu_items)
    menu_items.pocketbooksync = {
        sorting_hint = "tools",
        text = "Pocketbook Sync",
        sub_item_table = {
            {
                text = "Hide finished books from home screen",
                checked_func = function() return self.settings.hide_finished end,
                callback = function() self.settings.hide_finished = not self.settings.hide_finished end,
            },
            {
                text = "Update book cover on device",
                checked_func = function() return self.settings.update_cover end,
                callback = function() self.settings.update_cover = not self.settings.update_cover end,
                help_text = "Write the book's cover image to PocketBook system paths (lock screen, book cover).",
            },
            {
                text = "Scan home dir",
                callback = function()
                    self.ui:handleEvent(Event:new("PocketBookScanHomeDir"))
                end,
                help_text = "Rescan the home directory for new, moved, or deleted books. Use this after deleting books or downloading new ones (from Calibre for example).",
            },
        },
    }
end

function PocketbookSync:updateCover()
    if not self.settings.update_cover then return end
    if not self.ui.document then return end

    local image = FileManagerBookInfo:getCoverImage(self.ui.document)
    if not image then return end

    local width = Screen:getWidth()
    local height = Screen:getHeight()
    local rotation = Screen:getRotationMode()

    if rotation == 1 or rotation == 3 then
        width, height = height, width
    end

    local imageScaled = RenderImage:scaleBlitBuffer(image, width, height)
    imageScaled:writeToFile("/mnt/ext1/system/logo/bookcover", "bmp", 100, false)
    imageScaled:writeToFile("/mnt/ext1/system/resources/Line/taskmgr_lock_background.bmp", "bmp", 100, false)
end

function PocketbookSync:clearCache()
    bookIds = {}
end

function PocketbookSync:sync()
    self:doSync(self:prepareSync())
end

function PocketbookSync:prepareSync()
    -- onFlushSettings called during koreader exit and after onCloseDocument
    -- would raise an error in some of the self.document methods and we can
    -- avoid that by checking if self.ui.document is nil
    if not self.ui.document then
        return nil
    end

    local folder, file = self:getFolderFile()
    if not folder or folder == "" or not file or file == "" then
        logger.info("Pocketbook Sync: No folder/file found for " .. self.view.document.file)
        return nil
    end

    local globalPage = self.view.state.page
    local flow = self.document:getPageFlow(globalPage)

    -- skip sync if not in the main flow
    if flow ~= 0 then
        return nil
    end

    local totalPages = self.document:getTotalPagesInFlow(flow)
    local page = self.document:getPageNumberInFlow(globalPage)

    local summary = self.ui.doc_settings:readSetting("summary")
    local status = summary and summary.status
    local completed = (status == "complete" or page == totalPages) and 1 or 0

    -- hide the progress bar if we're on the title/cover page
    --
    -- we'll never set cpage=1 so the progress bar will seem to jump a bit at
    -- the start of a book, but there's no nice way to fix that: to use the
    -- full range, we'd need to map pages 2 to last-1 to cpages 1 to last-1,
    -- and that always skips one position; skipping the first one is the least
    -- surprising behaviour
    if page == 1 then
        page = 0
    end

    local time = os.time()
    if status == "complete" and self.settings.hide_finished then
        time = 0
    end

    return {
        folder = folder,
        file = file,
        totalPages = totalPages,
        page = page,
        completed = completed,
        time = time,
    }
end

function PocketbookSync:doSync(data)
    if not data then
        return
    end

    local cacheKey = data.folder .. "/" .. data.file

    if not bookIds[cacheKey] then
        local sql
        if pocketbookDbVersion == 2 then
            sql = [[
                SELECT id
                FROM books
                WHERE
                    foldername = ? AND filename = ?
                LIMIT 1
            ]]
        else -- pocketBookDbVersion == 3
            sql = [[
                SELECT book_id
                FROM files
                WHERE
                    folder_id = (SELECT id FROM folders WHERE name = ? LIMIT 1)
                AND filename = ?
                LIMIT 1
            ]]
        end
        local stmt = pocketbookDbConn:prepare(sql)
        local row = stmt:reset():bind(data.folder, data.file):step()
        stmt:close()

        if row == nil then
            logger.info("Pocketbook Sync: Book id for " .. data.folder .. "/" .. data.file .. " not found")
            return
        end
        bookIds[cacheKey] = row[1]
    end

    local book_id = bookIds[cacheKey]
    local sql = [[
            REPLACE INTO books_settings
            (bookid, profileid, cpage, npage, completed, opentime)
            VALUES (?, ?, ?, ?, ?, ?)
        ]]
    local stmt = pocketbookDbConn:prepare(sql)
    stmt:reset():bind(book_id, profile_id, data.page, data.totalPages, data.completed, data.time):step()
    stmt:close()
end

function PocketbookSync:getFolderFile()
    local path = self.view.document.file
    local folder, file = util.splitFilePathName(path)
    local folderTrimmed = folder:match("(.*)/")
    if folderTrimmed ~= nil then
        folder = folderTrimmed
    end
    return folder, file
end

function PocketbookSync:onReaderReady()
    self:updateCover()
end

function PocketbookSync:onFlushSettings()
    self:sync()
end

function PocketbookSync:onCloseDocument()
    self:updateCover()
    self:sync()
end

function PocketbookSync:onEndOfBook()
    self:updateCover()
    self:sync()
end

function PocketbookSync:onResume()
    self:updateCover()
end

-- TODO: PageSnapshot not needed once koreader get the first 2026 release
-- https://github.com/koreader/koreader-base/pull/2247
ffi.cdef[[
struct iconfig_s * GetGlobalConfig();
const char *ReadString(struct iconfig_s *cfg, const char *name, const char *deflt);
int PageSnapshot();
]]

function PocketbookSync:onSuspend()
    self:updateCover()
    self:sync()

    -- Enable PocketBook's ⚙ → Personalize → Logos → Boot Logo → Current Page
    --
    -- This lets users continue reading almost immediately after turning the
    -- reader back on after it automatically powered off
    -- (see ⚙ → Saving Power → Power off after)
    local bootlogo = ffi.string(inkview.ReadString(inkview.GetGlobalConfig(), "bootlogo", "@default_boot_logo"))
    if bootlogo == "@snapshot" then
        local snapshot_success, snapshot_err = pcall(inkview.PageSnapshot)
        if not snapshot_success then
            logger.warn("Pocketbook Sync: PageSnapshot failed: " .. tostring(snapshot_err))
        end
    end
end

-- needed since
-- https://github.com/koreader/koreader-base/commit/0b80fb26e64d3b3b2b59206c24297edc48c3199f
-- removed unused declarations
ffi.cdef[[
static const int REQ_OPENBOOK = 84;
int FindTaskByAppName(const char *);
int SendRequestTo(int, int, void *, int, int, int);
]]

function PocketbookSync:onPocketBookScanHomeDir()
    local task = inkview.FindTaskByAppName("scanner.app")
    if task ~= -1 then
        local parameters = "-scan:" .. G_reader_settings:readSetting("home_dir")
        inkview.SendRequestTo(
            task, ffi.C.REQ_OPENBOOK,
            ffi.cast("void *", ffi.new("const char *", parameters)), #parameters + 1,
            0, 2000
        )
        logger.info("Pocketbook Sync: scan request sent")
    end

    return true
end

return PocketbookSync

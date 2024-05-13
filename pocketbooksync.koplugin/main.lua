local Device = require("device")

if not Device:isPocketBook() then
    return { disabled = true, }
end

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")
local util = require("util")
local UIManager = require("ui/uimanager")
local SQ3 = require("lua-ljsqlite3/init")
local pocketbookDbConn = SQ3.open("/mnt/ext1/system/explorer-3/explorer-3.db")
local ffi = require("ffi")
local inkview = ffi.load("inkview")

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

function PocketbookSync:immediateSync()
    UIManager:unschedule(self.doSync)
    self:doSync(self:prepareSync())
end

function PocketbookSync:scheduleSync()
    UIManager:unschedule(self.doSync)
    UIManager:scheduleIn(3, self.doSync, self, self:prepareSync())
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

    local data = {
        folder = folder,
        file = file,
        totalPages = totalPages,
        page = page,
        completed = completed,
        time = os.time(),
    }
    return data
end

function PocketbookSync:doSync(data)
    if not data then
        return
    end

    local sql = [[
            SELECT book_id
            FROM files
            WHERE
                folder_id = (SELECT id FROM folders WHERE name = ? LIMIT 1)
            AND filename = ?
            LIMIT 1
        ]]
    local stmt = pocketbookDbConn:prepare(sql)
    local row = stmt:reset():bind(data.folder, data.file):step()
    stmt:close()

    if row == nil then
        logger.info("Pocketbook Sync: Book id for " .. data.folder .. "/" .. data.file .. " not found")
        return
    end
    local book_id = row[1]

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

function PocketbookSync:onPageUpdate()
    self:scheduleSync()
end

function PocketbookSync:onFlushSettings()
    self:immediateSync()
end

function PocketbookSync:onCloseDocument()
    self:immediateSync()
end

function PocketbookSync:onEndOfBook()
    self:immediateSync()
end

return PocketbookSync

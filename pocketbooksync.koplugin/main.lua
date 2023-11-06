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

-- wait for database locks for up to 1 second before raising an error
pocketbookDbConn:set_busy_timeout(1000)

local PocketbookSync = WidgetContainer:extend{
    name = "pocketbooksync",
    is_doc_only = false,
}

function PocketbookSync:sync(folder, file, page)
    local totalPages = self.view.document:getPageCount()
    if not totalPages then
        logger.info("Pocketbook Sync: No total pages found " .. title .. ", " .. page)
    end

    local completed = 0

    if page >= totalPages then
        completed = 1
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
    local row = stmt:reset():bind(folder, file):step()
    stmt:close()

    if row == nil then
        logger.info("Pocketbook Sync: Book id for " .. folder .. "/" .. file .. " not found")
        return
    end
    local book_id = row[1]

    local sql = [[
            REPLACE INTO books_settings
            (bookid, profileid, cpage, npage, completed, opentime)
            VALUES (?, 1, ?, ?, ?, ?)
        ]]
    local stmt = pocketbookDbConn:prepare(sql)
    stmt:reset():bind(book_id, page, totalPages, completed, os.time(os.date("!*t"))):step()
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

function PocketbookSync:onPageUpdate(page)
    UIManager:scheduleIn(3, function()
        local folder, file = self:getFolderFile()

        if folder ~= "" and file ~= "" then
            self:sync(folder, file, page);

            return
        end

        logger.info("Pocketbook Sync: File not specified")
    end)
end

return PocketbookSync

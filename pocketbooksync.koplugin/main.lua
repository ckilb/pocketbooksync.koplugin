local Device = require("device")

if not Device:isPocketBook() then
    return { disabled = true, }
end

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local SQ3 = require("lua-ljsqlite3/init")
local pocketbookDbConn = SQ3.open("/mnt/ext1/system/explorer-3/explorer-3.db")

local PocketbookSync = WidgetContainer:extend{
    name = "pocketbooksync",
    is_doc_only = false,
}

function PocketbookSync:sync(title, page)
    local totalPages = self.view.document:getPageCount()
    if not totalPages then
        logger.info("Pocketbook Sync: No total pages found " .. title .. ", " .. page)
    end

    local completed = 0

    if page >= totalPages then
        completed = 1
    end

    local stmt = [[
            REPLACE INTO books_settings
            (bookid, profileid, cpage, npage, completed, opentime)
            VALUES
            (
                (SELECT id
                FROM books_impl
                WHERE TRIM(LOWER(title))=TRIM(LOWER(?))
                ORDER BY id DESC
                LIMIT 1),
                1,
                ?,
                ?,
                ?,
                ?
            )
        ]]

    stmt = pocketbookDbConn:prepare(stmt)

    stmt:reset():bind(title, page, totalPages, completed, os.time(os.date("!*t"))):step()
end

function PocketbookSync:getTitle()
    local props = self.view.document:getProps()

    return props.title
end

function PocketbookSync:onPageUpdate(page)
    UIManager:scheduleIn(3, function()
        local title = self:getTitle()

        if title ~= "" then
            self:sync(title, page);

            return
        end

        logger.info("Pocketbook Sync: Title not found")
    end)
end

return PocketbookSync

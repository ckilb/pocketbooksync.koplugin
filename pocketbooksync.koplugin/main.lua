local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")
local UIManager = require("ui/uimanager")

local PocketbookSync = WidgetContainer:extend{
    name = "pocketbooksync",
    is_doc_only = false,
}

function PocketbookSync:sync(title, page)
    local command = "sh /mnt/ext1/applications/koreader/plugins/pocketbooksync.koplugin/sync.sh " .. page  .. " \"" .. title .. "\""
    logger.info("Pocketbook Sync: Run sync: " .. command)

    os.execute(command)
end

function PocketbookSync:getTitle()
    local props = self.view.document:getProps()

    logger.info("Pocketbook Sync: Get book title " .. props.title)

    return props.title
end

function PocketbookSync:onPageUpdate(page)
    logger.info("Pocketbook Sync: Page update registered")

    UIManager:scheduleIn(3, function()
        local title = self:getTitle()

        if title ~= "" then
            self:sync(title, page);
        end
    end)
end

return PocketbookSync

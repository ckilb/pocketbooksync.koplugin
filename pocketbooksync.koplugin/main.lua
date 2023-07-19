local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")

local PocketbookSync = WidgetContainer:extend{
    name = "pocketbooksync",
    is_doc_only = false,
}

function PocketbookSync:sync(pageno)
    logger.info("Pocketbook Sync: Run Syncing script. Page number: " .. pageno)

    os.execute("sh /mnt/ext1/applications/koreader/plugins/pocketbooksync.koplugin/sync.sh " .. pageno)
end

function PocketbookSync:onPageUpdate(page)
    self:sync(page);
end

return PocketbookSync

local Dispatcher = require("dispatcher")  -- luacheck:ignore
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")

local PocketbookSync = WidgetContainer:extend{
    name = "pocketbooksync",
    is_doc_only = false,
}


function PocketbookSync:onDispatcherRegisterActions()
    Dispatcher:registerAction("pocketbooksync_action", {category="none", event="PocketbookSync", title=_("Sync with PocketBook"), general=true,})
end


function PocketbookSync:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function PocketbookSync:sync()
    os.execute("sh /mnt/ext1/applications/pocketbooksync.app")
end

function PocketbookSync:syncSilently()
    os.execute("sh /mnt/ext1/applications/pocketbooksync.app --quite")
end

function PocketbookSync:onExit()
    self:syncSilently()
end

function PocketbookSync:onPocketbookSync()
    self:sync()
end

function PocketbookSync:onPageUpdate()
    self:syncSilently()
end

function PocketbookSync:addToMainMenu(menu_items)
    menu_items.pocketbooksync = {
        text = _("Sync with PocketBook"),
        sorting_hint = "progress_sync",
        callback = function()
            self:sync()

            return true
        end,
    }
end


return PocketbookSync

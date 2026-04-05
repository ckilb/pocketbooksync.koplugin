-- Keep previous screen visible during initial book loading

local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

-- Only patch during the first launch of KOReader after boot. The first refresh
-- after boot will clear the screen even if it's partial (even the fbink tool
-- will clear the screen ☹). Subsequent partial refreshes don't need this.
local tmp_flag = "/tmp/koreader_do_not_skip_first_repaint"
if lfs.attributes(tmp_flag, "mode") == "file" then
    logger.info("2-skip-first-repaint: skipping, not the first boot")
    return
end
local tmp_flag_f = io.open(tmp_flag, "w")
if tmp_flag_f then tmp_flag_f:write("1") tmp_flag_f:close() end

-- Skip the first UIManager:forceRePaint call in ReaderUI:showReaderCoroutine
-- (well, skips any first forceRePaint call but UIManager will repaint eventually anyway)
local firstRePaint = true
UIManager.forceRePaint = (function(orig)
    return function(...)
        if not firstRePaint then
            orig(...)
        end
        firstRePaint = false
    end
end)(UIManager.forceRePaint)

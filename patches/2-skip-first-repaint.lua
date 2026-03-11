-- Keep previous screen visible during initial book loading

local UIManager = require("ui/uimanager")

local firstRePaint = true

-- Skip the first UIManager:forceRePaint call in ReaderUI:showReaderCoroutine
-- (well, skips any first forceRePaint call but UIManager will repaint eventually anyway)
UIManager.forceRePaint = (function(orig)
    return function(...)
        if not firstRePaint then
            orig(...)
        end
        firstRePaint = false
    end
end)(UIManager.forceRePaint)

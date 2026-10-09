-- Pulse UI (phase2) fork: replaced span 2 of 2 (Classic lines 176-192, the layout). The kept render step calls layout() every frame (Classic 197); the view returns at once unless the size or scale changed, and the boost ring is written only when the whole percent changes.
local function layout() view.Layout(); view.SetBoostPercent(M.BoostPercent) end

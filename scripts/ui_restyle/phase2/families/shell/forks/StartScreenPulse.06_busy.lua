local busy = false
local function setBusy(active, target, text)
	busy = active == true
	local playText, shopText = playDefaultText, shopDefaultText
	if target == "Play" and text then playText = tostring(text)
	elseif target == "Shop" and text then shopText = tostring(text) end
	built.SetBusy(busy, playText, shopText)
end

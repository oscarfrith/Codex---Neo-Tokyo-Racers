-- Persistence Phase 17 module popup pool target reset repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Root cause addressed:
-- UIPool reuses TextButtons between module tabs/cards. The pooledButton reset
-- path cleared dynamic labels, text, size, colours, and visibility, but did not
-- clear popup-specific attributes/anchors. A recycled button could therefore
-- remain tagged as NTRModulePopupTarget and pull BUY/LOCKED/EQUIP toward a stale
-- card location.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Pool Target Reset Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another popup patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another popup patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "local function pooledButton(pool, text, size, position, color)"), "Expected pooledButton helper in active client bootstrap.")
assert(findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET"), "Expected anchor-target popup helper before applying pool target reset repair.")

local oldReset = [=[	clearPooledDynamicChildren(b)
	b.Text = string.upper(text or "")]=]

local newReset = [=[	clearPooledDynamicChildren(b)
	b:SetAttribute("NTRModuleCard", nil)
	b:SetAttribute("NTRModulePopupTarget", nil)
	local oldPopupAnchor = b:FindFirstChild("ModulePopupAnchor")
	if oldPopupAnchor then
		oldPopupAnchor:Destroy()
	end
	b.Text = string.upper(text or "")]=]

local changed
source, changed = replaceOnce(source, oldReset, newReset, "pooledButton popup target reset")
assert(changed, "pooledButton popup target reset was not applied.")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupPoolTargetResetRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "b:SetAttribute(\"NTRModulePopupTarget\", nil)"), "Popup target attribute reset was not installed.")
assert(findPlain(finalSource, "oldPopupAnchor:Destroy()"), "Old ModulePopupAnchor cleanup was not installed.")
assert(findPlain(finalSource, "card:SetAttribute(\"NTRModulePopupTarget\", selected and not isInstalled)"), "Buy module selected-card target attribute is missing.")
assert(findPlain(finalSource, "card:SetAttribute(\"NTRModulePopupTarget\", selected and not isInstalledHere)"), "Owned module selected-card target attribute is missing.")

info("PASS: pooled buttons now clear stale module popup target attributes and old ModulePopupAnchor children before reuse.")
info("Next: restart Play, click a locked/buyable module card, then rerun the alignment diagnostic. Expected dx near 0 and gap near 6.")

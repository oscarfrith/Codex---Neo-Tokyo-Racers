--!strict
-- Developer-product receipt template (inert until products exist and MarketplaceService.ProcessReceipt is bound).
-- Idempotent and save-first, never granting twice and never clawing a grant back:
--   1. Unknown/absent player, unloaded profile, or the same PurchaseId already in flight -> NotProcessedYet.
--   2. PurchaseId recorded and saved -> PurchaseGranted (no second grant).
--   3. PurchaseId recorded but not yet saved (earlier save failed) -> save again; success -> PurchaseGranted.
--   4. New PurchaseId -> apply grant and record it together in memory, save; failure -> NotProcessedYet and the
--      next retry only re-saves. If the server dies first, the unsaved grant is lost with memory and the retry on
--      another server grants exactly once.
-- Prerequisite before binding: the profile schema must persist PurchaseHistory (ProfileCompatibility/ProfileStore)
-- and bound its size; grants must be pure in-memory profile mutations.
local ReceiptProcessor = {}

export type Hooks = {
	getProfile: (Player) -> any?,
	saveNow: (Player) -> boolean,
	grants: { [number]: (profile: any, receipt: any) -> boolean },
	getPlayer: (number) -> Player?,
}

function ReceiptProcessor.new(hooks: Hooks)
	assert(type(hooks.getProfile) == "function" and type(hooks.saveNow) == "function" and type(hooks.getPlayer) == "function", "hooks required")
	local inFlight: { [string]: boolean } = {}
	return function(receipt: any): Enum.ProductPurchaseDecision
		local NotYet, Granted = Enum.ProductPurchaseDecision.NotProcessedYet, Enum.ProductPurchaseDecision.PurchaseGranted
		local key = tostring(receipt.PurchaseId)
		if inFlight[key] then return NotYet end
		local player = hooks.getPlayer(receipt.PlayerId)
		if not player then return NotYet end
		local profile = hooks.getProfile(player)
		if type(profile) ~= "table" then return NotYet end
		inFlight[key] = true
		local decision = NotYet
		local ok, err = pcall(function()
			profile.PurchaseHistory = profile.PurchaseHistory or {}
			local record = profile.PurchaseHistory[key]
			if record == nil then
				local grant = hooks.grants[receipt.ProductId]
				if not grant then warn("[ReceiptProcessor] No grant registered for product " .. tostring(receipt.ProductId)); return end
				local applied = grant(profile, receipt)
				if applied ~= true then warn("[ReceiptProcessor] Grant declined for " .. key); return end
				record = { ProductId = receipt.ProductId, At = os.time(), Saved = false }
				profile.PurchaseHistory[key] = record
			end
			if record.Saved ~= true then
				local saveOk, saved = pcall(hooks.saveNow, player)
				if not (saveOk and saved == true) then warn("[ReceiptProcessor] Save pending for " .. key .. "; will retry"); return end
				record.Saved = true
			end
			decision = Granted
		end)
		inFlight[key] = nil
		if not ok then warn("[ReceiptProcessor] " .. tostring(err)) end
		return decision
	end
end

return ReceiptProcessor

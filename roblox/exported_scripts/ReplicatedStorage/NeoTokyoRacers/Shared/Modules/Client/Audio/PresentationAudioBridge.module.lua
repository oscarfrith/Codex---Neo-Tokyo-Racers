-- NTR_PRESENTATION_AUDIO_BRIDGE_V1_3
local Bridge = {}
local subscribers = {}
local nextId = 0

local successCue = {
	Purchase = "UI.PurchaseSuccess",
	VehiclePurchase = "UI.VehiclePurchaseSuccess",
	ModuleEquip = "UI.ModuleEquipSuccess",
	DecorationPurchase = "UI.DecorationPurchaseSuccess",
	DecorationEquip = "UI.DecorationEquipSuccess",
	StructurePurchase = "UI.StructurePurchaseSuccess",
	StructureEquip = "UI.StructureEquipSuccess",
	Equip = "UI.EquipSuccess",
	Upgrade = "UI.UpgradeSuccess",
	Save = "UI.SaveSuccess",
}

local purchaseKinds = {
	Purchase = true,
	VehiclePurchase = true,
	DecorationPurchase = true,
	StructurePurchase = true,
}

function Bridge.Subscribe(callback)
	assert(type(callback) == "function", "PresentationAudioBridge.Subscribe requires a function")
	nextId += 1
	local id = nextId
	subscribers[id] = callback
	return function()
		subscribers[id] = nil
	end
end

function Bridge.Emit(cueId, payload)
	local id = tostring(cueId or "")
	if id == "" then return false end
	for _, callback in pairs(subscribers) do
		local ok, problem = pcall(callback, id, type(payload) == "table" and payload or {})
		if not ok then warn("[NTR Presentation Audio] subscriber failed safely: " .. tostring(problem)) end
	end
	return true
end

function Bridge.Result(kind, result, payload)
	local row = type(payload) == "table" and table.clone(payload) or {}
	row.Kind = tostring(kind or "")
	row.Message = type(result) == "table" and result.Message or nil
	local success = type(result) == "table" and result.Success == true
	if success then
		return Bridge.Emit(successCue[row.Kind] or "UI.SaveSuccess", row)
	end
	return Bridge.Emit(purchaseKinds[row.Kind] and "UI.PurchaseRejected" or "UI.ActionRejected", row)
end

return Bridge

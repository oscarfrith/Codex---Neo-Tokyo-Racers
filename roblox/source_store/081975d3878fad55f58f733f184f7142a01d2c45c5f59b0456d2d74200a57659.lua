--!strict
-- CollectionService binding that is safe under StreamingEnabled: an instance that streams in (or is tagged)
-- is bound once; streaming out, untagging or destruction runs its cleanup. Find world objects by tag, not path.
local CollectionService = game:GetService("CollectionService")

local Tags = {}

export type Watch = { destroy: (self: Watch) -> () }

-- onAdded(instance) may return a cleanup function (or an object with destroy/Destroy/Disconnect).
function Tags.watch(tag: string, onAdded: (Instance) -> any?): Watch
	assert(type(tag) == "string" and tag ~= "", "Tags.watch expects a tag")
	assert(type(onAdded) == "function", "Tags.watch expects an onAdded function")
	local cleanups: { [Instance]: any } = {}
	local destroyed = false

	local function release(instance: Instance)
		local cleanup = cleanups[instance]
		cleanups[instance] = nil
		if cleanup == nil or cleanup == true then return end
		local ok, err = pcall(function()
			if type(cleanup) == "function" then cleanup()
			elseif typeof(cleanup) == "RBXScriptConnection" then cleanup:Disconnect()
			elseif type(cleanup) == "table" then
				local method = cleanup.destroy or cleanup.Destroy or cleanup.Disconnect
				if method then method(cleanup) end
			end
		end)
		if not ok then warn("[Tags] cleanup failed for " .. tag .. ": " .. tostring(err)) end
	end

	local function bind(instance: Instance)
		if destroyed or cleanups[instance] ~= nil then return end
		cleanups[instance] = true
		local ok, result = pcall(onAdded, instance)
		if not ok then
			warn("[Tags] bind failed for " .. tag .. " on " .. instance:GetFullName() .. ": " .. tostring(result))
			return
		end
		if cleanups[instance] == true then cleanups[instance] = result == nil and true or result end
	end

	local added = CollectionService:GetInstanceAddedSignal(tag):Connect(bind)
	local removed = CollectionService:GetInstanceRemovedSignal(tag):Connect(release)
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do bind(instance) end

	local watch = {}
	function watch.destroy(_self)
		if destroyed then return end
		destroyed = true
		added:Disconnect()
		removed:Disconnect()
		local bound = {}
		for instance in pairs(cleanups) do table.insert(bound, instance) end
		for _, instance in ipairs(bound) do release(instance) end
	end
	return watch :: any
end

-- First currently tagged instance that is a descendant of root (or anywhere when root is nil).
function Tags.first(tag: string, root: Instance?): Instance?
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if root == nil or instance:IsDescendantOf(root) then return instance end
	end
	return nil
end

return Tags

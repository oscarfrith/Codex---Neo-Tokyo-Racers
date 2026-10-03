-- Exotic category, Stage B: content installer engine.
-- build_content.py puts a generated prelude in front of this file. The prelude defines two locals:
--   STAGE_B_DATA_JSON      the planned content (ids, attributes, parts, sockets, fixtures, fingerprints)
--   STAGE_B_CATALOGUE_GEN  scripts/exotic_category/catalogue/catalogue_gen.lua (function() -> sources)
-- Modes (baked into the data): AUDIT writes nothing. APPLY builds everything for the scope, all or
-- nothing. ROLLBACK removes exactly what APPLY created. Edit mode only, Backup v2 place only.
-- Writes are limited to: ServerStorage.Assets.Vehicles.Categories.EXOTIC,
-- ReplicatedStorage.Assets.VehiclePreviews.Categories.EXOTIC, the four Exotic folders in
-- ReplicatedStorage.Assets.VFX.VehicleTemplates, the VehicleCatalogData index source and its EXOTIC_n chunks.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DATA = HttpService:JSONDecode(STAGE_B_DATA_JSON)
local META = DATA.meta
local MODE = META.mode
local SCOPE = META.scope
local MARKER = META.marker
local CATEGORY = DATA.category.folder
local FIX = DATA.fixtures

assert(MODE == "AUDIT" or MODE == "APPLY" or MODE == "ROLLBACK", "Stage B: bad mode " .. tostring(MODE))
assert(SCOPE == "pilot" or SCOPE == "full", "Stage B: bad scope " .. tostring(SCOPE))
assert(game.PlaceId == META.placeId, "Stage B: wrong place. Expected " .. tostring(META.placeId) .. ", got " .. tostring(game.PlaceId))
assert(not RunService:IsRunning(), "Stage B: Edit mode only. Stop Play first.")
do
	local ok, isEdit = pcall(function() return RunService:IsEdit() end)
	assert(not ok or isEdit, "Stage B: Edit mode only.")
end

-- ---------------------------------------------------------------------------------------------
-- Findings
-- ---------------------------------------------------------------------------------------------
local blockers, warns, infos = {}, {}, {}
local function BLOCKER(code, message) table.insert(blockers, code .. ": " .. tostring(message)) end
local function WARN(code, message) table.insert(warns, code .. ": " .. tostring(message)) end
local function INFO(code, message) table.insert(infos, code .. ": " .. tostring(message)) end

local function capped(list, limit)
	local out = {}
	for i = 1, math.min(#list, limit) do out[i] = list[i] end
	if #list > limit then table.insert(out, "(" .. tostring(#list - limit) .. " more not shown)") end
	return out
end

local result = { mode = MODE, scope = SCOPE, contentHash = META.contentHash, fixture = META.fixture == true, changed = 0 }

local function finish(ok, extra)
	result.ok = ok
	if extra then
		for key, value in pairs(extra) do result[key] = value end
	end
	result.summary = string.format("BLOCKER=%d WARN=%d INFO=%d", #blockers, #warns, #infos)
	result.findings = { blockers = capped(blockers, 40), warns = capped(warns, 30), infos = capped(infos, 30) }
	return result
end

-- ---------------------------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------------------------
local function descend(root, names)
	local current = root
	for _, name in ipairs(names) do
		if not current then return nil end
		current = current:FindFirstChild(name)
	end
	return current
end

local function childrenNamed(parent, name)
	local list = {}
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name then table.insert(list, child) end
	end
	return list
end

local function isAscii(text)
	return string.find(text, "[^\32-\126]") == nil
end

local function rgb(value)
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function vec(value)
	return Vector3.new(value[1], value[2], value[3])
end

local function decodeAttribute(value)
	if type(value) == "table" then
		assert(value.__c3, "Stage B: unsupported attribute table")
		return rgb(value.__c3)
	end
	return value
end

local function setAttributes(instance, attributes)
	if not attributes then return end
	for name, value in pairs(attributes) do
		instance:SetAttribute(name, decodeAttribute(value))
	end
end

local function makeFolder(name, attributes, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	setAttributes(folder, attributes)
	folder.Parent = parent
	return folder
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= tolerance
end

local function own(instance)
	return instance:GetAttribute("InstalledBy") == MARKER
end

-- Order-independent fingerprint of everything under a root: count plus a sum of name/class hashes.
local function signature(root)
	local count, sum = 0, 0
	for _, item in ipairs(root:GetDescendants()) do
		count += 1
		local text = item.ClassName .. ":" .. item.Name
		local hash = 7
		for i = 1, #text do hash = (hash * 31 + string.byte(text, i)) % 2147483647 end
		sum = (sum + hash) % 2147483647
	end
	return tostring(count) .. ":" .. tostring(sum)
end

-- ---------------------------------------------------------------------------------------------
-- Locations
-- ---------------------------------------------------------------------------------------------
local categories = descend(ServerStorage, { "Assets", "Vehicles", "Categories" })
local previewCategories = descend(ReplicatedStorage, { "Assets", "VehiclePreviews", "Categories" })
local vfxTemplates = descend(ReplicatedStorage, { "Assets", "VFX", "VehicleTemplates" })
local catalogueIndex = descend(ReplicatedStorage, { "Modules", "Game", "Vehicles", "VehicleCatalogData" })

if not categories then BLOCKER("path", "ServerStorage.Assets.Vehicles.Categories is missing") end
if not previewCategories then BLOCKER("path", "ReplicatedStorage.Assets.VehiclePreviews.Categories is missing") end
if not vfxTemplates then BLOCKER("path", "ReplicatedStorage.Assets.VFX.VehicleTemplates is missing") end
if not (catalogueIndex and catalogueIndex:IsA("ModuleScript")) then BLOCKER("path", "ReplicatedStorage.Modules.Game.Vehicles.VehicleCatalogData is missing or not a ModuleScript") end
if #blockers > 0 then
	return finish(false, { state = "unknown" })
end

local piercer = categories:FindFirstChild(DATA.category.afterFolder)
local VFX_NAMES = {}
for _, template in ipairs(DATA.vfx.templates) do table.insert(VFX_NAMES, template.name) end

local function exoticChunks()
	local list = {}
	for _, child in ipairs(catalogueIndex:GetChildren()) do
		if string.match(child.Name, "^" .. CATEGORY .. "_%d+$") then table.insert(list, child) end
	end
	return list
end

-- ---------------------------------------------------------------------------------------------
-- State: absent / installed-pilot / installed-full / partial-or-foreign
-- ---------------------------------------------------------------------------------------------
local function readState()
	local found = { server = childrenNamed(categories, CATEGORY), preview = childrenNamed(previewCategories, CATEGORY), vfx = {}, chunks = exoticChunks() }
	local present, expected, foreign, problems = 0, 0, false, {}
	local function consider(label, list)
		expected += 1
		if #list == 0 then
			table.insert(problems, label .. " absent")
			return
		end
		present += 1
		if #list > 1 then
			foreign = true
			table.insert(problems, label .. " has " .. tostring(#list) .. " siblings with that name")
		end
		for _, item in ipairs(list) do
			if not own(item) then
				foreign = true
				table.insert(problems, label .. " exists without the installer marker")
			end
		end
	end
	consider("server category", found.server)
	consider("preview category", found.preview)
	for _, name in ipairs(VFX_NAMES) do
		found.vfx[name] = childrenNamed(vfxTemplates, name)
		consider("VFX template " .. name, found.vfx[name])
	end
	expected += 1
	if #found.chunks > 0 then
		present += 1
		-- A chunk is this installer's own only when it carries the marker. The name alone does not make it so.
		for _, chunk in ipairs(found.chunks) do
			if not chunk:IsA("ModuleScript") then
				foreign = true
				table.insert(problems, "chunk " .. chunk.Name .. " is not a ModuleScript")
			elseif not own(chunk) then
				foreign = true
				table.insert(problems, "chunk " .. chunk.Name .. " exists without the installer marker")
			end
		end
	else
		table.insert(problems, "catalogue chunks absent")
	end
	-- A category that claims the same id under another name is foreign.
	for _, root in ipairs({ categories, previewCategories }) do
		for _, child in ipairs(root:GetChildren()) do
			if child.Name ~= CATEGORY and (child:GetAttribute("CategoryId") == DATA.category.attributes.CategoryId or string.lower(child.Name) == string.lower(CATEGORY)) then
				foreign = true
				table.insert(problems, child:GetFullName() .. " also claims the Exotic category")
			end
		end
	end
	local state
	local installedScope, installedHash
	if present == 0 and not foreign then
		state = "absent"
	elseif present == expected and not foreign then
		local server, preview = found.server[1], found.preview[1]
		installedScope = server:GetAttribute("InstalledScope")
		installedHash = server:GetAttribute("InstalledContentHash")
		if (installedScope == "pilot" or installedScope == "full") and preview:GetAttribute("InstalledScope") == installedScope and preview:GetAttribute("InstalledContentHash") == installedHash then
			state = "installed-" .. installedScope
		else
			state = "partial-or-foreign"
			table.insert(problems, "server and preview markers disagree")
		end
	else
		state = "partial-or-foreign"
	end
	return { state = state, found = found, problems = problems, installedScope = installedScope, installedHash = installedHash }
end

-- Have the created roots been edited since they were installed?
local function signatureProblems(found)
	local problems = {}
	local server, preview = found.server[1], found.preview[1]
	if signature(server) ~= server:GetAttribute("InstalledServerSignature") then table.insert(problems, server:GetFullName()) end
	if signature(preview) ~= preview:GetAttribute("InstalledPreviewSignature") then table.insert(problems, preview:GetFullName()) end
	for _, name in ipairs(VFX_NAMES) do
		local folder = found.vfx[name][1]
		if signature(folder) ~= folder:GetAttribute("InstalledSignature") then table.insert(problems, folder:GetFullName()) end
	end
	return problems
end

-- ---------------------------------------------------------------------------------------------
-- Catalogue: compare what the generator makes from the live authoring tree with what is installed
-- ---------------------------------------------------------------------------------------------
local function catalogueState()
	local ok, generated = pcall(STAGE_B_CATALOGUE_GEN)
	if not ok then return nil, { "generator failed: " .. tostring(generated) } end
	local diffs, expectedNames = {}, {}
	if catalogueIndex.Source ~= generated.index then table.insert(diffs, "index source differs") end
	for _, chunk in ipairs(generated.chunks) do
		expectedNames[chunk.name] = true
		local list = childrenNamed(catalogueIndex, chunk.name)
		if #list ~= 1 or not list[1]:IsA("ModuleScript") then
			table.insert(diffs, chunk.name .. " missing or ambiguous")
		elseif list[1].Source ~= chunk.source then
			table.insert(diffs, chunk.name .. " source differs")
		end
	end
	for _, child in ipairs(catalogueIndex:GetChildren()) do
		if not expectedNames[child.Name] then table.insert(diffs, "unexpected child " .. child.Name) end
	end
	return generated, diffs
end

-- ---------------------------------------------------------------------------------------------
-- Donors (live Piercer content that is cloned at install time; never changed)
-- ---------------------------------------------------------------------------------------------
local donorCockpits, donorModules = {}, {}
if piercer then
	for _, item in ipairs(piercer:GetDescendants()) do
		if item:IsA("Model") then
			local cockpitId, moduleId = item:GetAttribute("CockpitId"), item:GetAttribute("ModuleId")
			if type(cockpitId) == "string" then donorCockpits[cockpitId] = item end
			if type(moduleId) == "string" then donorModules[moduleId] = item end
		end
	end
end

local SLOT_BY_ID = {}
for _, slot in ipairs(DATA.slots) do SLOT_BY_ID[slot.slotId] = slot end

local function donorRoot()
	local cockpit = donorCockpits[FIX.rootDonorCockpitId]
	local root = cockpit and cockpit.PrimaryPart
	return cockpit, root
end

local function donorPathsFolder(moduleId)
	local donor = donorModules[moduleId]
	local folder = donor and donor:FindFirstChild("VehiclePerformanceV2UpgradePaths")
	return folder
end

-- ---------------------------------------------------------------------------------------------
-- Preflight (read-only)
-- ---------------------------------------------------------------------------------------------
local function preflightStructure()
	local first = categories:GetChildren()[1]
	if not piercer then
		BLOCKER("piercer", "Categories." .. DATA.category.afterFolder .. " is missing")
	else
		if first ~= piercer then BLOCKER("order", DATA.category.afterFolder .. " is not the first child of Categories (first is " .. tostring(first and first.Name) .. ")") end
		if piercer:GetAttribute("CategoryId") ~= "bruiser" then BLOCKER("piercer", "PIERCER CategoryId is not bruiser") end
	end
end

local function preflightDonors()
	local cockpit, root = donorRoot()
	if not (cockpit and root and root.Name == "CockpitRoot_DoNotRename" and root:IsA("Part")) then
		BLOCKER("donor-root", "Piercer cockpit " .. tostring(FIX.rootDonorCockpitId) .. " or its CockpitRoot_DoNotRename is missing")
	else
		local size = FIX.rootSize
		if not (near(root.Size.X, size[1], 0.001) and near(root.Size.Y, size[2], 0.001) and near(root.Size.Z, size[3], 0.001)) then
			BLOCKER("donor-root", "donor root size is " .. tostring(root.Size) .. ", expected " .. table.concat(size, " x "))
		end
		if root:GetAttribute("TemplateRole") ~= "VehicleRoot" then BLOCKER("donor-root", "donor root TemplateRole is not VehicleRoot") end
		local want, have = {}, {}
		for _, child in ipairs(FIX.rootDonorChildren) do
			local key = child.class .. ":" .. child.name
			want[key] = (want[key] or 0) + 1
		end
		for _, child in ipairs(root:GetChildren()) do
			local key = child.ClassName .. ":" .. child.Name
			have[key] = (have[key] or 0) + 1
		end
		for key, count in pairs(want) do
			if have[key] ~= count then BLOCKER("donor-root", "donor root child drift: expected " .. tostring(count) .. " x " .. key .. ", found " .. tostring(have[key] or 0)) end
		end
		for key, count in pairs(have) do
			if not want[key] then BLOCKER("donor-root", "donor root has an unexpected child " .. key .. " x " .. tostring(count)) end
		end
		local slots = cockpit:FindFirstChild("ModuleSlots")
		for _, slot in ipairs(DATA.slots) do
			local folder = slots and slots:FindFirstChild("SLOT_" .. slot.mountDonorSlot)
			local mount = folder and folder:FindFirstChild("Mount_DoNotRename")
			local attachment = mount and mount:FindFirstChild("MountAttachment")
			if not (mount and mount:IsA("BasePart") and attachment and attachment:IsA("Attachment")) then
				BLOCKER("donor-mount", "donor mount SLOT_" .. slot.mountDonorSlot .. ".Mount_DoNotRename.MountAttachment is missing")
			elseif mount:GetAttribute("TemplateRole") ~= "FixedSlotMount" then
				BLOCKER("donor-mount", "donor mount SLOT_" .. slot.mountDonorSlot .. " TemplateRole is not FixedSlotMount")
			end
		end
	end
	for _, def in ipairs(DATA.cockpits) do
		local tierDonor = donorCockpits[def.tierDonorCockpitId]
		if not tierDonor then
			WARN("donor-tier", "Piercer cockpit " .. tostring(def.tierDonorCockpitId) .. " (same tier as " .. def.id .. ") is missing; audio profile cannot be checked")
		elseif tierDonor:GetAttribute("StandardAudioProfileId") ~= def.attributes.StandardAudioProfileId then
			WARN("donor-tier", def.id .. " StandardAudioProfileId " .. tostring(def.attributes.StandardAudioProfileId) .. " differs from live " .. def.tierDonorCockpitId .. " (" .. tostring(tierDonor:GetAttribute("StandardAudioProfileId")) .. ")")
		end
	end
	local checkedRoots, checkedPaths = {}, {}
	for _, def in ipairs(DATA.modules) do
		local slot = SLOT_BY_ID[def.slot]
		if not checkedRoots[slot.rootDonor] then
			checkedRoots[slot.rootDonor] = true
			local donor = donorModules[slot.rootDonor]
			local root = donor and donor.PrimaryPart
			local attachment = root and root:FindFirstChild("MountAttachment")
			if not (root and root.Name == "ModuleRoot_DoNotRename" and root:IsA("Part") and attachment and attachment:IsA("Attachment")) then
				BLOCKER("donor-module", "Piercer module " .. slot.rootDonor .. " or its ModuleRoot_DoNotRename.MountAttachment is missing")
			elseif root:GetAttribute("TemplateRole") ~= "ModuleRoot" then
				BLOCKER("donor-module", slot.rootDonor .. " root TemplateRole is not ModuleRoot")
			end
		end
		if def.upgradePathDonor and not checkedPaths[def.upgradePathDonor] then
			checkedPaths[def.upgradePathDonor] = true
			local folder = donorPathsFolder(def.upgradePathDonor)
			local count = 0
			if folder then
				for _, child in ipairs(folder:GetChildren()) do
					if child:IsA("Folder") then count += 1 end
				end
			end
			if count == 0 then BLOCKER("donor-paths", "upgrade path donor " .. def.upgradePathDonor .. " is missing or has no path folders") end
		end
	end
	for _, name in ipairs(DATA.vfx.requiredStock) do
		local folder = vfxTemplates:FindFirstChild(name)
		if not (folder and folder:IsA("Folder")) then
			BLOCKER("vfx-stock", "stock VFX template " .. name .. " is missing")
		elseif own(folder) then
			BLOCKER("vfx-stock", "stock VFX template " .. name .. " carries the installer marker")
		end
	end
	for _, template in ipairs(DATA.vfx.templates) do
		local source = vfxTemplates:FindFirstChild(template.source)
		local host = source and source:FindFirstChild("TemplateHost_Invisible", true)
		if source and not (host and host:IsA("BasePart")) then BLOCKER("vfx-stock", template.source .. " has no TemplateHost_Invisible part") end
	end
end

local function preflightPlan()
	local cockpitIds, moduleIds, strings = {}, {}, {}
	for _, def in ipairs(DATA.modules) do
		if moduleIds[def.id] then BLOCKER("plan", "duplicate planned ModuleId " .. def.id) end
		moduleIds[def.id] = def
		local slot = SLOT_BY_ID[def.slot]
		if not slot then
			BLOCKER("plan", def.id .. " names an unknown slot " .. tostring(def.slot))
		else
			if def.attributes.ModuleType ~= slot.attributes.ModuleType then BLOCKER("plan", def.id .. " ModuleType does not match slot " .. def.slot) end
			if def.attributes.ModuleFolder ~= slot.attributes.AllowedModuleFolder then BLOCKER("plan", def.id .. " ModuleFolder does not match slot " .. def.slot) end
			if def.folderPath[1] ~= slot.attributes.AllowedModuleFolder then BLOCKER("plan", def.id .. " is not filed under " .. slot.attributes.AllowedModuleFolder) end
		end
		if def.attributes.ModuleId ~= def.id then BLOCKER("plan", def.id .. " ModuleId attribute differs from the model name") end
		if def.attributes.CategoryId ~= DATA.category.attributes.CategoryId then BLOCKER("plan", def.id .. " CategoryId is wrong") end
		if not DATA.shapes[def.shape] then BLOCKER("plan", def.id .. " shape " .. tostring(def.shape) .. " is not in the data") end
		if not def.upgradePathDonor and not (def.upgradePaths and #def.upgradePaths > 0) then BLOCKER("plan", def.id .. " has neither an upgrade path donor nor explicit paths") end
		table.insert(strings, def.id)
		for name, value in pairs(def.attributes) do
			table.insert(strings, name)
			if type(value) == "string" then table.insert(strings, value) end
		end
	end
	for _, def in ipairs(DATA.cockpits) do
		if cockpitIds[def.id] then BLOCKER("plan", "duplicate planned CockpitId " .. def.id) end
		cockpitIds[def.id] = def
		if not DATA.shapes[def.shape] then BLOCKER("plan", def.id .. " shape is not in the data") end
		for name, value in pairs(def.attributes) do
			table.insert(strings, name)
			if type(value) == "string" then
				table.insert(strings, value)
				if string.sub(name, 1, 7) == "Default" and string.sub(name, -8) == "ModuleId" and not moduleIds[value] then
					BLOCKER("plan", def.id .. " " .. name .. " = " .. value .. " is not in this scope")
				end
			end
		end
		for _, slot in ipairs(DATA.slots) do
			for _, name in ipairs(slot.defaultAttributes) do
				local moduleId = def.attributes[name]
				local module = moduleId and moduleIds[moduleId]
				if not module then
					BLOCKER("plan", def.id .. " has no " .. name)
				elseif module.slot ~= slot.slotId then
					BLOCKER("plan", def.id .. " " .. name .. " points at a module of slot " .. module.slot)
				end
			end
		end
	end
	for _, def in ipairs(DATA.modules) do
		local reference = def.attributes.RatingReferenceCockpitId
		if reference ~= nil and not cockpitIds[reference] then BLOCKER("plan", def.id .. " RatingReferenceCockpitId " .. tostring(reference) .. " is not in this scope") end
		local source = def.attributes.SourceCockpitId
		if source ~= nil and not cockpitIds[source] then BLOCKER("plan", def.id .. " SourceCockpitId " .. tostring(source) .. " is not in this scope") end
	end
	for _, text in ipairs(strings) do
		if not isAscii(text) then BLOCKER("ascii", "non-ASCII text in the plan: " .. string.format("%q", text)) end
	end
	return cockpitIds, moduleIds
end

-- No id or name may collide with anything this installer did not create.
local function preflightCollisions(cockpitIds, moduleIds, ownRoots)
	local names, lowerIds = {}, {}
	for id, def in pairs(cockpitIds) do names[def.model] = true; lowerIds[string.lower(id)] = true end
	for id in pairs(moduleIds) do names[id] = true; lowerIds[string.lower(id)] = true end
	local reported = 0
	for _, root in ipairs({ categories, previewCategories }) do
		for _, item in ipairs(root:GetDescendants()) do
			if item:IsA("Model") then
				local inside = false
				for _, ownRoot in ipairs(ownRoots) do
					if item == ownRoot or item:IsDescendantOf(ownRoot) then inside = true; break end
				end
				if not inside then
					local cockpitId, moduleId = item:GetAttribute("CockpitId"), item:GetAttribute("ModuleId")
					local lowerName = string.lower(item.Name)
					local clash = names[item.Name] or (cockpitId ~= nil and lowerIds[string.lower(tostring(cockpitId))]) or (moduleId ~= nil and lowerIds[string.lower(tostring(moduleId))])
					if clash then
						reported += 1
						if reported <= 10 then BLOCKER("collision", item:GetFullName() .. " already uses a planned id or name") end
					elseif cockpitId ~= nil or moduleId ~= nil then
						-- The free-roam HUDs find a cockpit by substring, in descendant order.
						for id in pairs(cockpitIds) do
							if string.find(lowerName, id, 1, true) or string.find(string.lower(tostring(cockpitId or moduleId)), id, 1, true) then
								WARN("substring", item:GetFullName() .. " contains the cockpit id " .. id .. " (HUD lookups match by substring)")
							end
						end
					end
				end
			end
		end
	end
end

-- Compare the Studio blockout with fingerprints generated from the repository spec.
local function preflightBlockout()
	local holder = workspace:FindFirstChild("VehicleCategoryBlockouts")
	local block = holder and holder:FindFirstChild(CATEGORY)
	if not block then
		WARN("blockout", "Workspace.VehicleCategoryBlockouts." .. CATEGORY .. " is missing; geometry comes from the repository spec and could not be checked against Studio")
		return
	end
	local measured = {}
	for _, cell in ipairs(block:GetChildren()) do
		if cell:IsA("Model") and cell:GetAttribute("CockpitId") ~= nil and cell:GetAttribute("KitId") ~= nil then
			local label = cell:FindFirstChild("Label")
			if label and label:IsA("BasePart") then
				local origin = label.Position - Vector3.new(0, 12.5, 0)
				for _, group in ipairs(cell:GetChildren()) do
					local slotId = group:IsA("Model") and group:GetAttribute("SlotId")
					if slotId then
						local key
						if slotId == "Cockpit" then
							key = "Cockpit/" .. tostring(cell:GetAttribute("CockpitId"))
						else
							key = tostring(slotId) .. "/" .. tostring(group:GetAttribute("ModuleId"))
						end
						if DATA.fingerprints[key] and not measured[key] then
							local n, sx, sax, sy, sz, ss = 0, 0, 0, 0, 0, 0
							for _, part in ipairs(group:GetChildren()) do
								if part:IsA("BasePart") then
									local offset = part.Position - origin
									n += 1
									sx += offset.X; sax += math.abs(offset.X); sy += offset.Y; sz += offset.Z
									ss += part.Size.X + part.Size.Y + part.Size.Z
								end
							end
							measured[key] = { n, sx, sax, sy, sz, ss }
						end
					end
				end
			end
		end
	end
	-- strict (first install): a differing showroom block stops the install. warn (refinement): the repository spec is
	-- the source of geometry and the showroom block is design scaffolding, so a difference is reported only.
	local report = META.blockoutCheck == "warn" and WARN or BLOCKER
	local checked, differing = 0, 0
	for key, want in pairs(DATA.fingerprints) do
		local have = measured[key]
		checked += 1
		local same = have ~= nil and have[1] == want[1]
		if same then
			for i = 2, 6 do
				if not near(have[i], want[i], 0.05) then same = false end
			end
		end
		if not same then
			differing += 1
			if differing <= 8 then
				report("blockout", key .. " differs from the spec: Studio " .. (have and table.concat(have, " ") or "absent") .. " / spec " .. table.concat(want, " "))
			end
		end
	end
	if differing == 0 then
		INFO("blockout", tostring(checked) .. " groups match the spec fingerprints (part count, position sums, size sums)")
	elseif differing > 8 then
		report("blockout", tostring(differing) .. " groups differ in total")
	end
end

-- Stage A code and flag. Stage A arrives in separate parts (catalogue split, server sources, client sources),
-- so the split catalogue alone does not prove the rest is there.
-- Server sources are required (BLOCKER): without them the old GarageCatalogService publishes EXOTIC with no
-- FeatureFlag gate, the old GarageServer sells it through the old buy path, and the seats ignore the
-- per-cockpit offsets. A source that cannot be read is treated as not installed.
-- Client sources and the two artwork rows are reported (WARN): the server gate keeps the category hidden
-- while the flag is off, so they are needed before the flag is turned on, not before the content exists.
local function preflightStageA()
	local probes = {
		{ ServerStorage, { "Modules", "Game", "Garage", "GarageCatalogService" }, "FeatureFlag", "category FeatureFlag gate", true },
		{ ServerStorage, { "Modules", "Game", "Garage", "GarageServer" }, "FeatureFlag", "purchase FeatureFlag gate", true },
		{ ServerStorage, { "Modules", "Game", "Vehicles", "DriverSeatServer" }, "DriverSeatOffsetX", "per-cockpit driver seat offset", true },
		{ ServerStorage, { "Modules", "Game", "Garage", "VehicleBuildService" }, "PassengerSeatOffsetX", "per-cockpit passenger seat offset", true },
		{ ReplicatedStorage, { "Modules", "Game", "Garage", "GarageUI" }, "RailLabel", "slot RailLabel", false },
		{ ReplicatedStorage, { "Modules", "Game", "UI", "GarageWorkspaceUI" }, "FrontBody", "Front Body and Rear Body rail rows", false },
		{ ReplicatedStorage, { "Modules", "Game", "UI", "GarageModuleCardViewModel" }, "CardTitle", "module CardTitle", false },
		{ ReplicatedStorage, { "Modules", "Game", "Vehicles", "Performance", "VehiclePerformanceResolver" }, "RatingReferenceCockpitId", "module rating reference", false },
		{ ReplicatedStorage, { "Modules", "Game", "Garage", "PreviewCameraClient" }, "FrontBody", "Front Body and Rear Body preview cameras", false },
	}
	for _, probe in ipairs(probes) do
		local service, names, needle, what, required = probe[1], probe[2], probe[3], probe[4], probe[5]
		local path = service.Name .. "." .. table.concat(names, ".")
		local report = required and BLOCKER or WARN
		local target = descend(service, names)
		local ok, source = pcall(function() return target and target.Source end)
		if not (ok and type(source) == "string") then
			report("stage-a", "could not read " .. path .. " to check for the " .. what .. (required and "; Stage A server sources must be installed before Stage B content" or ""))
		elseif not string.find(source, needle, 1, true) then
			report("stage-a", path .. " has no " .. needle .. ": Stage A (" .. what .. ") is not installed" .. (required and "; install the Stage A server sources first" or "; install the Stage A client sources before the flag is turned on"))
		end
	end
	local artwork = descend(ReplicatedStorage, { "Config", "UI", "GarageReplacement", "ModuleArtwork" })
	for _, name in ipairs({ "FrontBody", "RearBody" }) do
		if not (artwork and artwork:FindFirstChild(name)) then
			WARN("stage-a", "ReplicatedStorage.Config.UI.GarageReplacement.ModuleArtwork." .. name .. " is missing: Stage A (client config) is not installed; install it before the flag is turned on")
		end
	end
	local config = ServerStorage:FindFirstChild("Config")
	local flagName = "Flag_" .. tostring(DATA.category.attributes.FeatureFlag)
	local flag = config and config:GetAttribute(flagName)
	INFO("flag", "ServerStorage.Config " .. flagName .. " = " .. tostring(flag) .. (flag == nil and " (unset: the Creator Dashboard value or the code default applies)" or ""))
end

-- Seat offsets rest on an assumed sitting height until the pilot Play test measures it
-- (data/seats.json pilotAcceptance, measure_seat.lua). The pilot may go in unmeasured; the full scope may not.
local function preflightSeats()
	local seats = type(META.seats) == "table" and META.seats or {}
	if seats.accepted == true then
		INFO("seats", "seat offsets accepted (" .. tostring(seats.decision) .. "): " .. tostring(seats.summary))
		return
	end
	local text = "seat offsets are not accepted (data/seats.json pilotAcceptance.decision = " .. tostring(seats.decision) .. "): " .. tostring(seats.summary)
	if SCOPE == "full" then
		BLOCKER("seats", text .. ". Run measure_seat.lua in the pilot Play test, record the result in data/seats.json and rebuild.")
	else
		WARN("seats", text .. ". Run measure_seat.lua in the pilot Play test and record the result before the full scope.")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Builders (everything here works on detached instances)
-- ---------------------------------------------------------------------------------------------
local CHANNELS = DATA.channels

local function paletteFrom(palette)
	local out = {}
	for key, value in pairs(palette) do out[key] = rgb(value) end
	return out
end

-- One part, exactly as scripts/vehicle_blockouts/builder.lua makes it, in root space.
local function makePart(record, palette)
	local shape = record[1]
	local sx, sy, sz = record[2], record[3], record[4]
	local part
	local fix = CFrame.new()
	if shape == "wedge" then
		part = Instance.new("WedgePart")
		part.Size = Vector3.new(sx, sy, sz)
	else
		part = Instance.new("Part")
		if shape == "block" then
			part.Size = Vector3.new(sx, sy, sz)
		elseif shape == "ball" then
			local d = math.min(sx, sy, sz)
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(d, d, d)
		elseif shape == "cyl_x" then
			part.Shape = Enum.PartType.Cylinder
			local d = math.min(sy, sz)
			part.Size = Vector3.new(sx, d, d)
		elseif shape == "cyl_y" then
			part.Shape = Enum.PartType.Cylinder
			local d = math.min(sx, sz)
			part.Size = Vector3.new(sy, d, d)
			fix = CFrame.Angles(0, 0, math.rad(90))
		elseif shape == "cyl_z" then
			part.Shape = Enum.PartType.Cylinder
			local d = math.min(sx, sy)
			part.Size = Vector3.new(sz, d, d)
			fix = CFrame.Angles(0, math.rad(90), 0)
		else
			error("Stage B: unknown shape " .. tostring(shape))
		end
	end
	local channel = CHANNELS[record[11]]
	assert(channel, "Stage B: unknown channel " .. tostring(record[11]))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material[channel.material]
	part.Transparency = channel.transparency
	part.Color = assert(palette[record[11]], "Stage B: no colour for channel " .. tostring(record[11]))
	part.Name = shape .. "_" .. channel.suffix
	part:SetAttribute("PaintChannel", channel.paintChannel)
	part.CFrame = CFrame.new(record[5], record[6], record[7]) * CFrame.fromOrientation(math.rad(record[8]), math.rad(record[9]), math.rad(record[10])) * fix
	return part
end

-- Channel folders for one cockpit or module, in the live Piercer child order.
local function makeChannelFolders(folderDefs, parent)
	local byChannel = {}
	for _, def in ipairs(folderDefs) do
		local folder = makeFolder(def.name, def.attributes, parent)
		if def.channel then byChannel[def.channel] = folder end
	end
	return byChannel
end

local function fillParts(shape, palette, byChannel, ownerName)
	local count = 0
	for _, record in ipairs(shape.parts) do
		local folder = byChannel[record[11]]
		assert(folder, "Stage B: " .. ownerName .. " has a part on channel " .. tostring(record[11]) .. " but no folder for it")
		makePart(record, palette).Parent = folder
		count += 1
	end
	return count
end

local function makeUnderglowEmitter(def, parent)
	local part = Instance.new("Part")
	part.Name = "cockpit underglow"
	part.Size = vec(def.size)
	part.CFrame = CFrame.new(vec(def.position))
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Transparency = 1
	part.Material = Enum.Material.Plastic
	part.Color = Color3.fromRGB(163, 162, 165)
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("PaintChannel", "Underglow")
	part:SetAttribute("VehicleCosmeticId", "Underglow")
	local light = Instance.new("SurfaceLight")
	light.Name = "UnderglowSurfaceLight"
	light.Enabled = false
	light.Brightness = def.brightness
	light.Range = def.range
	light.Angle = def.angle
	light.Face = Enum.NormalId[def.face]
	light.Color = Color3.fromRGB(255, 255, 255)
	light.Shadows = false
	light:SetAttribute("LightChannel", "Underglow")
	light:SetAttribute("PaintChannel", "Underglow")
	light:SetAttribute("VehicleCosmeticId", "Underglow")
	light.Parent = part
	part.Parent = parent
	return part
end

-- CockpitRoot_DoNotRename: a clone of the live Piercer root with its children re-placed for the Exotic.
local function makeCockpitRoot()
	local _, source = donorRoot()
	local sourceFrame = source.CFrame
	local lensRotation = {}
	for name in pairs(FIX.lenses) do
		local lens = source:FindFirstChild(name)
		if lens and lens:IsA("BasePart") then lensRotation[name] = sourceFrame:ToObjectSpace(lens.CFrame).Rotation end
	end
	local root = source:Clone()
	root.CFrame = CFrame.new()
	for _, def in ipairs(FIX.hoverDust) do
		local socket = root:FindFirstChild(def.name)
		assert(socket and socket:IsA("Attachment"), "Stage B: donor root has no " .. def.name)
		socket.Position = vec(def.position)
		socket.Orientation = Vector3.zero
	end
	local mount = root:FindFirstChild("UNDERGLOW_MOUNT_DoNotRename")
	assert(mount and mount:IsA("Attachment"), "Stage B: donor root has no UNDERGLOW_MOUNT_DoNotRename")
	mount.Position = vec(FIX.underglow.mountPosition)
	if FIX.underglow.removeLightsUnderMount then
		for _, child in ipairs(mount:GetChildren()) do child:Destroy() end
	end
	local emitters = root:FindFirstChild("UNDERGLOW_EMITTERS_DoNotRename")
	assert(emitters and emitters:IsA("Folder"), "Stage B: donor root has no UNDERGLOW_EMITTERS_DoNotRename")
	for _, child in ipairs(emitters:GetChildren()) do child:Destroy() end
	for _, def in ipairs(FIX.underglow.emitters) do makeUnderglowEmitter(def, emitters) end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("BasePart") then
			local def = FIX.lenses[child.Name]
			if def then
				child.CFrame = CFrame.new(vec(def.position)) * (lensRotation[child.Name] or CFrame.new())
			else
				child:Destroy()
			end
		end
	end
	return root
end

local function makeSlots(parent)
	local donorCockpit = donorRoot()
	local donorSlots = donorCockpit:FindFirstChild("ModuleSlots")
	local slots = Instance.new("Folder")
	slots.Name = "ModuleSlots"
	for _, slot in ipairs(DATA.slots) do
		local folder = makeFolder("SLOT_" .. slot.slotId, slot.attributes, slots)
		local mount = donorSlots:FindFirstChild("SLOT_" .. slot.mountDonorSlot):FindFirstChild("Mount_DoNotRename"):Clone()
		mount.CFrame = CFrame.new()
		setAttributes(mount, slot.mountAttributes)
		local attachment = mount:FindFirstChild("MountAttachment")
		attachment.Position = Vector3.zero
		attachment.Orientation = Vector3.zero
		mount.Parent = folder
	end
	slots.Parent = parent
	return slots
end

local function buildCockpit(def)
	local model = Instance.new("Model")
	model.Name = def.model
	local asset = Instance.new("Model")
	asset.Name = "ASSET_ReplaceWithYourCockpitModel"
	local byChannel = makeChannelFolders(DATA.cockpitFolders, asset)
	local parts = fillParts(DATA.shapes[def.shape], paletteFrom(def.palette), byChannel, def.model)
	assert(parts == def.partCount, "Stage B: " .. def.model .. " built " .. tostring(parts) .. " parts, expected " .. tostring(def.partCount))
	local root = makeCockpitRoot()
	root.Parent = asset
	asset.PrimaryPart = root
	asset.Parent = model
	makeSlots(model)
	makeFolder("INSTALLED_MODULES_Runtime", nil, model)
	makeFolder("TOTAL_STATS_Runtime", nil, model)
	makeFolder("VFXAttachments", { Note = "Actual VFX sockets are Attachments under CockpitRoot so particles emit correctly. Move/rotate the attachments to refine." }, model)
	model.PrimaryPart = root
	setAttributes(model, def.attributes)
	return model, parts
end

local function buildModule(def)
	local slot = SLOT_BY_ID[def.slot]
	local model = Instance.new("Model")
	model.Name = def.id
	local byChannel = makeChannelFolders(DATA.moduleFolders[slot.folderSet], model)
	local shape = DATA.shapes[def.shape]
	local parts = fillParts(shape, paletteFrom(def.palette), byChannel, def.id)
	assert(parts == def.partCount and parts > 0, "Stage B: " .. def.id .. " built " .. tostring(parts) .. " parts, expected " .. tostring(def.partCount))
	local paths = Instance.new("Folder")
	paths.Name = "VehiclePerformanceV2UpgradePaths"
	if def.upgradePathDonor then
		for _, child in ipairs(donorPathsFolder(def.upgradePathDonor):GetChildren()) do
			if child:IsA("Folder") then child:Clone().Parent = paths end
		end
	else
		for _, path in ipairs(def.upgradePaths) do makeFolder(path.name, path.attributes, paths) end
	end
	assert(#paths:GetChildren() > 0, "Stage B: " .. def.id .. " has no upgrade paths")
	paths.Parent = model
	local root = donorModules[slot.rootDonor].PrimaryPart:Clone()
	for _, child in ipairs(root:GetChildren()) do
		if child.Name ~= "MountAttachment" then child:Destroy() end
	end
	local attachment = root:FindFirstChild("MountAttachment")
	assert(attachment and attachment:IsA("Attachment"), "Stage B: " .. slot.rootDonor .. " root has no MountAttachment")
	attachment.Position = Vector3.zero
	attachment.Orientation = Vector3.zero
	root.CFrame = CFrame.new()
	for _, socket in ipairs(shape.sockets or {}) do
		local item = Instance.new("Attachment")
		item.Name = socket.name
		item.Position = vec(socket.position)
		item.Orientation = vec(socket.orientation)
		item:SetAttribute("VFXSocket", true)
		item:SetAttribute("VFXTemplate", socket.template)
		item.Parent = root
	end
	root.Parent = model
	model.PrimaryPart = root
	setAttributes(model, def.attributes)
	return model, parts, #(shape.sockets or {})
end

local function isToggleable(instance)
	return instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") or instance:IsA("Fire") or instance:IsA("Smoke")
		or instance:IsA("Sparkles") or instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
end

local function scaleSequence(sequence, factor)
	local points = {}
	for _, point in ipairs(sequence.Keypoints) do
		table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * factor, point.Envelope * factor))
	end
	return NumberSequence.new(points)
end

-- An Exotic VFX template: a clone of a stock template folder with every size-like value scaled.
local function buildVfxTemplate(def)
	local source = vfxTemplates:FindFirstChild(def.source)
	local folder = source:Clone()
	folder.Name = def.name
	local host = folder:FindFirstChild("TemplateHost_Invisible", true)
	assert(host and host:IsA("BasePart"), "Stage B: " .. def.source .. " has no TemplateHost_Invisible")
	local width, size, length, lateral = def.beamWidthScale, def.particleSizeScale, def.lengthScale, def.lateralScale
	if def.keepCentreJetOnly then
		for _, item in ipairs(folder:GetDescendants()) do
			if item:IsA("Attachment") and item.Parent and item.Parent:IsA("BasePart") and item.Name == "TemplateAttachmentLong" and math.abs(item.Position.X) > 0.01 then
				item:Destroy()
			end
		end
	end
	local effects = 0
	for _, item in ipairs(folder:GetDescendants()) do
		if item:IsA("BasePart") and item ~= host then
			local relative = host.CFrame:ToObjectSpace(item.CFrame)
			local p = relative.Position
			item.CFrame = host.CFrame * (CFrame.new(p.X * lateral, p.Y * lateral, p.Z * length) * relative.Rotation)
		elseif item:IsA("Attachment") then
			local p = item.Position
			item.Position = Vector3.new(p.X * lateral, p.Y * lateral, p.Z * length)
		elseif item:IsA("ParticleEmitter") then
			item.Size = scaleSequence(item.Size, size)
			item.Speed = NumberRange.new(item.Speed.Min * length, item.Speed.Max * length)
			item.Acceleration = item.Acceleration * length
			-- Not a custom-toggle template name, so the controller drives Rate from these attributes.
			item:SetAttribute("RateMin", item.Rate)
			item:SetAttribute("RateMax", item.Rate)
		elseif item:IsA("Beam") then
			item.Width0 = item.Width0 * width
			item.Width1 = item.Width1 * width
			item.CurveSize0 = item.CurveSize0 * length
			item.CurveSize1 = item.CurveSize1 * length
			-- The stock width attributes are stale (0.55 / 0.055). Min = Max keeps the authored width.
			item:SetAttribute("Width0Min", item.Width0)
			item:SetAttribute("Width0Max", item.Width0)
			item:SetAttribute("Width1Min", item.Width1)
			item:SetAttribute("Width1Max", item.Width1)
		elseif item:IsA("Trail") then
			item.MinLength = item.MinLength * length
			item.MaxLength = item.MaxLength * length
		elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
			item.Range = item.Range * length
			item:SetAttribute("RangeMin", item.Range)
			item:SetAttribute("RangeMax", item.Range)
			item:SetAttribute("BrightnessMin", item.Brightness)
			item:SetAttribute("BrightnessMax", item.Brightness)
		end
		if isToggleable(item) then
			effects += 1
			if def.group then item:SetAttribute("VFXGroup", def.group) end
		end
	end
	assert(effects > 0, "Stage B: " .. def.name .. " has no effects left")
	folder:SetAttribute("ScaledFrom", def.source)
	folder:SetAttribute("BeamWidthScale", width)
	folder:SetAttribute("ParticleSizeScale", size)
	folder:SetAttribute("LengthScale", length)
	folder:SetAttribute("LateralScale", lateral)
	return folder, effects
end

-- Build the whole scope detached. Returns the server category folder, the VFX folders and counts.
local function buildStaging()
	local counts = { cockpits = 0, modules = 0, parts = 0, sockets = 0 }
	local server = Instance.new("Folder")
	server.Name = CATEGORY
	setAttributes(server, DATA.category.attributes)
	local cockpitRoot = makeFolder("COCKPITS_ReplaceAssetsHere", nil, server)
	local moduleRoot = makeFolder("MODULES_InterchangeableWithinCategory", nil, server)
	for _, def in ipairs(DATA.cockpits) do
		local model, parts = buildCockpit(def)
		model.Parent = cockpitRoot
		counts.cockpits += 1
		counts.parts += parts
	end
	local typeFolders = {}
	for _, def in ipairs(DATA.moduleTypeFolders) do
		typeFolders[def.name] = makeFolder(def.name, def.attributes, moduleRoot)
	end
	for _, def in ipairs(DATA.modules) do
		local parent = assert(typeFolders[def.folderPath[1]], "Stage B: no module folder " .. tostring(def.folderPath[1]))
		for i = 2, #def.folderPath do
			parent = parent:FindFirstChild(def.folderPath[i]) or makeFolder(def.folderPath[i], nil, parent)
		end
		local model, parts, sockets = buildModule(def)
		model.Parent = parent
		counts.modules += 1
		counts.parts += parts
		counts.sockets += sockets
	end
	local vfx = {}
	for _, def in ipairs(DATA.vfx.templates) do
		local folder = buildVfxTemplate(def)
		table.insert(vfx, folder)
	end
	counts.instances = #server:GetDescendants() + 1
	return { server = server, vfx = vfx, counts = counts }
end

local function destroyStaging(staging)
	pcall(function() staging.server:Destroy() end)
	for _, folder in ipairs(staging.vfx) do pcall(function() folder:Destroy() end) end
	if staging.preview then pcall(function() staging.preview:Destroy() end) end
end

-- Structural checks on a built (detached or installed) server category.
local function validateStaging(staging)
	local server = staging.server
	local problems = {}
	local function problem(text)
		if #problems < 12 then table.insert(problems, text) end
	end
	local first = server:GetChildren()[1]
	if not (first and first.Name == "COCKPITS_ReplaceAssetsHere") then problem("COCKPITS_ReplaceAssetsHere is not the first child") end
	local templateNames = {}
	for _, folder in ipairs(staging.vfx) do templateNames[folder.Name] = true end
	for _, name in ipairs(DATA.vfx.requiredStock) do templateNames[name] = true end
	local cockpits, modules = 0, 0
	for _, item in ipairs(server:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("CockpitId") ~= nil then
			cockpits += 1
			local root = item.PrimaryPart
			if not (root and root.Name == "CockpitRoot_DoNotRename") then problem(item.Name .. " has no CockpitRoot_DoNotRename PrimaryPart") end
			if item:GetAttribute("V2Materialised") ~= true then problem(item.Name .. " is not V2Materialised") end
			local slots = item:FindFirstChild("ModuleSlots")
			if not slots or #slots:GetChildren() ~= #DATA.slots then problem(item.Name .. " does not have " .. tostring(#DATA.slots) .. " slots") end
			for _, slot in ipairs(DATA.slots) do
				local folder = slots and slots:FindFirstChild("SLOT_" .. slot.slotId)
				local mount = folder and folder:FindFirstChild("Mount_DoNotRename")
				if not (mount and mount:FindFirstChild("MountAttachment")) then problem(item.Name .. " SLOT_" .. slot.slotId .. " has no mount") end
			end
			local underglow = false
			for _, light in ipairs(item:GetDescendants()) do
				if light:IsA("SurfaceLight") and light:GetAttribute("VehicleCosmeticId") == "Underglow" and light.Parent:IsA("BasePart") then underglow = true end
			end
			if not underglow then problem(item.Name .. " has no underglow SurfaceLight on a part") end
		elseif item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil then
			modules += 1
			local root = item.PrimaryPart
			if not (root and root.Name == "ModuleRoot_DoNotRename" and root:FindFirstChild("MountAttachment")) then problem(item.Name .. " has no ModuleRoot_DoNotRename with a MountAttachment") end
			if item:GetAttribute("V2Materialised") ~= true then problem(item.Name .. " is not V2Materialised") end
			if item.Name ~= item:GetAttribute("ModuleId") then problem(item.Name .. " name differs from its ModuleId") end
		elseif item:IsA("Attachment") and item:GetAttribute("VFXSocket") == true then
			if not item.Parent:IsA("BasePart") then problem("socket " .. item:GetFullName() .. " is not under a part") end
			if not templateNames[tostring(item:GetAttribute("VFXTemplate"))] then problem("socket " .. item:GetFullName() .. " names an unknown template") end
		elseif item:IsA("BasePart") then
			local channel = item:GetAttribute("PaintChannel")
			if channel == "Thrust" or channel == "Driver" then problem(item:GetFullName() .. " still carries the blockout channel " .. channel) end
			if item.CanCollide and item.Name ~= "CockpitRoot_DoNotRename" then problem(item:GetFullName() .. " collides") end
		end
		if not isAscii(item.Name) then problem("non-ASCII name " .. string.format("%q", item.Name)) end
	end
	if cockpits ~= #DATA.cockpits then problem("built " .. tostring(cockpits) .. " cockpits, planned " .. tostring(#DATA.cockpits)) end
	if modules ~= #DATA.modules then problem("built " .. tostring(modules) .. " modules, planned " .. tostring(#DATA.modules)) end
	return problems
end

-- The replicated preview copy: a clone of the server category minus every upgrade-path folder.
local function makePreview(server)
	local clone = assert(server:Clone(), "Stage B: the server category could not be cloned")
	for _, item in ipairs(clone:GetDescendants()) do
		if item.Parent and (item.Name == "VehiclePerformanceV2UpgradePaths" or item.Name == "UpgradePaths") then
			assert(item:IsA("Folder"), "Stage B: upgrade path container is not a Folder")
			for _, child in ipairs(item:GetDescendants()) do assert(child:IsA("Folder"), "Stage B: refuse to omit physical content") end
			item:Destroy()
		end
	end
	return clone
end

-- Server and preview must hold the same instances outside the upgrade-path folders.
local function previewParity(server, preview)
	local function describe(value)
		local kind = typeof(value)
		if kind == "Color3" then return "C3:" .. value.R .. "," .. value.G .. "," .. value.B end
		return kind .. ":" .. tostring(value)
	end
	local function sig(instance, root)
		local names, current = {}, instance
		while current ~= root do
			table.insert(names, 1, current.Name)
			current = current.Parent
		end
		local attributes = {}
		for name, value in pairs(instance:GetAttributes()) do table.insert(attributes, name .. "=" .. describe(value)) end
		table.sort(attributes)
		local extra = ""
		if instance:IsA("BasePart") then
			extra = tostring(instance.Size) .. "|" .. tostring(instance.CFrame) .. "|" .. instance.Material.Name .. "|" .. tostring(instance.Color) .. "|" .. tostring(instance.Transparency)
		elseif instance:IsA("Attachment") then
			extra = tostring(instance.CFrame)
		end
		return table.concat(names, "/") .. "<" .. instance.ClassName .. ">" .. table.concat(attributes, ";") .. "#" .. extra
	end
	local function pruned(instance, root)
		local current = instance
		while current ~= root do
			if current.Name == "VehiclePerformanceV2UpgradePaths" or current.Name == "UpgradePaths" then return true end
			current = current.Parent
		end
		return false
	end
	local tally, serverCount, prunedCount = {}, 0, 0
	for _, item in ipairs(server:GetDescendants()) do
		if pruned(item, server) then
			prunedCount += 1
		else
			serverCount += 1
			local key = sig(item, server)
			tally[key] = (tally[key] or 0) + 1
		end
	end
	local previewCount, previewOnly = 0, 0
	for _, item in ipairs(preview:GetDescendants()) do
		previewCount += 1
		local key = sig(item, preview)
		if tally[key] and tally[key] > 0 then tally[key] -= 1 else previewOnly += 1 end
	end
	local serverOnly = 0
	for _, left in pairs(tally) do serverOnly += left end
	return { server = serverCount, pruned = prunedCount, preview = previewCount, previewOnly = previewOnly, serverOnly = serverOnly }
end

-- Every planned template must be reachable by its catalogue path in both trees.
local function templateWalk(server, preview)
	local missing = {}
	local function walk(root, path, attribute, id)
		local current = root
		for _, name in ipairs(path) do
			current = current and current:FindFirstChild(name)
		end
		return current and current:IsA("Model") and current:GetAttribute(attribute) == id
	end
	for _, def in ipairs(DATA.cockpits) do
		local path = { "COCKPITS_ReplaceAssetsHere", def.model }
		if not (walk(server, path, "CockpitId", def.id) and walk(preview, path, "CockpitId", def.id)) then table.insert(missing, def.id) end
	end
	for _, def in ipairs(DATA.modules) do
		local path = { "MODULES_InterchangeableWithinCategory" }
		for _, name in ipairs(def.folderPath) do table.insert(path, name) end
		table.insert(path, def.id)
		if not (walk(server, path, "ModuleId", def.id) and walk(preview, path, "ModuleId", def.id)) then table.insert(missing, def.id) end
	end
	return missing
end

-- Optional AUDIT evidence (build_content.py --sample): a short text dump of what the dry run built.
local function describeStaging(staging)
	local lines = {}
	local function add(text)
		if #lines < 160 then table.insert(lines, text) end
	end
	local function v3(value)
		return string.format("(%.3f, %.3f, %.3f)", value.X, value.Y, value.Z)
	end
	local function attributeCount(instance)
		local count = 0
		for _ in pairs(instance:GetAttributes()) do count += 1 end
		return count
	end
	local function childList(instance)
		local names = {}
		for _, child in ipairs(instance:GetChildren()) do
			table.insert(names, child.ClassName .. " " .. child.Name .. "[" .. tostring(#child:GetChildren()) .. "]")
		end
		return table.concat(names, ", ")
	end
	local function describePart(part)
		local rx, ry, rz = part.CFrame:ToOrientation()
		return string.format("%s %s size=%s pos=%s ori=(%.1f, %.1f, %.1f) %s transp=%s anchored=%s collide=%s query=%s touch=%s channel=%s", part.ClassName, part.Name, v3(part.Size), v3(part.Position),
			math.deg(rx), math.deg(ry), math.deg(rz), part.Material.Name, tostring(part.Transparency), tostring(part.Anchored), tostring(part.CanCollide), tostring(part.CanQuery), tostring(part.CanTouch), tostring(part:GetAttribute("PaintChannel")))
	end
	local cockpit = staging.server.COCKPITS_ReplaceAssetsHere:GetChildren()[1]
	add("COCKPIT " .. cockpit.Name .. " attributes=" .. attributeCount(cockpit) .. " primary=" .. tostring(cockpit.PrimaryPart) .. " pivot=" .. v3(cockpit:GetPivot().Position))
	add("  children: " .. childList(cockpit))
	local asset = cockpit.ASSET_ReplaceWithYourCockpitModel
	add("  asset children: " .. childList(asset) .. " primary=" .. tostring(asset.PrimaryPart))
	local root = cockpit.PrimaryPart
	add("  root: " .. describePart(root) .. " role=" .. tostring(root:GetAttribute("TemplateRole")) .. " mass=" .. string.format("%.3f", root.Mass))
	for _, child in ipairs(root:GetDescendants()) do
		if child:IsA("Attachment") then
			add("    Attachment " .. child.Name .. " pos=" .. v3(child.Position) .. " template=" .. tostring(child:GetAttribute("VFXTemplate")) .. " children=" .. tostring(#child:GetChildren()))
		elseif child:IsA("BasePart") then
			add("    " .. describePart(child) .. " parent=" .. child.Parent.Name)
		elseif child:IsA("Light") then
			add("    " .. child.ClassName .. " " .. child.Name .. " parent=" .. child.Parent.Name .. " enabled=" .. tostring(child.Enabled) .. " range=" .. tostring(child.Range) .. " brightness=" .. tostring(child.Brightness))
		else
			add("    " .. child.ClassName .. " " .. child.Name)
		end
	end
	for _, slot in ipairs(cockpit.ModuleSlots:GetChildren()) do
		local mount = slot.Mount_DoNotRename
		add("  " .. slot.Name .. " label=" .. tostring(slot:GetAttribute("DisplayName")) .. " type=" .. tostring(slot:GetAttribute("ModuleType")) .. " folder=" .. tostring(slot:GetAttribute("AllowedModuleFolder")) .. " order=" .. tostring(slot:GetAttribute("Order"))
			.. " mount=" .. v3(mount.Position) .. "/" .. tostring(mount:GetAttribute("SlotId")) .. "/" .. tostring(mount:GetAttribute("ModuleType")) .. "/" .. tostring(mount:GetAttribute("DisplayName")))
	end
	local firstPart = asset.PRIMARY_ReplaceWithPrimaryMeshes:GetChildren()[1]
	if firstPart then add("  first primary part: " .. describePart(firstPart)) end
	local glass = asset.GLASS_ReplaceWithGlassMeshes:GetChildren()[1]
	if glass then add("  first glass part: " .. describePart(glass)) end
	local seen = {}
	for _, def in ipairs(DATA.modules) do
		if not seen[def.slot] then
			seen[def.slot] = true
			local parent = staging.server.MODULES_InterchangeableWithinCategory
			for _, name in ipairs(def.folderPath) do parent = parent[name] end
			local module = parent[def.id]
			add("MODULE " .. module.Name .. " attributes=" .. attributeCount(module) .. " primary=" .. tostring(module.PrimaryPart) .. " pivot=" .. v3(module:GetPivot().Position))
			add("  children: " .. childList(module))
			for _, child in ipairs(module.PrimaryPart:GetChildren()) do
				add("  root child " .. child.ClassName .. " " .. child.Name .. " pos=" .. v3(child.Position) .. " ori=" .. v3(child.Orientation) .. " template=" .. tostring(child:GetAttribute("VFXTemplate")))
			end
			local paths = {}
			for _, path in ipairs(module.VehiclePerformanceV2UpgradePaths:GetChildren()) do table.insert(paths, path.Name) end
			add("  upgrade paths: " .. table.concat(paths, ", "))
			for _, folder in ipairs(module:GetChildren()) do
				local part = folder:IsA("Folder") and folder:FindFirstChildWhichIsA("BasePart")
				if part and (folder.Name == "THRUST_COLOR_WhiteByDefault" or folder.Name == "LIGHTS_AlwaysOn" or folder.Name == "NEON_OptionalLights") then
					add("  " .. folder.Name .. ": " .. describePart(part) .. " colour=" .. tostring(part.Color))
				end
			end
		end
	end
	for _, folder in ipairs(staging.vfx) do
		add("VFX " .. folder.Name .. " attributes=" .. attributeCount(folder))
		for _, item in ipairs(folder:GetDescendants()) do
			if item:IsA("Beam") then
				add(string.format("  Beam %s w0=%.3f w1=%.3f attrs w0=%s..%s w1=%s..%s group=%s a0=%s a1=%s", item.Name, item.Width0, item.Width1, tostring(item:GetAttribute("Width0Min")), tostring(item:GetAttribute("Width0Max")),
					tostring(item:GetAttribute("Width1Min")), tostring(item:GetAttribute("Width1Max")), tostring(item:GetAttribute("VFXGroup")), tostring(item.Attachment0), tostring(item.Attachment1)))
			elseif item:IsA("ParticleEmitter") then
				local peak = 0
				for _, point in ipairs(item.Size.Keypoints) do peak = math.max(peak, point.Value) end
				add(string.format("  Emitter %s sizePeak=%.3f speed=%.1f..%.1f accel=%s rate=%s attrs rate=%s..%s group=%s", item.Name, peak, item.Speed.Min, item.Speed.Max, v3(item.Acceleration), tostring(item.Rate),
					tostring(item:GetAttribute("RateMin")), tostring(item:GetAttribute("RateMax")), tostring(item:GetAttribute("VFXGroup"))))
			elseif item:IsA("Attachment") then
				add("  Attachment " .. item.Name .. " pos=" .. v3(item.Position) .. " parent=" .. item.Parent.Name)
			elseif item:IsA("BasePart") then
				add("  Part " .. item.Name .. " pos=" .. v3(item.Position) .. " size=" .. v3(item.Size))
			end
		end
	end
	return lines
end

-- ---------------------------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------------------------
local stateInfo = readState()
result.state = stateInfo.state
result.installedScope = stateInfo.installedScope
result.installedContentHash = stateInfo.installedHash

if META.fixture then BLOCKER("fixture", "this installer was built from test fixtures; it must not be applied") end
if stateInfo.state == "partial-or-foreign" then
	for i, text in ipairs(stateInfo.problems) do
		if i <= 10 then BLOCKER("state", text) end
	end
end

local edited = {}
if stateInfo.state == "installed-pilot" or stateInfo.state == "installed-full" then
	edited = signatureProblems(stateInfo.found)
	for _, path in ipairs(edited) do
		BLOCKER("edited", path .. " no longer matches what was installed (something was added, removed or renamed inside it). Inspect before replacing or rolling back.")
	end
	INFO("state", "installed scope " .. tostring(stateInfo.installedScope) .. ", content hash " .. tostring(stateInfo.installedHash) .. (stateInfo.installedHash == META.contentHash and " (this build)" or " (a different build)"))
end

preflightStructure()
local generated, catalogueDiffs = catalogueState()
if not generated then
	BLOCKER("catalogue", catalogueDiffs[1])
else
	result.revision = generated.revision
	result.catalogue = { cockpits = generated.cockpits, modules = generated.modules, chunks = #generated.chunks }
	local hasPiercerChunk = false
	for _, chunk in ipairs(generated.chunks) do
		if string.sub(chunk.name, 1, #DATA.category.afterFolder + 1) == DATA.category.afterFolder .. "_" then hasPiercerChunk = true end
	end
	if not hasPiercerChunk then BLOCKER("catalogue", "the generator produced no " .. DATA.category.afterFolder .. " chunk") end
	if stateInfo.state ~= "partial-or-foreign" then
		for i, diff in ipairs(catalogueDiffs) do
			if i <= 8 then BLOCKER("catalogue", "VehicleCatalogData is not the split, current form: " .. diff) end
		end
	end
	if #catalogueDiffs == 0 then INFO("catalogue", "installed index and " .. tostring(#generated.chunks) .. " chunks equal the generator output; revision " .. generated.revision) end
end

local ownRoots = {}
if stateInfo.state == "installed-pilot" or stateInfo.state == "installed-full" then
	ownRoots = { stateInfo.found.server[1], stateInfo.found.preview[1] }
end

if MODE == "ROLLBACK" then
	-- Rollback needs only: a clean installed state, unedited roots and a current catalogue.
	if stateInfo.state == "absent" then
		INFO("rollback", "nothing is installed; nothing to remove")
		return finish(#blockers == 0, { stateAfter = "absent" })
	end
	if #blockers > 0 then
		error("Stage B ROLLBACK refused: " .. HttpService:JSONEncode(finish(false, {})), 0)
	end
	local journal = { detached = {}, sources = {} }
	local function detach(instance)
		assert(own(instance), "refuse to remove " .. instance:GetFullName() .. ": it does not carry the installer marker")
		table.insert(journal.detached, { instance = instance, parent = instance.Parent })
		instance.Parent = nil
	end
	local ok, message = xpcall(function()
		detach(stateInfo.found.preview[1])
		for _, name in ipairs(VFX_NAMES) do detach(stateInfo.found.vfx[name][1]) end
		detach(stateInfo.found.server[1])
		local after = STAGE_B_CATALOGUE_GEN()
		for _, chunk in ipairs(after.chunks) do
			assert(not string.match(chunk.name, "^" .. CATEGORY .. "_%d+$"), "generator still emits " .. chunk.name)
			local list = childrenNamed(catalogueIndex, chunk.name)
			assert(#list == 1 and list[1]:IsA("ModuleScript") and list[1].Source == chunk.source, chunk.name .. " would change; rollback only rewrites the index")
		end
		assert(loadstring(after.index, "VehicleCatalogData"), "regenerated index does not compile")
		table.insert(journal.sources, { script = catalogueIndex, source = catalogueIndex.Source })
		catalogueIndex.Source = after.index
		-- The index is rewritten first, so it never names a chunk that has already gone.
		for _, chunk in ipairs(stateInfo.found.chunks) do detach(chunk) end
		local _, diffs = catalogueState()
		assert(#diffs == 0, "catalogue check after rollback: " .. table.concat(diffs, "; "))
		assert(categories:GetChildren()[1] == piercer, "PIERCER is no longer the first category")
		result.revision = after.revision
		result.catalogue = { cockpits = after.cockpits, modules = after.modules, chunks = #after.chunks }
	end, debug.traceback)
	if not ok then
		local incomplete = {}
		for i = #journal.sources, 1, -1 do
			local entry = journal.sources[i]
			if not pcall(function() entry.script.Source = entry.source end) then table.insert(incomplete, entry.script:GetFullName()) end
		end
		for i = #journal.detached, 1, -1 do
			local entry = journal.detached[i]
			if not pcall(function() entry.instance.Parent = entry.parent end) then table.insert(incomplete, entry.instance.Name) end
		end
		BLOCKER("rollback", tostring(message))
		error("Stage B ROLLBACK failed; " .. (#incomplete == 0 and "restored the installed state" or ("RECOVERY INCOMPLETE for " .. table.concat(incomplete, ", "))) .. ": " .. HttpService:JSONEncode(finish(false, {})), 0)
	end
	for _, entry in ipairs(journal.detached) do entry.instance:Destroy() end
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Exotic Stage B ROLLBACK") end)
	local afterState = readState()
	return finish(afterState.state == "absent", { stateAfter = afterState.state, changed = #journal.detached + 1 })
end

-- AUDIT and APPLY share the full preflight.
local blockersBeforeBuildChecks = #blockers
preflightDonors()
local plannedCockpits, plannedModules = preflightPlan()
local buildable = #blockers == blockersBeforeBuildChecks -- donors and plan are sound, whatever else is blocked
preflightCollisions(plannedCockpits, plannedModules, ownRoots)
preflightBlockout()
preflightStageA()
preflightSeats()

local alreadyCurrent = (stateInfo.state == "installed-" .. SCOPE) and stateInfo.installedHash == META.contentHash and #edited == 0 and generated ~= nil and #catalogueDiffs == 0

if MODE == "AUDIT" then
	-- Dry run: build the whole scope detached, check it, throw it away. Nothing enters the DataModel.
	-- It needs only the donors and the plan, so it also runs while other blockers (Stage A, state) are open.
	if buildable then
		local ok, message = pcall(function()
			local staging = buildStaging()
			local problems = validateStaging(staging)
			staging.preview = makePreview(staging.server)
			local parity = previewParity(staging.server, staging.preview)
			local missing = templateWalk(staging.server, staging.preview)
			result.counts = staging.counts
			result.counts.previewInstances = parity.preview + 1
			if META.sample then result.sample = describeStaging(staging) end
			destroyStaging(staging)
			for _, text in ipairs(problems) do BLOCKER("build", text) end
			if parity.previewOnly ~= 0 or parity.serverOnly ~= 0 then BLOCKER("build", "preview parity failed in the dry run: previewOnly=" .. parity.previewOnly .. " serverOnly=" .. parity.serverOnly) end
			if #missing > 0 then BLOCKER("build", "template path walk failed in the dry run for " .. table.concat(missing, ", ", 1, math.min(#missing, 6))) end
		end)
		if not ok then BLOCKER("build", "dry-run build failed: " .. tostring(message)) end
		INFO("build", "dry run built and discarded the " .. SCOPE .. " scope detached; chunk sizes are checked during APPLY before the catalogue is written")
	else
		INFO("build", "dry-run build skipped because the donors or the plan have blockers")
	end
	if alreadyCurrent then INFO("apply", "this build is already installed; APPLY would change nothing") end
	return finish(#blockers == 0, { wouldApply = #blockers == 0 and not alreadyCurrent })
end

-- APPLY ------------------------------------------------------------------------------------------
if #blockers > 0 then
	error("Stage B APPLY refused: " .. HttpService:JSONEncode(finish(false, {})), 0)
end
if alreadyCurrent then
	INFO("apply", "this build is already installed; nothing changed")
	return finish(true, { stateAfter = stateInfo.state, changed = 0 })
end

local journal = { created = {}, detached = {}, sources = {} }
local function detach(instance)
	assert(own(instance), "refuse to remove " .. instance:GetFullName() .. ": it does not carry the installer marker")
	table.insert(journal.detached, { instance = instance, parent = instance.Parent })
	instance.Parent = nil
end
local function place(instance, parent)
	instance.Parent = parent
	table.insert(journal.created, instance)
end

local staging
local ok, message = xpcall(function()
	-- 1. Build detached and check.
	staging = buildStaging()
	local problems = validateStaging(staging)
	assert(#problems == 0, "staging validation: " .. table.concat(problems, "; "))
	-- 2. Take this installer's own earlier content out of the way (kept in memory until the end).
	if stateInfo.state == "installed-pilot" or stateInfo.state == "installed-full" then
		detach(stateInfo.found.preview[1])
		for _, name in ipairs(VFX_NAMES) do detach(stateInfo.found.vfx[name][1]) end
		for _, chunk in ipairs(stateInfo.found.chunks) do detach(chunk) end
		detach(stateInfo.found.server[1])
	end
	-- 3. Authoring category and VFX templates. The marker goes on before the folder enters the tree, so a hard stop
	-- can never leave an unmarked EXOTIC folder behind.
	staging.server:SetAttribute("InstalledBy", MARKER)
	place(staging.server, categories)
	assert(categories:GetChildren()[1] == piercer, "PIERCER is no longer the first category")
	for _, folder in ipairs(staging.vfx) do
		folder:SetAttribute("InstalledBy", MARKER)
		folder:SetAttribute("InstalledScope", SCOPE)
		folder:SetAttribute("InstalledContentHash", META.contentHash)
		folder:SetAttribute("InstalledSignature", signature(folder))
		place(folder, vfxTemplates)
	end
	-- 4. Regenerate the catalogue from the live tree. Piercer chunks must not change.
	local after = STAGE_B_CATALOGUE_GEN()
	local exoticCount = 0
	for _, chunk in ipairs(after.chunks) do
		assert(#chunk.source < 190000, chunk.name .. " is too long")
		assert(loadstring(chunk.source, chunk.name), chunk.name .. " does not compile")
		if string.match(chunk.name, "^" .. CATEGORY .. "_%d+$") then
			exoticCount += 1
		else
			local list = childrenNamed(catalogueIndex, chunk.name)
			assert(#list == 1 and list[1]:IsA("ModuleScript") and list[1].Source == chunk.source, chunk.name .. " would change; Stage B never rewrites another category's chunk")
		end
	end
	assert(exoticCount > 0, "the generator produced no " .. CATEGORY .. " chunk")
	assert(#after.index < 190000 and loadstring(after.index, "VehicleCatalogData"), "regenerated index is too long or does not compile")
	local otherCockpits, otherModules = 0, 0
	for _, child in ipairs(categories:GetChildren()) do
		if child ~= staging.server then
			for _, item in ipairs(child:GetDescendants()) do
				if item.ClassName == "Model" then
					if item:GetAttribute("CockpitId") ~= nil then otherCockpits += 1 end
					if item:GetAttribute("ModuleId") ~= nil then otherModules += 1 end
				end
			end
		end
	end
	assert(after.cockpits == otherCockpits + #DATA.cockpits, "catalogue cockpit count " .. tostring(after.cockpits) .. " is not the other categories (" .. tostring(otherCockpits) .. ") plus this scope")
	assert(after.modules == otherModules + #DATA.modules, "catalogue module count " .. tostring(after.modules) .. " is not the other categories (" .. tostring(otherModules) .. ") plus this scope")
	-- 5. Markers (identical on both category roots so the preview stays an exact copy), then the preview.
	staging.preview = makePreview(staging.server)
	local serverSignature, previewSignature = signature(staging.server), signature(staging.preview)
	for _, root in ipairs({ staging.server, staging.preview }) do
		root:SetAttribute("InstalledBy", MARKER)
		root:SetAttribute("InstalledScope", SCOPE)
		root:SetAttribute("InstalledContentHash", META.contentHash)
		root:SetAttribute("InstalledServerSignature", serverSignature)
		root:SetAttribute("InstalledPreviewSignature", previewSignature)
	end
	place(staging.preview, previewCategories)
	-- 6. Catalogue sources: new EXOTIC chunks, then the index.
	for _, chunk in ipairs(after.chunks) do
		if string.match(chunk.name, "^" .. CATEGORY .. "_%d+$") then
			assert(#childrenNamed(catalogueIndex, chunk.name) == 0, chunk.name .. " already exists")
			local chunkScript = Instance.new("ModuleScript")
			chunkScript.Name = chunk.name
			chunkScript.Source = chunk.source
			chunkScript:SetAttribute("InstalledBy", MARKER)
			place(chunkScript, catalogueIndex)
		end
	end
	table.insert(journal.sources, { script = catalogueIndex, source = catalogueIndex.Source })
	catalogueIndex.Source = after.index
	-- 7. Audit the result.
	local _, diffs = catalogueState()
	assert(#diffs == 0, "catalogue check after install: " .. table.concat(diffs, "; "))
	local parity = previewParity(staging.server, staging.preview)
	assert(parity.previewOnly == 0 and parity.serverOnly == 0, "preview parity: previewOnly=" .. parity.previewOnly .. " serverOnly=" .. parity.serverOnly)
	local missing = templateWalk(staging.server, staging.preview)
	assert(#missing == 0, "template path walk failed for " .. table.concat(missing, ", ", 1, math.min(#missing, 6)))
	local afterState = readState()
	assert(afterState.state == "installed-" .. SCOPE, "state after install is " .. afterState.state .. ": " .. table.concat(afterState.problems, "; "))
	assert(#signatureProblems(afterState.found) == 0, "signatures do not match straight after install")
	result.revision = after.revision
	result.catalogue = { cockpits = after.cockpits, modules = after.modules, chunks = #after.chunks, exoticChunks = exoticCount }
	result.counts = staging.counts
	result.counts.previewInstances = parity.preview + 1
	result.parity = parity
end, debug.traceback)

if not ok then
	local incomplete = {}
	for i = #journal.created, 1, -1 do
		if not pcall(function() journal.created[i]:Destroy() end) then table.insert(incomplete, "destroy " .. tostring(journal.created[i])) end
	end
	if staging then destroyStaging(staging) end
	for i = #journal.sources, 1, -1 do
		local entry = journal.sources[i]
		if not pcall(function() entry.script.Source = entry.source end) then table.insert(incomplete, "source " .. entry.script:GetFullName()) end
	end
	for i = #journal.detached, 1, -1 do
		local entry = journal.detached[i]
		if not pcall(function() entry.instance.Parent = entry.parent end) then table.insert(incomplete, "restore " .. entry.instance.Name) end
	end
	local restored = readState()
	if restored.state ~= stateInfo.state then table.insert(incomplete, "state is " .. restored.state .. ", was " .. stateInfo.state) end
	BLOCKER("apply", tostring(message))
	error("Stage B APPLY failed; " .. (#incomplete == 0 and "everything was restored" or ("RECOVERY INCOMPLETE: " .. table.concat(incomplete, "; "))) .. ": " .. HttpService:JSONEncode(finish(false, {})), 0)
end

for _, entry in ipairs(journal.detached) do entry.instance:Destroy() end
pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Exotic Stage B APPLY " .. SCOPE) end)
return finish(true, { stateAfter = "installed-" .. SCOPE, changed = #journal.created + 1 })

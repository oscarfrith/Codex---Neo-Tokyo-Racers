-- Read-only. Returns the v3 lighting state as JSON (service, skies, Config.World.Lighting tree).
-- Give it a URL (first argument) to also POST the JSON to receive_dump.py on this PC.
local url = ...
assert(game.PlaceId == 93959280828322, "wrong place")
local H = game:GetService("HttpService")
local function enc(v)
	local t = typeof(v)
	if t == "Color3" then return {Type="Color3", R=v.R, G=v.G, B=v.B} end
	if t == "Vector3" then return {Type="Vector3", X=v.X, Y=v.Y, Z=v.Z} end
	if t == "EnumItem" then return {Type="Enum", Value=tostring(v)} end
	if t == "number" or t == "string" or t == "boolean" then return v end
	return {Type=t, Value=tostring(v)}
end
local function attrs(i) local o = {} for k, v in pairs(i:GetAttributes()) do o[k] = enc(v) end return o end
local function tree(i)
	local o = {name=i.Name, class_name=i.ClassName, attributes=attrs(i), children={}}
	if i:IsA("StringValue") then o.value = i.Value end
	for _, c in ipairs(i:GetChildren()) do table.insert(o.children, tree(c)) end
	table.sort(o.children, function(a,b) return a.name < b.name end)
	return o
end
local P = {
	Lighting={"Brightness","Ambient","OutdoorAmbient","ColorShift_Top","ColorShift_Bottom","EnvironmentDiffuseScale","EnvironmentSpecularScale","ExposureCompensation","ClockTime","GeographicLatitude","GlobalShadows","ShadowSoftness","FogColor","FogStart","FogEnd","LightingStyle","PrioritizeLightingQuality"},
	Sky={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp","SunTextureId","MoonTextureId","SunAngularSize","MoonAngularSize","StarCount","CelestialBodiesShown","SkyboxOrientation"},
	Atmosphere={"Density","Offset","Color","Decay","Glare","Haze"},
	BloomEffect={"Enabled","Intensity","Size","Threshold"},
	ColorCorrectionEffect={"Enabled","Brightness","Contrast","Saturation","TintColor"},
	ColorGradingEffect={"Enabled","TonemapperPreset"},
	SunRaysEffect={"Enabled","Intensity","Spread"},
	DepthOfFieldEffect={"Enabled","FarIntensity","FocusDistance","InFocusRadius","NearIntensity"},
	Clouds={"Enabled","Cover","Density","Color"},
}
local function props(i) local o = {} for _, p in ipairs(P[i.ClassName] or {}) do o[p] = enc(i[p]) end return o end
local function row(c) return {name=c.Name, class_name=c.ClassName, properties=props(c), attributes=attrs(c)} end
local L = game:GetService("Lighting")
local out = {place_id=game.PlaceId, mode=game:GetService("RunService"):IsRunning() and "Play" or "Edit", taken_utc=os.date("!%Y-%m-%d %H:%M:%S"),
	lighting_service={properties=props(L), attributes=attrs(L), children={}}, skies={}, clouds={}}
for _, c in ipairs(L:GetChildren()) do table.insert(out.lighting_service.children, row(c)) end
for _, c in ipairs(game.ReplicatedStorage.Assets.World.Skies:GetChildren()) do table.insert(out.skies, row(c)) end
for _, c in ipairs(workspace.Terrain:GetChildren()) do if c:IsA("Clouds") then table.insert(out.clouds, row(c)) end end
out.config = tree(game.ReplicatedStorage.Config.World.Lighting)
local json = H:JSONEncode(out)
if url then H:PostAsync(url, json, Enum.HttpContentType.ApplicationJson) return #json end
return json

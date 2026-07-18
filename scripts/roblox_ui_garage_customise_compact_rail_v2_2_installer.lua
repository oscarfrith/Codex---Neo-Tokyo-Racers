-- Neo Tokyo Racers - Canonical garage Customise compact rail V2.2
-- NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2
-- Run once in the Studio Edit Command Bar, then restart Play.

local REVISION="NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2"
local PREFIX="[NTR Garage Customise Compact Rail V2.2]"
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local function need(parent,name,className)
	local object=parent:FindFirstChild(name); assert(object,parent:GetFullName().."."..name.." missing")
	if className then assert(object:IsA(className),object:GetFullName().." must be "..className) end
	return object
end
local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true); assert(first,"Missing source anchor: "..label)
	assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label)
	return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end
local function compile(name,source) local fn,err=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(err)) end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local uiRoot=need(need(clientRoot,"Controllers","Folder"),"UI","Folder")
local controller=need(uiRoot,"ModuleShopUIController","ModuleScript")
local original=controller.Source

assert(string.find(original,"NTR_GARAGE_FLOW_REFINEMENT_V2_1",1,true),"Confirmed V2.1 baseline missing; refresh the live source before patching")
if string.find(original,REVISION,1,true) then print(PREFIX.." ALREADY INSTALLED"); return end

local source=original
source=replaceOnce(source,
	[[c.LeftCardMode=true; c.LeftFloating=true; c.LeftSharedCardSize=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("WorkspaceCardHeight")) or 146; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("ModuleCardImageHeight")) or 104; c.LeftItems={}; c.Cards={}]],
	[[c.LeftCardMode=true; c.LeftFloating=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78; c.LeftItems={}; c.Cards={} -- NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2]],
	"Customise compact floating card geometry")
source=replaceOnce(source,
	[[ImageKey=art.TargetId,Image=art.Image,ImageZoom=.5,Selected=target==id]],
	[[ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04,Selected=target==id]],
	"Customise category artwork scale")

source="-- "..REVISION.."\n"..source
compile("ModuleShopUIController",source)
assert(#source<199000,"Projected ModuleShopUIController Source exceeds the safe Studio limit")

local function audit()
	local installed=controller.Source; local pass,fail=0,0
	local function check(ok,message) if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end end
	check(string.find(installed,REVISION,1,true)~=nil,"V2.2 owner installed")
	check(string.find(installed,'c.LeftCardMode=true; c.LeftFloating=true; c.LeftAlignCarouselBottom=true',1,true)~=nil,"Customise rail remains floating and compact")
	check(string.find(installed,'CustomiseCategoryCardHeight',1,true)~=nil and string.find(installed,'CustomiseCategoryImageHeight',1,true)~=nil,"pre-V2.1 category dimensions restored")
	check(string.find(installed,'ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04',1,true)~=nil,"category artwork scale restored")
	check(string.find(installed,'c.ShowLeft=true; c.LeftFloating=true; c.LeftCardMode=true; c.LeftSharedCardSize=true',1,true)~=nil,"Build/Customise navigation keeps shared action-card sizing")
	check(string.find(installed,'if target=="ALL" then return {"Primary","Secondary","Detail","Neon"}',1,true)~=nil,"V2.1 Neon tab retained")
	check(string.find(installed,'OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget=id',1,true)~=nil,"V2.1 transient neon cleanup retained")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail)); return fail==0
end

local ok,err=pcall(function() controller.Source=source; assert(audit(),"Post-install audit failed") end)
if not ok then controller.Source=original; error("Customise compact rail V2.2 rolled back: "..tostring(err)) end
print(PREFIX.." INSTALL COMPLETE - restart Play and verify compact All/Cockpit/Thrust/module cards, large artwork, floating rail, and unchanged Build/Customise navigation cards.")

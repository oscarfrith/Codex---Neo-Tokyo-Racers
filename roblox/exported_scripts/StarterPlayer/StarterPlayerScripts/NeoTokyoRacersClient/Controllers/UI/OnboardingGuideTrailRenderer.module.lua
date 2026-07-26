-- NTR_ONBOARDING_GUIDE_TRAIL_RENDERER_V4_TEXTURED_CHEVRON_BEAM
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Renderer={}
Renderer.__index=Renderer

local function number(config,name,fallback)
	local value=config:GetAttribute(name)
	return tonumber(value) or fallback
end
local function boolean(config,name,fallback)
	local value=config:GetAttribute(name)
	return type(value)=="boolean" and value or fallback
end
local function texture(config,name)
	local value=tostring(config:GetAttribute(name) or "")
	value=string.gsub(value,"^%s+",""); value=string.gsub(value,"%s+$","")
	if value=="" then return "" end
	if string.match(value,"^%d+$") then return "rbxassetid://"..value end
	if string.match(value,"^rbxassetid://%d+$") then return value end
	warn("[NTR Onboarding] GuideTrailChevronTexture must be a numeric asset ID or rbxassetid:// URI; using Part-arrow fallback")
	return ""
end
local function makeArrowPart(parent,name,size,color,transparency)
	local object=Instance.new("Part")
	object.Name=name; object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false
	object.CastShadow=false; object.Material=Enum.Material.Neon; object.Color=color; object.Transparency=transparency; object.Size=size
	object.TopSurface=Enum.SurfaceType.Smooth; object.BottomSurface=Enum.SurfaceType.Smooth; object.Parent=parent
	return object
end
local function makeBeamAnchor(parent,name)
	local object=Instance.new("Part"); object.Name=name; object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false; object.CastShadow=false; object.Transparency=1; object.Size=Vector3.new(.2,.2,.2); object.Parent=parent
	local attachment=Instance.new("Attachment"); attachment.Name="Attachment"; attachment.Parent=object
	return object,attachment
end
local function createBeam(parent,config,color)
	if not boolean(config,"GuideTrailBeamEnabled",true) then return nil end
	local folder=Instance.new("Folder"); folder.Name="DynamicBeam"; folder.Parent=parent
	local startPart,startAttachment=makeBeamAnchor(folder,"BeamStart")
	local endPart,endAttachment=makeBeamAnchor(folder,"BeamEnd")
	local aura=Instance.new("Beam"); aura.Name="AuraBeam"; aura.Attachment0=startAttachment; aura.Attachment1=endAttachment; aura.Color=ColorSequence.new(color); aura.Transparency=NumberSequence.new(number(config,"GuideTrailBeamTransparency",.58)); aura.Width0=number(config,"GuideTrailBeamWidth",3.5); aura.Width1=aura.Width0; aura.LightEmission=1; aura.Brightness=1.8; aura.FaceCamera=true; aura.Segments=16; aura.Enabled=false; aura.Parent=folder
	local core=Instance.new("Beam"); core.Name="CoreBeam"; core.Attachment0=startAttachment; core.Attachment1=endAttachment; core.Color=ColorSequence.new(color); core.Transparency=NumberSequence.new(number(config,"GuideTrailBeamCoreTransparency",.25)); core.Width0=number(config,"GuideTrailBeamCoreWidth",.8); core.Width1=core.Width0; core.LightEmission=1; core.Brightness=2.2; core.FaceCamera=true; core.Segments=16; core.Enabled=false; core.Parent=folder
	local chevronTexture=texture(config,"GuideTrailChevronTexture"); local chevron=nil
	if boolean(config,"GuideTrailChevronBeamEnabled",true) and chevronTexture~="" then
		chevron=Instance.new("Beam"); chevron.Name="ChevronBeam"; chevron.Attachment0=startAttachment; chevron.Attachment1=endAttachment; chevron.Color=ColorSequence.new(color); chevron.Transparency=NumberSequence.new(math.clamp(number(config,"GuideTrailChevronTransparency",.08),0,1)); chevron.Width0=math.max(.1,number(config,"GuideTrailChevronWidth",2.2)); chevron.Width1=chevron.Width0; chevron.LightEmission=1; chevron.Brightness=math.max(0,number(config,"GuideTrailChevronBrightness",2)); chevron.FaceCamera=true; chevron.Segments=16; chevron.Texture=chevronTexture; chevron.TextureMode=Enum.TextureMode.Wrap; chevron.TextureLength=math.max(.1,number(config,"GuideTrailChevronTextureLength",6)); chevron.TextureSpeed=number(config,"GuideTrailChevronTextureSpeed",1.5); chevron.ZOffset=number(config,"GuideTrailChevronZOffset",.05); chevron.Enabled=false; chevron.Parent=folder
	end
	return {StartPart=startPart,EndPart=endPart,Aura=aura,Core=core,Chevron=chevron}
end
local function createArrow(parent,index,config,color)
	local scale=number(config,"GuideTrailArrowScale",1); local transparency=math.clamp(number(config,"GuideTrailTransparency",.12),0,.9)
	local model=Instance.new("Model"); model.Name=string.format("DynamicArrow_%02d",index); model.Parent=parent
	local shaft=makeArrowPart(model,"Shaft",Vector3.new(number(config,"GuideTrailArrowWidth",.42),.16,number(config,"GuideTrailShaftLength",2.6))*scale,color,transparency)
	local left=makeArrowPart(model,"HeadLeft",Vector3.new(number(config,"GuideTrailHeadWidth",.36),.16,number(config,"GuideTrailHeadLength",1.05))*scale,color,transparency)
	local right=makeArrowPart(model,"HeadRight",left.Size,color,transparency)
	return {Model=model,Shaft=shaft,Left=left,Right=right,Transparency=transparency,ShaftEnabled=boolean(config,"GuideTrailShaftEnabled",true)}
end
local function setArrowVisible(arrow,shown)
	local transparency=shown and arrow.Transparency or 1
	arrow.Shaft.Transparency=arrow.ShaftEnabled and transparency or 1; arrow.Left.Transparency=transparency; arrow.Right.Transparency=transparency
end
local function setBeamVisible(beam,shown)
	if beam then beam.Aura.Enabled=shown; beam.Core.Enabled=shown; if beam.Chevron then beam.Chevron.Enabled=shown end end
end
function Renderer.new(config)
	local self=setmetatable({},Renderer)
	self.Config=config; self.Target=nil; self.Folder=nil; self.Arrows={}; self.Beam=nil; self.Elapsed=0
	self.Connection=RunService.RenderStepped:Connect(function(dt) self:Update(dt) end)
	return self
end
function Renderer:EnsureFolder()
	if self.Folder and self.Folder.Parent then return self.Folder end
	local client=workspace:FindFirstChild("_NTR_ClientOnly")
	if not client then client=Instance.new("Folder"); client.Name="_NTR_ClientOnly"; client.Parent=workspace end
	local old=client:FindFirstChild("OnboardingGuideTrail"); if old then old:Destroy() end
	self.Folder=Instance.new("Folder"); self.Folder.Name="OnboardingGuideTrail"; self.Folder.Parent=client
	local color=self.Config:GetAttribute("TutorialGold") or Color3.fromRGB(255,196,66)
	self.Beam=createBeam(self.Folder,self.Config,color)
	local hasChevron=self.Beam and self.Beam.Chevron~=nil
	local usePartArrows=boolean(self.Config,"GuideTrailPartArrowsEnabled",false) or not hasChevron
	if usePartArrows then
		for index=1,math.max(1,math.floor(number(self.Config,"GuideTrailMaximumArrows",18))) do
			self.Arrows[index]=createArrow(self.Folder,index,self.Config,color); setArrowVisible(self.Arrows[index],false)
		end
	end
	return self.Folder
end
function Renderer:SetTarget(target)
	if not (target and target:IsA("BasePart") and target.Parent) then self:Clear(); return end
	if self.Target==target then return end
	self.Target=target; self:EnsureFolder()
end
function Renderer:Clear()
	if not self.Target and not self.Folder then return end
	self.Target=nil
	if self.Folder then self.Folder:Destroy(); self.Folder=nil end
	table.clear(self.Arrows); self.Beam=nil
end
function Renderer:Update(dt)
	local target=self.Target
	if not (target and target.Parent) then if self.Target then self:Clear() end; return end
	local player=Players.LocalPlayer; local character=player and player.Character; local root=character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local start=root.Position; local finish=target.Position; local delta=finish-start; local flatDelta=Vector3.new(delta.X,0,delta.Z); local distance=flatDelta.Magnitude
	local minimum=number(self.Config,"GuideTrailMinimumDistance",7)
	if distance<=minimum then
		setBeamVisible(self.Beam,false); for _,item in ipairs(self.Arrows) do setArrowVisible(item,false) end
		return
	end
	self:EnsureFolder()
	local direction=flatDelta.Unit; local startOffset=number(self.Config,"GuideTrailStartOffset",4); local endOffset=number(self.Config,"GuideTrailEndOffset",3)
	local usableDistance=math.max(0,distance-startOffset-endOffset); local spacing=math.max(3,number(self.Config,"GuideTrailSpacing",9))
	local count=0
	if #self.Arrows>0 then count=math.clamp(math.floor(usableDistance/spacing),1,#self.Arrows) end
	local trailHeight=number(self.Config,"GuideTrailHeightOffset",1.8); local height=Vector3.new(0,trailHeight,0)
	local beamStartHeight=number(self.Config,"GuideTrailBeamStartHeightOffset",-1); local beamStart=start+direction*startOffset+Vector3.new(0,beamStartHeight,0); local beamEnd=finish-direction*endOffset+height
	if self.Beam then self.Beam.StartPart.CFrame=CFrame.new(beamStart); self.Beam.EndPart.CFrame=CFrame.new(beamEnd); setBeamVisible(self.Beam,true) end
	self.Elapsed+=dt; local pulseSpeed=number(self.Config,"GuideTrailPulseSpeed",2); local pulseAmplitude=math.max(0,number(self.Config,"GuideTrailPulseAmplitude",.4)); local scale=number(self.Config,"GuideTrailArrowScale",1)
	local shaftForward=number(self.Config,"GuideTrailShaftLength",2.6)*.48*scale
	local headForward=(number(self.Config,"GuideTrailShaftLength",2.6)*.78+number(self.Config,"GuideTrailHeadLength",1.05)*.45)*scale
	local headSide=number(self.Config,"GuideTrailHeadWidth",.36)*.95*scale
	local color=self.Config:GetAttribute("TutorialGold") or Color3.fromRGB(255,196,66)
	if self.Beam then self.Beam.Aura.Color=ColorSequence.new(color); self.Beam.Core.Color=ColorSequence.new(color); if self.Beam.Chevron then self.Beam.Chevron.Color=ColorSequence.new(color) end end
	for index,item in ipairs(self.Arrows) do
		for _,object in ipairs({item.Shaft,item.Left,item.Right}) do object.Color=color end
		if index<=count then
			local travel=startOffset+usableDistance*(index/(count+1)); local center=start+direction*travel+height
			local frame=CFrame.lookAt(center,center+direction); local rightVector=frame.RightVector; local lift=Vector3.new(0,pulseSpeed>0 and pulseAmplitude*math.sin(self.Elapsed*pulseSpeed+index*.55) or 0,0)
			item.Shaft.CFrame=frame+lift
			item.Left.CFrame=CFrame.lookAt(center+lift+direction*shaftForward-rightVector*headSide,center+lift+direction*headForward)
			item.Right.CFrame=CFrame.lookAt(center+lift+direction*shaftForward+rightVector*headSide,center+lift+direction*headForward)
			setArrowVisible(item,true)
		else setArrowVisible(item,false) end
	end
end
function Renderer:Destroy()
	self:Clear(); if self.Connection then self.Connection:Disconnect(); self.Connection=nil end
end
return Renderer

-- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
-- NTR_GARAGE_FLOW_REFINEMENT_V2
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- NTR_GARAGE_REPLACEMENT_SHARED_COMPONENTS_V1
-- NTR_OWNED_GARAGE_PHASE8_SHARED_PRESENTATION
-- NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Racing=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local inRace=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing"):WaitForChild("InRace")
local M={}
-- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
function M.FormatNumber(value)
	local numeric=tonumber(value) or 0; local negative=numeric<0; local digits=tostring(math.floor(math.abs(numeric)+.5)); local reversed=string.gsub(string.reverse(digits),"(%d%d%d)","%1,"); local grouped=string.gsub(string.reverse(reversed),"^,",""); return (negative and "-" or "")..grouped
end
function M.FormatMoney(value) return Racing.FormatMoney(value) end
function M.ProjectEconomy(response,fallback) return Racing.ProjectEconomy(response,fallback) end
function M.EconomyMetric(parent,props) return Racing.MetricLabel(parent,props) end
function M.ActionButton(parent,props)
	props=props or {}; local button=Racing.Button(parent,{Name=props.Name or "GarageAction",Text="",Size=props.Size or UDim2.fromOffset(170,46),Color=props.Color or Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=props.StrokeColor or Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),FocusColor=props.FocusColor or Racing.Colour("Telemetry")}); button:SetAttribute("CanonicalGarageAction",true)
	local group=Instance.new("Frame"); group.Name="ActionContent"; group.AnchorPoint=Vector2.new(.5,.5); group.Position=UDim2.fromScale(.5,.5); group.Size=UDim2.new(0,0,1,0); group.AutomaticSize=Enum.AutomaticSize.X; group.BackgroundTransparency=1; group.ZIndex=button.ZIndex+1; group.Parent=button
	local layout=Instance.new("UIListLayout"); layout.FillDirection=Enum.FillDirection.Horizontal; layout.HorizontalAlignment=Enum.HorizontalAlignment.Center; layout.VerticalAlignment=Enum.VerticalAlignment.Center; layout.Padding=UDim.new(0,8); layout.Parent=group
	local image=Instance.new("ImageLabel"); image.Name="ActionIcon"; image.BackgroundTransparency=1; image.BorderSizePixel=0; image.Size=UDim2.fromOffset(22,22); image.ImageColor3=Racing.Colour("Text",Color3.new(1,1,1)); image.ZIndex=group.ZIndex+1; image.Parent=group
	local glyph=Instance.new("TextLabel"); glyph.Name="ActionGlyph"; glyph.BackgroundTransparency=1; glyph.Size=UDim2.fromOffset(22,26); glyph.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); glyph.TextSize=22; glyph.TextXAlignment=Enum.TextXAlignment.Center; glyph.TextYAlignment=Enum.TextYAlignment.Center; glyph.ZIndex=group.ZIndex+1; Racing.Font(glyph,"Heading"); glyph.Parent=group
	local label=Instance.new("TextLabel"); label.Name="ActionText"; label.BackgroundTransparency=1; label.AutomaticSize=Enum.AutomaticSize.X; label.Size=UDim2.new(0,0,1,0); label.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); label.TextSize=14; label.TextXAlignment=Enum.TextXAlignment.Center; label.TextYAlignment=Enum.TextYAlignment.Center; label.ZIndex=group.ZIndex+1; Racing.Font(label,"Heading"); label.Parent=group
	M.SetActionButton(button,props.Text,props.Icon,props.IconText); return button
end
function M.SetActionButton(button,text,icon,iconText)
	local group=button and button:FindFirstChild("ActionContent"); if not group then button.Text=string.upper(tostring(text or "")); return end
	local image=group:FindFirstChild("ActionIcon"); local glyph=group:FindFirstChild("ActionGlyph"); local label=group:FindFirstChild("ActionText"); local imageText=tostring(icon or ""); if image then image.Image=imageText; image.Visible=imageText~="" end; if glyph then glyph.Text=tostring(iconText or ""); glyph.Visible=imageText=="" and glyph.Text~="" end; if label then label.Text=string.upper(tostring(text or "")) end
end

local function metricNumber(name,fallback) local v=inRace:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function gradient(parent,a,b,rotation)
	local g=Instance.new("UIGradient"); g.Name="SurfaceGradient"; g.Color=ColorSequence.new(a,b); g.Rotation=rotation or 90; g.Parent=parent; return g
end
function M.Panel(parent,name,props)
	props=props or {}; local p=Racing.Panel(parent,{Name=name,Color=props.Color or Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),Transparency=props.Transparency or .12,StrokeColor=props.StrokeColor or Racing.Colour("Outline",Color3.fromRGB(244,46,151)),StrokeTransparency=props.StrokeTransparency or .12,StrokeWidth=props.StrokeWidth,NoStroke=props.NoStroke==true,NoGlow=props.NoGlow==true})
	gradient(p,Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90); return p
end
function M.MetricCard(parent,name)
	local p=Racing.Panel(parent,{Name=name,Color=Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Transparency=metricNumber("MetricCardTransparency",.34),NoStroke=true}); local corner=p:FindFirstChildOfClass("UICorner"); if corner then Racing.SetCorner(corner,metricNumber("MetricCardCornerRadius",9)) end; local g=gradient(p,Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90); g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(1,.28)}); return p
end
function M.Card(parent,props)
	props=props or {}; local selected=props.Selected==true; local accent=selected and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or (props.Muted and Color3.fromRGB(132,142,145) or Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)))
	local card=Racing.Button(parent,{Name=props.Name or "GarageCard",Text="",Size=props.Size or UDim2.fromOffset(226,146),Color=selected and Color3.fromRGB(18,45,54) or Racing.Colour("Panel",Color3.fromRGB(15,19,24)),StrokeColor=accent,FocusColor=Racing.Colour("Telemetry"),StrokeWidth=selected and 2 or 1.2})
	card:SetAttribute("CanonicalGarageCard",true); card.ClipsDescendants=false
	local imageH=props.ImageHeight or 136
	local holder=Instance.new("Frame"); holder.Name="ImageSlot"; holder.BackgroundTransparency=1; holder.BorderSizePixel=0; holder.ClipsDescendants=true; holder.Position=UDim2.fromOffset(5,4); holder.Size=UDim2.new(1,-10,0,imageH); holder.ZIndex=card.ZIndex+2; holder.Parent=card
	Racing.Corner(holder,5)
	local imageZoom=props.ImageZoom or 1.06; local image=Instance.new("ImageLabel"); image.Name="Artwork"; image.BackgroundTransparency=1; image.BorderSizePixel=0; image.AnchorPoint=Vector2.new(.5,.5); image.Position=UDim2.fromScale(.5,.5); image.Size=UDim2.fromScale(imageZoom,imageZoom); image.ScaleType=props.ImageScaleType or Enum.ScaleType.Fit; image.Image=props.Image or ""; image.ZIndex=holder.ZIndex+1; image.Parent=holder; Racing.Corner(image,5)
	local overlayName=props.NameOverlay~=false
	if overlayName then local plate=Instance.new("Frame"); plate.Name="NamePlate"; plate.BackgroundColor3=Color3.fromRGB(5,8,12); plate.BackgroundTransparency=.16; plate.BorderSizePixel=0; plate.Position=UDim2.new(0,5,1,-29); plate.Size=UDim2.new(1,-10,0,25); plate.ZIndex=holder.ZIndex+2; plate.Parent=card; Racing.Corner(plate,4); local fade=Instance.new("UIGradient"); fade.Rotation=90; fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.46),NumberSequenceKeypoint.new(1,.06)}); fade.Parent=plate; local name=Racing.Label(plate,{Name="ItemName",Text=props.DisplayName or "",Position=UDim2.fromOffset(8,1),Size=UDim2.new(1,-16,1,-2),TextSize=12,XAlignment=Enum.TextXAlignment.Center,Truncate=Enum.TextTruncate.AtEnd,Role="Button"}); name.ZIndex=plate.ZIndex+1 else local name=Racing.Label(card,{Name="ItemName",Text=props.DisplayName or "",Position=UDim2.fromOffset(9,imageH+6),Size=UDim2.new(1,-18,0,20),TextSize=props.NameTextSize or 10,XAlignment=Enum.TextXAlignment.Center,Truncate=Enum.TextTruncate.AtEnd,Role=props.NameRole}); name.ZIndex=card.ZIndex+4 end
	if props.EmptyPlus then local circle=Instance.new("Frame"); circle.Name="EmptyPlus"; circle.AnchorPoint=Vector2.new(.5,.5); circle.Position=UDim2.fromScale(.5,.43); circle.Size=UDim2.fromOffset(58,58); circle.BackgroundColor3=Racing.Colour("PanelSoft"); circle.BorderSizePixel=0; circle.ZIndex=card.ZIndex+5; circle.Parent=card; Racing.Corner(circle,29); local plus=Racing.Label(circle,{Text="+",Size=UDim2.fromScale(1,1),TextSize=34,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); plus.ZIndex=circle.ZIndex+1 end
	if props.Rating then local badge=Instance.new("Frame"); badge.Name="RatingBadge"; badge.AnchorPoint=Vector2.new(1,0); badge.Position=UDim2.new(1,-8,0,8); badge.Size=UDim2.fromOffset(68,21); badge.BackgroundColor3=props.RatingColor or accent; badge.BorderSizePixel=0; badge.ZIndex=card.ZIndex+6; badge.Parent=card; Racing.Corner(badge,4); local t=Racing.Label(badge,{Text=props.Rating,Size=UDim2.fromScale(1,1),TextSize=9,XAlignment=Enum.TextXAlignment.Center}); t.ZIndex=badge.ZIndex+1 end
	return card
end
function M.ModuleCard(parent,props) props=props or {}; props.ImageHeight=props.ImageHeight or 104; props.ImageZoom=props.ImageZoom or 1; props.NameOverlay=false; props.NameTextSize=props.NameTextSize or 15; props.NameRole=props.NameRole or "Heading"; props.ImageScaleType=props.ImageScaleType or Enum.ScaleType.Fit; return M.Card(parent,props) end
-- NTR_GARAGE_MODULE_CARD_VARIANTS_V3
function M.ModuleCategoryCard(parent,props) return M.ModuleCard(parent,props) end
-- NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1
function M.ModuleListingCard(parent,props)
	props=props or {}; local selected=props.Selected==true; local state=tostring(props.SemanticState or "Shop")
	local pink=Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)); local blue=Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)); local grey=Color3.fromRGB(132,142,145)
	local accent=selected and blue or ((state=="InUse" or state=="Locked" or state=="Unavailable") and grey or pink); local invested=state=="Equipped" or state=="Invested"; local fill=invested and Color3.fromRGB(92,31,73) or Racing.Colour("Panel",Color3.fromRGB(15,19,24)) -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1
	local card=Racing.Button(parent,{Name=props.Name or "ModuleListingCard",Text="",Size=props.Size or UDim2.fromOffset(210,146),Color=fill,StrokeColor=accent,FocusColor=blue,StrokeWidth=selected and 2 or 1.35}); card:SetAttribute("CanonicalGarageCard",true); card:SetAttribute("ModuleSemanticState",state); card.ClipsDescendants=false
	local surface=gradient(card,invested and Color3.fromRGB(118,38,91) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90); surface.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(1,.28)})
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
	-- Locked shop cards intentionally reserve the complete upper area for one clear lock symbol.
	if state~="Locked" then
		local vehicle=Racing.Label(card,{Name="VehicleName",Text=string.upper(props.VehicleName or props.Eyebrow or "UNIVERSAL"),Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,20),TextSize=13,Role="Heading"}); vehicle.ZIndex=card.ZIndex+2
		local variant=tostring(props.TagText or props.Variant or props.DisplayName or "STANDARD"); local variantColour=props.TagColor or (variant=="Power" and pink or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or grey))
		local tag=Instance.new("Frame"); tag.Name="Variant"; tag.BackgroundColor3=variantColour; tag.BorderSizePixel=0; tag.Position=UDim2.fromOffset(12,35); tag.Size=UDim2.fromOffset(112,25); tag.ZIndex=card.ZIndex+2; tag.Parent=card; Racing.Corner(tag,4); local tagText=Racing.Label(tag,{Text=string.upper(variant),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}); tagText.ZIndex=tag.ZIndex+1
		if props.Badge then local rating=Instance.new("Frame"); rating.Name="ModuleRating"; rating.AnchorPoint=Vector2.new(1,0); rating.Position=UDim2.new(1,-12,0,35); rating.Size=UDim2.fromOffset(54,25); rating.BackgroundColor3=props.BadgeColor or grey; rating.BorderSizePixel=0; rating.ZIndex=card.ZIndex+2; rating.Parent=card; Racing.Corner(rating,4); local text=Racing.Label(rating,{Text=tostring(props.Badge),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Metric"}); text.ZIndex=rating.ZIndex+1 end
	end
	local priceText=props.PriceText or (props.Price~=nil and M.FormatMoney(props.Price) or nil); if priceText~=nil and state~="Locked" then local price=Racing.Label(card,{Name="Price",Text=tostring(priceText),Position=UDim2.fromOffset(12,74),Size=UDim2.new(1,-24,0,23),TextSize=13,Color=props.PriceColor or Color3.fromRGB(89,255,102),Role="Heading",Truncate=Enum.TextTruncate.None}); price.TextScaled=false; price.TextWrapped=false; price.ZIndex=card.ZIndex+2 end -- NTR_GARAGE_RESPONSIVE_STATUS_TEXT_V1_2
	if state=="Locked" and props.LockImage and props.LockImage~="" then local lockSize=math.max(1,tonumber(props.LockIconSize) or 68); local lockY=math.clamp(tonumber(props.LockIconYScale) or .46,0,1); local lock=Instance.new("ImageLabel"); lock.Name="LockIcon"; lock.BackgroundTransparency=1; lock.BorderSizePixel=0; lock.Image=props.LockImage; lock.AnchorPoint=Vector2.new(.5,.5); lock.Position=UDim2.fromScale(.5,lockY); lock.Size=UDim2.fromOffset(lockSize,lockSize); lock.ZIndex=card.ZIndex+2; lock.Parent=card end
	local divider=Instance.new("Frame"); divider.BackgroundColor3=accent; divider.BackgroundTransparency=.48; divider.BorderSizePixel=0; divider.Position=UDim2.new(0,12,1,-39); divider.Size=UDim2.new(1,-24,0,1); divider.ZIndex=card.ZIndex+2; divider.Parent=card
	local footerColour=(state=="InUse" or state=="Locked" or state=="Unavailable") and grey or Racing.Colour("Text")
	local footer=Racing.Label(card,{Name="Status",Text=string.upper(props.Footer or ""),Position=UDim2.new(0,12,1,-34),Size=UDim2.new(1,-24,0,25),TextSize=10,Color=footerColour,XAlignment=Enum.TextXAlignment.Center,Role="Metric"}); footer.ZIndex=card.ZIndex+2
	return card
end
function M.Popup(root)
	local shell=Instance.new("Frame"); shell.Name="CardActionPopup"; shell.BackgroundTransparency=1; shell.BorderSizePixel=0; shell.AnchorPoint=Vector2.new(.5,1); shell.Size=UDim2.fromOffset(194,38); shell.Visible=false; shell.ZIndex=100; shell.Parent=root
	local button=Racing.Button(shell,{Name="Action",Text="",Size=UDim2.fromScale(1,1),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),FocusColor=Racing.Colour("Telemetry"),ZIndex=102})
	local target,callback,scaleObject,connection
	local function stop() if connection then connection:Disconnect(); connection=nil end end
	local function update() if not (shell.Visible and target and target.Parent and root.Visible) then return end; local scale=scaleObject and scaleObject.Scale or 1; local rootPos=root.AbsolutePosition; shell.Position=UDim2.fromOffset((target.AbsolutePosition.X+target.AbsoluteSize.X*.5-rootPos.X)/math.max(scale,.01),(target.AbsolutePosition.Y-rootPos.Y)/math.max(scale,.01)-8) end
	button.Activated:Connect(function() if callback then callback() end end)
	return {Shell=shell,Set=function(_,newTarget,text,fn,newScale) stop(); target=newTarget; callback=fn; scaleObject=newScale; button.Text=string.upper(text or ""); shell.Visible=target~=nil; if target then update(); connection=RunService.RenderStepped:Connect(update) end end,Hide=function() stop(); shell.Visible=false; target=nil; callback=nil; scaleObject=nil end,Destroy=function() stop(); target=nil; callback=nil; scaleObject=nil; shell:Destroy() end}
end-- NTR_GARAGE_PRESENTATION_SINGLE_OWNER_V1
local presentationOwner = nil
local retiredSurfaces = {}
local ownerConnection = nil
local function suppressRetiredSurfaces()
	if not (presentationOwner and presentationOwner.Parent and presentationOwner.Visible) then return end
	for object in pairs(retiredSurfaces) do
		if object.Parent and object.Visible then object.Visible = false end
	end
end
function M.AcquirePresentation(owner, surfaces)
	if presentationOwner and presentationOwner ~= owner and presentationOwner.Parent then presentationOwner.Visible = false end
	presentationOwner = owner
	for _, object in pairs(surfaces or {}) do
		if typeof(object) == "Instance" and object:IsA("GuiObject") then retiredSurfaces[object] = true; object.Visible = false end
	end
	if next(retiredSurfaces)~=nil and not ownerConnection then ownerConnection = RunService.RenderStepped:Connect(suppressRetiredSurfaces) end
	suppressRetiredSurfaces()
end
function M.ReleasePresentation(owner)
	if presentationOwner == owner then presentationOwner = nil end
	for object in pairs(retiredSurfaces) do if object.Parent then object.Visible = false end end
	if not presentationOwner and ownerConnection then ownerConnection:Disconnect(); ownerConnection=nil; table.clear(retiredSurfaces) end
end
function M.AuditPresentation(owner, labelText)
	local cfg=kit.Config.UI:FindFirstChild("GarageReplacement"); if not (cfg and cfg:GetAttribute("RuntimeAuditEnabled")==true) then return end
	task.defer(function()
		RunService.Heartbeat:Wait(); suppressRetiredSurfaces(); local failures = {}
		if presentationOwner ~= owner then table.insert(failures, "canonical owner changed") end
		for object in pairs(retiredSurfaces) do if object.Parent and object.Visible then table.insert(failures, object.Name) end end
		if #failures == 0 then print("[NTR Garage Presentation Owner] PASS " .. tostring(labelText or owner.Name)) else warn("[NTR Garage Presentation Owner] FAIL " .. table.concat(failures, " | ")) end
	end)
end-- NTR_GARAGE_SHARED_PERFORMANCE_V2
-- NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1
function M.RenderPerformance(parent,options)
	options=options or {}; local attribute=options.GeneratedAttribute or "GeneratedGarageUI"
	for _,child in ipairs(parent:GetChildren()) do if child:GetAttribute(attribute) then child:Destroy() end end
	local function generated(object) object:SetAttribute(attribute,true); return object end
	local performance=options.Performance
	if not performance then generated(Racing.Label(parent,{Text=options.EmptyText or "NO PERFORMANCE DATA",Size=UDim2.new(1,0,0,42),TextSize=options.StatNameTextSize or 11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"})); return end
	local overall=performance.Overall or {}; local tier=tostring(overall.Tier or "E"); local index=math.floor(tonumber(overall.PerformanceIndex) or 100); local tierColor=typeof(options.TierColor)=="function" and options.TierColor(tier) or Racing.Colour("PanelSoft")
	local header=generated(Instance.new("Frame")); header.Name="Rating"; header.LayoutOrder=1; header.BackgroundColor3=tierColor; header.BorderSizePixel=0; header.Size=UDim2.new(1,0,0,42); header.Parent=parent; Racing.Corner(header,4)
	Racing.Label(header,{Text=tier.."  "..index,Position=UDim2.fromOffset(8,0),Size=UDim2.new(.5,-8,1,0),TextSize=options.RatingTextSize or 20,Role="Metric"})
	Racing.Label(header,{Text="PERFORMANCE",Position=UDim2.fromScale(.5,0),Size=UDim2.new(.5,-8,1,0),TextSize=options.HeadingTextSize or 11,XAlignment=Enum.TextXAlignment.Right,Role="Heading"})
	local baseline=options.Baseline; local reference=tonumber(options.Reference) or 180
	for order,name in ipairs({"Speed","Acceleration","Handling","Drift","Braking","Boost"}) do
		local value=tonumber(performance.Headline and performance.Headline[name]) or 0; local baseValue=tonumber(baseline and baseline.Headline and baseline.Headline[name]); local delta=baseValue and (math.floor(value+.5)-math.floor(baseValue+.5)) or 0; local deltaText=delta==0 and "-" or ((delta>0 and "+" or "")..tostring(delta)); local deltaColor=delta>0 and Color3.fromRGB(89,255,102) or (delta<0 and Color3.fromRGB(255,105,116) or Racing.Colour("Text"))
		local stat=generated(Instance.new("Frame")); stat.Name=name; stat.LayoutOrder=order+1; stat.BackgroundTransparency=1; stat.Size=UDim2.new(1,0,0,38); stat.Parent=parent
		Racing.Label(stat,{Text=string.upper(name),Size=UDim2.new(.55,0,0,17),TextSize=options.StatNameTextSize or 11,Role="Heading"})
		Racing.Label(stat,{Text=tostring(math.floor(value+.5)),Position=UDim2.new(.55,0,0,0),Size=UDim2.new(.25,0,0,17),TextSize=options.StatValueTextSize or 12,XAlignment=Enum.TextXAlignment.Right,Role="Metric"})
		Racing.Label(stat,{Text=deltaText,Position=UDim2.new(.82,0,0,0),Size=UDim2.new(.18,0,0,17),TextSize=options.StatValueTextSize or 12,Color=deltaColor,XAlignment=Enum.TextXAlignment.Right,Role="Metric"})
		local track=Instance.new("Frame"); track.BackgroundColor3=Racing.Colour("PanelSoft"); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(0,22); track.Size=UDim2.new(1,0,0,9); track.Parent=stat; Racing.Corner(track,5)
		local fill=Instance.new("Frame"); fill.BackgroundColor3=Racing.Colour("Telemetry"); fill.BorderSizePixel=0; fill.Size=UDim2.fromScale(math.clamp(value/reference,0,1),1); fill.Parent=track; Racing.Corner(fill,5); local barGradient=Instance.new("UIGradient"); barGradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry")); barGradient.Parent=fill
	end
end
-- NTR_GARAGE_SHARED_SHELL_V2
-- NTR_GARAGE_RESPONSIVE_SCALED_TOUCH_V1_2
local responsiveAuditKeys=setmetatable({},{__mode="k"})
local responsiveConfig=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local function responsiveNumber(N,name,fallback) local value=responsiveConfig:GetAttribute(name); if typeof(value)=="number" then return value end; return N(name,fallback) end
function M.HeaderTextSizes() return responsiveNumber(function(_,fallback) return fallback end,"HeaderTitleTextSize",22),responsiveNumber(function(_,fallback) return fallback end,"HeaderSubtitleTextSize",15) end -- NTR_GARAGE_FLOW_REFINEMENT_V2
local function rememberSize(object)
	local original=object:GetAttribute("NTRResponsiveOriginalSize")
	if typeof(original)~="UDim2" then original=object.Size; object:SetAttribute("NTRResponsiveOriginalSize",original) end
	return original
end
local function restoreResponsive(root)
	for _,object in ipairs(root:GetDescendants()) do
		local originalSize=object:GetAttribute("NTRResponsiveOriginalSize"); if typeof(originalSize)=="UDim2" then object.Size=originalSize end
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			local originalText=object:GetAttribute("NTRResponsiveOriginalTextSize"); if type(originalText)=="number" then object.TextSize=originalText end
			local originalScaled=object:GetAttribute("NTRResponsiveOriginalTextScaled"); if type(originalScaled)=="boolean" then object.TextScaled=originalScaled end
			local constraint=object:FindFirstChild("NTRTouchTextConstraint"); if constraint then constraint:Destroy() end
		end
	end
end
local function targetSize(object,pixels,scale)
	if not (object and object:IsA("GuiObject")) then return end
	local original=rememberSize(object); local minimum=pixels/math.max(scale,.01); local xo,yo=original.X.Offset,original.Y.Offset
	if original.X.Scale==0 then xo=math.max(xo,math.ceil(minimum)) end
	if original.Y.Scale==0 then yo=math.max(yo,math.ceil(minimum)) end
	object.Size=UDim2.new(original.X.Scale,xo,original.Y.Scale,yo)
end
local function applyTouchPresentation(ui,N,scale)
	restoreResponsive(ui.Root)
	if not UserInputService.TouchEnabled then return end
	local arrow=math.max(28,responsiveNumber(N,"TouchArrowPixels",32))
	for _,button in ipairs({ui.Left,ui.RightArrow}) do targetSize(button,arrow,scale) end
end
local function queueResponsiveAudit(ui,options,N,viewport,scale,categoryTop)
	if not (UserInputService.TouchEnabled and ui.Root.Visible) then return end
	local title=ui.Context and ui.Context.Title or "Browser"; local key=string.format("%dx%d:%s",math.floor(viewport.X),math.floor(viewport.Y),tostring(title)); if responsiveAuditKeys[ui]==key then return end; responsiveAuditKeys[ui]=key
	task.defer(function()
		RunService.Heartbeat:Wait(); if not (ui.Root and ui.Root.Parent and ui.Root.Visible) then return end
		local failures={}; local function expect(ok,message) if not ok then table.insert(failures,message) end end; local arrow=math.max(28,responsiveNumber(N,"TouchArrowPixels",32))
		local canvas=ui.Host and ui.Host.Canvas; if canvas then local p,s=canvas.AbsolutePosition,canvas.AbsoluteSize; expect(p.X>=-1 and p.Y>=-1,"canvas begins outside viewport"); expect(p.X+s.X<=viewport.X+1 and p.Y+s.Y<=viewport.Y+1,"canvas ends outside viewport") end
		for _,button in ipairs({ui.Left,ui.RightArrow}) do if button and button.Visible then expect(button.AbsoluteSize.X>=arrow-1 and button.AbsoluteSize.Y>=arrow-1,"undersized carousel arrow "..button.Name) end end
		if ui.Categories and ui.Categories.Visible then expect(math.abs(ui.Categories.AbsolutePosition.Y-categoryTop)<=3,"category rail top differs from free-roam contract") end
		for _,container in ipairs({ui.Cash,ui.Capacity}) do if container then for _,button in ipairs(container:GetDescendants()) do if button:IsA("GuiButton") and button.Visible then local p,s=button.AbsolutePosition,button.AbsoluteSize; local cp,cs=container.AbsolutePosition,container.AbsoluteSize; expect(p.X>=cp.X-1 and p.Y>=cp.Y-1 and p.X+s.X<=cp.X+cs.X+1 and p.Y+s.Y<=cp.Y+cs.Y+1,"economy action escapes its card") end end end end
		for _,button in ipairs(options.Actions or {}) do if button.Visible then expect(button.AbsolutePosition.X+button.AbsoluteSize.X<=ui.Root.AbsolutePosition.X+ui.Root.AbsoluteSize.X+1,"action escapes viewport "..button.Name) end end
		for _,object in ipairs(ui.Root:GetDescendants()) do if object:IsA("TextLabel") and object.Name=="Price" and string.find(string.upper(tostring(object.Text)),"LIMIT REACHED",1,true) then expect(object.TextTruncate==Enum.TextTruncate.None,"limit status truncation enabled"); expect(object.TextBounds.X<=object.AbsoluteSize.X+2,"limit status exceeds label") end end
		if ui.Categories and ui.Categories.Visible and ui.Carousel then expect(ui.Categories.AbsolutePosition.Y+ui.Categories.AbsoluteSize.Y<=ui.Carousel.AbsolutePosition.Y-2,"categories overlap carousel") end
		if ui.Popup and ui.Popup.Shell.Visible then for _,button in ipairs(options.Actions or {}) do if button.Visible then expect(button.AbsolutePosition.Y+button.AbsoluteSize.Y<=ui.Popup.Shell.AbsolutePosition.Y-2,"navigation overlaps card action popup") end end; if ui.Budget and ui.Budget.Visible then expect(ui.Budget.AbsolutePosition.Y+ui.Budget.AbsoluteSize.Y<=ui.Popup.Shell.AbsolutePosition.Y-2,"budget overlaps card action") end end
		if #failures==0 then print("[NTR Garage Responsive Runtime] PASS "..key.." scale="..string.format("%.3f",scale)) else warn("[NTR Garage Responsive Runtime] FAIL "..key.." | "..table.concat(failures," | ")) end
	end)
end
function M.LayoutGarageShell(ui,options)
	-- NTR_GARAGE_SHARED_SHELL_CANONICAL_HOST_V3
	options=options or {}; local N=assert(options.Number,"Garage shell Number resolver missing"); local viewport=options.Viewport or Vector2.new(1600,900); local touch=UserInputService.TouchEnabled and responsiveNumber(N,"ResponsiveTouchEnabled",1)~=0
	local safeTop=touch and math.max(0,responsiveNumber(N,"TouchSafeTop",4)) or 0; local safeBottom=touch and math.max(0,responsiveNumber(N,"TouchSafeBottom",4)) or 0; local safeSide=touch and math.max(0,responsiveNumber(N,"TouchSafeSide",4)) or 0; local availableWidth=math.max(1,viewport.X-safeSide*2); local availableHeight=math.max(1,viewport.Y-safeTop-safeBottom)
	local minimum=touch and math.max(.1,responsiveNumber(N,"TouchScaleMin",.25)) or (options.MinimumScale or .68); local scale=math.clamp(math.min(availableWidth/N("BaseWidth",1600),availableHeight/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); ui.Scale.Scale=scale; local vw,vh=availableWidth/scale,availableHeight/scale
	if ui.Host and ui.Host.Canvas then ui.Host.Canvas.Position=UDim2.fromOffset(safeSide,safeTop); ui.Host.Canvas.Size=UDim2.fromOffset(vw,vh) end; ui.Root.Position=UDim2.fromOffset(0,0); ui.Root.Size=UDim2.fromOffset(vw,vh)
	applyTouchPresentation(ui,N,scale)
	if ui.Right then ui.Right.Name="Right" end; if ui.Economy then ui.Economy.Name="Economy" end; if ui.Carousel then ui.Carousel.Name="Carousel" end; if ui.Paint then ui.Paint.Name="Paint" end; if ui.Scroller and ui.Scroller.Name=="Frame" then ui.Scroller.Name="CarouselScroller" end
	local margin,gap=N("Margin",18),N("Gap",14); local carouselH=N("CarouselHeight",166); local carouselTop=vh-margin-carouselH; local arrowW=N("ArrowWidth",42); local railReserve=30; ui.LayoutScale=scale; ui.ReferenceWidth=vw
	ui.Header.AnchorPoint=Vector2.new(.5,0); ui.Header.Position=UDim2.fromOffset(vw*.5,28); ui.Header.Size=UDim2.fromOffset(420,responsiveNumber(N,"HeaderHeight",68))
	local categoryTop=touch and responsiveNumber(N,viewport.Y<500 and "TouchCategoryTopTiny" or "TouchCategoryTop",viewport.Y<500 and 68 or 82) or (safeTop+72*scale); local categoryY=touch and math.max(0,(categoryTop-safeTop)/math.max(scale,.01)) or 72
	local categoryWidth=ui.Context and ui.Context.LeftCardMode and N("ModuleCategoryRailWidth",238) or N("CategoryWidth",214); ui.Categories.Position=UDim2.fromOffset(margin,categoryY); ui.Categories.Size=UDim2.fromOffset(categoryWidth,math.max(170,carouselTop-categoryY-N("CategoryCarouselClearance",82)))
	local economyCardHeight=responsiveNumber(N,"EconomyCardHeight",N("EconomyHeight",46)); local economyStackGap=responsiveNumber(N,"EconomyStackGap",10)
	ui.Right.AnchorPoint=Vector2.new(1,0); ui.Right.Position=UDim2.fromOffset(vw-margin,28); ui.Right.Size=UDim2.fromOffset(N("StatsWidth",354),0); ui.Stats.LayoutOrder=1; ui.Economy.LayoutOrder=2; ui.Economy.Size=UDim2.new(1,0,0,economyCardHeight*2+economyStackGap); local rightLayout=ui.Right:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout"); rightLayout.Padding=UDim.new(0,gap); rightLayout.SortOrder=Enum.SortOrder.LayoutOrder; rightLayout.Parent=ui.Right
	ui.Capacity.AnchorPoint=Vector2.new(0,0); ui.Capacity.Position=UDim2.fromOffset(0,0); ui.Capacity.Size=UDim2.new(1,0,0,economyCardHeight); ui.Cash.AnchorPoint=Vector2.new(0,0); ui.Cash.Position=UDim2.fromOffset(0,economyCardHeight+economyStackGap); ui.Cash.Size=UDim2.new(1,0,0,economyCardHeight) -- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
	ui.Carousel.Position=UDim2.fromOffset(margin+railReserve+gap,carouselTop); ui.Carousel.Size=UDim2.fromOffset(vw-2*(margin+railReserve+gap),carouselH); if ui.Scroller then ui.Scroller.Size=UDim2.fromScale(1,1) end; if ui.Paint then ui.Paint.Size=UDim2.fromScale(1,1) end; ui.ReferenceCarouselWidth=vw-2*(margin+railReserve+gap)
	ui.Left.AnchorPoint=Vector2.new(0,.5); ui.Left.Position=UDim2.fromOffset(margin,carouselTop+carouselH*.5); ui.Left.Size=UDim2.fromOffset(math.max(arrowW,ui.Left.Size.X.Offset),math.max(N("ArrowHeight",72),ui.Left.Size.Y.Offset)); ui.RightArrow.AnchorPoint=Vector2.new(1,.5); ui.RightArrow.Position=UDim2.fromOffset(vw-margin,carouselTop+carouselH*.5); ui.RightArrow.Size=UDim2.fromOffset(math.max(arrowW,ui.RightArrow.Size.X.Offset),math.max(N("ArrowHeight",72),ui.RightArrow.Size.Y.Offset))
	local actionWidth=(N("StatsWidth",354)-gap)*.5; local actionHeight=responsiveNumber(N,"NavigationButtonHeight",N("EconomyHeight",46)); local actionBottom=carouselTop-responsiveNumber(N,"NavigationPopupClearance",48); local actionX=vw-margin; if ui.Context and ui.Context.ExitBelowEconomy and ui.Exit.Visible then ui.Exit.AnchorPoint=Vector2.new(1,0); ui.Exit.Size=UDim2.fromOffset(actionWidth,actionHeight); ui.Exit.Position=UDim2.fromOffset(vw-margin,28+economyCardHeight*2+economyStackGap+gap) end; for _,actionButton in ipairs(options.Actions or {}) do if actionButton.Visible and not (ui.Context and ui.Context.ExitBelowEconomy and actionButton==ui.Exit) then actionButton.AnchorPoint=Vector2.new(1,1); actionButton.Size=UDim2.fromOffset(actionWidth,actionHeight); actionButton.Position=UDim2.fromOffset(actionX,actionBottom); actionX-=actionWidth+gap end end
	queueResponsiveAudit(ui,options,N,viewport,scale,categoryTop)
	return {Scale=scale,Width=vw,Height=vh,CarouselTop=carouselTop,Touch=touch,SafeTop=safeTop,SafeBottom=safeBottom,SafeSide=safeSide}
end

-- NTR_GARAGE_INDEPENDENT_CANONICAL_HOST_V1
local canonicalHost=nil
function M.CanonicalHost()
	local player=game:GetService("Players").LocalPlayer; local playerGui=player:WaitForChild("PlayerGui")
	if canonicalHost and canonicalHost.Gui.Parent==playerGui and canonicalHost.Canvas.Parent==canonicalHost.Gui and canonicalHost.Scale.Parent==canonicalHost.Canvas then return canonicalHost end
	local gui=playerGui:FindFirstChild("CanonicalGarageGui")
	if gui and not gui:IsA("ScreenGui") then gui:Destroy(); gui=nil end
	if not gui then gui=Instance.new("ScreenGui"); gui.Name="CanonicalGarageGui"; gui.Parent=playerGui end
	gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=40; gui.Enabled=true
	local canvas=gui:FindFirstChild("CanonicalCanvas")
	if canvas and not canvas:IsA("Frame") then canvas:Destroy(); canvas=nil end
	if not canvas then canvas=Instance.new("Frame"); canvas.Name="CanonicalCanvas"; canvas.Parent=gui end
	canvas.BackgroundTransparency=1; canvas.BorderSizePixel=0; canvas.Position=UDim2.fromOffset(0,0); canvas.Size=UDim2.fromOffset(1600,900)
	local scale=canvas:FindFirstChild("CanonicalScale")
	if scale and not scale:IsA("UIScale") then scale:Destroy(); scale=nil end
	if not scale then scale=Instance.new("UIScale"); scale.Name="CanonicalScale"; scale.Parent=canvas end
	for _,child in ipairs(canvas:GetChildren()) do if child:IsA("UIScale") and child~=scale then child:Destroy() end end
	canonicalHost={Gui=gui,Canvas=canvas,Scale=scale}; return canonicalHost
end
function M.ConfirmationModal(root,options)
	return Racing.ConfirmationModal(root,options)
end
-- NTR_OWNED_GARAGE_ANCHORED_DROPDOWN_V2
function M.AttachDropdownChevron(button)
	local chevron=button:FindFirstChild("DropdownChevron")
	if not chevron then chevron=Racing.Label(button,{Name="DropdownChevron",Text=utf8.char(9662),Position=UDim2.new(1,-30,0,0),Size=UDim2.new(0,22,1,0),TextSize=14,Role="Button",XAlignment=Enum.TextXAlignment.Center}); chevron.AnchorPoint=Vector2.new(0,.5); chevron.Position=UDim2.new(1,-30,.5,0); chevron.ZIndex=button.ZIndex+3 end
	return chevron
end
function M.SetDropdownOpen(button,isOpen)
	local chevron=M.AttachDropdownChevron(button); chevron.Rotation=isOpen and 180 or 0
end
function M.AnchoredDropdown(parent,options)
	options=options or {}; local panel; local anchor; local outsideConnection; local rows={}; local callback; local metrics={}
	local function notify(target,isOpen) if type(options.OnOpenChanged)=="function" then options.OnOpenChanged(target,isOpen) end end
	local function inside(object,point)
		if not (object and object.Parent and object.Visible) then return false end; local position=object.AbsolutePosition; local size=object.AbsoluteSize; return point.X>=position.X and point.X<=position.X+size.X and point.Y>=position.Y and point.Y<=position.Y+size.Y
	end
	local function hide()
		local closedAnchor=anchor; if outsideConnection then outsideConnection:Disconnect(); outsideConnection=nil end; if panel then panel:Destroy(); panel=nil end; anchor=nil; rows={}; callback=nil; if closedAnchor then notify(closedAnchor,false) end
	end
	local function place()
		if not (panel and anchor and anchor.Parent) then return end; local scale=math.max(.01,tonumber(options.Scale and options.Scale() or 1) or 1); local logical=(anchor.AbsolutePosition-parent.AbsolutePosition)/scale; local width=parent.AbsoluteSize.X/scale; panel.Position=UDim2.fromOffset(0,logical.Y+anchor.AbsoluteSize.Y/scale+(tonumber(metrics.Gap) or 5)); panel.Size=UDim2.fromOffset(width,panel.Size.Y.Offset)
	end
	local function show(target,newRows,onPick,newMetrics)
		hide(); anchor=target; rows=type(newRows)=="table" and newRows or {}; callback=onPick; metrics=type(newMetrics)=="table" and newMetrics or {}; local rowHeight=math.max(40,tonumber(metrics.RowHeight) or 46); local rowGap=math.max(0,tonumber(metrics.RowGap) or 5); local maximum=math.max(1,math.floor(tonumber(metrics.MaxRows) or 5)); local visibleCount=math.max(1,math.min(#rows,maximum)); local panelHeight=visibleCount*rowHeight+math.max(0,visibleCount-1)*rowGap
		panel=Instance.new("Frame"); panel.Name="AnchoredDropdown"; panel.BackgroundTransparency=1; panel.BorderSizePixel=0; panel.ClipsDescendants=true; panel.ZIndex=tonumber(options.ZIndex) or 80; panel.Size=UDim2.fromOffset(100,panelHeight); panel.Parent=parent
		local scroll=Instance.new("ScrollingFrame"); scroll.Name="Choices"; scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.Size=UDim2.fromScale(1,1); scroll.CanvasSize=UDim2.fromOffset(0,math.max(1,#rows)*rowHeight+math.max(0,#rows-1)*rowGap); scroll.ScrollBarThickness=#rows>maximum and 3 or 0; scroll.ScrollBarImageColor3=Racing.Colour("Telemetry"); scroll.ZIndex=panel.ZIndex+1; scroll.Parent=panel
		local renderRows=#rows>0 and rows or {{Text="NO OPTIONS AVAILABLE",Disabled=true}}
		for index,row in ipairs(renderRows) do
			local selected=row.Selected==true; local button=Instance.new("TextButton"); button.Name="Choice"..index; button.AutoButtonColor=false; button.BorderSizePixel=0; button.BackgroundColor3=selected and Racing.Colour("PanelBlue") or Racing.Colour("PanelSoft"); button.BackgroundTransparency=.04; button.Position=UDim2.fromOffset(0,(index-1)*(rowHeight+rowGap)); button.Size=UDim2.new(1,-(#rows>maximum and 7 or 0),0,rowHeight); button.Text=""; button.ZIndex=panel.ZIndex+2; button.Active=row.Disabled~=true; button.Selectable=row.Disabled~=true; button.Parent=scroll; Racing.Corner(button,6)
			local fill=Instance.new("UIGradient"); fill.Name="ChoiceGradient"; fill.Rotation=12; fill.Color=selected and ColorSequence.new(Racing.Colour("PanelBlue"),Racing.Colour("PanelSoft")) or ColorSequence.new(Racing.Colour("PanelSoft"),Racing.Colour("PanelDeep")); fill.Parent=button
			local imageText=tostring(row.Icon or ""); local glyphText=tostring(row.IconText or ""); local image=Instance.new("ImageLabel"); image.Name="ChoiceIcon"; image.BackgroundTransparency=1; image.BorderSizePixel=0; image.Position=UDim2.fromOffset(12,math.floor((rowHeight-22)*.5)); image.Size=UDim2.fromOffset(22,22); image.Image=imageText; image.ImageColor3=Racing.Colour("Text"); image.Visible=imageText~=""; image.ZIndex=button.ZIndex+1; image.Parent=button
			local glyph=Racing.Label(button,{Name="ChoiceGlyph",Text=glyphText,Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(22,rowHeight),TextSize=18,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); glyph.Visible=imageText=="" and glyphText~=""; glyph.ZIndex=button.ZIndex+1
			local text=Racing.Label(button,{Name="ChoiceText",Text=string.upper(tostring(row.Text or row.Id or "")),Position=UDim2.fromOffset(44,0),Size=UDim2.new(1,-142,1,0),TextSize=tonumber(metrics.TextSize) or 11,Role="Button",XAlignment=Enum.TextXAlignment.Left}); text.ZIndex=button.ZIndex+1
			local detail=Racing.Label(button,{Name="Detail",Text=string.upper(tostring(row.Detail or "")),Position=UDim2.new(1,-92,0,0),Size=UDim2.fromOffset(78,rowHeight),TextSize=tonumber(metrics.DetailTextSize) or 9,Color=selected and Racing.Colour("Telemetry") or Racing.Colour("Muted"),Role="Metric",XAlignment=Enum.TextXAlignment.Right}); detail.ZIndex=button.ZIndex+1
			button.MouseEnter:Connect(function() if button.Active then button.BackgroundTransparency=0 end end); button.MouseLeave:Connect(function() button.BackgroundTransparency=.04 end)
			if row.Disabled~=true then button.Activated:Connect(function() if callback then callback(row) end end) end
		end
		place(); notify(anchor,true); outsideConnection=UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; local point=Vector2.new(input.Position.X,input.Position.Y); if not inside(panel,point) and not inside(anchor,point) then hide() end
		end)
	end
	return {Show=function(_,target,newRows,onPick,newMetrics) show(target,newRows,onPick,newMetrics) end,Toggle=function(_,target,newRows,onPick,newMetrics) if panel and anchor==target then hide() else show(target,newRows,onPick,newMetrics) end end,Hide=function() hide() end,Relayout=function() place() end,IsOpenFor=function(_,target) return panel~=nil and anchor==target end,Destroy=function() hide() end}
end

-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
return M

-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")

local M={}
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local theme=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Theme")

local function number(name,fallback)
	local child=theme:FindFirstChild(name)
	if child and child:IsA("NumberValue") then return tonumber(child.Value) or fallback end
	local value=theme:GetAttribute(name)
	return typeof(value)=="number" and value or fallback
end

function M.IsMobile()
	return UserInputService.TouchEnabled
end

function M.CornerScale()
	return M.IsMobile() and number("CornerScaleMobile",.5) or number("CornerScaleDesktop",.7)
end

function M.CornerRadius(baseRadius)
	return math.max(0,(tonumber(baseRadius) or 0)*M.CornerScale())
end

function M.SetCorner(corner,baseRadius)
	assert(corner and corner:IsA("UICorner"),"SetCorner requires a UICorner")
	corner:SetAttribute("NTRBaseCornerRadius",tonumber(baseRadius) or 0)
	corner.CornerRadius=UDim.new(0,M.CornerRadius(baseRadius))
	return corner
end

function M.Corner(parent,baseRadius)
	local corner=Instance.new("UICorner")
	M.SetCorner(corner,baseRadius)
	corner.Parent=parent
	return corner
end

function M.StrokeWidth(role)
	role=string.lower(tostring(role or "Structural"))
	if role=="glow" then
		return M.IsMobile() and number("GlowStrokeMobile",2) or number("GlowStrokeDesktop",3)
	elseif role=="emphasis" or role=="selected" then
		return M.IsMobile() and number("EmphasisStrokeMobile",1.25) or number("EmphasisStrokeDesktop",1.5)
	end
	return M.IsMobile() and number("StructuralStrokeMobile",1) or number("StructuralStrokeDesktop",1.2)
end

function M.StyleStroke(stroke,role)
	assert(stroke and stroke:IsA("UIStroke"),"StyleStroke requires a UIStroke")
	stroke.Thickness=M.StrokeWidth(role)
	stroke:SetAttribute("NTRStrokeRole",tostring(role or "Structural"))
	return stroke
end

function M.ApplyBevel(parent,options)
	assert(parent and parent:IsA("GuiObject"),"ApplyBevel requires a GuiObject")
	options=options or {}
	local overlay=parent:FindFirstChild("GradientOverlay")
	if overlay and not overlay:IsA("Frame") then overlay:Destroy(); overlay=nil end
	if not overlay then
		overlay=Instance.new("Frame")
		overlay.Name="GradientOverlay"
		overlay.Parent=parent
	end
	overlay.Active=false
	overlay.BackgroundColor3=Color3.new(1,1,1)
	local strength=math.clamp(tonumber(options.Strength) or number("BevelStrength",.1),0,.35)
	overlay.BackgroundTransparency=1-strength
	overlay.BorderSizePixel=0
	overlay.Position=UDim2.fromScale(0,0)
	overlay.Size=UDim2.fromScale(1,1)
	overlay.ZIndex=options.ZIndex or parent.ZIndex
	local corner=overlay:FindFirstChildOfClass("UICorner")
	if corner then M.SetCorner(corner,options.Radius or 6) else M.Corner(overlay,options.Radius or 6) end
	local gradient=overlay:FindFirstChild("NeutralOverlay")
	if gradient and not gradient:IsA("UIGradient") then gradient:Destroy(); gradient=nil end
	if not gradient then
		gradient=Instance.new("UIGradient")
		gradient.Name="NeutralOverlay"
		gradient.Parent=overlay
	end
	gradient.Rotation=tonumber(options.Rotation) or number("BevelRotation",90)
	gradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(95,95,95))
	gradient.Transparency=NumberSequence.new({
		NumberSequenceKeypoint.new(0,.2),
		NumberSequenceKeypoint.new(.52,.7),
		NumberSequenceKeypoint.new(1,.28),
	})
	return overlay
end

function M.FormatNumber(value)
	local numeric=tonumber(value) or 0
	local negative=numeric<0
	local digits=tostring(math.floor(math.abs(numeric)+.5))
	local reversed=string.gsub(string.reverse(digits),"(%d%d%d)","%1,")
	local grouped=string.gsub(string.reverse(reversed),"^,","")
	return (negative and "-" or "")..grouped
end

function M.FormatCompactMoney(value)
	local amount=math.max(0,math.floor(tonumber(value) or 0))
	if amount<1000000 then return "$"..M.FormatNumber(amount) end
	local tenths=math.floor(amount/100000)
	return "$"..string.format("%.1f",tenths/10).."M"
end

-- NTR_FREEROAM_CASH_PRESENTER_V1
-- Presentation state only. Authoritative Cash remains leaderstats.Cash and is
-- never inferred from, delayed by, or written through this presenter.
local function cashPresentationFlag(name,fallback)
	local child=theme:FindFirstChild(name)
	if child and child:IsA("BoolValue") then return child.Value end
	local value=theme:GetAttribute(name)
	return typeof(value)=="boolean" and value or fallback
end

function M.FormatFullMoney(value)
	return "$"..M.FormatNumber(math.max(0,math.floor(tonumber(value) or 0)))
end

function M.FormatFreeRoamMoney(value)
	if cashPresentationFlag("FreeRoamCashUseFullFormatting",true) then
		return M.FormatFullMoney(value)
	end
	return M.FormatCompactMoney(value)
end

function M.CreateCashDisplayPresenter(render,options)
	assert(type(render)=="function","Cash presenter requires a render callback")
	options=type(options)=="table" and options or {}
	local displayed=nil
	local authoritative=nil
	local generation=0
	local destroyed=false

	local function publish(value)
		if destroyed then return end
		displayed=math.max(0,math.floor(tonumber(value) or 0))
		render(displayed,authoritative)
	end

	local presenter={}
	function presenter:SetTarget(value,forceSnap)
		if destroyed then return end
		local target=math.clamp(math.floor(tonumber(value) or 0),0,2000000000)
		authoritative=target
		generation+=1
		local token=generation
		local enabled=options.Enabled
		if enabled==nil then enabled=cashPresentationFlag("CashCountAnimationEnabled",true) end
		if forceSnap==true or displayed==nil or enabled~=true or target<=displayed then
			publish(target)
			return
		end

		local start=displayed
		local delta=target-start
		local duration=math.clamp(tonumber(options.DurationSeconds)
			or number("CashCountDurationSeconds",0.4),0.15,0.75)
		local everyDollarLimit=math.clamp(math.floor(tonumber(options.EveryDollarLimit)
			or number("CashCountEveryDollarLimit",12)),1,24)
		local maximumSteps=math.clamp(math.floor(tonumber(options.MaximumSteps)
			or number("CashCountLargeIncreaseMaximumSteps",20)),4,60)
		local steps=delta<=everyDollarLimit and delta or math.min(delta,maximumSteps)
		local stepDelay=duration/math.max(1,steps)

		task.spawn(function()
			for step=1,steps do
				task.wait(stepDelay)
				if destroyed or token~=generation then return end
				local nextValue
				if delta<=everyDollarLimit then
					nextValue=start+step
				else
					nextValue=start+math.floor(delta*step/steps)
				end
				publish(math.min(target,nextValue))
			end
			if not destroyed and token==generation and displayed~=target then publish(target) end
		end)
	end

	function presenter:Snap(value)
		self:SetTarget(value,true)
	end

	function presenter:GetDisplayed()
		return displayed
	end

	function presenter:GetAuthoritative()
		return authoritative
	end

	function presenter:Destroy()
		if destroyed then return end
		destroyed=true
		generation+=1
	end

	return presenter
end

function M.StyleMetric(label,kind)
	assert(label and (label:IsA("TextLabel") or label:IsA("TextButton")),"StyleMetric requires text UI")
	label:SetAttribute("NTRSharedMetric",true)
	label:SetAttribute("NTRMetricKind",tostring(kind or "Metric"))
	label.TextWrapped=false
	label.TextTruncate=Enum.TextTruncate.None
	pcall(function()
		label.FontFace=Font.new("rbxasset://fonts/families/Michroma.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
	end)
	return label
end

function M.ProjectEconomy(response,fallback)
	local result=type(fallback)=="table" and {
		Cash=tonumber(fallback.Cash),
		Used=tonumber(fallback.Used),
		Capacity=tonumber(fallback.Capacity),
	} or {}
	if type(response)~="table" then return result end
	local profile=type(response.Profile)=="table" and response.Profile or nil
	local management=type(response.ManagementState)=="table" and response.ManagementState
		or (response.InGarage~=nil and response.Properties and response or nil)
	if tonumber(response.Cash) then result.Cash=tonumber(response.Cash) end
	if profile then
		result.Cash=tonumber(profile.Cash) or result.Cash
		local garage=type(profile.Garage)=="table" and profile.Garage or {}
		result.Used=tonumber(garage.OwnedVehicleCount) or result.Used
		result.Capacity=tonumber(garage.Capacity) or tonumber(profile.GarageCapacity) or result.Capacity
	end
	if management then
		result.Cash=tonumber(management.Cash) or result.Cash
		local currentId=tostring(management.CurrentPropertyId or "")
		for _,property in ipairs(management.Properties or {}) do
			if currentId=="" or tostring(property.PropertyId or "")==currentId then
				result.Used=tonumber(property.Filled) or result.Used
				result.Capacity=tonumber(property.Capacity) or result.Capacity
				if currentId~="" then break end
			end
		end
	end
	return result
end

function M.BindReplicatedCash(player,callback)
	player=player or Players.LocalPlayer
	assert(player and type(callback)=="function","BindReplicatedCash requires player and callback")
	local connections={}
	local valueConnection
	local stopped=false
	local function disconnectValue()
		if valueConnection then valueConnection:Disconnect(); valueConnection=nil end
	end
	local function bind()
		if stopped then return false end
		disconnectValue()
		local stats=player:FindFirstChild("leaderstats")
		local cash=stats and stats:FindFirstChild("Cash")
		if not (cash and (cash:IsA("IntValue") or cash:IsA("NumberValue"))) then return false end
		local function publish() if not stopped then callback(tonumber(cash.Value) or 0,cash) end end
		publish()
		valueConnection=cash:GetPropertyChangedSignal("Value"):Connect(publish)
		return true
	end
	table.insert(connections,player.ChildAdded:Connect(function(child)
		if child.Name=="leaderstats" then
			table.insert(connections,child.ChildAdded:Connect(function(value) if value.Name=="Cash" then bind() end end))
			bind()
		end
	end))
	local stats=player:FindFirstChild("leaderstats")
	if stats then table.insert(connections,stats.ChildAdded:Connect(function(value) if value.Name=="Cash" then bind() end end)) end
	bind()
	return function()
		stopped=true
		disconnectValue()
		for _,connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
	end
end

local function rootLogicalSize(root)
	local absolute=root.AbsoluteSize
	local width=root.Size.X.Offset>0 and root.Size.X.Offset or absolute.X
	local height=root.Size.Y.Offset>0 and root.Size.Y.Offset or absolute.Y
	return Vector2.new(math.max(1,width),math.max(1,height)),Vector2.new(math.max(1,absolute.X),math.max(1,absolute.Y))
end

function M.Confirmation(root,options,components)
	options=options or {}
	assert(root and root:IsA("GuiObject"),"Confirmation requires a GuiObject root")
	assert(type(components)=="table","Confirmation requires shared UI components")
	local oldSelection=GuiService.SelectedObject
	local connections={}
	local closed=false
	local exitAction="NTRSharedConfirmationExit_"..tostring(os.clock())
	local shade=Instance.new("Frame")
	shade.Name="NTRSharedConfirmation"
	shade.Active=true
	shade.BackgroundColor3=Color3.new(0,0,0)
	shade.BackgroundTransparency=.22
	shade.BorderSizePixel=0
	shade.Size=UDim2.fromScale(1,1)
	shade.ZIndex=300
	shade.Parent=root
	local panel=components.Panel(shade,{Name="Panel",StrokeColor=components.Colour("ElectricBlue"),NoGlow=true})
	panel.AnchorPoint=Vector2.new(.5,.5)
	panel.ZIndex=301
	local title=components.Label(panel,{Text=options.Title or "CONFIRM",TextSize=22,Role="Heading",XAlignment=Enum.TextXAlignment.Center})
	title.ZIndex=302
	local body=components.Label(panel,{Text=options.Body or "Continue?",TextSize=14,XAlignment=Enum.TextXAlignment.Center,Wrapped=true})
	body.ZIndex=302
	local no=components.Button(panel,{Text=options.CancelText or "NO",Color=Color3.fromRGB(116,120,128),ZIndex=303})
	local yes=components.Button(panel,{Text=options.ConfirmText or "YES",Color=components.Colour("PanelBlue"),StrokeColor=components.Colour("ElectricBlue"),ZIndex=303})
	no.Selectable=true
	yes.Selectable=true
	no.NextSelectionRight=yes
	yes.NextSelectionLeft=no

	local function disconnect()
		ContextActionService:UnbindAction(exitAction)
		for _,connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
	end
	local function close(confirmed)
		if closed then return end
		closed=true
		disconnect()
		if GuiService.SelectedObject==no or GuiService.SelectedObject==yes then GuiService.SelectedObject=oldSelection end
		shade:Destroy()
		if confirmed then
			if options.OnConfirm then options.OnConfirm() end
		elseif options.OnCancel then options.OnCancel() end
	end
	local function relayout()
		if closed or not shade.Parent then return end
		local logical,absolute=rootLogicalSize(root)
		local topLeft,bottomRight=GuiService:GetGuiInset()
		local sx=logical.X/absolute.X
		local sy=logical.Y/absolute.Y
		local safeLeft=math.max(12,topLeft.X*sx+12)
		local safeRight=math.max(12,bottomRight.X*sx+12)
		local safeTop=math.max(12,topLeft.Y*sy+12)
		local safeBottom=math.max(12,bottomRight.Y*sy+12)
		local width=math.max(280,math.min(620,logical.X-safeLeft-safeRight))
		local height=math.max(230,math.min(320,logical.Y-safeTop-safeBottom))
		panel.Position=UDim2.fromOffset(safeLeft+(logical.X-safeLeft-safeRight)*.5,safeTop+(logical.Y-safeTop-safeBottom)*.5)
		panel.Size=UDim2.fromOffset(width,height)
		title.Position=UDim2.fromOffset(24,22)
		title.Size=UDim2.new(1,-48,0,42)
		body.Position=UDim2.fromOffset(32,72)
		body.Size=UDim2.new(1,-64,1,-150)
		local gap=math.max(12,math.min(24,width*.035))
		local buttonWidth=math.max(112,math.min(190,(width-64-gap)*.5))
		local buttonHeight=math.max(48,M.IsMobile() and 52 or 48)
		no.AnchorPoint=Vector2.new(1,1)
		no.Position=UDim2.new(.5,-gap*.5,1,-24)
		no.Size=UDim2.fromOffset(buttonWidth,buttonHeight)
		yes.AnchorPoint=Vector2.new(0,1)
		yes.Position=UDim2.new(.5,gap*.5,1,-24)
		yes.Size=UDim2.fromOffset(buttonWidth,buttonHeight)
	end
	no.Activated:Connect(function() close(false) end)
	yes.Activated:Connect(function() close(true) end)
	ContextActionService:BindActionAtPriority(exitAction,function(_,state)
		if state==Enum.UserInputState.Begin then close(false) end
		return Enum.ContextActionResult.Sink
	end,false,10000,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
	table.insert(connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout))
	local camera=Workspace.CurrentCamera
	if camera then table.insert(connections,camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)) end
	relayout()
	task.defer(function() if not closed and no.Parent then GuiService.SelectedObject=no end end)
	return {Root=shade,Cancel=function() close(false) end,Confirm=function() close(true) end,Relayout=relayout}
end

function M.CreateTopNotificationController(playerGui)
	assert(playerGui and playerGui:IsA("PlayerGui"),"Top notification controller requires PlayerGui")
	local old=playerGui:FindFirstChild("NTR_SharedTopNotification")
	if old then old:Destroy() end
	local gui=Instance.new("ScreenGui")
	gui.Name="NTR_SharedTopNotification"
	gui.ResetOnSpawn=false
	gui.IgnoreGuiInset=true
	gui.DisplayOrder=1100
	gui.Parent=playerGui
	local stack=Instance.new("Frame")
	stack.Name="Stack"
	stack.AnchorPoint=Vector2.new(.5,0)
	stack.BackgroundTransparency=1
	stack.BorderSizePixel=0
	stack.AutomaticSize=Enum.AutomaticSize.Y
	stack.Parent=gui
	local layout=Instance.new("UIListLayout")
	layout.Padding=UDim.new(0,6)
	layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
	layout.SortOrder=Enum.SortOrder.LayoutOrder
	layout.Parent=stack
	local cards={}
	local serial=0
	local maxCards=math.max(1,math.floor(number("TopNotificationMaxCards",3)))
	local function relayout()
		local camera=Workspace.CurrentCamera
		local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
		local topLeft=GuiService:GetGuiInset()
		local mobile=M.IsMobile()
		local side=mobile and 12 or 24
		local width=math.min(mobile and 540 or 620,math.max(260,viewport.X-side*2))
		local height=mobile and (viewport.X>viewport.Y and 44 or 52) or 48
		stack.Position=UDim2.fromOffset(viewport.X*.5,math.max(12,topLeft.Y+10))
		stack.Size=UDim2.fromOffset(width,0)
		for _,card in ipairs(cards) do if card.Parent then card.Size=UDim2.fromOffset(width,height) end end
	end
	local camera=Workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout) end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local current=Workspace.CurrentCamera
		if current then current:GetPropertyChangedSignal("ViewportSize"):Connect(relayout) end
		relayout()
	end)
	local function remove(card)
		local index=table.find(cards,card)
		if index then table.remove(cards,index) end
		if card.Parent then card:Destroy() end
	end
	local function show(message,duration)
		local text=string.upper(tostring(message or ""))
		if text=="" then return end
		serial+=1
		while #cards>=maxCards do remove(cards[1]) end
		local card=Instance.new("TextLabel")
		card.Name="Message"..serial
		card.LayoutOrder=serial
		card.BackgroundColor3=Color3.fromRGB(72,76,84)
		card.BackgroundTransparency=.04
		card.BorderSizePixel=0
		card.Text=text
		card.TextColor3=Color3.new(1,1,1)
		card.TextSize=M.IsMobile() and 12 or 14
		card.TextWrapped=true
		card.ZIndex=2
		pcall(function() card.FontFace=Font.new("rbxasset://fonts/families/Michroma.json",Enum.FontWeight.Bold) end)
		card.Parent=stack
		M.Corner(card,6)
		local gradient=Instance.new("UIGradient")
		gradient.Name="GreyGradient"
		gradient.Color=ColorSequence.new(Color3.fromRGB(105,109,117),Color3.fromRGB(48,52,60))
		gradient.Rotation=90
		gradient.Parent=card
		table.insert(cards,card)
		relayout()
		task.delay(math.clamp(tonumber(duration) or 2.5,.5,10),function() remove(card) end)
	end
	relayout()
	return {Gui=gui,Show=show,Relayout=relayout,Count=function() return #cards end}
end

return M

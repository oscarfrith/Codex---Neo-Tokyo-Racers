-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1
-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V2_HARDENED
-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V3_ASYNC_OPEN
local Controller={}; local started=false; local closeCurrent=function() end; local isOpenCurrent=function() return false end
function Controller.Close(reason) closeCurrent(reason) end
function Controller.IsOpen() return isOpenCurrent() end
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local ProximityPromptService=game:GetService("ProximityPromptService"); local ReplicatedStorage=game:GetService("ReplicatedStorage"); local UserInputService=game:GetService("UserInputService"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local Mobile=require(kit.Shared.Modules.UI:WaitForChild("RacingMobileScaledDesktopLayout")); local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local openEvent=script.Parent:WaitForChild("OpenOwnedGarageBrowser")
	local loadingInvoke=script.Parent:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_BROWSER_V1
	local C=function(name) return UI.Colour(name) end; local L=function(name,fallback) return UI.Layout(name,fallback) end; local T=function(name,fallback) return UI.Type(name,fallback) end; local state; local selected; local busy=false; local cards={}; local generation=0; local physicalLoadingGeneration
	local gui=Instance.new("ScreenGui"); gui.Name="NTR_OwnedGarageBrowser"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.DisplayOrder=171; gui.Parent=playerGui
	local overlay=Instance.new("Frame"); overlay.Name="Overlay"; overlay.BackgroundColor3=Color3.new(0,0,0); overlay.BackgroundTransparency=.38; overlay.BorderSizePixel=0; overlay.Size=UDim2.fromScale(1,1); overlay.Visible=false; overlay.Parent=gui
	local shell=UI.Panel(overlay,{Name="OwnedGarageShell",Color=C("PanelDeep"),Transparency=L("PanelTransparency",.08),StrokeColor=C("Outline"),StrokeWidth=L("ShellStrokeWidth",2),StrokeTransparency=.02,Clips=true}); shell.AnchorPoint=Vector2.new(.5,.5); shell.Position=UDim2.fromScale(.5,.5)
	local layoutScale; if Mobile.IsEnabled(UserInputService.TouchEnabled) then layoutScale=Mobile.Attach(shell) else shell.Size=UDim2.fromOffset(1200,720); layoutScale=UI.AttachResponsiveScale(shell) end
	local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
	local function hardenTouch() if not UserInputService.TouchEnabled then return end; local scale=math.max(layoutScale and layoutScale.Scale or 1,.01); local minimum=math.ceil(math.max(32,tonumber(settings:GetAttribute("MinimumTouchTargetPixels")) or 44)/scale); for _,object in ipairs(overlay:GetDescendants()) do if object:IsA("GuiButton") then local original=object:GetAttribute("NTR_OwnedGarageOriginalSize"); if typeof(original)~="UDim2" then original=object.Size; object:SetAttribute("NTR_OwnedGarageOriginalSize",original) end; if original.Y.Scale==0 then object.Size=UDim2.new(original.X.Scale,original.X.Offset,0,math.max(original.Y.Offset,minimum)) end end end end
	if layoutScale then layoutScale:GetPropertyChangedSignal("Scale"):Connect(function() if overlay.Visible then task.defer(hardenTouch) end end) end
	UI.Label(shell,{Name="Title",Text="MY GARAGES",Position=UDim2.fromOffset(24,0),Size=UDim2.new(.55,0,0,64),TextSize=T("Heading",22),Role="Heading"}); local divider=Instance.new("Frame"); divider.BorderSizePixel=0; divider.BackgroundColor3=C("Outline"); divider.BackgroundTransparency=.5; divider.Position=UDim2.fromOffset(0,64); divider.Size=UDim2.new(1,0,0,1); divider.Parent=shell
	local content=Instance.new("Frame"); content.BackgroundTransparency=1; content.Position=UDim2.fromOffset(24,88); content.Size=UDim2.new(1,-48,1,-176); content.Parent=shell
	local listScroller=Instance.new("ScrollingFrame"); listScroller.Name="GarageList"; listScroller.BackgroundTransparency=1; listScroller.BorderSizePixel=0; listScroller.Size=UDim2.new(.38,-8,1,0); listScroller.AutomaticCanvasSize=Enum.AutomaticSize.Y; listScroller.CanvasSize=UDim2.fromOffset(0,0); listScroller.ScrollBarThickness=6; listScroller.ScrollBarImageColor3=C("Outline"); listScroller.Parent=content
	local list=Instance.new("Frame"); list.BackgroundTransparency=1; list.Size=UDim2.new(1,-14,0,0); list.AutomaticSize=Enum.AutomaticSize.Y; list.Parent=listScroller; local listLayout=Instance.new("UIListLayout"); listLayout.Padding=UDim.new(0,12); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=list
	local detail=Instance.new("Frame"); detail.BackgroundTransparency=1; detail.Position=UDim2.new(.38,8,0,0); detail.Size=UDim2.new(.62,-8,1,0); detail.Parent=content
	local hero=Shared.Panel(detail,"GarageImage",{NoGlow=true}); hero.Size=UDim2.new(1,0,0,290); local heroImage=Instance.new("ImageLabel"); heroImage.Name="Image"; heroImage.BackgroundTransparency=1; heroImage.Position=UDim2.fromOffset(5,5); heroImage.Size=UDim2.new(1,-10,1,-10); heroImage.ScaleType=Enum.ScaleType.Crop; heroImage.Parent=hero; UI.Corner(heroImage,5)
	local placeholder=UI.Label(hero,{Name="Placeholder",Text="GARAGE IMAGE",Size=UDim2.fromScale(1,1),TextSize=T("Heading",20),Color=C("Muted"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}); placeholder.TextTransparency=.25
	local detailTitle=UI.Label(detail,{Name="GarageTitle",Text="",Position=UDim2.fromOffset(0,308),Size=UDim2.new(1,0,0,38),TextSize=T("Heading",26),Role="Heading"}); local district=UI.Label(detail,{Name="District",Text="",Position=UDim2.fromOffset(0,347),Size=UDim2.new(1,0,0,25),TextSize=T("Caption",13),Color=C("Telemetry"),Role="Heading"}); local description=UI.Label(detail,{Name="Description",Text="",Position=UDim2.fromOffset(0,382),Size=UDim2.new(1,0,0,72),TextSize=T("Body",15),Color=C("Text")}); description.TextWrapped=true; description.TextYAlignment=Enum.TextYAlignment.Top
	local capacity=Shared.MetricCard(detail,"Capacity"); capacity.Position=UDim2.fromOffset(0,466); capacity.Size=UDim2.new(1,0,0,54); local capacityText=UI.Label(capacity,{Text="",Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-28,1,0),TextSize=T("Metric",16),Role="Metric",XAlignment=Enum.TextXAlignment.Center})
	local status=UI.Label(shell,{Name="Status",Text="",Position=UDim2.new(0,24,1,-82),Size=UDim2.new(1,-48,0,20),TextSize=T("Caption",11),Color=C("Danger"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}); status.Visible=false
	local exit=Shared.ActionButton(shell,{Name="Exit",Text="EXIT",IconText="×",Size=UDim2.fromOffset(220,48),Color=C("PanelSoft"),StrokeColor=C("Outline")}); exit.AnchorPoint=Vector2.new(0,1); exit.Position=UDim2.new(0,24,1,-16)
	local enter=Shared.ActionButton(shell,{Name="Enter",Text="ENTER GARAGE",IconText="E",Size=UDim2.fromOffset(300,48),Color=C("PanelBlue"),StrokeColor=C("Telemetry")}); enter.AnchorPoint=Vector2.new(1,1); enter.Position=UDim2.new(1,-24,1,-16); if UserInputService.TouchEnabled then status.Position=UDim2.new(0,24,1,-150) end
	local function presentation(active) local event=script.Parent:FindFirstChild("FreeRoamHudPresentationMode"); if event and event:IsA("BindableEvent") then event:Fire({Owner="OwnedGarageBrowser",Active=active==true,KeepTelemetry=false}) end end
	local function request(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage service unavailable."} end
	local function loadingAction(action,payload) local ok,result=pcall(function() return loadingInvoke:Invoke(action,payload or {}) end); if ok then return result end; warn("[NTR Owned Garage] Loading transition "..tostring(action).." failed: "..tostring(result)); return nil end
	local function beginPhysicalLoading(destination,status) if physicalLoadingGeneration then return end; physicalLoadingGeneration=loadingAction("Begin",{Destination=destination,Status=status}) end
	local function finishPhysicalLoading(success,message) local current=physicalLoadingGeneration; if not current then return end; physicalLoadingGeneration=nil; loadingAction(success and "Complete" or "Fail",{Generation=current,Status=success and "READY" or "RETURNING",Reason=message}) end
	local function setStatus(text,good) status.Text=tostring(text or ""); status.TextColor3=good and C("Telemetry") or C("Danger"); status.Visible=status.Text~="" end
	local function clearList() for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end; table.clear(cards) end
	local render
	local function selectProperty(property) selected=property; render() end
	local function renderDetail()
		if not selected then detailTitle.Text="NO GARAGES"; district.Text=""; description.Text="No owned garage properties are available."; capacityText.Text=""; heroImage.Visible=false; placeholder.Visible=true; enter.Visible=false; return end
		detailTitle.Text=string.upper(selected.DisplayName or selected.PropertyId); district.Text=string.upper(selected.District or ""); description.Text=tostring(selected.Description or ""); heroImage.Image=UI.Asset(selected.Image or ""); heroImage.Visible=heroImage.Image~=""; placeholder.Visible=not heroImage.Visible; capacityText.Text=tostring(selected.Filled or 0).." / "..tostring(selected.Capacity or 0).." DISPLAY SPACES"; enter.Visible=true; Shared.SetActionButton(enter,state and state.InGarage and "RETURN TO CITY" or "ENTER GARAGE",nil,state and state.InGarage and "↩" or "E")
	end
	render=function()
		clearList(); for index,property in ipairs(state and state.Properties or {}) do local card=Shared.Card(list,{Name="Garage_"..property.PropertyId,DisplayName=property.DisplayName,Image=UI.Asset(property.Image or ""),Rating=tostring(property.Capacity or 0).." BAYS",Selected=selected and selected.PropertyId==property.PropertyId,Size=UDim2.new(1,0,0,158),ImageHeight=148}); card.LayoutOrder=index; card.Activated:Connect(function() selectProperty(property) end); cards[property.PropertyId]=card end; renderDetail()
	end
	local function close() generation+=1; for _,child in ipairs(shell:GetChildren()) do if child.Name=="ReplacementPrompt" then child:Destroy() end end; overlay.Visible=false; presentation(false); setStatus("") end; closeCurrent=close; isOpenCurrent=function() return overlay.Visible end
	local function replacementPrompt(result)
		local shade=Instance.new("Frame"); shade.Name="ReplacementPrompt"; shade.BackgroundColor3=Color3.new(0,0,0); shade.BackgroundTransparency=.18; shade.Size=UDim2.fromScale(1,1); shade.ZIndex=200; shade.Parent=shell; local panel=Shared.Panel(shade,"Panel",{}); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); local touchPrompt=UserInputService.TouchEnabled; panel.Size=UDim2.fromOffset(touchPrompt and 720 or 560,touchPrompt and 600 or 330); panel.ZIndex=201; UI.Label(panel,{Text="GARAGE FULL",Position=UDim2.fromOffset(20,14),Size=UDim2.new(1,-40,0,38),TextSize=T("Heading",24),Role="Heading",XAlignment=Enum.TextXAlignment.Center}).ZIndex=202; UI.Label(panel,{Text="Choose the display vehicle to replace. The replaced vehicle stays owned.",Position=UDim2.fromOffset(24,60),Size=UDim2.new(1,-48,0,48),TextSize=T("Body",14),XAlignment=Enum.TextXAlignment.Center}).ZIndex=202
		for index,slot in ipairs(result.Slots or {}) do
			local button=Shared.ActionButton(panel,{Name=slot.SlotId,Text=tostring(slot.DisplayName or slot.VehicleId),IconText=tostring(index),Size=UDim2.new(1,-48,0,touchPrompt and 112 or 58),Color=C("PanelSoft"),StrokeColor=C("Outline")}); button.Position=UDim2.fromOffset(24,112+(index-1)*(touchPrompt and 124 or 68)); button.ZIndex=203
			button.Activated:Connect(function()
				if busy then return end; busy=true
				local loadingGeneration=loadingAction("Begin",{Destination="OwnedGarageInterior",Status="ENTERING OWNED GARAGE"})
				local replaced=request("EnterSelectedGarage",{PropertyId=selected.PropertyId,ReplacementSlotId=slot.SlotId}); busy=false
				if replaced.Success then shade:Destroy(); close(); loadingAction("Complete",{Generation=loadingGeneration,Status="READY"}) else loadingAction("Fail",{Generation=loadingGeneration,Status="RETURNING",Reason=replaced.Message}); setStatus(replaced.Message,false) end
			end)
		end
		local cancel=Shared.ActionButton(panel,{Name="Cancel",Text="CANCEL",IconText="×",Size=UDim2.fromOffset(180,touchPrompt and 112 or 42),Color=C("PanelSoft"),StrokeColor=C("Outline")}); cancel.AnchorPoint=Vector2.new(.5,1); cancel.Position=UDim2.new(.5,0,1,-14); cancel.ZIndex=203; cancel.Activated:Connect(function() shade:Destroy() end); task.defer(hardenTouch)
	end
	local function open()
		generation+=1; local token=generation; overlay.Visible=true; presentation(true); if state then render() end; setStatus(state and "" or "LOADING GARAGES...",true); task.spawn(function() local result=request("GetState",{}); if token~=generation then return end; if not result.Success then setStatus(result.Message,false); return end; state=result; selected=nil; for _,property in ipairs(state.Properties or {}) do if property.PropertyId==state.ActiveGarageId then selected=property; break end end; selected=selected or (state.Properties and state.Properties[1]); render(); setStatus(""); task.defer(hardenTouch) end)
	end
	exit.Activated:Connect(close)
	enter.Activated:Connect(function()
		if busy or not selected then return end; busy=true
		local returning=state and state.InGarage==true
		local loadingGeneration=loadingAction("Begin",{Destination=returning and "OwnedGarageExterior" or "OwnedGarageInterior",Status=returning and "RETURNING TO CITY" or "ENTERING OWNED GARAGE"})
		local result;if returning then result=request("ExitOnFoot",{}) else result=request("EnterSelectedGarage",{PropertyId=selected.PropertyId}) end; busy=false
		if result.Success then close(); loadingAction("Complete",{Generation=loadingGeneration,Status="READY"}) elseif result.NeedsReplacement then loadingAction("Fail",{Generation=loadingGeneration,Status="SELECT A DISPLAY SPACE",Reason=result.Message}); replacementPrompt(result) else loadingAction("Fail",{Generation=loadingGeneration,Status="RETURNING",Reason=result.Message}); setStatus(result.Message,false) end
	end)
	openEvent.Event:Connect(function() if overlay.Visible then close() else open() end end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt,triggeringPlayer)
		if triggeringPlayer and triggeringPlayer~=player then return end
		if player:GetAttribute("NTR_OwnedGarageInside")~=true or not prompt then return end
		if prompt.Name=="FootExitPrompt" then beginPhysicalLoading("OwnedGarageExterior","RETURNING TO CITY") elseif prompt.Name=="DriveOutPrompt" then beginPhysicalLoading("OwnedGarageDriveOut","PREPARING VEHICLE") end
	end)
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(function() if player:GetAttribute("NTR_OwnedGarageInside")~=true then finishPhysicalLoading(true,"Ready") end end)
	push.OnClientEvent:Connect(function(message)
		if type(message)~="table" then return end
		if message.Type=="DriveOut" then close()
		elseif message.Type=="DriveOutResult" then finishPhysicalLoading(message.Success==true,message.Message)
		elseif message.Type=="FootExitResult" then finishPhysicalLoading(message.Success==true,message.Message) end
	end)
	started=true; print("[NTR Owned Garage] Browser controller active."); return true,"Started"
end
return Controller

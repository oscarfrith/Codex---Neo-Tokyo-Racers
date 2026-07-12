-- Neo Tokyo Racers - Racing UI Phase 13 Results Visual Hierarchy
-- Paste into Roblox Studio Command Bar in Edit mode.
-- Client presentation only: larger lap rows, podium medals, and cached headshots.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 13"
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end
local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end
local function controller()
	local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local ntr = scripts and scripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = ntr and ntr:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	local item = racing and racing:FindFirstChild("RaceTimeTrialResultCoachClient_Active")
	if not (item and item:IsA("LuaSourceContainer")) then fail("Missing unified result controller") end
	return item
end
local function replaceOnce(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then fail("Could not find " .. label .. " anchor. Refresh the mirror before another repair.") end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end
local function replaceFunction(source, name, nextName, replacement)
	local first = string.find(source, "local function " .. name, 1, true)
	local nextAt = first and string.find(source, "local function " .. nextName, first + 1, true)
	if not (first and nextAt) then fail("Could not find " .. name .. " function boundaries") end
	return string.sub(source, 1, first - 1) .. replacement .. "\n\n" .. string.sub(source, nextAt)
end

local AVATAR_HELPER = [==[local avatarCache = {}
local function avatar(parent, userId, position, size)
	local image = Instance.new("ImageLabel")
	image.Name = "PlayerHeadshot"
	image.BackgroundColor3 = C("PanelSoft")
	image.BackgroundTransparency = 0.15
	image.BorderSizePixel = 0
	image.Position = position
	image.Size = size
	image.ScaleType = Enum.ScaleType.Crop
	image.Parent = parent
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, touch and 4 or 6) corner.Parent = image
	userId = tonumber(userId)
	if not userId or userId <= 0 then return image end
	if avatarCache[userId] then image.Image = avatarCache[userId] return image end
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and type(content) == "string" then
			avatarCache[userId] = content
			if image.Parent then image.Image = content end
		end
	end)
	return image
end
]==]

local RENDER_RACE = [==[local function renderRace(payload)
	clear(body) title.Text=string.upper(tostring(payload.DisplayName or "RACE")) complete.Text="RACE COMPLETE"
	local gap=touch and 10 or L("Gap",16) local leftW=.5
	local left=Instance.new("Frame") left.BackgroundTransparency=1 left.Size=UDim2.new(leftW,-gap/2,1,0) left.Parent=body
	local right=panel(body,"RaceResults",UDim2.new(leftW,gap/2,0,0),UDim2.new(1-leftW,-gap/2,1,0))
	local resultH=touch and 190 or 252
	local result=panel(left,"YourResult",UDim2.fromOffset(0,0),UDim2.new(1,0,0,resultH))
	heading(result,"YOUR RESULT",UDim2.fromOffset(18,8),UDim2.new(1,-36,0,26))
	local place=tonumber(payload.Place) local suffix=place==1 and "ST" or place==2 and "ND" or place==3 and "RD" or "TH"
	UI.Label(result,{Text=(place and tostring(place)..suffix or "--").." PLACE",Position=UDim2.fromOffset(20,touch and 40 or 48),Size=UDim2.new(1,touch and -124 or -164,0,touch and 52 or 72),TextSize=touch and 34 or 52,Color=place==1 and C("Telemetry") or C("Text"),Role="Metric"})
	local podiumMedal=place==1 and "Gold" or place==2 and "Silver" or place==3 and "Bronze" or nil
	if podiumMedal then medalIcon(result,podiumMedal,UDim2.new(1,touch and -104 or -138,0,touch and 38 or 42),UDim2.fromOffset(touch and 82 or 112,touch and 82 or 112)) end
	UI.Label(result,{Text="PRIZE",Position=UDim2.fromOffset(22,touch and 100 or 126),Size=UDim2.fromOffset(140,20),TextSize=touch and 9 or 11,Color=C("Muted"),Role="Heading"})
	UI.Label(result,{Text=money(payload.RewardAmount),Position=UDim2.fromOffset(22,touch and 118 or 146),Size=UDim2.new(.46,-22,0,touch and 30 or 38),TextSize=touch and 19 or 28,Color=C("Telemetry"),Role="Metric"})
	UI.Label(result,{Text="FINISH TIME",Position=UDim2.new(.49,0,0,touch and 100 or 126),Size=UDim2.new(.46,-22,0,20),TextSize=touch and 9 or 11,Color=C("Muted"),Role="Heading"})
	UI.Label(result,{Text=timeText(payload.Elapsed),Position=UDim2.new(.49,0,0,touch and 118 or 146),Size=UDim2.new(.48,-22,0,touch and 30 or 38),TextSize=touch and 19 or 28,Color=C("Telemetry"),Role="Metric"})
	local highlights=panel(left,"RaceHighlights",UDim2.fromOffset(0,resultH+gap),UDim2.new(1,0,1,-(resultH+gap)))
	heading(highlights,"RACE HIGHLIGHTS",UDim2.fromOffset(18,8),UDim2.new(1,-36,0,26))
	local highlightText=UI.Label(highlights,{Text="FASTEST LAP",Position=UDim2.fromOffset(touch and 58 or 72,touch and 38 or 48),Size=UDim2.new(.52,-72,0,touch and 30 or 38),TextSize=touch and 12 or 16,Color=C("Text"),Role="Heading"})
	UI.Label(highlights,{Text="--",Position=UDim2.new(.65,0,0,touch and 38 or 48),Size=UDim2.new(.31,-18,0,touch and 30 or 38),TextSize=touch and 14 or 20,Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	local divider=Instance.new("Frame") divider.BorderSizePixel=0 divider.BackgroundColor3=C("Outline") divider.BackgroundTransparency=.65 divider.Position=UDim2.new(0,18,.5,0) divider.Size=UDim2.new(1,-36,0,1) divider.Parent=highlights
	UI.Label(highlights,{Text="HIGHEST SPEED",Position=UDim2.fromOffset(touch and 58 or 72,touch and 94 or 112),Size=UDim2.new(.52,-72,0,touch and 30 or 38),TextSize=touch and 12 or 16,Color=C("Text"),Role="Heading"})
	UI.Label(highlights,{Text="--",Position=UDim2.new(.65,0,0,touch and 94 or 112),Size=UDim2.new(.31,-18,0,touch and 30 or 38),TextSize=touch and 14 or 20,Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	local silhouetteSize=touch and 32 or 40
	local function silhouette(y) local f=Instance.new("Frame") f.BackgroundColor3=C("PanelSoft") f.BackgroundTransparency=.15 f.BorderSizePixel=0 f.Position=UDim2.fromOffset(18,y) f.Size=UDim2.fromOffset(silhouetteSize,silhouetteSize) f.Parent=highlights local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=f end
	silhouette(touch and 34 or 42) silhouette(touch and 90 or 106)
	heading(right,"RACE RESULTS",UDim2.fromOffset(14,6),UDim2.new(1,-28,0,26))
	local y=tableHeader(right,{{"POS",0,.11},{"PLAYER",.11,.44},{"FINISH TIME",.55,.25},{"VEHICLE",.80,.20}}) local list=scrolling(right,y)
	local positions=lastPositions or payload.Positions or {} local rowH=touch and 38 or 46
	for index,entry in ipairs(positions) do
		local row=Instance.new("Frame") local you=tonumber(entry.UserId)==player.UserId
		row.BackgroundColor3=you and C("PanelBlue") or C("PanelSoft") row.BackgroundTransparency=you and .30 or (index%2==0 and .58 or .82) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,(index-1)*rowH) row.Size=UDim2.new(1,-6,0,rowH-2) row.Parent=list
		local elapsed=tonumber(entry.FinishElapsed) or (you and tonumber(payload.Elapsed)) local finish=elapsed and timeText(elapsed) or (entry.Finished and "FINISHED" or "RACING") local vehicle=string.upper(tostring(entry.VehicleName or entry.VehicleId or "--"))
		UI.Label(row,{Text=tostring(entry.Place or index),Position=UDim2.fromOffset(6,0),Size=UDim2.new(.10,-6,1,0),TextSize=touch and 10 or 13,Color=index<=3 and C("Telemetry") or C("Text"),Role="Heading"})
		local avatarSize=touch and 28 or 34 avatar(row,entry.UserId,UDim2.new(.11,5,.5,-avatarSize/2),UDim2.fromOffset(avatarSize,avatarSize))
		UI.Label(row,{Text=string.upper(tostring(entry.Name or "PLAYER")),Position=UDim2.new(.11,avatarSize+12,0,0),Size=UDim2.new(.44,-(avatarSize+16),1,0),TextSize=touch and 9 or 12,Color=you and C("Telemetry") or C("Text"),Role="Heading"})
		UI.Label(row,{Text=finish,Position=UDim2.new(.55,6,0,0),Size=UDim2.new(.25,-12,1,0),TextSize=touch and 9 or 12,Color=you and C("Telemetry") or C("Text"),Role="Heading"})
		UI.Label(row,{Text=vehicle,Position=UDim2.new(.80,6,0,0),Size=UDim2.new(.20,-12,1,0),TextSize=touch and 8 or 10,Color=you and C("Telemetry") or C("Text"),Role="Heading"})
	end
	footerButtons("EXIT TO START","RACE AGAIN",function() hide() invoke(queueRequest,"ExitRaceToStart",{}) end,function() local eventId=tostring(player:GetAttribute("NTR_LastRacingEventId") or payload.EventId or "") local vehicleId=tostring(player:GetAttribute("NTR_LastRacingVehicleId") or "") local root=script.Parent local start=root:FindFirstChild("StartRaceQueueRequest") if start and start:IsA("BindableEvent") and eventId~="" and vehicleId~="" then hide() start:Fire({EventId=eventId,VehicleId=vehicleId,DisplayName=payload.DisplayName}) end end)
end]==]

local function install()
	local item=controller() local source=item.Source
	if not string.find(source,"NTR_RACING_UI_PHASE13_RESULTS_VISUAL_HIERARCHY",1,true) then
		source=replaceOnce(source,"local function setSuppressed(open)","-- NTR_RACING_UI_PHASE13_RESULTS_VISUAL_HIERARCHY\n"..AVATAR_HELPER.."\nlocal function setSuppressed(open)","avatar helper")
		source=replaceOnce(source,"local list = scrolling(laps,touch and 34 or 40) local rowH=touch and 25 or 30","local list = scrolling(laps,touch and 38 or 46) local rowH=touch and 38 or 44","Time Trial row geometry")
		source=replaceOnce(source,"TextSize=touch and 8 or 10,Color=C(\"Text\"),Role=\"Heading\"}) UI.Label(row,{Text=timeText(lap.Elapsed)","TextSize=touch and 11 or 14,Color=C(\"Text\"),Role=\"Heading\"}) UI.Label(row,{Text=timeText(lap.Elapsed)","Time Trial lap number size")
		source=replaceOnce(source,"TextSize=touch and 9 or 11,Color=C(\"Text\"),Role=\"Metric\"}) if tonumber(lap.Lap)","TextSize=touch and 13 or 17,Color=C(\"Text\"),Role=\"Metric\"}) if tonumber(lap.Lap)","Time Trial lap time size")
		source=replaceOnce(source,"TextSize=touch and 8 or 10,Color=C(\"Telemetry\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Right}) end end","TextSize=touch and 10 or 13,Color=C(\"Telemetry\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Right}) end end","Time Trial best size")
		source=replaceFunction(source,"renderRace(payload)","show(mode,payload)",RENDER_RACE)
		item.Source=source log("Installed Results visual hierarchy and cached player headshots.")
	else log("Results visual hierarchy already installed.") end
end
local function smoke()
	local source=controller().Source
	assert(string.find(source,"NTR_RACING_UI_PHASE13_RESULTS_VISUAL_HIERARCHY",1,true),"Phase 13 marker missing")
	assert(string.find(source,"GetUserThumbnailAsync",1,true),"Headshot cache missing")
	assert(string.find(source,"local rowH=touch and 38 or 44",1,true),"Larger Time Trial rows missing")
	assert(string.find(source,"podiumMedal",1,true),"Podium medal presentation missing")
	log("SMOKE PASS")
end
if MODE=="INSTALL" then install() smoke() log("Install complete. Restart Play and verify both result modes.") elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE: "..tostring(MODE)) end

-- Owns preview input subscriptions only; host owns preview state and camera rendering.
local Scope=require(game:GetService("ReplicatedStorage").Modules.Core.ConnectionScope)
local Client={}
local active
function Client.destroy()
	if active then active:destroy(); active=nil end
end
function Client.bind(state,is_driving,update_camera,owner)
	Client.destroy()
	local scope=Scope.new(); active=scope
	local inputService=game:GetService("UserInputService")
	scope:connect(inputService.InputBegan,function(input,processed)
		if processed or is_driving() then return end
		if input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.Touch then
			state.Dragging=true; state.LastPointer=input.Position
		end
	end)
	scope:connect(inputService.InputEnded,function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.Touch then
			state.Dragging=false; state.LastPointer=nil
		end
	end)
	scope:connect(inputService.InputChanged,function(input)
		if is_driving() then return end
		if input.UserInputType==Enum.UserInputType.MouseWheel then return
		elseif state.Dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
			if state.LastPointer then
				local delta=input.Position-state.LastPointer
				state.TargetYaw-=delta.X*0.006
				state.TargetPitch=math.clamp(state.TargetPitch-delta.Y*0.004,math.rad(-45),math.rad(10))
			end
			state.LastPointer=input.Position
		end
	end)
	scope:connect(game:GetService("RunService").RenderStepped,update_camera)
	if owner then scope:connect(owner.Destroying,function() Client.destroy() end) end
	return scope
end
return Client

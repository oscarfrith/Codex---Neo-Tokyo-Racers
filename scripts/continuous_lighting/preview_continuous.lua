local renderer=require(ReplicatedStorage.Modules.Game.World.LightingClient)
if renderer.isContinuous() then
    local runtime=game.Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("World")
    local Cycle=require(ReplicatedStorage.Modules.Game.World.LightingCycle)
    local keys={[Enum.KeyCode.One]="SevenAM",[Enum.KeyCode.Two]="Day",[Enum.KeyCode.Three]="Day",[Enum.KeyCode.Four]="Day",[Enum.KeyCode.Five]="FivePM",[Enum.KeyCode.Six]="EightPM",[Enum.KeyCode.Seven]="ClearNight",[Enum.KeyCode.Eight]="FourAM",[Enum.KeyCode.N]="ClearNight",[Enum.KeyCode.M]="Day"}
    local connection=UserInputService.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.KeyCode==Enum.KeyCode.R then runtime:SetAttribute("LightingPreviewClockTime",nil); return end
        if input.KeyCode==Enum.KeyCode.LeftBracket or input.KeyCode==Enum.KeyCode.RightBracket then
            local current=runtime:GetAttribute("LightingPreviewClockTime") or Lighting.ClockTime
            runtime:SetAttribute("LightingPreviewClockTime",(current+(input.KeyCode==Enum.KeyCode.RightBracket and .25 or -.25))%24)
            return
        end
        local preset=keys[input.KeyCode]; if not preset then return end
        local incoming=game.HttpService:JSONDecode(Lighting:GetAttribute("LightingCycleState"))
        local cycle=Cycle.build(presets,schedule,incoming)
        runtime:SetAttribute("LightingPreviewClockTime",Cycle.previewClock(cycle,preset))
    end)
    script.Destroying:Once(function() connection:Disconnect(); runtime:SetAttribute("LightingPreviewClockTime",nil) end)
    print("[Lighting Preview] 1 sunrise, 3/M day, 5 sunset, 6 dusk, 7/N night, 8 dawn; brackets scrub 15 minutes; R resumes")
    return
end

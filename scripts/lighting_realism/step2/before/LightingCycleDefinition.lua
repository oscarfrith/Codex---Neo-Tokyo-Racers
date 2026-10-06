-- Authoring adapter only. Tune Config.World.Lighting and its ContinuousLooks folders.
local Definition={}
function Definition.read(config)
    local points={}
    local looks=assert(config:FindFirstChild("ContinuousLooks"),"Missing ContinuousLooks")
    local palette=assert(config:FindFirstChild("ContinuousPresets"),"Missing ContinuousPresets")
    for _,folder in ipairs(looks:GetChildren()) do
        assert(folder:IsA("Folder"),"ContinuousLooks accepts Folder milestones only")
        local point={Name=folder.Name,Preset=folder:GetAttribute("Preset"),Anchor=folder:GetAttribute("Anchor"),OffsetHours=folder:GetAttribute("OffsetHours"),HoldHours=folder:GetAttribute("HoldHours")}
        for _,group in ipairs({"Light","Colour","Haze","Glare","Distance","Post"}) do
            point[group.."FadeStart"]=folder:GetAttribute(group.."FadeStart")
            point[group.."FadeEnd"]=folder:GetAttribute(group.."FadeEnd")
        end
        points[#points+1]=point
    end
    table.sort(points,function(a,b) return a.Name<b.Name end)
    local presets={}
    for _,look in ipairs(palette:GetChildren()) do
        assert(look:IsA("Folder") and not presets[look.Name],"Invalid or duplicate continuous preset")
        local sections={}; presets[look.Name]=sections
        for _,section in ipairs(look:GetChildren()) do
            assert(section:IsA("Folder") and not sections[section.Name] and #section:GetChildren()==0,"Invalid preset section")
            local properties={}; sections[section.Name]=properties
            for key,value in pairs(section:GetAttributes()) do
                properties[key]=typeof(value)=="Color3" and {Type="Color3",R=value.R,G=value.G,B=value.B} or value
            end
        end
    end
    return {
        DurationSeconds=config:GetAttribute("ContinuousCycleDurationSeconds"),
        Latitude=config:GetAttribute("ContinuousGeographicLatitude"),
        Sunrise=config:GetAttribute("SunriseClockTime"),Sunset=config:GetAttribute("SunsetClockTime"),
        SkyName=config:GetAttribute("ContinuousSkyName"),Points=points,Presets=presets,
        RayFadeHours=config:GetAttribute("ContinuousRayFadeHours"),
        Auto=config:GetAttribute("AutoCycleEnabled")~=false,
        Synchronized=config:GetAttribute("SynchronizeAcrossServers")~=false,
        ManualClockTime=config:GetAttribute("ContinuousManualClockTime"),
    }
end
return Definition

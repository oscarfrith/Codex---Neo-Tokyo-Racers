-- Pulse fork span (API2 5.5): replaces Classic 271-300, the wrong-way label builder. Everything outside this span is
-- the Classic RaceRouteGuideClient text. Nothing above this point creates an instance or connects a signal, so the
-- claim here is the owner's first effect.
local pulseKit = script.Parent.Parent.Kit
local PulseLayers = require(pulseKit.Layers)
PulseLayers.Switch().Claim("RaceRouteGuide")
local PulseOverlay = require(pulseKit.Overlay)
local pulseScope = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("ConnectionScope")).new()
local guideLayer = PulseLayers.Create("RaceRouteGuide_Phase5", { Frame = "Hud" })
local wrongWayBanner = PulseOverlay.PromptBanner(guideLayer.Slot("PromptStack"), { Name = "WrongWayPrompt", Action = "WRONG WAY" }, pulseScope)
local wrongWay = wrongWayBanner.Instance
wrongWay.Visible = false

-- Pulse: the GarageEntranceStatus ScreenGui and its label are not created (API2 5.7). The native prompt still owns
-- all normal input presentation; actionable errors after a trigger go to the shared top notification.
require(script.Parent.Parent:WaitForChild("Kit"):WaitForChild("Layers")).Switch().Claim("GarageEntrance")

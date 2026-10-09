local scope = Kit.Scope.new()
local playDefaultText = tostring(config:GetAttribute("StartScreenPlayText") or "PLAY")
local shopDefaultText = tostring(config:GetAttribute("StartScreenShopText") or "SHOP")
local built = StartScreen._buildMenu(Kit, safeRoot, Kit.Metrics.Of(safeRoot), scope, { Play = playDefaultText, Shop = shopDefaultText })
local menu = built.Menu
local play, shop = built.Play.Instance, built.Shop.Instance
claimWhenCommitted(SURFACE)

-- The kit lays the menu out and follows the screen by itself. The one thing release() has to end is the kit scope,
-- which it does through the loop it already runs over layoutConnections.
local layoutConnections = { { Disconnect = function() scope:destroy() end } }

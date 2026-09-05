-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
-- NTR_MOBILE_FREEROAM_UI_PHASE1K_BOOST_PLATE_EXIT_ALIGNMENT
-- Superseded by the canonical isolated mobile HUD/control owners.
return
end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client

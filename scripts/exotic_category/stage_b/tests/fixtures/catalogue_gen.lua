-- STAGE_B_FIXTURE: stand-in for scripts/exotic_category/catalogue/catalogue_gen.lua, for offline build tests only.
-- An installer built with this file is marked as a fixture build and refuses to APPLY.
return function()
	error("STAGE_B_FIXTURE catalogue generator: this installer was built from test fixtures and cannot run")
end

-- hash.lua: the one hash convention of the UI restyle programme. build.py inlines this file; do not copy it.
-- Both hashes run over the raw source BYTES and stay exact in Luau doubles.
--   djb2     x = (x * 33 + byte) % 2^32, seed 5381 (same as scripts/hover_feel and classic/manifest.json "djb2")
--   fnv1a32  FNV-1a 32, seed 2166136261, prime 16777619 (classic/manifest.json "fnv1a32").
--            f * 16777619 = f * 2^24 + f * 403; lshift keeps the first term under 2^32.
-- A fingerprint is "<djb2>-<fnv1a32>-<byte length>" in decimal. Python mirror: plan.py fingerprint().
local Hash = {}
function Hash.pair(s)
	local d = 5381
	local f = 2166136261
	for i = 1, #s do
		local b = string.byte(s, i)
		d = (d * 33 + b) % 4294967296
		f = bit32.bxor(f, b)
		f = (bit32.lshift(f, 24) + f * 403) % 4294967296
	end
	return d, f
end
function Hash.fingerprint(s)
	local d, f = Hash.pair(s)
	return string.format("%d-%d-%d", d, f, #s)
end

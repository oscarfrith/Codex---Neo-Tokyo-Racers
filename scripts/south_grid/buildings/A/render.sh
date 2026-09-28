#!/bin/sh
# usage (from anywhere): render.sh <outdir-name> <spec-name...> -- <cams...>
A="C:/Users/Oscar/Documents/LUCIDITY/Codex---Neo-Tokyo-Racers/scripts/south_grid/buildings/A"
SG="C:/Users/Oscar/Documents/LUCIDITY/Codex---Neo-Tokyo-Racers/scripts/south_grid"
out="$A/preview/$1"; shift
specs=""; while [ "$1" != "--" ]; do specs="$specs $A/$1"; shift; done; shift
"C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup -P "$A/preview_a.py" -- --specs $specs --out "$out" ${ALL---all-specs} --cams "$@" 2>&1 | grep -E "PREVIEW_DONE|Error|rror:" | head

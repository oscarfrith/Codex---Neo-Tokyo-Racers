#!/bin/sh
# usage: _render.sh outdir cams...   (renders C's specs + neighbours)
OUT=$1; shift
cd "$(dirname "$0")/../.."
"C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup -P common/preview.py -- \
  --specs buildings/C/P12.json $( [ -f buildings/C/P05.json ] && echo buildings/C/P05.json ) $( [ -f buildings/C/X6.json ] && echo buildings/C/X6.json ) \
  --out "$OUT" --all-specs --cams "$@" 2>&1 | grep -E "PREVIEW_DONE|Error|error" 

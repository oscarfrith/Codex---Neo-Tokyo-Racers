# Importing the South Grid kit into Studio

File: `scripts/south_grid/kit/out/SouthGridKit.fbx` (26 mesh objects, one per kit piece, each named exactly as the piece in `common/kit_catalog.json`).

The FBX is Y-up with -Z as the front face, and the axis conversion is baked into the mesh data. Raw vertex values are studs. The assembler resizes every MeshPart to its catalog size, so the import scale does not matter. Only the orientation and the piece names matter.

## Steps (Oscar)

1. Open the target place, which is the test copy `09282026_3` first.
2. In Explorer, make sure `ReplicatedStorage.Assets.World` exists. Create a **Folder** named `SouthGridKit` inside it if it is missing.
3. Go to **Home → Import 3D** (or File → Import 3D) and choose `SouthGridKit.fbx`.
4. In the importer settings:
   - **File General → Scale Unit:** `Stud`. Leave World Forward and World Up at their defaults: **Front**/-Z and **Top**/+Y.
   - **File General → Import Only As Model:** on.
   - **File General → Merge Meshes:** **off**. Every piece must stay its own MeshPart.
   - **File General → Insert In Workspace:** on, so you can move it afterwards. Keep **Anchored** on.
   - **Materials:** you can leave these alone. The assembler sets Material, MaterialVariant and Color from the catalog, so no textures or SurfaceAppearances are needed.
   - **Rig/Skinning:** none.
5. Click **Import**. You get one Model with 26 MeshParts laid out in a row along +X, 20 studs apart.
6. Check two things:
   - `capsule_shell`: the round porthole recess faces **-Z** (the front). Select it and look at its Front face.
   - `ext_stair`: it stands upright, 40 tall.

   If both are right, the orientation is right for every piece.
7. Check that the MeshPart names match the piece names exactly, for example `capsule_shell` and `bridge_tube_glass`. Rename any the importer suffixed (such as `capsule_shell.001`) or wrapped in a sub-Model.
8. Move all 26 MeshParts (not the wrapper Model) into `ReplicatedStorage.Assets.World.SouthGridKit`, then delete the empty wrapper Model.
9. On each MeshPart, set **CollisionFidelity = Box** and **RenderFidelity = Automatic**. Set **DoubleSided** off (the two-sided pieces already have back faces). The assembler may also set these.
10. Re-run the assembler (`install/assemble.lua`). It will replace the box proxies with clones of these MeshParts, resized to catalog size.

## Piece list

`capsule_shell`, `capsule_porthole`, `porthole_panel`, `porthole_glass_4`, `balcony_slab`, `balcony_infill`, `laundry`, `ac_cluster`, `water_tank`, `dish_cluster`, `antenna_mast`, `rooftop_shack`, `ext_stair`, `pipe_bundle`, `bridge_truss`, `bridge_truss_glass`, `bridge_tube_ribs`, `bridge_tube_glass`, `louvre_fins`, `tray_edge`, `stall_frame`, `stall_awning`, `vending_body`, `vending_front`, `bench`, `chainlink`.

To rebuild after changes, run:

`"C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup -P scripts/south_grid/kit/build_kit.py`

Then re-import. In Studio, replace the existing MeshParts: delete the old ones first so the names stay unique.

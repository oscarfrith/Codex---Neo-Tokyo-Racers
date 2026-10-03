"""Exotic Stage A, client sources: exact single-occurrence edits over the exotic-before blobs.

Writes after/<ScriptName>.lua, before/<ScriptName>.lua (the verified blob bytes, for run_checks.lua after APPLY),
ops.json and config_ops.json in this folder. Never touches Studio.
Usage: py -3 scripts/exotic_category/stage_a/client/build.py
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
REL = 'scripts/exotic_category/stage_a/client'
CAP = ROOT / 'roblox/captures/exotic-before/capture.json'
OUT = HERE / 'after'
OUT.mkdir(exist_ok=True)
BEFORE = HERE / 'before'
BEFORE.mkdir(exist_ok=True)

capture = json.loads(CAP.read_text(encoding='utf8'))
MANIFEST = {tuple(r['path_parts']): r for r in capture['manifest']}
GAME = ('ReplicatedStorage', 'Modules', 'Game')


def edit(path, reps):
    record = MANIFEST[path]
    raw = (ROOT / record['file']).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == record['source_sha256'], path
    (BEFORE / (path[-1] + '.lua')).write_bytes(raw)
    s = raw.decode('utf8')
    for a, b in reps:
        assert s.count(a) == 1, (path[-1], a[:80], s.count(a))
        s = s.replace(a, b)
    assert '\r' not in s and all(ord(c) < 128 for c in s), path
    assert len(s.encode('utf8')) < 190000, path
    (OUT / (path[-1] + '.lua')).write_bytes(s.encode('utf8'))
    return {"kind": "source", "path": list(path), "file": f"{REL}/after/{path[-1]}.lua"}


ops = []

# 1. Two artwork rows. GarageUI only shows a row when the current category has that slot.
ops.append(edit(GAME + ('UI', 'GarageWorkspaceUI'), [
    ('\t{Name="Boost",DisplayName="Boost",TargetId="Boost",SortOrder=70,ShowInBuild=true,ShowInCustomise=true},\n',
     '\t{Name="Boost",DisplayName="Boost",TargetId="Boost",SortOrder=70,ShowInBuild=true,ShowInCustomise=true},\n'
     '\t{Name="FrontBody",DisplayName="Front Body",TargetId="FrontBody",SortOrder=72,ShowInBuild=true,ShowInCustomise=true},\n'
     '\t{Name="RearBody",DisplayName="Rear Body",TargetId="RearBody",SortOrder=74,ShowInBuild=true,ShowInCustomise=true},\n'),
]))

# 2. Slot label from the slot's RailLabel; card title and tag from the view-model row; which categories are listed.
CURRENT_LINE = 'local function currentCategory() return categoryById(State.CategoryId) or allCategories()[1] end\n'
SLOT_LINE = 'local function slot(id) for _,s in ipairs(slots()) do if tostring(s.SlotId)==tostring(id) then return s end end end\n'
ops.append(edit(GAME + ('Garage', 'GarageUI'), [
    # A category the server marks PurchaseDisabled (flag off) stays usable for its owners and is never offered for sale.
    (CURRENT_LINE,
     CURRENT_LINE
     + '-- A category the server marks PurchaseDisabled is not on sale. The dealership leaves it out; Customisation keeps it for a player who owns one of its vehicles.\n'
     + 'local function categoryListed(c) if c.PurchaseDisabled~=true then return true end; if State.ShopMode~="Customisation" then return false end; '
       'local p=State.Profile or {}; for _,vehicle in pairs(p.Vehicles or {}) do '
       'local item=vehicle.CockpitInstanceId and p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]; '
       'local id=item and tostring(item.TemplateId or "") or ""; '
       'for _,k in ipairs(c.Cockpits or {}) do if id~="" and tostring(k.CockpitId)==id then return true end end end; return false end\n'
     + 'local function listedCategories() local result={}; for _,c in ipairs(allCategories()) do if categoryListed(c) then table.insert(result,c) end end; return result end\n'),
    ('for _,source in ipairs(allCategories()) do for _,cockpit in ipairs(source.Cockpits or {}) do ',
     'for _,source in ipairs(listedCategories()) do for _,cockpit in ipairs(source.Cockpits or {}) do '),
    ('local function browserCategory() return State.BrowseAll and combinedCategory() or currentCategory() end\n',
     'local function browserCategory() local c=currentCategory(); if State.BrowseAll or (c and not categoryListed(c)) then return combinedCategory() end; return c end\n'),
    ('Category=browserCategory(),Cash=State.Profile.Cash,',
     'Category=browserCategory(),Categories=listedCategories(),Cash=State.Profile.Cash,'),
    (SLOT_LINE,
     SLOT_LINE
     + 'local function slotLabel(s,art) local label=tostring(s and s.RailLabel or ""); if label~="" then return label end; return art.DisplayName end\n'),
    ('table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,',
     'table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=slotLabel(s,art),Badge=installed and "EQUIPPED" or nil,'),
    ('table.insert(c.LeftItems,{Id=s.SlotId,Text=art.DisplayName,ImageKey=art.TargetId,',
     'table.insert(c.LeftItems,{Id=s.SlotId,Text=slotLabel(s,art),ImageKey=art.TargetId,'),
    ('Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,',
     'Text=id=="THRUST_COLOR" and "Thrust" or slotLabel(slot(id),art),ImageKey=art.TargetId,'),
    ('table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Footer=row.Status,',
     'table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.Title,Variant=row.Tag,Footer=row.Status,'),
    ('table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price,',
     'table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.Title,Variant=row.Tag,Price=row.Price,'),
]))

# 2b. Category buttons come from the list GarageUI passes (it owns which categories are listed); absent: the whole catalogue as before.
ops.append(edit(GAME + ('UI', 'GarageBrowserUI'), [
    ('for _,c in ipairs((context.State.Catalog and context.State.Catalog.Categories) or {}) do table.insert(categories,c) end',
     'for _,c in ipairs(context.Categories or (context.State.Catalog and context.State.Catalog.Categories) or {}) do table.insert(categories,c) end'),
]))

# 3. Rows gain Title and Tag. Existing fields, sort keys and order are untouched.
OWNED_ROW = ('{Id=tostring(instanceId),Module=module,Item=item,State=state,Status=status,Variant=ViewModel.Variant(module),'
             'VehicleName=context.SourceVehicleName(module),Rating=ViewModel.Rating(module,item,context.Rating),OwnerVehicleId=owner}')
SHOP_ROW = ('{Id=tostring(module.ModuleId),Module=module,State=locked and "Locked" or "Shop",'
            'Status=locked and ("BUY "..string.upper(context.SourceVehicleName(module)).." TO UNLOCK") or ("OWNED x"..tostring(context.OwnedCount(module.ModuleId))),'
            'Variant=ViewModel.Variant(module),VehicleName=context.SourceVehicleName(module),Rating=ViewModel.Rating(module,nil,context.Rating),'
            'SourceRating=context.SourceRating(module),Locked=locked,Price=tonumber(module.Price) or 0}')
ops.append(edit(GAME + ('UI', 'GarageModuleCardViewModel'), [
    # The sort key of a module with a CardTitle never comes from a search of its (free text) name.
    ('\tif explicit=="Standard" or explicit=="Lightweight" or explicit=="Power" then return explicit end\n',
     '\tif explicit=="Standard" or explicit=="Lightweight" or explicit=="Power" then return explicit end\n'
     '\t-- A module with a CardTitle is named freely, so its name is never read as a variant.\n'
     '\tif tostring(module and module.CardTitle or "")~="" then return "Standard" end\n'),
    ('function ViewModel.Owned(context)\n',
     '-- Card text. Title is the module CardTitle when it has one, else the source vehicle name as before.\n'
     '-- Tag is the variant as before; a module with a CardTitle shows its own VariantName (never "Level n").\n'
     'function ViewModel.CardText(row)\n'
     '\tlocal module=row.Module; local title=tostring(module and module.CardTitle or ""); local explicit=tostring(module and module.VariantName or "")\n'
     '\trow.Title=title~="" and title or row.VehicleName\n'
     '\trow.Tag=(title~="" and explicit~="" and not string.match(explicit,"^Level %d+$")) and explicit or row.Variant\n'
     '\treturn row\n'
     'end\n'
     '\n'
     'function ViewModel.Owned(context)\n'),
    ('table.insert(rows,' + OWNED_ROW + ')', 'table.insert(rows,ViewModel.CardText(' + OWNED_ROW + '))'),
    ('table.insert(rows,' + SHOP_ROW + ')', 'table.insert(rows,ViewModel.CardText(' + SHOP_ROW + '))'),
]))

# 4. Dealership preview: optional defaults for any slot beyond the four legacy ones.
ops.append(edit(GAME + ('Garage', 'GarageVehiclePreviewProfile'), [
    ('local function defaultModules(cockpit)\n'
     '\tcockpit=cockpit or {}; local engine=cockpit.DefaultFrontEngineModuleId or cockpit.DefaultEngineModuleId\n'
     '\treturn {\n',
     '-- Default<X>ModuleId keys the four legacy slots own. Any other Default<SlotId>ModuleId key is an optional default for that slot.\n'
     'local legacyDefaultKeys={Engine=true,FrontEngine=true,RearEngine=true,EngineB=true,Stabilisers=true,Stabiliser=true,Boost=true,Engine1=true,Engine2=true}\n'
     'local function defaultModules(cockpit)\n'
     '\tcockpit=cockpit or {}; local engine=cockpit.DefaultFrontEngineModuleId or cockpit.DefaultEngineModuleId\n'
     '\tlocal result={\n'),
    ('\t\tBoost=cockpit.DefaultBoostModuleId,\n'
     '\t}\n'
     'end\n',
     '\t\tBoost=cockpit.DefaultBoostModuleId,\n'
     '\t}\n'
     '\tfor key,moduleId in pairs(cockpit) do\n'
     '\t\tlocal slotId=typeof(key)=="string" and string.match(key,"^Default(.+)ModuleId$")\n'
     '\t\tif slotId and not legacyDefaultKeys[slotId] then result[slotId]=moduleId end\n'
     '\tend\n'
     '\treturn result\n'
     'end\n'),
]))

# 5. Dealership rating: the same optional defaults; module rating reference from RatingReferenceCockpitId.
MANDATORY = ('\tfor slotId,names in pairs(defaultNames) do local moduleId=first(cockpit,names) or first(template,names); '
             'local module=findTemplate(root,"ModuleId",moduleId); if not module then return nil,nil,slotId.." default not found: "..tostring(moduleId) end; '
             'bySlot[slotId]=module; table.insert(modules,module) end\n')
ops.append(edit(GAME + ('Vehicles', 'Performance', 'VehiclePerformanceResolver'), [
    ('\tBoost={"DefaultBoostModuleId"},\n'
     '}\n',
     '\tBoost={"DefaultBoostModuleId"},\n'
     '}\n'
     '-- Any other Default<SlotId>ModuleId key is an optional default for that slot. Piercer cockpits have none.\n'
     'local legacyDefaultNames={}\n'
     'for slotId,names in pairs(defaultNames) do legacyDefaultNames["Default"..slotId.."ModuleId"]=true; for _,name in ipairs(names) do legacyDefaultNames[name]=true end end\n'),
    ('function Resolver.DefaultBuild(root,cockpit)\n',
     'local function optionalDefaults(cockpit,template)\n'
     '\tlocal order,ids={},{}\n'
     '\tfor _,source in ipairs({cockpit or false,template or false}) do\n'
     '\t\tlocal fields=typeof(source)=="Instance" and source:GetAttributes() or source\n'
     '\t\tif typeof(fields)=="table" then\n'
     '\t\t\tfor key,value in pairs(fields) do\n'
     '\t\t\t\tlocal slotId=typeof(key)=="string" and not legacyDefaultNames[key] and string.match(key,"^Default(.+)ModuleId$")\n'
     '\t\t\t\tif slotId and ids[slotId]==nil and tostring(value)~="" then ids[slotId]=tostring(value); table.insert(order,slotId) end\n'
     '\t\t\tend\n'
     '\t\tend\n'
     '\tend\n'
     '\ttable.sort(order); return order,ids\n'
     'end\n'
     'function Resolver.DefaultBuild(root,cockpit)\n'),
    (MANDATORY,
     MANDATORY
     + '\tlocal order,ids=optionalDefaults(cockpit,template); for _,slotId in ipairs(order) do local module=findTemplate(root,"ModuleId",ids[slotId]); '
       'if module then bySlot[slotId]=module; table.insert(modules,module) end end\n'),
    ('\tlocal reference=findTemplate(root,"CockpitId","bruiser_01"); ',
     '\tlocal referenceId=tostring(attributeOrField(template,"RatingReferenceCockpitId") or ""); if referenceId=="" then referenceId="bruiser_01" end\n'
     '\tlocal reference=findTemplate(root,"CockpitId",referenceId); '),
]))

# 6. Camera views for the two new slots.
ops.append(edit(GAME + ('Garage', 'PreviewCameraClient'), [
    ('RearBumper="Rear",FrontBumper="Front"}\n', 'RearBumper="Rear",FrontBumper="Front",FrontBody="Front",RearBody="Rear45"}\n'),
]))

(HERE / 'ops.json').write_bytes((json.dumps(ops, indent=1) + '\n').encode('utf8'))

# Config: artwork folders with the same attribute set as the eleven live entries. Images reuse live entries (no upload).
nodes = {}


def walk(items):
    for n in items:
        nodes[tuple(n['path_parts'])] = n
        walk(n.get('children') or [])


walk(capture['hierarchy'])
ARTWORK = ('ReplicatedStorage', 'Config', 'UI', 'GarageReplacement', 'ModuleArtwork')
KEYS = {'DisplayName', 'Image', 'ShowInBuild', 'ShowInCustomise', 'SortOrder', 'TargetId'}
live = {p[-1]: n for p, n in nodes.items() if p[:-1] == ARTWORK}
assert len(live) == 11 and all(set(n['attributes']) == KEYS for n in live.values()), sorted(live)
assert not any(n['attributes']['SortOrder']['value'] in (72, 74) for n in live.values())


def image(name):
    return live[name]['attributes']['Image']['value']


config = [
    {"kind": "folder", "parent": list(ARTWORK), "name": "FrontBody", "attributes": {
        "DisplayName": "Front Body", "Image": image('FrontBumper'), "ShowInBuild": True, "ShowInCustomise": True,
        "SortOrder": 72, "TargetId": "FrontBody"}},
    {"kind": "folder", "parent": list(ARTWORK), "name": "RearBody", "attributes": {
        "DisplayName": "Rear Body", "Image": image('RearBumper'), "ShowInBuild": True, "ShowInCustomise": True,
        "SortOrder": 74, "TargetId": "RearBody"}},
]
for op in config:
    assert set(op['attributes']) == KEYS and tuple(op['parent']) + (op['name'],) not in nodes
(HERE / 'config_ops.json').write_bytes((json.dumps(config, indent=1) + '\n').encode('utf8'))
print(len(ops), 'source operations;', len(config), 'config operations')

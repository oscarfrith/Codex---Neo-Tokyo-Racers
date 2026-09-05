from prepare import *
rows=json.loads(read(HERE/'baseline.json'))
code='local expected={'+','.join('{'+json.dumps(r['roblox_path'])+','+str(r['hash32'])+'}' for r in rows)+'}\n'
code+='''local count=0; local mismatches={}
for _,r in ipairs(expected) do
 local o=game; for p in r[1]:gmatch("[^%.]+") do o=o and o:FindFirstChild(p) end
 if o and o:IsA("LuaSourceContainer") then
  local h=0; for i=1,#o.Source do h=(h*31+string.byte(o.Source,i))%4294967296 end
  if h~=r[2] then table.insert(mismatches,r[1]) end; count+=1
 else table.insert(mismatches,r[1]) end
end
return game:GetService("HttpService"):JSONEncode({count=count,mismatches=mismatches})
'''
print(code)

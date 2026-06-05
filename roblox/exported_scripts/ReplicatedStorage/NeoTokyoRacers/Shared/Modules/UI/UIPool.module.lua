local UIPool = {}
local Pool = {}
Pool.__index = Pool

function UIPool.new(container)
	return setmetatable({
		Container = container,
		Items = {},
		Connections = {},
		Active = 0,
	}, Pool)
end

function Pool:SetContainer(container)
	self.Container = container
end

function Pool:_disconnect(item)
	local list = self.Connections[item]
	if not list then return end
	for _, connection in ipairs(list) do
		if connection then connection:Disconnect() end
	end
	self.Connections[item] = nil
end

function Pool:Begin()
	self.Active = 0
	for _, item in ipairs(self.Items) do
		self:_disconnect(item)
		if item then
			item.Visible = false
			item.Parent = nil
		end
	end
end

function Pool:Acquire(factory)
	self.Active += 1
	local item = self.Items[self.Active]
	if not item then
		item = factory()
		self.Items[self.Active] = item
	end
	if item then
		item.Parent = self.Container
		item.Visible = true
		self:_disconnect(item)
	end
	return item
end

function Pool:Next(factory)
	return self:Acquire(factory)
end

function Pool:Connect(item, signal, callback)
	if not item or not signal or typeof(callback) ~= "function" then return nil end
	local connection = signal:Connect(callback)
	local list = self.Connections[item]
	if not list then
		list = {}
		self.Connections[item] = list
	end
	table.insert(list, connection)
	return connection
end

function Pool:End()
	for index = self.Active + 1, #self.Items do
		local item = self.Items[index]
		if item then
			self:_disconnect(item)
			item.Visible = false
			item.Parent = nil
		end
	end
end

function Pool:HideUnused()
	self:End()
end

function Pool:Destroy()
	for _, item in ipairs(self.Items) do
		self:_disconnect(item)
		if item then item:Destroy() end
	end
	table.clear(self.Items)
	table.clear(self.Connections)
	self.Active = 0
end

function Pool:Clear()
	self:Destroy()
end

return UIPool

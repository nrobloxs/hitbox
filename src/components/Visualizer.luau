--!strict

local RunService = game:GetService("RunService")
local Data = require(script.Parent.Parent.Data)
local Util = require(script.Parent.Util)
local Visualizer = {}
Visualizer.__index = Visualizer

export type Visualizer = typeof(setmetatable(
	{} :: {
		Body: Part,
		_HeartbeatConnection: RBXScriptConnection?,
	},
	Visualizer
))

local function configureBody(body: Part)
	body.Name = "HitboxVisualizer"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = false
	body.Locked = true
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = 0.9
	body.Color = Color3.fromRGB(159, 0, 0)
end

function Visualizer.new(): Visualizer
	local self = setmetatable({}, Visualizer) :: Visualizer
	self.Body = Instance.new("Part")
	configureBody(self.Body)
	self._HeartbeatConnection = nil
	return self
end

function Visualizer.Show(self: Visualizer, size: Data.HitboxSize, anchor: Data.HitboxAnchor, offset: Data.HitboxOffset?)
	self:Hide()

	local function update()
		self.Body.CFrame = Util.GetAnchor(anchor, offset)
	end

	self.Body.Size = size
	update()
	self.Body.Parent = workspace

	if typeof(anchor) ~= "CFrame" then
		self._HeartbeatConnection = RunService.Heartbeat:Connect(update)
	end
end

function Visualizer.Hide(self: Visualizer)
	if self._HeartbeatConnection then
		self._HeartbeatConnection:Disconnect()
		self._HeartbeatConnection = nil
	end
	self.Body.Parent = nil
end

function Visualizer.Destroy(self: Visualizer)
	self:Hide()
	self.Body:Destroy()
end

return Visualizer

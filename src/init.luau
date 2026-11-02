--!strict
local Data = require(script.Data)
local Signal = require(script.components.Signal)
local Util = require(script.components.Util)
local Visualizer = require(script.components.Visualizer)

local LOG_PREFIX = "[HITBOX]"

local Hitbox = {}
Hitbox.__index = Hitbox

export type Config = {
	Size: Data.HitboxSize?,
	Anchor: Data.HitboxAnchor?,
	Offset: Data.HitboxOffset?,
	ExcludeList: Data.HitboxExcludeList?,
	Options: Data.HitboxOptionsConfig?,
	Caster: Model?,
}

export type Hitbox = typeof(setmetatable(
	{} :: {
		Size: Data.HitboxSize,
		Anchor: Data.HitboxAnchor,
		Offset: Data.HitboxOffset,
		ExcludeList: Data.HitboxExcludeList,
		Options: Data.HitboxOptions,
		State: Data.HitboxState,

		Hit: Signal.Signal<{ Model }>,

		_Visualizer: Visualizer.Visualizer?,
		_HeartbeatConnection: RBXScriptConnection?,
		_AnchorConnection: RBXScriptConnection?,
	},
	Hitbox
))

local function log(message: string)
	Util.Log(LOG_PREFIX, message)
end

local function isAnchorInWorld(anchor: Data.HitboxAnchor): boolean
	return typeof(anchor) == "CFrame" or anchor:IsDescendantOf(workspace)
end

function Hitbox.new(config: Config?): Hitbox
	local settings: Config = config or {}
	local self = setmetatable({}, Hitbox) :: Hitbox

	self.Size = settings.Size or Data.DEFAULTS.Size
	self.Anchor = settings.Anchor or Data.DEFAULTS.Anchor
	self.Offset = settings.Offset or Vector3.zero
	self.Options = Util.ResolveOptions(settings.Options)

	self.ExcludeList = if settings.ExcludeList then table.clone(settings.ExcludeList) else {}
	if self.Options.AutoExcludeCaster and settings.Caster then
		table.insert(self.ExcludeList, settings.Caster)
	end
	self.State = Data.DEFAULTS.State

	self.Hit = Signal.new()

	self._Visualizer = if self.Options.VisualizeBox then Visualizer.new() else nil
	self._HeartbeatConnection = nil
	self._AnchorConnection = nil

	log("created")
	return self
end

function Hitbox._SetState(self: Hitbox, state: Data.HitboxState)
	self.State = state
	log(string.lower(state))
end

function Hitbox._Release(self: Hitbox)
	if self._HeartbeatConnection then
		self._HeartbeatConnection:Disconnect()
		self._HeartbeatConnection = nil
	end
	if self._AnchorConnection then
		self._AnchorConnection:Disconnect()
		self._AnchorConnection = nil
	end
	if self._Visualizer then
		self._Visualizer:Hide()
	end
end

function Hitbox.Start(self: Hitbox)
	if self.State ~= "Idle" or not isAnchorInWorld(self.Anchor) then
		return
	end

	local alreadyHit: { [Model]: boolean } = {}

	self._HeartbeatConnection = Util.StartConnection({
		Size = self.Size,
		Anchor = self.Anchor,
		Offset = self.Offset,
		ExcludeList = self.ExcludeList,
		Options = self.Options,
	}, function(characters: { Model })
		Util.OnCharactersFound(characters, self.Hit, alreadyHit)
	end)

	self._AnchorConnection = Util.BindAnchorLifecycle(self.Anchor, function()
		self:Stop()
	end)

	if self._Visualizer then
		self._Visualizer:Show(self.Size, self.Anchor, self.Offset)
	end

	self:_SetState("Started")
end

function Hitbox.Stop(self: Hitbox)
	if self.State ~= "Started" then
		return
	end
	self:_Release()
	self:_SetState("Idle")
end

function Hitbox.Destroy(self: Hitbox)
	if self.State == "Destroyed" then
		return
	end
	self:Stop()
	self.Hit:DisconnectAll()
	if self._Visualizer then
		self._Visualizer:Destroy()
		self._Visualizer = nil
	end
	self:_SetState("Destroyed")
end

return Hitbox

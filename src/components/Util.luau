--!strict

local RunService = game:GetService("RunService")
local Data = require(script.Parent.Parent.Data)
local Signal = require(script.Parent.Signal)

local DEBUG = RunService:IsStudio()

local Util = {}

local function getCharacter(part: BasePart): Model?
	local current: Instance? = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Util.GetAliveCharactersFromParts(parts: { BasePart }): { Model }
	local aliveCharacters: { Model } = {}
	local seen: { [Model]: boolean } = {}

	for _, part in parts do
		local model = getCharacter(part)
		if not model or seen[model] then
			continue
		end
		seen[model] = true

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(aliveCharacters, model)
		end
	end

	return aliveCharacters
end

function Util.GetAnchor(anchor: Data.HitboxAnchor, offset: Data.HitboxOffset?): CFrame
	local baseCFrame: CFrame = if typeof(anchor) == "CFrame" then anchor else anchor.CFrame
	return baseCFrame * CFrame.new(offset or Vector3.zero)
end

function Util.ResolveOptions(partial: Data.HitboxOptionsConfig?): Data.HitboxOptions
	local defaults = Data.DEFAULTS.Options
	local given: Data.HitboxOptionsConfig = partial or {}
	return {
		VisualizeBox = if given.VisualizeBox ~= nil then given.VisualizeBox else defaults.VisualizeBox,
		AutoExcludeCaster = if given.AutoExcludeCaster ~= nil
			then given.AutoExcludeCaster
			else defaults.AutoExcludeCaster,
	}
end

function Util.StartConnection(
	hitboxData: {
		Size: Data.HitboxSize,
		Anchor: Data.HitboxAnchor,
		Offset: Data.HitboxOffset,
		ExcludeList: Data.HitboxExcludeList,
		Options: Data.HitboxOptions,
	},
	onCharactersFound: ({ Model }) -> ()
): RBXScriptConnection
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = hitboxData.ExcludeList

	return RunService.Heartbeat:Connect(function()
		local boxCFrame = Util.GetAnchor(hitboxData.Anchor, hitboxData.Offset)
		local parts = workspace:GetPartBoundsInBox(boxCFrame, hitboxData.Size, overlapParams)
		if #parts == 0 then
			return
		end
		onCharactersFound(Util.GetAliveCharactersFromParts(parts))
	end)
end

function Util.BindAnchorLifecycle(anchor: Data.HitboxAnchor, callback: () -> ()): RBXScriptConnection?
	if typeof(anchor) == "CFrame" then
		return nil
	end
	return anchor.AncestryChanged:Connect(function()
		if not anchor:IsDescendantOf(workspace) then
			callback()
		end
	end)
end

function Util.OnCharactersFound(
	characters: { Model },
	hitSignal: Signal.Signal<{ Model }>,
	alreadyHit: { [Model]: boolean }
)
	local fresh: { Model } = {}
	for _, character in characters do
		if not alreadyHit[character] then
			alreadyHit[character] = true
			table.insert(fresh, character)
		end
	end
	if #fresh > 0 then
		hitSignal:Fire(fresh)
	end
end

function Util.Log(prefix: string, message: string)
	if DEBUG then
		print(prefix .. " " .. message)
	end
end

return Util

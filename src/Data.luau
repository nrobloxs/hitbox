--!strict

export type HitboxAnchor = CFrame | BasePart
export type HitboxSize = Vector3
export type HitboxOffset = Vector3
export type HitboxExcludeList = { Instance }
export type HitboxState = "Idle" | "Started" | "Destroyed"

export type HitboxOptions = {
	VisualizeBox: boolean,
	AutoExcludeCaster: boolean,
}
export type HitboxOptionsConfig = {
	VisualizeBox: boolean?,
	AutoExcludeCaster: boolean?,
}

local DEFAULTS = {
	Size = Vector3.new(3, 3, 3),
	Anchor = CFrame.identity,
	State = "Idle" :: HitboxState,
	Options = {
		VisualizeBox = false,
		AutoExcludeCaster = false,
	} :: HitboxOptions,
}

return {
	DEFAULTS = DEFAULTS,
}

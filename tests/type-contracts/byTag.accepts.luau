--!strict
local Guard = require(game.ReplicatedStorage.packages.guard)

type Alpha = { kind: "alpha", value: number }
type Beta = { kind: "beta", value: string }
type Arm = Alpha | Beta
type MixedArms = { read alpha: Guard.GuardFn<Alpha> } & { read [string]: Guard.GuardFn<Arm> }

local alpha = Guard.exactRecord({ kind = Guard.literal("alpha" :: "alpha"), value = Guard.number })
local beta = Guard.exactRecord({ kind = Guard.literal("beta" :: "beta"), value = Guard.string })
local named: Guard.GuardFn<Arm> = Guard.byTag("kind", { alpha = alpha, beta = beta })
local indexedArms: { [string]: Guard.GuardFn<Arm> } = { alpha = alpha, beta = beta }
local indexed: Guard.GuardFn<Arm> = Guard.byTag("kind", indexedArms)
local mixedArms: MixedArms = { alpha = alpha, beta = beta }
local mixed: Guard.GuardFn<Arm> = Guard.byTag("kind", mixedArms)

local function readValue(value: unknown): number | string
	local arm = named(value)
	if arm.kind == "alpha" then
		local numericValue: number = arm.value
		return numericValue
	end
	local stringValue: string = arm.value
	return stringValue
end

return { named, indexed, mixed, readValue }

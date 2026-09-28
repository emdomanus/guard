--!strict
local Guard = require(game.ReplicatedStorage.packages.guard)

local emptyAll: Guard.GuardFn<unknown> = Guard.all()
local emptyOneOf: Guard.GuardFn<unknown> = Guard.oneOf()
local excluded: Guard.GuardFn<Guard.UnknownTable> =
	Guard.mapExcluding(Guard.string, Guard.number, { metadata = true })
local inferred = Guard.exactRecord({ name = Guard.string, weight = Guard.optional(Guard.number) })
local function narrow(value: unknown): { name: string, weight: number? }
	return inferred(value)
end
return { emptyAll, emptyOneOf, excluded, narrow }

--!strict

local Guard = require(game.ReplicatedStorage.packages.guard)

type Profile = {
	name: string,
	nickname: string?,
}

type Counted = {
	count: number,
}

type Root = {
	profile: Profile,
}

type Tagged = {
	kind: "profile",
	profile: Profile,
} | {
	kind: "count",
	count: number,
}

local function narrowString(value: unknown): string
	return Guard.string(value)
end

local function narrowOptionalNumber(value: unknown): number?
	return Guard.optional(Guard.number)(value)
end

local function narrowStringOrNumber(value: unknown): string | number
	return Guard.oneOf(Guard.string, Guard.number)(value)
end

local profileGuard: Guard.GuardFn<Profile> = Guard.exactRecord({
	name = Guard.string,
	nickname = Guard.optional(Guard.string),
})

local rootGuard: Guard.GuardFn<Root> = Guard.exactRecord({
	profile = profileGuard,
})

local countedGuard: Guard.GuardFn<Counted> = Guard.exactRecord({
	count = Guard.number,
})

local profileTaggedGuard: Guard.GuardFn<Tagged> = Guard.exactRecord({
	kind = Guard.literal("profile" :: "profile"),
	profile = profileGuard,
})
local countTaggedGuard: Guard.GuardFn<Tagged> = Guard.exactRecord({
	kind = Guard.literal("count" :: "count"),
	count = Guard.number,
})
local taggedGuard: Guard.GuardFn<Tagged> = Guard.byTag("kind", {
	profile = profileTaggedGuard,
	count = countTaggedGuard,
})

local namedAndCountedGuard: Guard.GuardFn<{ name: string } & Counted> =
	Guard.all(Guard.property("name", Guard.string), Guard.property("count", Guard.number))

local propertyGuard: Guard.GuardFn<{ name: string } & Guard.UnknownTable> =
	Guard.property("name", Guard.string)
local mapGuard: Guard.GuardFn<{ [string]: number }> = Guard.map(Guard.string, Guard.number)
local arrayGuard: Guard.GuardFn<{ string }> = Guard.array(Guard.string)
type State = "ready" | "waiting"
type Position = "first" | "second"
local booleanSet: { [State]: true } = { ready = true, waiting = true }
local booleanSetGuard: Guard.GuardFn<State> = Guard.enumInSet(booleanSet)
local numberSet: { [Position]: number } = { first = 1, second = 2 }
local numberSetGuard: Guard.GuardFn<Position> = Guard.enumInSet(numberSet)

local function narrowProfile(value: unknown): Profile
	return profileGuard(value)
end

return {
	narrowString = narrowString,
	narrowOptionalNumber = narrowOptionalNumber,
	narrowStringOrNumber = narrowStringOrNumber,
	narrowProfile = narrowProfile,
	rootGuard = rootGuard,
	countedGuard = countedGuard,
	taggedGuard = taggedGuard,
	namedAndCountedGuard = namedAndCountedGuard,
	propertyGuard = propertyGuard,
	mapGuard = mapGuard,
	arrayGuard = arrayGuard,
	booleanSetGuard = booleanSetGuard,
	numberSetGuard = numberSetGuard,
}

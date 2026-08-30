# Guard

Guard is a strictly typed, identity-preserving runtime validation package for Roblox Luau.

```luau
local Guard = require(game.ReplicatedStorage.packages.guard)

type Profile = {
	name: string,
	nickname: string?,
}

local guardProfile: Guard.GuardFn<Profile> = Guard.exactRecord({
	name = Guard.string,
	nickname = Guard.optional(Guard.string),
})

local input: unknown = { name = "Ada" }
local profile = guardProfile(input)
assert(rawequal(profile, input))
```

Successful guards return the exact input value. They do not mutate, normalize, coerce, clone, or
replace it. Guard constructors snapshot their configuration tables, so later source-table mutations
do not change an existing guard.

`Guard.exactRecord` rejects unexpected fields. `Guard.array` retains numeric-map semantics and
accepts sparse numeric keys. Custom `GuardFn` children are contractually non-yielding, though Luau's
yieldable `pcall` cannot enforce that requirement.

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

## Finite numbers

`Guard.finite(value)` validates a number and rejects NaN, positive infinity, and negative infinity.
It returns the original number without clamping or coercion, including preserving signed zero.
`Guard.number` still accepts any numeric value; use `finite` when nonfinite values are invalid.

```luau
local guardSettings = Guard.exactRecord({
	speed = Guard.finite,
	weight = Guard.optional(Guard.finite),
})
```

Finite does not imply positive, integral, or within a particular range. Compose those checks in
the domain guard. Run package tests with `pwsh -NoProfile -File scripts/verify/tests.ps1`.

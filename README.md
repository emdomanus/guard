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

## Solver V2 contracts

The package uses Luau-LSP 1.70.1 with solver V2, Lune 0.10.5, Selene 0.31.0 and StyLua 2.1.0.
Public methods are read-only, matching the frozen runtime module. `exactRecord` derives its result
fields from the schema's guard results; `byTag` derives the union of its arm results. Keep tag
literals precise, for example `Guard.literal("profile" :: "profile")`. A mismatched claimed record
shape is rejected instead of being inferred from a return-only generic.

`byTag` preserves the supplied arms' type without intersecting it with an unknown-valued map.
Its type function validates string arm keys and guard functions callable with `unknown`, then
combines their result types. Named arms, string-indexed maps, and intersections of those table
shapes are supported. Invalid arm declarations produce type errors; runtime validation and
identity preservation are unchanged.

`mapExcluding` preserves and skips excluded entries, including their keys and values. Its return
type is now `GuardFn<UnknownTable>`: an excluded value may not satisfy the value guard, and an excluded
key may not satisfy the key guard. Previously the signature incorrectly claimed that every entry
formed a homogeneous map. Runtime behavior is unchanged. Consumers needing a domain record must
validate excluded fields separately and establish that domain contract at their validation boundary;
do not cast the result to an unrestricted homogeneous map. `map` still returns `GuardFn<{ [K]: V }>`.

The public Pesde entry remains `src/init.luau`. Implementation lives in
`src/utils/guard/shared/guard.luau`; canonical contracts live in `src/types/def/guard/shared/guard.luau`.
Behavior tests load the actual public entry with its script-relative dependencies in memory.

## Verification

Install pinned tools with `rokit install`. Supply a fixed Roblox definitions file via `-Definitions`
to `scripts/verify/analyze.ps1`. CLI and workspace editor settings select solver V2 explicitly.
`LUAU_LSP_OVERRIDE` optionally selects an absolute patched analyzer path (the persisted Windows user
value is used when absent from the process). It must report the pinned version. The analyzer wrapper
records its path, selection mode, override SHA-256, pins, definitions hash, arguments and native exit
alongside complete output under `.verification/`; it never replaces Rokit's cache or shims.

Run `scripts/verify/tests.ps1`, `scripts/verify/stylua.ps1`, `scripts/verify/selene.ps1`, and
`scripts/verify/analyze.ps1` through PowerShell 7. Accepted contracts must have zero diagnostics.
Run `scripts/verify/type-errors.ps1 -Definitions <fixed-definitions-file> -OutDir <fresh-directory>`
to verify the rejected examples in `tests/type-errors/`. Every `EXPECT_ERROR` marker must have a
type diagnostic on that expression's line, and every diagnostic must belong to a marked expression.
The runner rejects unexpected dependency/syntax diagnostics, missing rejections, infrastructure
failures and complexity failures. It saves complete analyzer output, identity metadata and a passing
expectation report. Use a fresh output directory for each run to prevent stale evidence reuse.
`scripts/verify/tooling-tests.ps1` exercises process capture, invalid override rejection, diagnostic
path normalization and ten failure cases that must not be mistaken for successful negative tests.

The September 28 follow-up passes source/accepted-contract analysis with zero diagnostics and rejects
all eight marked invalid expressions. It retains the broad-intersection removal and closes the
numeric-key and narrow-function-input gaps exposed by the new tests. Local evidence is in
`.verification/contract-verification/accepted-final/` and `rejected-final/`. VoxelMMO's
`docs/todo/overnightPackageMigration.md` is the earlier handoff, not the current package verification
status. Further migration work follows the repository owner's individual instructions.

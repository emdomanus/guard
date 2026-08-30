--!strict

type GuardFn<T> = (value: unknown) -> T
type UnknownTable = { [unknown]: unknown }
type GuardModule = {
	string: GuardFn<string>,
	number: GuardFn<number>,
	boolean: GuardFn<boolean>,
	table: GuardFn<UnknownTable>,
	literal: <T>(T) -> GuardFn<T>,
	enum: <T>({ T }) -> GuardFn<T>,
	optional: <T>(GuardFn<T>) -> GuardFn<T?>,
	oneOf: (...GuardFn<unknown>) -> GuardFn<unknown>,
	byTag: <T>(string, { [string]: GuardFn<T> }) -> GuardFn<T>,
	all: (...GuardFn<unknown>) -> GuardFn<unknown>,
	map: <K, V>(GuardFn<K>, GuardFn<V>) -> GuardFn<{ [K]: V }>,
	array: <V>(GuardFn<V>) -> GuardFn<{ V }>,
	mapExcluding: <K, V>(GuardFn<K>, GuardFn<V>, { [unknown]: true }) -> GuardFn<{ [K]: V }>,
	property: <T, P>(P, GuardFn<T>) -> GuardFn<UnknownTable>,
	exactRecord: <T>({ [string]: GuardFn<unknown> }) -> GuardFn<T>,
	forbid: (...string) -> GuardFn<UnknownTable>,
	enumInSet: <T>({ [T]: unknown }) -> GuardFn<T>,
}

local requireFile = (require :: unknown) :: (string) -> GuardModule
local Guard = requireFile("../../src/guard/init.luau")

type TestCase = {
	name: string,
	run: () -> (),
}

local tests = {} :: { TestCase }

local function test(name: string, run: () -> ())
	table.insert(tests, {
		name = name,
		run = run,
	})
end

local function assertSame(actual: unknown, expected: unknown, message: string?)
	assert(rawequal(actual, expected), message or "Expected values to have identical identity")
end

local function assertEqual(actual: unknown, expected: unknown, message: string?)
	assert(actual == expected, message or `Expected {tostring(expected)}, got {tostring(actual)}`)
end

local function expectErrorContains(callback: () -> (), expected: string)
	local ok, resultOrError = pcall(function(): unknown
		callback()
		return nil
	end)
	assert(not ok, `Expected an error containing {string.format("%q", expected)}`)
	local message = tostring(resultOrError)
	assert(
		string.find(message, expected, 1, true) ~= nil,
		`Expected error containing {string.format("%q", expected)}, got: {message}`
	)
end

test("primitive, literal, and enum guards return their input", function()
	local text = "identity"
	assertSame(Guard.string(text), text)

	local token = table.freeze({ kind = "token" })
	assertSame(Guard.literal(token)(token), token)
	assertSame(Guard.enum({ token })(token), token)
	assertSame(Guard.enumInSet({ [token] = true })(token), token)
end)

test("enum snapshots its construction values", function()
	local values = { "alpha" }
	local guard = Guard.enum(values)

	values[1] = "beta"
	table.insert(values, "gamma")

	assertEqual(guard("alpha"), "alpha")
	expectErrorContains(function()
		guard("beta")
	end, "Guard.enum rejected beta")
	expectErrorContains(function()
		guard("gamma")
	end, "Guard.enum rejected gamma")
end)

test("enumInSet snapshots its construction set", function()
	local set: { [string]: unknown } = { alpha = true }
	local guard = Guard.enumInSet(set)

	set.alpha = nil
	set.beta = true

	assertEqual(guard("alpha"), "alpha")
	expectErrorContains(function()
		guard("beta")
	end, "Guard.enumInSet rejected beta")
end)

test("property validates frozen input without assigning", function()
	local nested = table.freeze({ name = "Ada" })
	local input = table.freeze({ profile = nested })
	local guard = Guard.property("profile", Guard.property("name", Guard.string))

	local result = guard(input)
	assertSame(result, input)
	assertSame(input.profile, nested)
end)

test("property rejects replacement without mutating input", function()
	local input = { score = "4" }
	local function coerceScore(_value: unknown): number
		return 4
	end

	expectErrorContains(function()
		Guard.property("score", coerceScore)(input)
	end, 'Guard.property field "score" returned a replacement')
	assertEqual(input.score, "4")
end)

test("map and mapExcluding validate original entries and preserve identity", function()
	local nested = table.freeze({ name = "Ada" })
	local input = table.freeze({ primary = nested })
	local nestedGuard = Guard.exactRecord({ name = Guard.string })

	local result = Guard.map(Guard.string, nestedGuard)(input)
	assertSame(result, input)
	assertSame(input.primary, nested)
	assertSame(Guard.mapExcluding(Guard.string, Guard.string, { primary = true })(input), input)
end)

test("mapExcluding snapshots its excluded keys", function()
	local excludedKeys: { [unknown]: true } = { ignored = true }
	local guard = Guard.mapExcluding(Guard.string, Guard.string, excludedKeys)

	excludedKeys.ignored = nil
	excludedKeys.added = true

	local input = table.freeze({ ignored = 42, kept = "valid" })
	assertSame(guard(input), input)
	expectErrorContains(function()
		guard({ ignored = 42, added = 42 })
	end, "Guard.mapExcluding value [added]")
end)

test("map rejects key and value replacement without cloning", function()
	local input = { score = 4 }
	local function replaceKey(_value: unknown): string
		return "replacement"
	end
	local function replaceValue(_value: unknown): number
		return 5
	end

	expectErrorContains(function()
		Guard.map(replaceKey, Guard.number)(input)
	end, "Guard.map key [score] returned a replacement")
	expectErrorContains(function()
		Guard.map(Guard.string, replaceValue)(input)
	end, "Guard.map value [score] returned a replacement")
	assertEqual(input.score, 4)
end)

test("array preserves table and element identity", function()
	local first = table.freeze({ name = "first" })
	local second = table.freeze({ name = "second" })
	local input = table.freeze({ first, second })
	local result = Guard.array(Guard.exactRecord({ name = Guard.string }))(input)

	assertSame(result, input)
	assertSame(input[1], first)
	assertSame(input[2], second)
end)

test("array retains sparse numeric-map acceptance", function()
	local sparse = table.freeze({ [1] = "first", [3] = "third" })
	assertSame(Guard.array(Guard.string)(sparse), sparse)
end)

test("exactRecord accepts required and optional fields and rejects exact-key violations", function()
	local guard = Guard.exactRecord({
		name = Guard.string,
		nickname = Guard.optional(Guard.string),
	})
	local requiredOnly = table.freeze({ name = "Ada" })
	local withOptional = table.freeze({ name = "Ada", nickname = "A" })

	assertSame(guard(requiredOnly), requiredOnly)
	assertSame(guard(withOptional), withOptional)
	expectErrorContains(function()
		guard({ nickname = "A" })
	end, 'Guard.exactRecord field "name"')
	expectErrorContains(function()
		guard({ name = "Ada", extra = true })
	end, 'Guard.exactRecord unexpected field "extra"')
end)

test("exactRecord snapshots its construction schema", function()
	local schema: { [string]: GuardFn<unknown> } = { name = Guard.string }
	local guard: GuardFn<UnknownTable> = Guard.exactRecord(schema)

	schema.name = Guard.number
	schema.extra = Guard.boolean

	local input = table.freeze({ name = "Ada" })
	assertSame(guard(input), input)
	expectErrorContains(function()
		guard({ name = 42 })
	end, "Guard.string expected string")
	expectErrorContains(function()
		guard({ name = "Ada", extra = true })
	end, 'Guard.exactRecord unexpected field "extra"')
end)

test(
	"nested exactRecord composition accepts frozen records and preserves nested identity",
	function()
		local profileGuard = Guard.exactRecord({ name = Guard.string })
		local rootGuard = Guard.exactRecord({
			profile = profileGuard,
			enabled = Guard.boolean,
			note = Guard.optional(Guard.string),
		})
		local profile = table.freeze({ name = "Ada" })
		local input = table.freeze({ profile = profile, enabled = true })

		local result = rootGuard(input)
		assertSame(result, input)
		assertSame(input.profile, profile)
	end
)

test("exactRecord rejects a replacement-returning child with field diagnostics", function()
	local originalNested = { value = 1 }
	local input = { nested = originalNested }
	local replacement = { value = 1 }
	local function replacingGuard(_value: unknown): UnknownTable
		return replacement
	end

	expectErrorContains(function()
		Guard.exactRecord({ nested = replacingGuard })(input)
	end, 'Guard.exactRecord field "nested" returned a replacement')
	assertSame(input.nested, originalNested)
	assert(not rawequal(input.nested, replacement), "Input nested table must remain unchanged")
end)

test("oneOf does not conceal replacement-returning successful children", function()
	local input = { value = 1 }
	local function replacementGuard(_value: unknown): UnknownTable
		return { value = 1 }
	end

	expectErrorContains(function()
		Guard.oneOf(replacementGuard, Guard.table)(input)
	end, "Guard.oneOf child #1 returned a replacement")
	assertSame(Guard.oneOf(Guard.string, Guard.table)(input), input)
end)

test("byTag preserves identity and rejects replacement arms", function()
	local input = table.freeze({ kind = "ready", value = 1 })
	local readyGuard = Guard.exactRecord({ kind = Guard.literal("ready"), value = Guard.number })
	local tagged = Guard.byTag("kind", { ready = readyGuard })
	assertSame(tagged(input), input)

	local function replacementArm(_value: unknown): UnknownTable
		return { kind = "ready", value = 1 }
	end
	expectErrorContains(function()
		Guard.byTag("kind", { ready = replacementArm })(input)
	end, 'Guard.byTag arm "ready" returned a replacement')
	expectErrorContains(function()
		Guard.byTag("kind", { ready = readyGuard })({ kind = "unknown", value = 1 })
	end, 'Guard.byTag unknown kind "unknown"')
end)

test("byTag snapshots its construction arms", function()
	local readyGuard: GuardFn<UnknownTable> = Guard.exactRecord({
		kind = Guard.literal("ready"),
		value = Guard.number,
	})
	local arms: { [string]: GuardFn<UnknownTable> } = { ready = readyGuard }
	local tagged = Guard.byTag("kind", arms)

	local function mutatedArm(_value: unknown): UnknownTable
		error("mutated arm should not run")
	end
	arms.ready = mutatedArm
	arms.other = Guard.table

	local input = table.freeze({ kind = "ready", value = 1 })
	assertSame(tagged(input), input)
	expectErrorContains(function()
		tagged({ kind = "other" })
	end, 'Guard.byTag unknown kind "other"')
end)

test("all runs every child against the original value and rejects replacement", function()
	local input = { value = 1 }
	local firstSeen: unknown = nil
	local secondSeen: unknown = nil
	local function first(value: unknown): UnknownTable
		firstSeen = value
		return Guard.table(value)
	end
	local function second(value: unknown): UnknownTable
		secondSeen = value
		return Guard.table(value)
	end

	assertSame(Guard.all(first, second)(input), input)
	assertSame(firstSeen, input)
	assertSame(secondSeen, input)

	local function replacement(_value: unknown): UnknownTable
		return {}
	end
	expectErrorContains(function()
		Guard.all(first, replacement, second)(input)
	end, "Guard.all child #2 returned a replacement")
end)

test("optional and forbid preserve identity and diagnostics remain useful", function()
	local input = table.freeze({ name = "Ada" })
	assertSame(Guard.optional(Guard.table)(input), input)
	assertEqual(Guard.optional(Guard.string)(nil), nil)
	assertSame(Guard.forbid("secret")(input), input)

	local function replacement(_value: unknown): UnknownTable
		return {}
	end
	expectErrorContains(function()
		Guard.optional(replacement)(input)
	end, "Guard.optional child returned a replacement")
	expectErrorContains(function()
		Guard.string(42)
	end, "Guard.string expected string, got number")
	expectErrorContains(function()
		Guard.forbid("secret")({ secret = true })
	end, 'Guard.forbid rejected field "secret"')
end)

local passed = 0
local failed = 0

for _, testCase in tests do
	local ok, resultOrError = pcall(function(): unknown
		testCase.run()
		return nil
	end)
	if ok then
		passed += 1
		print(`PASS: {testCase.name}`)
	else
		failed += 1
		print(`FAIL: {testCase.name}`)
		print(tostring(resultOrError))
	end
end

if failed > 0 then
	error(`Guard spec failed: {failed} failed`, 0)
end

print(`Guard spec: {passed} passed, {failed} failed`)

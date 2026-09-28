--!strict
--!optimize 2
--!native

-- Guards preserve identity. Child guards are contractually non-yielding, but Luau's yieldable
-- pcall can propagate a violating child's yield rather than enforce that contract.

export type GuardFn<T> = (value: unknown) -> T
export type UnknownTable = { [unknown]: unknown }
export type ExactRecordSchema = { [string]: GuardFn<unknown> }

export type OneOf =
	(<A>(GuardFn<A>) -> GuardFn<A>)
	& (<A, B>(GuardFn<A>, GuardFn<B>) -> GuardFn<A | B>)
	& (<A, B, C>(GuardFn<A>, GuardFn<B>, GuardFn<C>) -> GuardFn<A | B | C>)
	& (<A, B, C, D>(GuardFn<A>, GuardFn<B>, GuardFn<C>, GuardFn<D>) -> GuardFn<A | B | C | D>)
	& ((...GuardFn<unknown>) -> GuardFn<unknown>)

export type All =
	(<A>(GuardFn<A>) -> GuardFn<A>)
	& (<A, B>(GuardFn<A>, GuardFn<B>) -> GuardFn<A & B>)
	& (<A, B, C>(GuardFn<A>, GuardFn<B>, GuardFn<C>) -> GuardFn<A & B & C>)
	& (<A, B, C, D>(GuardFn<A>, GuardFn<B>, GuardFn<C>, GuardFn<D>) -> GuardFn<A & B & C & D>)
	& ((...GuardFn<unknown>) -> GuardFn<unknown>)

local function kindOf(value: unknown): string
	return typeof(value)
end

local function isIdentical(left: unknown, right: unknown): boolean
	if rawequal(left, right) then
		return true
	end

	-- NaN is the only primitive value that is not raw-equal to itself. Luau has no
	-- observable identity beyond its value for numbers, so two NaNs are equivalent here.
	return type(left) == "number" and type(right) == "number" and left ~= left and right ~= right
end

local function runChild<T>(context: string, guard: GuardFn<T>, value: unknown): T
	local ok, resultOrError = pcall(function(): unknown
		return guard(value)
	end)

	if not ok then
		error(`{context}: {tostring(resultOrError)}`, 3)
	end

	if not isIdentical(resultOrError, value) then
		error(`{context} returned a replacement; guards must return their original input`, 3)
	end

	return resultOrError :: T
end

local function stringGuard(value: unknown): string
	assert(type(value) == "string", `Guard.string expected string, got {kindOf(value)}`)
	return value
end

local function functionGuard(value: unknown): (...any) -> ...any
	assert(typeof(value) == "function", `Guard.fn expected function, got {kindOf(value)}`)
	return value :: (...any) -> ...any
end

local function color3Guard(value: unknown): Color3
	assert(typeof(value) == "Color3", `Guard.color3 expected Color3, got {kindOf(value)}`)
	return value :: Color3
end

local function numberGuard(value: unknown): number
	assert(type(value) == "number", `Guard.number expected number, got {kindOf(value)}`)
	return value
end

local function finiteGuard(value: unknown): number
	assert(type(value) == "number", `Guard.finite expected number, got {kindOf(value)}`)
	assert(
		value == value and value > -math.huge and value < math.huge,
		"Guard.finite expected a finite number"
	)
	return value
end

local function anyGuard(value: unknown): any
	return value
end

local function booleanGuard(value: unknown): boolean
	assert(type(value) == "boolean", `Guard.boolean expected boolean, got {kindOf(value)}`)
	return value
end

local function tableGuard(value: unknown): UnknownTable
	assert(type(value) == "table", `Guard.table expected table, got {kindOf(value)}`)
	return value :: UnknownTable
end

local function literal<T>(expected: T): GuardFn<T>
	return function(value: unknown): T
		assert(
			isIdentical(value, expected),
			`Guard.literal expected {tostring(expected)}, got {tostring(value)}`
		)
		return value :: T
	end
end

local function enumGuard<E>(values: { E }): GuardFn<E>
	local valueSnapshot = table.freeze(table.clone(values))
	local labels = {} :: { string }
	for _, candidate in valueSnapshot do
		table.insert(labels, tostring(candidate))
	end

	return function(value: unknown): E
		for _, candidate in valueSnapshot do
			if isIdentical(value, candidate) then
				return value :: E
			end
		end

		error(
			`Guard.enum rejected {tostring(value)} (expected one of: {table.concat(labels, ", ")})`,
			2
		)
	end
end

local function vector2Guard(value: unknown): Vector2
	assert(typeof(value) == "Vector2", `Guard.vector2 expected Vector2, got {kindOf(value)}`)
	return value :: Vector2
end

local function vector3Guard(value: unknown): Vector3
	assert(typeof(value) == "Vector3", `Guard.vector3 expected Vector3, got {kindOf(value)}`)
	return value :: Vector3
end

local function cframeGuard(value: unknown): CFrame
	assert(typeof(value) == "CFrame", `Guard.cframe expected CFrame, got {kindOf(value)}`)
	return value :: CFrame
end

local function tweenInfoGuard(value: unknown): TweenInfo
	assert(typeof(value) == "TweenInfo", `Guard.tweenInfo expected TweenInfo, got {kindOf(value)}`)
	return value :: TweenInfo
end

local function optional<T>(guard: GuardFn<T>): GuardFn<T | nil>
	return function(value: unknown): T | nil
		if value == nil then
			return nil
		end

		runChild("Guard.optional child", guard, value)
		return value :: T
	end
end

local function oneOfImplementation(...: GuardFn<unknown>): GuardFn<unknown>
	local guards = { ... }

	return function(value: unknown): unknown
		local failures = {} :: { string }

		for index, guard in guards do
			local ok, resultOrError = pcall(function(): unknown
				return guard(value)
			end)

			if ok then
				if not isIdentical(resultOrError, value) then
					error(
						`Guard.oneOf child #{index} returned a replacement; guards must return their original input`,
						2
					)
				end

				return value
			end

			table.insert(failures, `child #{index}: {tostring(resultOrError)}`)
		end

		local detail = if #failures == 0
			then "no guards were provided"
			else table.concat(failures, "; ")
		error(`Guard.oneOf value did not match any child ({detail})`, 2)
	end
end

local function byTag<T>(tagKey: string, arms: { [string]: GuardFn<T> }): GuardFn<T>
	local armSnapshot = table.freeze(table.clone(arms))

	return function(value: unknown): T
		assert(type(value) == "table", `Guard.byTag expected table, got {kindOf(value)}`)

		local record = value :: UnknownTable
		local tag = record[tagKey]
		local arm = if type(tag) == "string" then armSnapshot[tag] else nil
		if arm == nil then
			local validTags = {} :: { string }
			for validTag in armSnapshot do
				table.insert(validTags, validTag)
			end
			table.sort(validTags)
			error(
				`Guard.byTag unknown {tagKey} {string.format("%q", tostring(tag))} (expected: {table.concat(
					validTags,
					", "
				)})`,
				2
			)
		end

		assert(type(tag) == "string", "Guard.byTag selected an arm without a string tag")
		runChild(`Guard.byTag arm {string.format("%q", tag)}`, arm, value)
		return value :: T
	end
end

local function allImplementation(...: GuardFn<unknown>): GuardFn<unknown>
	local guards = { ... }

	return function(value: unknown): unknown
		for index, guard in guards do
			runChild(`Guard.all child #{index}`, guard, value)
		end

		return value
	end
end

local function map<K, V>(keyGuard: GuardFn<K>, valueGuard: GuardFn<V>): GuardFn<{ [K]: V }>
	return function(value: unknown): { [K]: V }
		assert(type(value) == "table", `Guard.map expected table, got {kindOf(value)}`)

		local record = value :: UnknownTable
		for rawKey, rawValue in record do
			runChild(`Guard.map key [{tostring(rawKey)}]`, keyGuard, rawKey)
			runChild(`Guard.map value [{tostring(rawKey)}]`, valueGuard, rawValue)
		end

		return value :: { [K]: V }
	end
end

local function array<V>(valueGuard: GuardFn<V>): GuardFn<{ V }>
	-- Array retains numeric-map semantics, including sparse numeric keys.
	return map(numberGuard, valueGuard) :: GuardFn<{ V }>
end

local function mapExcluding<K, V>(
	keyGuard: GuardFn<K>,
	valueGuard: GuardFn<V>,
	excludeKeys: { [unknown]: true }
): GuardFn<{ [K]: V }>
	local excludedKeySnapshot = table.freeze(table.clone(excludeKeys))

	return function(value: unknown): { [K]: V }
		assert(type(value) == "table", `Guard.mapExcluding expected table, got {kindOf(value)}`)

		local record = value :: UnknownTable
		for rawKey, rawValue in record do
			if excludedKeySnapshot[rawKey] then
				continue
			end

			runChild(`Guard.mapExcluding key [{tostring(rawKey)}]`, keyGuard, rawKey)
			runChild(`Guard.mapExcluding value [{tostring(rawKey)}]`, valueGuard, rawValue)
		end

		return value :: { [K]: V }
	end
end

local function property<T, P>(key: P, valueGuard: GuardFn<T>): GuardFn<{ [P]: T } & UnknownTable>
	return function(value: unknown): { [P]: T } & UnknownTable
		assert(type(value) == "table", `Guard.property expected table, got {kindOf(value)}`)

		local record = value :: UnknownTable
		local rawValue = record[key]
		runChild(`Guard.property field {string.format("%q", tostring(key))}`, valueGuard, rawValue)

		return value :: { [P]: T } & UnknownTable
	end
end

local function exactRecord<T>(schema: ExactRecordSchema): GuardFn<T>
	local schemaSnapshot = table.freeze(table.clone(schema))

	return function(value: unknown): T
		assert(type(value) == "table", `Guard.exactRecord expected table, got {kindOf(value)}`)

		local record = value :: UnknownTable
		for rawKey in record do
			if type(rawKey) ~= "string" or schemaSnapshot[rawKey] == nil then
				error(
					`Guard.exactRecord unexpected field {string.format("%q", tostring(rawKey))}`,
					2
				)
			end
		end

		for fieldName, fieldGuard in schemaSnapshot do
			local rawValue: unknown = rawget(record, fieldName)
			runChild(
				`Guard.exactRecord field {string.format("%q", fieldName)}`,
				fieldGuard,
				rawValue
			)
		end

		return value :: T
	end
end

local function forbid(...: string): GuardFn<UnknownTable>
	local forbiddenKeys = { ... }

	return function(value: unknown): UnknownTable
		assert(type(value) == "table", `Guard.forbid expected table, got {kindOf(value)}`)

		local record = value :: UnknownTable
		for _, key in forbiddenKeys do
			assert(record[key] == nil, `Guard.forbid rejected field {string.format("%q", key)}`)
		end

		return record
	end
end

local function enumInSet<E>(set: { [E]: unknown }): GuardFn<E>
	local setSnapshot = table.freeze(table.clone(set))

	return function(value: unknown): E
		assert(value ~= nil, "Guard.enumInSet expected a non-nil value")
		assert(setSnapshot[value :: E] ~= nil, `Guard.enumInSet rejected {tostring(value)}`)
		return value :: E
	end
end

return table.freeze({
	string = stringGuard,
	fn = functionGuard,
	color3 = color3Guard,
	number = numberGuard,
	finite = finiteGuard,
	any = anyGuard,
	boolean = booleanGuard,
	table = tableGuard,
	literal = literal,
	enum = enumGuard,
	vector2 = vector2Guard,
	vector3 = vector3Guard,
	cframe = cframeGuard,
	tweenInfo = tweenInfoGuard,
	optional = optional,
	oneOf = oneOfImplementation :: OneOf,
	byTag = byTag,
	all = allImplementation :: All,
	map = map,
	array = array,
	mapExcluding = mapExcluding,
	property = property,
	exactRecord = exactRecord,
	forbid = forbid,
	enumInSet = enumInSet,
})

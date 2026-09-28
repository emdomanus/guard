--!strict

export type GuardFn<T> = (value: unknown) -> T
export type UnknownTable = { [unknown]: unknown }
export type ExactRecordSchema = { [string]: GuardFn<unknown> }

export type OneOf =
	(() -> GuardFn<unknown>)
	& (<A>(GuardFn<A>) -> GuardFn<A>)
	& (<A, B>(GuardFn<A>, GuardFn<B>) -> GuardFn<A | B>)
	& (<A, B, C>(GuardFn<A>, GuardFn<B>, GuardFn<C>) -> GuardFn<A | B | C>)
	& (<A, B, C, D>(GuardFn<A>, GuardFn<B>, GuardFn<C>, GuardFn<D>) -> GuardFn<A | B | C | D>)
	& ((
		GuardFn<unknown>,
		GuardFn<unknown>,
		GuardFn<unknown>,
		GuardFn<unknown>,
		GuardFn<unknown>,
		...GuardFn<unknown>
	) -> GuardFn<unknown>)

export type All =
	(() -> GuardFn<unknown>)
	& (<A>(GuardFn<A>) -> GuardFn<A>)
	& (<A, B>(GuardFn<A>, GuardFn<B>) -> GuardFn<A & B>)
	& (<A, B, C>(GuardFn<A>, GuardFn<B>, GuardFn<C>) -> GuardFn<A & B & C>)
	& (<A, B, C, D>(GuardFn<A>, GuardFn<B>, GuardFn<C>, GuardFn<D>) -> GuardFn<A & B & C & D>)
	& ((
		GuardFn<unknown>,
		GuardFn<unknown>,
		GuardFn<unknown>,
		GuardFn<unknown>,
		GuardFn<unknown>,
		...GuardFn<unknown>
	) -> GuardFn<unknown>)

-- The schema determines the record: callers cannot invent an unrelated result type.
export type function RecordOf(schema)
	assert(schema:is("table"), "Guard.exactRecord requires a table schema")
	local record = types.newtable()
	for key, field in schema:properties() do
		local guard = field.read
		assert(guard and guard:is("function"), "Guard.exactRecord fields must be guards")
		local results = guard:returns()
		assert(results.head and results.head[1], "Guard.exactRecord guards must return a value")
		record:setproperty(key, results.head[1])
	end
	local indexer = schema:indexer()
	if indexer then
		local guard = indexer.readresult
		assert(guard:is("function"), "Guard.exactRecord indexed fields must be guards")
		local results = guard:returns()
		assert(results.head and results.head[1], "Guard.exactRecord guards must return a value")
		record:setindexer(indexer.index, results.head[1])
	end
	return record
end

export type function TaggedOf(arms)
	assert(arms:is("table"), "Guard.byTag requires an arms table")
	local result = types.never
	for _, field in arms:properties() do
		local guard = field.read
		assert(guard and guard:is("function"), "Guard.byTag arms must be guards")
		local returns = guard:returns()
		assert(returns.head and returns.head[1], "Guard.byTag arms must return a value")
		result = types.unionof(result, returns.head[1])
	end
	local indexer = arms:indexer()
	if indexer then
		local guard = indexer.readresult
		assert(guard:is("function"), "Guard.byTag indexed arms must be guards")
		local returns = guard:returns()
		assert(returns.head and returns.head[1], "Guard.byTag arms must return a value")
		result = types.unionof(result, returns.head[1])
	end
	return result
end

return {}

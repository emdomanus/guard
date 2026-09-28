--!strict

local Guard = require(script.utils.guard.shared.guard)
local GuardTypes = require(script.types.def.guard.shared.guard)

export type GuardFn<T> = GuardTypes.GuardFn<T>
export type ExactRecordSchema = GuardTypes.ExactRecordSchema
export type UnknownTable = GuardTypes.UnknownTable

return Guard

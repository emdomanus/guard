--!strict
--!optimize 2
--!native

local Guard = require(script.guard)

export type GuardFn<T> = Guard.GuardFn<T>
export type ExactRecordSchema = Guard.ExactRecordSchema
export type UnknownTable = Guard.UnknownTable

return Guard

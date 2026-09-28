--!strict
local Guard = require(game.ReplicatedStorage.packages.guard)

-- Each marked assignment must be rejected; the runner checks every line.
Guard.number = Guard.string -- EXPECT_ERROR
local wrongMap: Guard.GuardFn<{ [string]: string }> = Guard.map(Guard.string, Guard.number) -- EXPECT_ERROR
local wrongRecord: Guard.GuardFn<{ name: number }> = Guard.exactRecord({ name = Guard.string }) -- EXPECT_ERROR
local excluded = Guard.mapExcluding(Guard.string, Guard.number, { metadata = true })
local uncheckedExcluded: Guard.GuardFn<{ [string]: number }> = excluded -- EXPECT_ERROR
return { wrongMap, wrongRecord, uncheckedExcluded }

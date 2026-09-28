--!strict
local Guard = require(game.ReplicatedStorage.packages.guard)

local nonFunctionArms = { invalid = 42 }
Guard.byTag("kind", nonFunctionArms) -- EXPECT_ERROR

local numericArms = { [1] = Guard.table }
Guard.byTag("kind", numericArms) -- EXPECT_ERROR

local function needsNumber(value: number): number
	return value
end
local narrowArms = { invalid = needsNumber }
Guard.byTag("kind", narrowArms) -- EXPECT_ERROR

local indexedNarrowArms: { [string]: (number) -> number } = narrowArms
Guard.byTag("kind", indexedNarrowArms) -- EXPECT_ERROR

return {}

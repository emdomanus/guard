--!strict
-- Load the actual public entry and script-relative dependencies without generated files.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local root = {}
root.utils = { guard = { shared = {} } }
root.types = { def = { guard = { shared = {} } } }
local implementation = { Parent = root.utils.guard.shared }
local contracts = {}
root.utils.Parent = root
root.utils.guard.Parent = root.utils
root.utils.guard.shared.Parent = root.utils.guard
root.utils.guard.shared.guard = implementation
root.types.def.guard.shared.guard = contracts

local paths = {
	[root] = "src/init.luau",
	[implementation] = "src/utils/guard/shared/guard.luau",
	[contracts] = "src/types/def/guard/shared/guard.luau",
}
local loaded = {}
local function loadModule(module)
	if loaded[module] then
		return loaded[module]
	end
	local path = assert(paths[module], "Unexpected package dependency")
	loaded[module] = luau.load(fs.readFile(path), {
		debugName = "@" .. path,
		environment = { script = module, require = loadModule },
		injectGlobals = true,
	})()
	return loaded[module]
end

return loadModule(root)

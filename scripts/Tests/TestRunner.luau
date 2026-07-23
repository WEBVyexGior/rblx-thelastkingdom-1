--!strict
--[[
	TestRunner
	A tiny, dependency-free test runner for the pure domain modules. It exists
	instead of pulling in a full framework (TestEZ + Wally) because Phase 2 only
	needs to validate a handful of self-contained modules — keeping with the
	project rule to avoid unnecessary complexity. It is intentionally trivial to
	swap for TestEZ later; the spec files would barely change.

	How it works:
		- Every sibling ModuleScript named `<Name>.spec` returns a function that
		  receives a registrar `t` and registers cases via `t.test(name, fn)`.
		- `run()` requires each spec, runs its cases in isolation (pcall), and
		  prints a PASS/FAIL line per case plus a summary. A failing `assert`
		  inside a case marks it failed without aborting the rest.

	Run it from the Studio command bar (server context):
		require(game:GetService("TestService").Tests.TestRunner).run()

	Location: TestService.Tests.TestRunner
]]

local TestRunner = {}

-- The API each spec receives. `test` registers one named case.
export type Registrar = {
	test: (name: string, fn: () -> ()) -> (),
}

type Case = { name: string, fn: () -> () }

-- Sibling `*.spec` ModuleScripts, sorted for deterministic output.
local function collectSpecs(): { ModuleScript }
	local specs: { ModuleScript } = {}
	for _, child in script.Parent:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	return specs
end

-- Runs every spec and returns true only if all cases passed.
function TestRunner.run(): boolean
	local passed, failed = 0, 0

	for _, specModule in collectSpecs() do
		local cases: { Case } = {}
		local registrar: Registrar = {
			test = function(name: string, fn: () -> ())
				table.insert(cases, { name = name, fn = fn })
			end,
		}

		local okLoad, specFn = pcall(require, specModule)
		if not okLoad or type(specFn) ~= "function" then
			failed += 1
			warn(("[Tests] LOAD FAIL  %s — %s"):format(specModule.Name, tostring(specFn)))
			continue
		end

		specFn(registrar)

		for _, case in cases do
			-- `table.pack` keeps pcall's error value visible to the type-checker:
			-- pcall of a `() -> ()` case is statically typed to return only the
			-- success boolean, so the error is captured positionally instead.
			local result = table.pack(pcall(case.fn))
			if result[1] then
				passed += 1
				print(("[Tests] PASS  %s › %s"):format(specModule.Name, case.name))
			else
				failed += 1
				warn(("[Tests] FAIL  %s › %s — %s"):format(specModule.Name, case.name, tostring(result[2])))
			end
		end
	end

	print(("[Tests] %d passed, %d failed"):format(passed, failed))
	return failed == 0
end

return TestRunner

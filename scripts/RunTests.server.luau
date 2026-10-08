-- Runs all *.spec tests with Jest-lua when the test place is started with Run (F8).
-- Build the test place with:
--   rojo build test.project.json -o build/tests.rbxl
--
-- Current Studio versions block this path: Jest reads ModuleScript.Source, which only
-- plugin-level code may do ("lacking capability PluginOrOpenCloud"). In that case use
-- scripts/RunTestsCommandBar.luau from the Command Bar instead (see README > Tests).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jest = require(ReplicatedStorage.DevPackages.Jest)

local status, result = Jest.runCLI(ReplicatedStorage.Tests, {
	verbose = true,
	ci = false,
}, { ReplicatedStorage.Tests }):awaitStatus()

if status == "Rejected" then
	warn("[Animora tests] runner error:", result)
elseif result.results.numFailedTestSuites > 0 and result.results.numTotalTests == 0 then
	warn(
		"[Animora tests] no test could run from a Script. Stop the test, then paste "
			.. "scripts/RunTestsCommandBar.luau into the Command Bar and press Enter."
	)
elseif result.results.numFailedTests > 0 or result.results.numFailedTestSuites > 0 then
	warn(
		`[Animora tests] {result.results.numFailedTests} test(s) and {result.results.numFailedTestSuites} suite(s) failed`
	)
else
	print(`[Animora tests] all {result.results.numPassedTests} tests passed`)
end

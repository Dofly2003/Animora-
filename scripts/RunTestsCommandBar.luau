-- Runs all *.spec tests from Studio's Command Bar (paste this whole file, press Enter).
-- Open build/tests.rbxl first and stay in edit mode (do not press Run / Play).
--
-- Why the Command Bar: Jest-lua loads each spec by reading ModuleScript.Source, and
-- Studio only lets plugin-level code (the Command Bar, plugins) read Source. A Script
-- started with Run (F8) fails with "lacking capability PluginOrOpenCloud".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jest = require(ReplicatedStorage.DevPackages.Jest)
local status, result = Jest.runCLI(ReplicatedStorage.Tests, { verbose = true, ci = false }, { ReplicatedStorage.Tests })
	:awaitStatus()
if status == "Rejected" then
	warn("[Animora tests] runner error:", result)
elseif result.results.numFailedTests > 0 or result.results.numFailedTestSuites > 0 then
	warn(
		`[Animora tests] {result.results.numFailedTests} test(s) and {result.results.numFailedTestSuites} suite(s) failed, {result.results.numPassedTests} passed`
	)
else
	print(`[Animora tests] all {result.results.numPassedTests} tests passed`)
end

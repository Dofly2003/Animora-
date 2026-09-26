-- Runs all *.spec tests with Jest-lua. Build the test place with:
--   rojo build test.project.json -o build/tests.rbxl
-- then open it in Studio and press Run (F8). Results print to the Output window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jest = require(ReplicatedStorage.DevPackages.Jest)

local status, result = Jest.runCLI(ReplicatedStorage.Tests, {
	verbose = true,
	ci = false,
}, { ReplicatedStorage.Tests }):awaitStatus()

if status == "Rejected" then
	warn("[Animora tests] runner error:", result)
elseif result.results.numFailedTests > 0 then
	warn(`[Animora tests] {result.results.numFailedTests} test(s) failed`)
else
	print(`[Animora tests] all {result.results.numPassedTests} tests passed`)
end

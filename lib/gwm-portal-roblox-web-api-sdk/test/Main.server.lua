local tests = require(script.Parent.Tests)

local function runTests()
	local testsPassed = 0
	local testsTotal = 0
	print("Running tests...")
	for name, func in pairs(tests) do
		print(("==== %s ===="):format(name))
		local passed, err = pcall(func)
		testsTotal += 1
		if passed then
			print("PASSED")
			testsPassed += 1
		else
			print("FAILED")
			warn(err)
		end
	end
	print(("Tests passed: %i / %i"):format(testsPassed, testsTotal))
end

local function main()
	runTests()
end

main()

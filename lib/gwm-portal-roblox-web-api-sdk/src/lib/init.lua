local lib = {}

lib.Event = require(script.Event)
lib.Timer = require(script.Timer)
lib.Promise = require(script.Promise)

do
	local HttpService = game:GetService("HttpService")

	-- Creates a URL-encoded query string given a dict, eg:
	-- {username="Hello world"} ==> username=Hello%20world
	function lib.queryString(dict)
		local strs = {}
		for k, v in pairs(dict) do
			assert(typeof(k) == "string", ("key must be string, got %s: %s"):format(typeof(k), tostring(k)))
			assert(typeof(v) == "string", ("value must be string (key: %s), got %s: %s"):format(k, typeof(v), tostring(v)))
			table.insert(strs, ("%s=%s"):format(
				HttpService:UrlEncode(k),
				HttpService:UrlEncode(v)
			))
		end
		return table.concat(strs, "&")
	end

	function lib.jsonDecode(...)
		return HttpService:JSONDecode(...)
	end

	function lib.jsonEncode(...)
		return HttpService:JSONEncode(...)
	end

	function lib.generateGUID()
		return HttpService:GenerateGUID(false)
	end

	lib.requestAsyncPromise = lib.Promise.promisify(function (...)
		return HttpService:RequestAsync(...)
	end)
end

do
	function lib.isInt(n)
		return math.floor(n) == n
	end

	function lib.isPositiveInteger(n)
		return typeof(n) == "number" and n > 0 and lib.isInt(n)
	end
	lib.isRobloxPlaceId = lib.isPositiveInteger
	lib.isRobloxUserId = lib.isPositiveInteger

	function lib.assertRobloxPlaceId(robloxPlaceId)
		assert(lib.isRobloxPlaceId, "Invalid Roblox Place Id: " .. tostring(robloxPlaceId))
	end

	function lib.assertRobloxUserId(robloxUserId)
		assert(lib.isRobloxUserId, "Invalid Roblox User Id: " .. tostring(robloxUserId))
	end
end

return lib

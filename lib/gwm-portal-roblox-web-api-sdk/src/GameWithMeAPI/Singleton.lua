local GameWithMeAPI = require(script.Parent)

local GameWithMeAPISingleton = {}
GameWithMeAPISingleton.config = script
GameWithMeAPISingleton.ATTR_ENVIRONMENT = "Environment"
GameWithMeAPISingleton.ATTR_DEBUG_MAIN_TOKEN = "DebugMainToken"
GameWithMeAPISingleton.ATTR_DEBUG_URL_BASE = "DebugUrlBase"

GameWithMeAPISingleton.gameWithMeAPI = nil
GameWithMeAPISingleton.DEFAULT_ENVIRONMENT = "Production"

function GameWithMeAPISingleton:getDebugMainToken()
	return self.config:GetAttribute(GameWithMeAPISingleton.ATTR_DEBUG_MAIN_TOKEN)
end

function GameWithMeAPISingleton:getDebugUrlBase()
	return self.config:GetAttribute(GameWithMeAPISingleton.ATTR_DEBUG_URL_BASE)
end

function GameWithMeAPISingleton:getEnvironment()
	return self.config:GetAttribute(GameWithMeAPISingleton.ATTR_ENVIRONMENT) or GameWithMeAPISingleton.DEFAULT_ENVIRONMENT
end

function GameWithMeAPISingleton:main()
	if not self.gameWithMeAPI then
		local debugMainToken = self:getDebugMainToken()
		local debugUrlBase = self:getDebugUrlBase()
		if debugMainToken ~= nil and debugUrlBase ~= nil then
			assert(typeof(debugUrlBase) == "string", GameWithMeAPISingleton.ATTR_DEBUG_URL_BASE .. " should be a string")
			assert(typeof(debugMainToken) == "string", GameWithMeAPISingleton.ATTR_DEBUG_MAIN_TOKEN .. " should be a string")
			warn(("GameWithMeAPISingleton debug: using url base %s with main token %s - remember to remove this!"):format(
				debugUrlBase,
				debugMainToken
			))
			return GameWithMeAPI.new(debugUrlBase, debugMainToken)
		else
			local environment = GameWithMeAPISingleton:getEnvironment()
			self.gameWithMeAPI = GameWithMeAPI.loadEnvironment(environment):expect()
		end
	end
	return self.gameWithMeAPI
end

return GameWithMeAPISingleton:main()

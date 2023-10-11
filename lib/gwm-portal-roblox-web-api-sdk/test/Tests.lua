local ServerScriptService = game:GetService("ServerScriptService")
local GameWithMeAPI = require(ServerScriptService["GameWithMe Portal Roblox Web API SDK"].GameWithMeAPI.Singleton)

local tests = {}

function tests.GameWithMeAPI_getMainToken()
	assert(GameWithMeAPI:getMainToken(), "Tests require main token to run")
end

function tests.GameWithMeAPI_authenticate()
	assert(GameWithMeAPI:authenticate():len() > 0, "Auth should private non-empty token")
end

function tests.GameWithMeAPI_getUpComingEvents()
	assert(#GameWithMeAPI:getUpcomingEvents():getRecordObjects() > 0, "There should be at least one upcoming event")
end

function tests.GameWithMeAPI_isUserRegisteredForEvent()
	local eventId = "4d9e94b6-a923-4adf-99af-a9b4c8a690ae"
	local robloxUserId = 269323
	assert(
		GameWithMeAPI:isUserRegisteredForEvent(robloxUserId, eventId),
		("Roblox user %i should be registered for event ID %s"):format(
			robloxUserId,
			eventId
		)
	)
end

function tests.GameWithMeAPI_hasUserCompletedChallenge()
	local challengeId = "d9e99a22-b2db-4130-bf19-147b5c76a84e"
	local robloxUserId = 269323
	assert(
		GameWithMeAPI:hasUserCompletedChallenge(robloxUserId, challengeId),
		("Roblox user %i should have completed challenge %s"):format(
			robloxUserId,
			challengeId
		)
	)
end

return tests

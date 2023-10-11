local Players = game:GetService("Players")

local lib = require(script.Parent.Parent:WaitForChild("lib"))

local ChallengeStatusResult = {}
ChallengeStatusResult.__index = ChallengeStatusResult

function ChallengeStatusResult.new(challengeId, robloxUserId, payload)
	assert(typeof(challengeId) == "string" and challengeId:len() > 0, "challengeId must be nonempty string")
	lib.assertRobloxUserId(robloxUserId)
	assert(typeof(payload) == "table", "payload must be a table")
	assert(typeof(payload["completed"]) == "boolean", "payload must include boolean \"completed\"")
	local self = setmetatable({
		challengeId = challengeId;
		robloxUserId = robloxUserId;
		player = nil;
		
		payload = payload;
		completed = payload["completed"];
	}, ChallengeStatusResult)
	return self
end

function ChallengeStatusResult:findPlayer()
	if not self.player then
		for _, player in pairs(Players:GetPlayers()) do
			if player.UserId == self.robloxUserId then
				self.player = player
				break
			end
		end
	end
	return self.player
end

function ChallengeStatusResult:isCompleted()
	return self.completed
end

return ChallengeStatusResult

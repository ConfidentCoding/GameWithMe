local Players = game:GetService("Players")

local UserStatusResult = {}
UserStatusResult.__index = UserStatusResult

function UserStatusResult.new(event, robloxUserId, payload)
	assert(event, "event expected")
	assert(typeof(robloxUserId) == "number" and robloxUserId > 0 and math.floor(robloxUserId) == robloxUserId, "robloxUserId positive integer")
	assert(typeof(payload) == "table", "payload must be a table")
	assert(typeof(payload["registered"]) == "boolean", "payload must include boolean \"registered\"")
	assert(typeof(payload["verified"]) == "boolean", "payload must include boolean \"verified\"")
	local self = setmetatable({
		event = event;
		robloxUserId = robloxUserId;
		
		payload = payload;
		registered = payload["registered"];
		verified = payload["verified"];
	}, UserStatusResult)
	self.player = nil;
	return self
end

function UserStatusResult:findPlayer()
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

function UserStatusResult:isRegistered()
	return self.registered
end

function UserStatusResult:isVerified()
	return self.verified
end

return UserStatusResult

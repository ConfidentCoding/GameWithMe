local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local lib = require(script.Parent.Parent:WaitForChild("lib"))
local Promise = lib.Promise
local Timer = lib.Timer

local getUserInfosByUserIdsAsyncPromise = Promise.promisify(function (...)
	return UserService:GetUserInfosByUserIdsAsync(...)
end)

local GameWithMeEvent = {}
GameWithMeEvent.__index = GameWithMeEvent

GameWithMeEvent.EP_USER_STATUS = "/user-status"
GameWithMeEvent.EP_TELEPORT_DETAILS = "/teleport-details"

function GameWithMeEvent.new(api, payload)
	local self = setmetatable({
		api = nil;
		payload = nil;
	}, GameWithMeEvent)

	self.api = api
	self.payload = payload
		
	self.id = assert(payload["id"], "id expected")
	self.userId = assert(payload["userId"], "userId expected")
	self.communityId = payload["communityId"]
	self.feedItemId = payload["feedItemId"]
	-- Note: timestamps are in milliseconds, convert to seconds for os.time compatibility
	self.eventTimestamp = assert(payload["eventTimestamp"], "eventTimestamp expected") / 1000
	self.endsAt = assert(payload["endsAt"], "endsAt expected") / 1000
	self.description = assert(payload["description"], "description expected")
	-- self.instructions = assert(payload["instructions"], "instructions expected")
	self.instructions = ""
	self.featured = assert(typeof(payload["featured"]) ~= nil, "featured expected") or payload["featured"]
	self.numberOfRegisteredUsers = assert(payload["numberOfRegisteredUsers"], "numberOfRegisteredUsers expected")
	self.gameType = assert(payload["gameType"], "gameType expected")
	
	-- TODO: add place ID and private server access code fields (do not replicate)
	self.placeId = payload["metadata"] and payload["metadata"]["placeId"]
	self.privateServerAccessCode = payload["metadata"] and payload["metadata"]["serverAccessCode"]
	self.robloxUserId = tonumber(payload["robloxUserId"])
	self.hasTeleportData = (self.placeId and self.privateServerAccessCode) and true or false 
	

	return self
end

function GameWithMeEvent:getId()
	return self.id
end

function GameWithMeEvent:__tostring()
	return ("<GameWithMeEvent:%s %s %s>"):format(
		self:getId(),
		self:getHostUserId(),
		self:getShortDescription()
	)
end

function GameWithMeEvent:getUrlBase()
	return self.api:getUrlBase() .. "/" .. self:getId()
end

function GameWithMeEvent:isFeatured()
	return self.featured
end

function GameWithMeEvent:getHostUserId()
	return self.robloxUserId
end

function GameWithMeEvent:getHostUserInfoAsync()
	local robloxUserId = self:getHostUserId()
	return getUserInfosByUserIdsAsyncPromise({self.robloxUserId}):andThen(function (result)
		for _, userInfo in pairs(result) do
			if userInfo["Id"] == robloxUserId then
				return Promise.resolve(userInfo)
			end
		end
		return Promise.reject("Could not get host user info")
	end)
end

function GameWithMeEvent:getHostUserInfo(...)
	return GameWithMeEvent:getHostUserInfoAsync(...):expect()
end

function GameWithMeEvent:getHostUsernameAsync()
	return self:getHostUserInfoAsync():andThen(function (userInfo)
		return Promise.resolve(assert(userInfo["Username"], "Username expected"))
	end)
end

function GameWithMeEvent:getHostUsername()
	return self:getHostUsernameAsync():expect()
end

function GameWithMeEvent:getHostDisplayNameAsync()
	return self:getHostUserInfoAsync():andThen(function (userInfo)
		return Promise.resolve(assert(userInfo["DisplayName"], "DisplayName expected"))
	end)
end

function GameWithMeEvent:getHostDisplayName()
	return self:getHostDisplayNameAsync():expect()
end

function GameWithMeEvent:getDescription()
	return self.description
end

function GameWithMeEvent:getShortDescription()
	local desc = self:getDescription() or ""
	local s, _e = desc:find("[\n\r]+")
	if s then
		return desc:sub(1, s - 1)
	else
		return desc
	end
end

function GameWithMeEvent:getInstructions()
	return self.instructions
end

function GameWithMeEvent:getNumberOfRegisteredUsers()
	return self.numberOfRegisteredUsers
end

function GameWithMeEvent:isRegistered()
	return self.isRegistered
end

function GameWithMeEvent:isEventOngoing()
	local now = os.time()
	return self.eventTimestamp < now and now < self.endsAt
end

function GameWithMeEvent:isEventInFuture()
	local now = os.time()
	return self.eventTimestamp > now
end

function GameWithMeEvent:getStartTimer()
	if self._startTimer then
		return self._startTimer
	end
	local now = os.time()
	local timeRemaining = self.eventTimestamp - now 
	assert(timeRemaining > 0, "Event has already started")
	local timer = Timer.new()
	timer:start(timeRemaining)
	self._startTimer = timer
	return self._startTimer
end

function GameWithMeEvent:getEndTimer()
	if self._endTimer then
		return self._endTimer
	end
	local now = os.time()
	local timeRemaining = self.endsAt - now 
	assert(timeRemaining > 0, "Event has already started")
	local timer = Timer.new()
	timer:start(timeRemaining)
	self._endTimer = timer
	return self._endTimer
end

function GameWithMeEvent:timeRemaining()
	return self.endsAt - os.time()
end

function GameWithMeEvent:isHost(player)
	return self.robloxUserId == player.UserId
end

do -- User event registration status
	function GameWithMeEvent:isUserRegisteredAsync(robloxUserId)
		lib.assertRobloxUserId(robloxUserId)
		assert(RunService:IsServer())
		return self.api:isUserRegisteredForEventAsync(robloxUserId, self:getId())
	end
	
	function GameWithMeEvent:isUserRegistered(...)
		return self:isUserRegisteredAsync(...):expect()
	end
end

function GameWithMeEvent:hasTeleportData()
	return self.hasTeleportData
end

return GameWithMeEvent

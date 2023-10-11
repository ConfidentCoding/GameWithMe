--[[

GameWithMe Web API

]]

local RunService = game:GetService("RunService")

local lib = require(script.Parent:WaitForChild("lib"))
local Promise = lib.Promise

local GameWithMeAPI = {}
GameWithMeAPI.__index = GameWithMeAPI
GameWithMeAPI.VERSION = "1.2.0"

-- ==== Modules ====

GameWithMeAPI.Promise = Promise
GameWithMeAPI.GameWithMeEvent = require(script:WaitForChild("GameWithMeEvent"))
GameWithMeAPI.Pagination = require(script:WaitForChild("Pagination"))
GameWithMeAPI.UserStatusResult = require(script:WaitForChild("UserStatusResult"))
GameWithMeAPI.ChallengeStatusResult = require(script:WaitForChild("ChallengeStatusResult"))

-- ==== Defaults ====

-- Duration in seconds that the JWT returned from the /authenticate endpoint can be considered valid
GameWithMeAPI.DEFAULT_JWT_TIMEOUT = 30

-- ==== Environments ====

GameWithMeAPI.GROUP_ID = 12478861
GameWithMeAPI.Environments = {
	["Production"] = {
		urlBase = "https://roblox-api.gamewithme.co";
		mainTokenAssetId = 13265550921;
	};
	["Staging"] = {
		urlBase = "https://1p637xu82l.execute-api.eu-west-1.amazonaws.com/staging";
		mainTokenAssetId = 13265550921;
	};
}

-- ==== Endpoints ====

GameWithMeAPI.EP_AUTHENTICATE = "/authenticate"
GameWithMeAPI.EP_UPCOMING_EVENTS = "/upcoming"
GameWithMeAPI.EP_CHALLENGE_STATUS = "/challenge-status"
GameWithMeAPI.EP_EVENT_SETUP = "/event-setup"

-- ==== Errors ====

-- Endpoint returned a non-200 response.
GameWithMeAPI.ERR_STATUS_CODE = "ErrStatusCode"

-- Endpoint did not return valid JSON
GameWithMeAPI.ERR_JSON_PARSE = "ErrJsonParse"

-- Provided Roblox user ID did not have a matching GameWithMe user
GameWithMeAPI.ERR_GameWithMe_USER_NOT_FOUND = "ErrGameWithMeUserNotFound"

-- No event has the provided setup code
GameWithMeAPI.ERR_SETUP_CODE_INVALID = "ErrSetupCode"
GameWithMeAPI.ERR_NO_MATCHING_EVENT = "ErrNoMatchingEvent"

-- Endpoint had a malformed response (missing JSON keys)
GameWithMeAPI.ERR_BAD_RESPONSE = "ErrBadResponse"

function GameWithMeAPI.loadEnvironment(name)
	assert(typeof(name) == "string", "name should be a string")
	local environment = assert(GameWithMeAPI.Environments[name], "No such environment: " .. name)
	local urlBase = assert(environment.urlBase, "Environment missing urlBase")
	local useMainToken = GameWithMeAPI.isOfficial()
	if useMainToken then
		return Promise.new(function (resolve, _reject, _onCancel)
			resolve(require(assert(environment.mainTokenAssetId, "Environment missing mainTokenAssetId")))
		end):andThen(function (mainToken)
			local api = GameWithMeAPI.new(urlBase, mainToken)
			api._environment = name
			return Promise.resolve(api)
		end)
	else
		local api = GameWithMeAPI.new(urlBase, nil)
		api._environment = name
		return Promise.resolve(api)
	end
end

function GameWithMeAPI.isOfficial()
	return game.CreatorType == Enum.CreatorType.Group and game.CreatorId == GameWithMeAPI.GROUP_ID
end

function GameWithMeAPI.production()
	return GameWithMeAPI.loadEnvironment("Production")
end

function GameWithMeAPI.staging()
	return GameWithMeAPI.loadEnvironment("Staging")
end

function GameWithMeAPI.new(urlBase, mainToken)
	assert(typeof(urlBase) == "string", "urlBase should be a string")
	--assert(typeof(mainToken) == "string")
	local self = setmetatable({
		_environment = "Unknown";
		-- Protocol and hostname without trailing slash of request URLs
		_urlBase = urlBase;
		-- Token to provide the /authenticate endpoint
		_mainToken = mainToken;
		-- JWT returned by the /authenticate endpoint
		_jwt = nil;
		-- Timestamp (os.time()) that the JWT was received
		_jwtTimestamp = nil;
	}, GameWithMeAPI)
	if self._mainToken then
		self:authenticateAsync(true)
	end
	return self
end

function GameWithMeAPI:getUrlBase()
	return self._urlBase
end

function GameWithMeAPI:getMainToken()
	return self._mainToken
end

function GameWithMeAPI:getEnvironment()
	return self._environment
end

do -- Authenticate and JWT methods
	function GameWithMeAPI.getJWTTimeout()
		return GameWithMeAPI.DEFAULT_JWT_TIMEOUT
	end

	--- Confidence check for JWT value
	function GameWithMeAPI.isJWT(value)
		return typeof(value) == "string"
	end
	
	function GameWithMeAPI:getAuthenticateEndpoint()
		return self:getUrlBase() .. GameWithMeAPI.EP_AUTHENTICATE
	end

	function GameWithMeAPI:isJWTValid()
		local timeout = GameWithMeAPI.getJWTTimeout()
		return assert(self._jwtTimestamp, "JWT Timestamp missing") + timeout > os.time()
	end

	function GameWithMeAPI:isJWTAuthenticated()
		return self._jwt and self:isJWTValid()
	end
	
	function GameWithMeAPI:getAuthorizationHeader()
		return ("Bearer %s"):format(self._jwt)
	end
	
	function GameWithMeAPI:getHeaders(includeAuth)
		local headers = {}
		if includeAuth then
			headers["Authorization"] = self:getAuthorizationHeader();
		end
		return headers
	end

	function GameWithMeAPI:authenticateAsync(override)
		-- If the JWT is still good, then this is a no-op.
		if self:isJWTAuthenticated() and not override then return Promise.resolve(self._jwt) end
		
		-- Use an existing auth promise if it is still pending. 
		if self._authPromise then return self._authPromise end
		
		local mainToken = self:getMainToken()
		assert(typeof(mainToken) == "string", "Main token required for authentication")
		
		-- Build request data to send to HttpService:RequestAsync 
		-- https://developer.roblox.com/en-us/api-reference/function/HttpService/RequestAsync
		local requestData = {
			["Url"] = self:getAuthenticateEndpoint();
			["Headers"] = {
				["Authorization"] = "Bearer " .. mainToken
			};
			["Method"] = "GET";
		}
		
		-- Build promise
		local promise = lib.requestAsyncPromise(requestData)
		:andThen(function (responseData)
			-- Must have received a 200 OK
			if responseData["StatusCode"] ~= 200 then
				warn("GameWithMeAPI auth failed")
				return Promise.reject(GameWithMeAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
			end
			
			-- Check for existence of string "token" key in response
			local payload = lib.jsonDecode(responseData["Body"])
			local token = payload["token"]
			if GameWithMeAPI.isJWT(token) then
				self._jwt = token
				self._jwtTimestamp = os.time()
				return Promise.resolve(token)
			else
				return Promise.reject(GameWithMeAPI.ERR_BAD_RESPONSE)
			end
		end)
		--:catch(self.handleAuthFailure)
		
		-- Remember the promise so that if something else calls :authenticateAsync(), it uses
		-- the in-progress promise we just built. When it resolves, forget about it.
		self._authPromise = promise
		promise:finally(function ()
			self._authPromise = nil
		end)
		return promise
	end

	function GameWithMeAPI:authenticate(...)
		return self:authenticateAsync(...):expect()
	end
end

do -- Events
	function GameWithMeAPI:getUpcomingEventsEndpoint()
		return self:getUrlBase() .. GameWithMeAPI.EP_UPCOMING_EVENTS
	end
	
	function GameWithMeAPI:getUpcomingEventsAsync()
		return self:authenticateAsync():andThen(function (_jwt)
			local requestData = {
				["Url"] = self:getUpcomingEventsEndpoint();
				["Headers"] = self:getHeaders(true);
				["Method"] = "GET";
			}
			return lib.requestAsyncPromise(requestData):andThen(function (responseData)
				-- Must have received a 200 OK
				if responseData["StatusCode"] ~= 200 then
					return Promise.reject(GameWithMeAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
				end

				local payload = lib.jsonDecode(responseData["Body"])
				return Promise.resolve(GameWithMeAPI.Pagination.new(self, GameWithMeAPI.GameWithMeEvent.new, payload))
			end)
		end)
	end

	function GameWithMeAPI:getUpcomingEvents(...)
		return self:getUpcomingEventsAsync(...):expect()
	end

	do -- User event registration status
		function GameWithMeAPI:getUserStatusEndpoint(eventId)
			return self:getUrlBase() .. "/" .. eventId .. GameWithMeAPI.GameWithMeEvent.EP_USER_STATUS
		end

		function GameWithMeAPI:getUserStatusForEventAsync(robloxUserId, eventId)
			assert(lib.isRobloxUserId(robloxUserId), "Invalid Roblox User Id")
			assert(RunService:IsServer())
			return self:authenticateAsync():andThen(function ()
				local requestData = {
					["Url"] = self:getUserStatusEndpoint(eventId) .. "?" .. lib.queryString{userId=tostring(robloxUserId)};
					["Headers"] = self:getHeaders(true);
					["Method"] = "GET";
				}
				
				return lib.requestAsyncPromise(requestData):andThen(function (responseData)
					-- Must have received a 200 OK
					if responseData["StatusCode"] ~= 200 then
						local success, payload = lib.jsonDecode(responseData["Body"])
						if success and typeof(payload) == "table" then
							warn(payload)
						end
						return Promise.reject(self.ERR_STATUS_CODE .. responseData["StatusCode"])
					end

					local payload = lib.jsonDecode(responseData["Body"])
					return Promise.resolve(GameWithMeAPI.UserStatusResult.new(self, robloxUserId, payload))
				end)
			end)
		end

		function GameWithMeAPI:getUserStatusForEvent(...)
			return self:getUserStatusForEventAsync(...):expect()
		end

		function GameWithMeAPI:isUserRegisteredForEventAsync(robloxUserId, eventId)
			return self:getUserStatusForEventAsync(robloxUserId, eventId):andThen(function (userStatusResult)
				return Promise.resolve(userStatusResult:isRegistered())
			end, function (err)
				warn(tostring(err))
				return Promise.resolve(nil)
			end)
		end

		function GameWithMeAPI:isUserRegisteredForEvent(...)
			return self:isUserRegisteredForEventAsync(...):expect()
		end
	end
	
	do  -- In-app challenges
		function GameWithMeAPI:getChallengeStatusEndpoint(challengeId)
			assert(typeof(challengeId) == "string", "challengeId should be a string")
			return self:getUrlBase() .. "/" .. challengeId .. GameWithMeAPI.EP_CHALLENGE_STATUS
		end

		function GameWithMeAPI:getChallengeStatusForUserAsync(challengeId, robloxUserId)
			assert(typeof(challengeId) == "string" and challengeId:len() > 0, "challengeId should be a nonempty string")
			return self:authenticateAsync():andThen(function ()
				local requestData = {
					["Url"] = self:getChallengeStatusEndpoint(challengeId) .. "?" .. lib.queryString{userId=tostring(robloxUserId)};
					["Headers"] = self:getHeaders(true);
					["Method"] = "GET";
					--["Body"] = nil;
				}
				return lib.requestAsyncPromise(requestData):andThen(function (responseData)
					-- Must have received a 200 OK
					if responseData["StatusCode"] == 404 then
						return Promise.reject(GameWithMeAPI.ERR_GameWithMe_USER_NOT_FOUND)
					elseif responseData["StatusCode"] ~= 200 then
						--local success, payload = lib.jsonDecode(responseData["Body"])
						return Promise.reject(self.ERR_STATUS_CODE .. responseData["StatusCode"])
					end

					local payload = lib.jsonDecode(responseData["Body"])
					return Promise.resolve(GameWithMeAPI.ChallengeStatusResult.new(challengeId, robloxUserId, payload))
				end)
			end)
		end

		function GameWithMeAPI:getChallengeStatusForUser(...)
			return self:getChallengeStatusForUserAsync(...):expect()
		end

		function GameWithMeAPI:hasUserCompletedChallengeAsync(robloxUserId, challengeId)
			assert(RunService:IsServer())
			return self:getChallengeStatusForUserAsync(challengeId, robloxUserId):andThen(function (challengeStatusResult)
				print(robloxUserId, "Challenge status", challengeStatusResult:isCompleted())
				return Promise.resolve(challengeStatusResult:isCompleted())
			end, function (err)
				warn(tostring(err))
				return Promise.resolve(nil)
			end)
		end

		function GameWithMeAPI:hasUserCompletedChallenge(...)
			return self:hasUserCompletedChallengeAsync(...):expect()
		end
	end
	
	do -- Event host module API
		local function isSetupCodeValid(setupCode)
			return typeof(setupCode) == "string" and setupCode:len() >= 6
		end
		
		function GameWithMeAPI:getEventIdBySetupCodeAsync(setupCode)
			assert(isSetupCodeValid(setupCode))
			local requestData = {
				["Url"] = self:getUrlBase() .. GameWithMeAPI.EP_EVENT_SETUP .. "?" .. lib.queryString{setupCode=setupCode};
				["Method"] = "GET";
				["Headers"] = self:getHeaders(false);
			}
			return lib.requestAsyncPromise(requestData):andThen(function (responseData)
				local payload = lib.jsonDecode(responseData["Body"])
				assert(payload, GameWithMeAPI.ERR_JSON_PARSE)
				if responseData["StatusCode"] == 200 then
					local eventId = payload["id"]
					assert(typeof(eventId) == "string" and eventId:len() > 0, "eventId should be a nonempty string")
					return Promise.resolve(eventId)
				elseif responseData["StatusCode"] == 400 then
					warn(table.concat(payload["message"],"\n"))
					return Promise.reject(GameWithMeAPI.ERR_SETUP_CODE_INVALID)
				elseif responseData["StatusCode"] == 404 then
					return Promise.reject(GameWithMeAPI.ERR_NO_MATCHING_EVENT)
				else
					return Promise.reject(GameWithMeAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
				end
			end)
		end

		function GameWithMeAPI:getEventIdBySetupCode(...)
			return self:getEventIdBySetupCodeAsync(...):expect()
		end

		function GameWithMeAPI:setTeleportDetailsForEventAsync(eventId, setupCode, placeId, privateServerId, privateServerAccessCode)
			assert(typeof(eventId) == "string" and eventId:len() > 0, "eventId should be a nonempty string")
			assert(isSetupCodeValid(setupCode), "valid setup code expected, got " .. tostring(setupCode))
			assert(typeof(placeId) == "number" and math.floor(placeId) == placeId and placeId > 0, "placeId should be valid")
			assert(typeof(privateServerAccessCode) == "string" and privateServerAccessCode:len() > 0, "privateServerAccessCode should be a nonempty string")
			local requestPayload = {
				["setupCode"] = setupCode;
				["placeId"] = placeId;
				["serverId"] = privateServerId;
				["serverAccessCode"] = privateServerAccessCode;
			}
			local headers = self:getHeaders(false)
			headers["Content-Type"] = "application/json"
			local requestData = {
				["Method"] = "PATCH";
				["Url"] = self:getUrlBase() .. "/" .. eventId .. GameWithMeAPI.GameWithMeEvent.EP_TELEPORT_DETAILS;
				["Headers"] = headers;
				["Body"] = lib.jsonEncode(requestPayload);
			}
			return lib.requestAsyncPromise(requestData):andThen(function (responseData)
				if responseData["StatusCode"] == 200 then
					return Promise.resolve(true)
				else
					warn("Failed to set event teleport details of event", setupCode, eventId, responseData["Body"])
					return Promise.reject(GameWithMeAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
				end
			end)
		end

		function GameWithMeAPI:setTeleportDetailsForEvent(...)
			return self:setTeleportDetailsForEventAsync(...):expect()
		end
	end
end

return GameWithMeAPI

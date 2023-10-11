local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")
local Chat = game:GetService("Chat")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Promise = require(
	script
	:WaitForChild("Client")
	:WaitForChild("lib")
	:WaitForChild("Promise")
)

local GameWithMeAPI = require(
	script
	:WaitForChild("lib")
	:WaitForChild("GameWithMe Portal Roblox Web API SDK")
	:WaitForChild("GameWithMeAPI")
	:WaitForChild("Singleton")
)

local GameWithMeConnect = {}
GameWithMeConnect.__index = GameWithMeConnect
GameWithMeConnect.VERSION = "1.4.0"
GameWithMeConnect.GameWithMeAPI = GameWithMeAPI
GameWithMeConnect.Promise = Promise
GameWithMeConnect.DS_PREFIX = "GameWithMe"
GameWithMeConnect.DS_EVENT_ID = GameWithMeConnect.DS_PREFIX .. "EventId" -- "GameWithMeEventId"
GameWithMeConnect.DS_TELEPORT_DETAILS = GameWithMeConnect.DS_PREFIX .. "TeleportDetails" -- "GameWithMeTeleportDetails"
GameWithMeConnect.DS_SCOPE = nil

GameWithMeConnect.NO_EVENT = ""
GameWithMeConnect.EVENT_UNKNOWN = nil

GameWithMeConnect.config = script
GameWithMeConnect.ATTR_DEBUG_MODE = "DebugMode"
GameWithMeConnect.ATTR_PRIVATE_SERVER_ID_OVERRIDE = "PrivateServerIdOverride"

-- A special setup code which can be used to set up a mock GameWithMe event,
-- whose teleport details are NOT sent to GameWithMe for use in the portal.
GameWithMeConnect.MOCK_EVENT_SETUP_CODE = "000000"

-- The SuperAwesomeGaming group, who authors the GameWithMe Portal.
GameWithMeConnect.SA_GROUP_ID = 4337180 --12478861

-- The minimum rank in the group identified by GROUP_ID which should be
-- considered an admin who can test event teleportaion using TEST_SETUP_CODE
GameWithMeConnect.SA_GROUP_MIN_RANK = 254

-- If this universe is owned by a group, this is the minimum rank required
-- in order to allow test event teleportation using TEST_SETUP_CODE
GameWithMeConnect.GROUP_MIN_RANK = 255

-- Print wrapper
local print_ = print
local function print(...)
	if GameWithMeConnect:isDebugMode() then
		print_("GameWithMeConnect", ...)
	end
end

-- Warn wrapper
local warn_ = warn
local function warn(...)
	warn_("GameWithMeConnect", ...)
end

function GameWithMeConnect:isDebugMode()
	return self.config:GetAttribute(self.ATTR_DEBUG_MODE) or RunService:IsStudio()
end

function GameWithMeConnect:setDebugMode(isDebugMode)
	assert(typeof(isDebugMode) == "boolean", "boolean expected")
	return self.config:SetAttribute(self.ATTR_DEBUG_MODE, isDebugMode)
end

function GameWithMeConnect:getCurrentPrivateServerId()
	local privateServerId = game.PrivateServerId
	if RunService:IsStudio() then
		local privateServerIdOverride = self.config:GetAttribute(self.ATTR_PRIVATE_SERVER_ID_OVERRIDE) or ""
		if privateServerIdOverride then
			warn("PrivateServerId override: " .. privateServerIdOverride)
		end
		privateServerId = privateServerIdOverride
	end
	return privateServerId
end

function GameWithMeConnect:overridePrivateServerId(privateServerId)
	assert(typeof(privateServerId) == "string" or typeof(privateServerId) == "nil", "string or nil expected")
	self.config:SetAttribute(self.ATTR_PRIVATE_SERVER_ID_OVERRIDE, privateServerId)
	print("PrivateServerId override set to " .. (privateServerId or "nil"))
end

function GameWithMeConnect.new()
	local self = setmetatable({
		chatModuleInjected = false;
		clientContent = script.Client;
		starterPlayerScripts = script.StarterPlayerScripts;
	}, GameWithMeConnect)
	self.remotes = self.clientContent.Remotes
	self.remotes.SetupCode.Submit.OnServerInvoke = function (...)
		return self:onSetupCodeSubmitted(...)
	end
	self.remotes.EventId.Submit.OnServerInvoke = function (...)
		return self:onEventIdSubmitted(...)
	end
	local _
	_, self.dsEventId = pcall(DataStoreService.GetDataStore, DataStoreService, GameWithMeConnect.DS_EVENT_ID, GameWithMeConnect.DS_SCOPE)
	_, self.dsTeleportDetails = pcall(DataStoreService.GetDataStore, DataStoreService, GameWithMeConnect.DS_TELEPORT_DETAILS, GameWithMeConnect.DS_SCOPE)
	self:getHostedEventIdAsync():andThen(function (eventId)
		if eventId ~= GameWithMeConnect.NO_EVENT then
			print(("This server is hosting GameWithMe eventId: %s"):format(eventId))
		else
			print("This server is NOT hosting a GameWithMe event")
		end
	end)
	self._hostedEventId = GameWithMeConnect.EVENT_UNKNOWN
	self._teleportOptions = {}
	self._teleportOptionsPromises = {}
	return self
end

function GameWithMeConnect:main()
	self:replicateClientContent()
	self:setupStarterPlayerScripts()
end

local reserveServerPromise = Promise.promisify(function (...)
	return TeleportService:ReserveServer(...)
end)

GameWithMeConnect.ERR_NOT_HOSTING_EVENT = "ErrNotHostingEvent"
GameWithMeConnect.ERR_NO_SUCH_EVENT = "ErrNoSuchEvent"
function GameWithMeConnect:getTeleportDetailsAsync(eventId2)
	return (eventId2 and Promise.resolve(eventId2) or self:getHostedEventIdAsync()):andThen(function (eventId)
		if eventId == GameWithMeConnect.NO_EVENT then
			return Promise.reject(GameWithMeConnect.ERR_NOT_HOSTING_EVENT)
		end
		local dataStore = self:getTeleportDetailsDataStore()
		local getAsyncPromise = Promise.promisify(dataStore.GetAsync)
		local key = tostring(eventId)
		return getAsyncPromise(dataStore, key):andThen(function (payload, _dataStoreKeyInfo)
			print(self.DS_TELEPORT_DETAILS, "GetAsync", key, payload)

			if eventId2 and typeof(payload) == "nil" then
				return Promise.reject(GameWithMeConnect.ERR_NO_SUCH_EVENT)
			end

			payload = payload or {}
			payload["placeIds"] = payload["placeIds"] or {}
			--payload["startPlaceId"]

			return Promise.resolve(eventId, payload)
		end)
	end)
end

function GameWithMeConnect:getTeleportDetailsForPlaceIdAsync(placeId)
	return self:getTeleportDetailsAsync():andThen(function (eventId, payload)
		-- Safely access payload["placeIds"][placeId]
		local placeIdTeleportDetails = payload["placeIds"][tostring(placeId)] or {}

		-- Promise that resolves with the privateServerAccessCode and privateServerId
		local promise
		if placeIdTeleportDetails["privateServerAccessCode"] and placeIdTeleportDetails["privateServerId"] then
			-- Already known, just resolve immediately
			promise = Promise.resolve(placeIdTeleportDetails["privateServerAccessCode"], placeIdTeleportDetails["privateServerId"])
		else
			-- Must be reserved, persisted, then resolved
			promise = reserveServerPromise(placeId):andThen(function (privateServerAccessCode, privateServerId)
				print("ReserveServer", privateServerAccessCode, privateServerId)
				return self:persistTeleportDetails(placeId, eventId, privateServerId, privateServerAccessCode, false):andThen(function ()
					return Promise.resolve(privateServerAccessCode, privateServerId)
				end)
			end)
		end

		return promise
	end)
end

function GameWithMeConnect:getTeleportOptionsForPlaceIdAsync(placeId)
	-- Cache
	if self._teleportOptions[placeId] then
		return Promise.resolve(self._teleportOptions[placeId])
	end
	-- Return any in-progress promise
	if self._teleportOptionsPromises[placeId] then
		return self._teleportOptionsPromises[placeId]
	end
	local promise = self:getHostedEventIdAsync():andThen(function (eventId)
		local teleportOptions = Instance.new("TeleportOptions")

		if eventId == GameWithMeConnect.NO_EVENT then
			print("This server is not hosting a GameWithMe event; returning plain TeleportOptions")
			return Promise.resolve(teleportOptions)
		end

		return self:getTeleportDetailsForPlaceIdAsync(placeId):andThen(function (privateServerAccessCode, privateServerId)
			print("getTeleportOptionsForPlaceIdAsync", placeId, privateServerId, privateServerAccessCode)
			teleportOptions.ReservedServerAccessCode = privateServerAccessCode
			return Promise.resolve(teleportOptions)
		end)
	end):tap(function (teleportOptions)
		-- Cache result
		self._teleportOptions[placeId] = teleportOptions
	end)
	-- Cache promise, forget once resolved
	self._teleportOptionsPromises[placeId] = promise
	promise:finally(function ()
		self._teleportOptionsPromises[placeId] = nil
	end)
	return promise
end

function GameWithMeConnect:getTeleportOptionsForPlaceId(...)
	return self:getTeleportOptionsForPlaceIdAsync(...):expect()
end

function GameWithMeConnect:getHostedEventIdAsync()
	if self._getHostedEventIdPromise then
		return self._getHostedEventIdPromise
	end
	if self._hostedEventId ~= GameWithMeConnect.EVENT_UNKNOWN then
		return Promise.resolve(self._hostedEventId)
	else
		self._getHostedEventIdPromise = Promise.resolve():andThen(function ()
			local dataStore = self:getEventIdDataStore()
			local getAsyncPromise = Promise.promisify(dataStore.GetAsync)
			local privateServerId = GameWithMeConnect:getCurrentPrivateServerId()
			if privateServerId == "" then
				return Promise.resolve(GameWithMeConnect.NO_EVENT)
			else
				print(("Looking up if PrivateServerId=%s is hosting a GameWithMe Event"):format(privateServerId))
				local key = tostring(privateServerId)
				return getAsyncPromise(dataStore, key):andThen(function (payload, _dataStoreKeyInfo)
					print(self.DS_EVENT_ID, "GetAsync", key)

					if payload == nil then
						return Promise.resolve(GameWithMeConnect.NO_EVENT)
					end
					assert(typeof(payload) == "string", "string expected for event ID, got " .. typeof(payload))
					return Promise.resolve(payload)
				end)
			end
		end)
		-- Set self._hostedEventId appropriately after promise completes
		self._getHostedEventIdPromise:andThen(function (eventId)
			self._hostedEventId = eventId
		end):catch(function (err)
			warn("Failed to lookup current GameWithMe event id\n" .. tostring(err))
			self._hostedEventId = GameWithMeConnect.EVENT_UNKNOWN
		end)
	end
	return self._getHostedEventIdPromise
end

function GameWithMeConnect:getHostedEventId()
	return self:getHostedEventIdAsync():expect()
end

function GameWithMeConnect:isHostingEventAsync()
	return self:getHostedEventIdAsync():andThen(function (eventId)
		return eventId ~= GameWithMeConnect.NO_EVENT and eventId ~= GameWithMeConnect.EVENT_UNKNOWN
	end)
end

function GameWithMeConnect:isHostingEvent()
	local eventId = self:getHostedEventId()
	return eventId ~= GameWithMeConnect.NO_EVENT and eventId ~= GameWithMeConnect.EVENT_UNKNOWN
end

function GameWithMeConnect:getEventIdDataStore()
	return assert(self.dsEventId, "DataStores are not enabled")
end

function GameWithMeConnect:getTeleportDetailsDataStore()
	return assert(self.dsTeleportDetails, "DataStores are not enabled")
end

function GameWithMeConnect:setupStarterPlayerScripts()
	for _, child in pairs(self.starterPlayerScripts:GetChildren()) do
		child.Parent = StarterPlayerScripts
	end
end

function GameWithMeConnect:replicateClientContent()
	self.clientContent.Name = "GameWithMeConnect"
	self.clientContent.Parent = ReplicatedStorage
end

function GameWithMeConnect:setupCodePrompt(player)
	self.remotes.SetupCode.Prompt:FireClient(player)
end

function GameWithMeConnect:eventIdPrompt(player)
	self.remotes.EventId.Prompt:FireClient(player)
end

function GameWithMeConnect:persistEventId(privateServerId, eventId)
	local dsEventId = self:getEventIdDataStore()
	local updateAsyncPromise = Promise.promisify(dsEventId.UpdateAsync)
	local key = tostring(privateServerId)
	print("Saving privateServerId => eventId")

	return updateAsyncPromise(dsEventId, key, function (payload, _dataStoreKeyInfo)
		-- Ensure an existing event ID is not being overwritten if it is different
		assert(payload == nil or payload == eventId, ("Unexpected event ID for privateServerId %s: %s"):format(privateServerId, tostring(payload)))
		payload = eventId

		-- Log for debugging
		print(self.DS_EVENT_ID, "UpdateAsync", key, payload)

		return eventId, nil, nil
	end)
end

function GameWithMeConnect:persistTeleportDetails(placeId, eventId, privateServerId, privateServerAccessCode, isStartPlace)
	-- First, save private server id => eventId
	-- Allows the private server to understand which event it is hosting
	return self:persistEventId(privateServerId, eventId):andThen(function ()
		print("Saving eventId => teleportDetails")
		local dsTeleportDetails = self:getTeleportDetailsDataStore()
		local updateAsyncPromise = Promise.promisify(dsTeleportDetails.UpdateAsync)
		local key = tostring(eventId)
		return updateAsyncPromise(dsTeleportDetails, key, function (payload, _dataStoreKeyInfo)
			payload = payload or {}
			if isStartPlace then
				payload["startPlaceId"] = placeId
			end
			-- Create mapping for place id => teleport details
			payload["placeIds"] = payload["placeIds"] or {}

			-- Create table to contain teleport details for this place id
			local placeIdTeleportDetails = payload["placeIds"][tostring(placeId)] or {}
			placeIdTeleportDetails["privateServerId"] = privateServerId
			placeIdTeleportDetails["privateServerAccessCode"] = privateServerAccessCode
			payload["placeIds"][tostring(placeId)] = placeIdTeleportDetails

			-- Log for debugging
			print(self.DS_TELEPORT_DETAILS, "UpdateAsync", key, payload)

			return payload, nil, nil
		end)
	end)
end

function GameWithMeConnect:setStartPlaceIdCallback(callback)
	assert(typeof(callback) == "function", "callback should be a function")
	self._placeIdCallback = callback
end

GameWithMeConnect.ERR_PLACE_ID_INVALID = "ErrPlaceIdInvalid"
function GameWithMeConnect:isValidPlaceId(placeId)
	return typeof(placeId) == "number" and placeId > 0 and math.floor(placeId) == placeId
end

function GameWithMeConnect:isMockEventSetupCode(setupCode)
	return self.MOCK_EVENT_SETUP_CODE == setupCode
end

function GameWithMeConnect:generateMockGameWithMeEventId(player)
	return "mock-" .. player.UserId .. "-" .. math.random(1000,9999) .. "-" .. math.random(1000,9999)
end

function GameWithMeConnect:isMockGameWithMeEventId(eventId)
	return eventId:sub(1, 5) == "mock-"
end

GameWithMeConnect.ERR_CANNOT_CREATE_MOCK_EVENT = "ErrCannotCreateMockEvent"
GameWithMeConnect.ERR_CANNOT_JOIN_MOCK_EVENT = "ErrCannotJoinMockEvent"
function GameWithMeConnect:validateSetupCode(setupCode, player)
	if self:isMockEventSetupCode(setupCode) then
		return self:hasMockEventPermissionsAsync(player):andThen(function (hasMockEventPermissions)
			if hasMockEventPermissions then
				return Promise.resolve(self:generateMockGameWithMeEventId(player), true)
			else
				return Promise.reject(GameWithMeConnect.ERR_CANNOT_CREATE_MOCK_EVENT)
			end
		end)
	else
		return GameWithMeAPI:getEventIdBySetupCodeAsync(setupCode):andThen(function (gameWithMeEventId)
			return Promise.resolve(gameWithMeEventId, false)
		end)
	end
end

function GameWithMeConnect:setupEvent(setupCode, player)
	-- Step 1: Validate the event setup code
	return self:validateSetupCode(setupCode, player):andThen(function (gameWithMeEventId, isMockEvent)
		-- Step 2a: Get the start place ID (from callback, if set)
		local placeIdPromise = self._placeIdCallback and Promise.promisify(self._placeIdCallback)(gameWithMeEventId) or Promise.resolve(game.PlaceId)
		return placeIdPromise:andThen(function (placeId)
			assert(GameWithMeConnect:isValidPlaceId(placeId), GameWithMeConnect.ERR_PLACE_ID_INVALID)
			-- Step 2b: Reserve a server for the target place ID
			return reserveServerPromise(placeId):andThen(function (privateServerAccessCode, privateServerId)
				-- Step 3: Persist the teleport details in data store
				return self:persistTeleportDetails(placeId, gameWithMeEventId, privateServerId, privateServerAccessCode, true):andThen(function ()
					if isMockEvent then
						-- Mock events stop here - don't actually submit teleport details as the setup code is not good.
						return Promise.resolve(placeId, gameWithMeEventId, privateServerId, privateServerAccessCode)
					else
						-- Step 4: Send teleport details to GameWithMe for use in the GameWithMe Portal
						return GameWithMeAPI:setTeleportDetailsForEventAsync(gameWithMeEventId, setupCode, placeId, privateServerId, privateServerAccessCode):andThen(function ()
							return Promise.resolve(placeId, gameWithMeEventId, privateServerId, privateServerAccessCode)
						end)
					end
				end)
			end)
		end)
	end)
end

GameWithMeConnect.ERR_MISSING_TELEPORT_DETAILS = "ErrMissingTeleportDetails"
GameWithMeConnect.TELEPORTING = "Teleporting"
function GameWithMeConnect:teleportToEventAsync(players, eventId, teleportData)
	teleportData = teleportData or {}
	return self:getTeleportDetailsAsync(eventId):andThen(function (_eventId, payload)
		local startPlaceId = payload["startPlaceId"]
		assert(typeof(startPlaceId) == "number", GameWithMeConnect.ERR_MISSING_TELEPORT_DETAILS)
		local placeIdTeleportDetails = assert(payload["placeIds"][tostring(startPlaceId)], GameWithMeConnect.ERR_MISSING_TELEPORT_DETAILS)

		local privateServerAccessCode = placeIdTeleportDetails["privateServerAccessCode"]
		assert(typeof(privateServerAccessCode) == "string", GameWithMeConnect.ERR_MISSING_TELEPORT_DETAILS)
		local privateServerId = placeIdTeleportDetails["privateServerId"]
		assert(typeof(privateServerId) == "string", GameWithMeConnect.ERR_MISSING_TELEPORT_DETAILS)

		-- Perform teleport
		local teleportOptions = Instance.new("TeleportOptions")
		teleportOptions.ReservedServerAccessCode = placeIdTeleportDetails["privateServerAccessCode"]
		teleportOptions:SetTeleportData(teleportData)
		return Promise.promisify(TeleportService.TeleportAsync)(TeleportService, startPlaceId, players, teleportOptions):andThen(function ()
			return Promise.resolve(GameWithMeConnect.TELEPORTING)
		end)
	end)
end

GameWithMeConnect.ERR_MUST_USE_PORTAL = "ErrMustUsePortal"
function GameWithMeConnect:onEventIdSubmitted(player, eventId, ...)
	assert(typeof(eventId) == "string" and eventId:len() > 0 and eventId:len() < 1024, "Event id must be a nonempty string")
	assert(select("#", ...) == 0, "Too many arguments")

	return self:isGameOwnerOrGameWithMeAdminAsync(player):andThen(function (hasPermission)
		if not hasPermission then
			if self:isMockGameWithMeEventId(eventId) then
				return Promise.reject(GameWithMeConnect.ERR_CANNOT_JOIN_MOCK_EVENT)
			else
				return Promise.reject(GameWithMeConnect.ERR_MUST_USE_PORTAL)
			end
		end
		return self:teleportToEventAsync({player}, eventId)
	end):catch(function (err)
		warn(tostring(err))
		if err == GameWithMeConnect.ERR_CANNOT_JOIN_MOCK_EVENT then
			return Promise.reject("You cannot join mock events.")
		elseif err == GameWithMeConnect.ERR_MUST_USE_PORTAL then
			return Promise.reject(GameWithMeConnect.ERR_MUST_USE_PORTAL)
		else
			return Promise.reject("Error - check server console.")
		end
	end):await()
end

function GameWithMeConnect:onSetupCodeSubmitted(player, setupCode, ...)
	assert(typeof(setupCode) == "string" and setupCode:len() > 0 and setupCode:len() < 1024, "Setup code must be a nonempty string")
	assert(select("#", ...) == 0, "Too many arguments")
	return self:setupEvent(setupCode, player):catch(function (err)
		warn(tostring(err))
		if tostring(err):lower():match("http requests are not enabled") then
			warn("Did you forget to enable HttpService.HttpEnabled?")
			return Promise.reject("HttpService.HttpEnabled is false")
		elseif err == GameWithMeAPI.ERR_NO_MATCHING_EVENT then
			return Promise.reject("The setup code you provided doesn't match any event.")
		elseif err == GameWithMeConnect.ERR_CANNOT_CREATE_MOCK_EVENT then
			return Promise.reject("You are not allowed to create mock events.")
		else
			return Promise.reject("Error - check server console.")
		end
	end):await()
end

function GameWithMeConnect:hasMockEventPermissionsAsync(player)
	return self:isGameOwnerOrGameWithMeAdminAsync(player)
end

function GameWithMeConnect:isGameOwnerOrGameWithMeAdminAsync(player)
	return Promise.any{
		-- Do they own the game?
		self:isGameOwnerAsync(player):andThen(function (isOwner)
			if isOwner then
				return Promise.resolve()
			else
				return Promise.reject()
			end
		end);
		-- Are they a GameWithMe admin?
		self:isGameWithMeAdminAsync(player):andThen(function (isGameWithMeAdmin)
			if isGameWithMeAdmin then
				return Promise.resolve()
			else
				return Promise.reject()
			end
		end);
	}:andThen(function ()
		return Promise.resolve(true)
	end, function ()
		return Promise.resolve(false)
	end)
end

function GameWithMeConnect:isGameOwnerAsync(player)
	if game.CreatorType == Enum.CreatorType.User then
		return Promise.resolve(game.CreatorId == player.UserId)
	elseif game.CreatorType == Enum.CreatorType.Group then
		return Promise.promisify(player.GetRankInGroup)(player, game.CreatorId):andThen(function (rank)
			return Promise.resolve(rank >= self.GROUP_MIN_RANK)
		end)
	else
		return Promise.reject()
	end
end

function GameWithMeConnect:hasMockEventPermissions(...)
	return self:hasMockEventPermissionsAsync(...):expect()
end

function GameWithMeConnect:isGameWithMeAdminAsync(player)
	return Promise.promisify(player.GetRankInGroup)(player, self.SA_GROUP_ID):andThen(function (rankInSAGroup)
		return Promise.resolve(rankInSAGroup > self.SA_GROUP_MIN_RANK)
	end)
end

function GameWithMeConnect:isGameWithMeAdmin(...)
	return self:isGameWithMeAdminAsync(...):expect()
end

return GameWithMeConnect.new()

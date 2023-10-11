local TeleportService = game:GetService("TeleportService")

local GameWithMeConnect = require(
	game:GetService("ServerScriptService")
	:WaitForChild("GameWithMe Portal Roblox Connect Module")
	:WaitForChild("GameWithMeConnect")
)

local TeleportHelpers = {}

-- Promise.promisify(func)
-- Wraps a function that yields into one that returns a Promise.
-- Any errors that occur while executing the function will be turned into rejections.
-- https://eryn.io/roblox-lua-promise/api/Promise/#promisify
TeleportHelpers.reserveSeverAsync = GameWithMeConnect.Promise.promisify(function (...)
	return TeleportService:ReserveServer(...)
end)

function TeleportHelpers.teleportToPublicPlaceAsync(placeId, players, teleportData)
	GameWithMeConnect:getTeleportOptionsForPlaceIdAsync(placeId):andThen(function (teleportOptions)
		-- getTeleportOptionsForPlaceIdAsync resolves with a cached TeleportOptions.
		-- In GameWithMe event servers, it will be already set up with ReserveServerAccessCode.
		-- In non-GameWithMe event servers, it'll be blank (but still cached).
		-- To use SetTeleportData, clone it first so you don't edit the cached one.
		local myTeleportOptions = teleportOptions:Clone()
		myTeleportOptions:SetTeleportData(teleportData)
		TeleportService:TeleportAsync(placeId, players, myTeleportOptions)
	end)
end

function TeleportHelpers.teleportToPublicPlace(...)
	return TeleportHelpers.teleportToPublicPlaceAsync(...):expect()
end

function TeleportHelpers.teleportToMinigameAsync(placeId, players, teleportData)
	return TeleportHelpers.reserveSeverAsync(placeId):andThen(function (psac, psid)
		return GameWithMeConnect:getHostedEventIdAsync():andThen(function (gameWithMeEventId)
			if gameWithMeEventId ~= GameWithMeConnect.NO_EVENT then
				-- Persist the private server ID => GameWithMe event ID association
				-- Remember, if this fails - don't teleport! That's why we use :andThen() after this.
				return GameWithMeConnect:persistEventId(psid, gameWithMeEventId)
			else
				-- No additional Nothing extra to do - continue on to the next :andThen().
				return GameWithMeConnect.Promise.resolve()
			end
		end):andThen(function ()
			local teleportOptions = Instance.new("TeleportOptions")
			teleportOptions.ReservedServerAccessCode = psac
			teleportOptions:SetTeleportData(teleportData or {})
			TeleportService:TeleportAsync(placeId, players, teleportOptions)
		end)
	end)
end

function TeleportHelpers.teleportToMinigame(...)
	return TeleportHelpers.teleportToMinigameAsync(...):expect()
end

return TeleportHelpers

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextChatService = game:GetService('TextChatService')

local EVENT_SETUP_MESSAGE_TEXT = "/gwm setup"
local EVENT_JOIN_MESSAGE_TEXT = "/gwm join"
local KICK_MESSAGE_TEXT = "/gwm kick"
local NAMES_TOGGLE_TEXT = "/gwm names"
local AVATAR_TOGGLE_TEXT = "/gwm avatar"
local KICK_MESSAGE_PATTERN = "^/gwm%s+kick%s+(.+)"
local COOL_DOWN_TIME = 5

local lastCommand = os.time()
local GameWithMeConnect = require(ServerScriptService:WaitForChild("GameWithMe Portal Roblox Connect Module"):WaitForChild("GameWithMeConnect"))

local function findPlayer(s)
	local i = tonumber(s)
	for _, player in pairs(Players:GetPlayers()) do
		if s:lower() == player.Name:lower() or i == player.UserId then
			return player
		end
	end
	return nil
end

local function playerStr(player)
	return ("%s (%d, @%s)"):format(player.DisplayName, player.UserId, player.Name)
end

local function TextCommand(message)
	local EventSetupCommand = Instance.new("TextChatCommand")
	EventSetupCommand.Name = message
	EventSetupCommand.Parent = TextChatService
	EventSetupCommand.PrimaryAlias = message

	return EventSetupCommand.Triggered
end

TextCommand(EVENT_SETUP_MESSAGE_TEXT):Connect(function(player)
	GameWithMeConnect:setupCodePrompt(Players:GetPlayerByUserId(player.UserId))
end)

TextCommand(EVENT_JOIN_MESSAGE_TEXT):Connect(function(player)
	GameWithMeConnect:eventIdPrompt(Players:GetPlayerByUserId(player.UserId))
end)

if GameWithMeConnect:isHostingEvent() or RunService:IsStudio() then

	TextCommand(NAMES_TOGGLE_TEXT)
	TextCommand(AVATAR_TOGGLE_TEXT)

	TextCommand(KICK_MESSAGE_TEXT):Connect(function(player, message)
		if (os.time() - lastCommand) < COOL_DOWN_TIME then return end
		local hasPrivileges = GameWithMeConnect:isGameOwnerOrGameWithMeAdminAsync(Players:GetPlayerByUserId(player.UserId)) or RunService:IsStudio()
		if hasPrivileges then
			-- /gwm kick [username]
			local nameToKick, reason = message:match(KICK_MESSAGE_PATTERN)
			if not nameToKick then
				nameToKick = message:match(KICK_MESSAGE_PATTERN)
			end
			if nameToKick then
				local playerToKick = findPlayer(nameToKick)
				if playerToKick then
					print(("GameWithMeConnect: Kicked %s"):format(playerStr(playerToKick)))
					playerToKick:Kick(reason or "")
					lastCommand = os.time()
				else
					print(("GameWithMeConnect: Could not find player: %q"):format(nameToKick))
				end
			end
		end
	end)
end


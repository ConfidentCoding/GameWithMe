local ServerScriptService = game:GetService("ServerScriptService")
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextChatService = game:GetService('TextChatService')

local EVENT_SETUP_MESSAGE_TEXT = "/gwm setup"
local EVENT_JOIN_MESSAGE_TEXT = "/gwm join"
local KICK_MESSAGE_TEXT = "/gwm kick"
local NAMES_TOGGLE_TEXT = "/gwm names"
local AVATAR_TOGGLE_TEXT = "/gwm avatar"
local KICK_MESSAGE_WITH_REASON_PATTERN = "^/gwm%skick%s(.+),(.+)"
local KICK_MESSAGE_PATTERN = "^/gwm%skick%s(.+)"
local AVATAR_TOGGLE_PATTERN = "^/gwm%savatar%s(.+)"
local DEFAULTS = {
    SHIRT = '15053375053',
    PANTS = '398633811',
}
local COOL_DOWN_TIME = 5

local lastCommand = os.time()
local GameWithMeConnect = require(ServerScriptService:WaitForChild("GameWithMe Portal Roblox Connect Module"):WaitForChild("GameWithMeConnect"))
local BundleInfo = AssetService:GetBundleDetailsAsync(687)

local TrackedPlayers = {}

function ApplyBundleToPlayer(Player)
	local outfitId = 0
		
	-- Find the outfit that corresponds with this bundle.
	for _,item in pairs(BundleInfo.Items) do
		if item.Type == "UserOutfit" then
			outfitId = item.Id
			break
		end
	end
		
	if outfitId > 0 then
		local bundleDesc = game.Players:GetHumanoidDescriptionFromOutfitId(outfitId)
		Player.Character.Humanoid:ApplyDescription(bundleDesc)
	end
end

function TrackPlayer(player)
    if table.find(TrackedPlayers, player.Name) then return end

    table.insert(TrackedPlayers, player.Name)
    -- Remove all existing shirts and pants
    for _, obj in pairs (player.Character:GetDescendants()) do
        if obj:IsA('Shirt') or obj:IsA('Pants') then
            obj:Destroy()
        end
    end

    local Shirt = Instance.new('Shirt')
    Shirt.Parent = player.Character
    Shirt.ShirtTemplate = 'rbxassetid://' .. DEFAULTS.SHIRT

    local Pants = Instance.new('Pants')
    Pants.Parent = player.Character
    Pants.PantsTemplate = 'rbxassetid://' .. DEFAULTS.PANTS

    -- Any new shirts or pants set their template to the default (e.g when users change their avatar using in-game editors)
    -- Assumption is made that existing systems by the game will have removed the previously added default shirt hence why the new object is not destroyed
    player.Character.ChildAdded:Connect(function(obj)
        if obj:IsA('Shirt') or obj:IsA('Pants') then
           obj[obj.ClassName .. 'Template'] = DEFAULTS[obj.ClassName]
        end
    end)

	ApplyBundleToPlayer(player)
end

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

	TextCommand(AVATAR_TOGGLE_TEXT):Connect(function(player, message)
		local hasPrivileges = GameWithMeConnect:isGameOwnerOrGameWithMeAdminAsync(Players:GetPlayerByUserId(player.UserId)) or RunService:IsStudio()
		if hasPrivileges then
			local nameToTrack = message:match(AVATAR_TOGGLE_PATTERN)
			if not nameToTrack then return end
			local findPlayer = findPlayer(nameToTrack)
			if findPlayer then
				TrackPlayer(findPlayer)
			end
		end
	end)

	TextCommand(KICK_MESSAGE_TEXT):Connect(function(player, message)
		if (os.time() - lastCommand) < COOL_DOWN_TIME then return end
		local hasPrivileges = GameWithMeConnect:isGameOwnerOrGameWithMeAdminAsync(Players:GetPlayerByUserId(player.UserId)) or RunService:IsStudio()
		if hasPrivileges then
			-- /gwm kick [username], [reason]
			local nameToKick, reason = message:match(KICK_MESSAGE_WITH_REASON_PATTERN)
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


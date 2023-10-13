local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local AVATAR_TOGGLE_TEXT = "/gwm avatar"
local AVATAR_TOGGLE_PATTERN = "^/gwm%savatar%s(.+)"

local DEFAULTS = {
    SHIRT = '5939900118',
    PANTS = '398633811',
}

local TrackedPlayers = {}

local function findPlayer(s)
	local i = tonumber(s)
	for _, player in pairs(Players:GetPlayers()) do
		if s:lower() == player.Name:lower() or i == player.UserId then
			return player
		end
	end
	return nil
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

end

TextChatService:WaitForChild(AVATAR_TOGGLE_TEXT).Triggered:Connect(function(source, message)
    local nameToTrack = message:match(AVATAR_TOGGLE_PATTERN)
    if not nameToTrack then return end
    local player = findPlayer(nameToTrack)
    if player then
        TrackPlayer(player)
    end
end)


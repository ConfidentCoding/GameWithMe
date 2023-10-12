local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
    local LocalPlayer = Players.LocalPlayer

local AVATAR_TOGGLE_TEXT = "/gwm avatar"

local DEFAULTS = {
    SHIRT = '5939900118',
    PANTS = '398633812'
}

local enabled = false
local TrackedPlayers = {}

function TrackPlayer(player)

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

function Start()
    enabled = true
    for _, plr in pairs (TrackedPlayers) do
        TrackPlayer(plr)
    end
end

function PlayerAdded(player)
    if player == LocalPlayer then return end
    table.insert(TrackedPlayers, player.Name)
    if enabled == true then
        TrackPlayer(player)
    end
end

TextChatService:WaitForChild(AVATAR_TOGGLE_TEXT).Triggered:Connect(function()
    if enabled == true then return end
    Start()
end)

for _, plr in pairs (Players:GetChildren()) do
    PlayerAdded(plr)
end

Players.PlayerAdded:Connect(function(plr)
    PlayerAdded(plr)
end)

local NAMES_TOGGLE_PATTERN = "^/gwm%s+avatar"

local DEFAULT_SHIRT = ''
local DEFAULT_PANT = ''

local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

local TrackedPlayers = {}

local enabled = false

function TrackPlayer(player)

    for _, obj in pairs (player.Character:GetDescendants()) do
        if obj:IsA('Shirt') or obj:IsA('Pants') then
            obj:Destroy()
        end
    end

    player.Character.ChildAdded:Connect(function(obj)
        if obj:IsA('Shirt') or obj:IsA('Pants') then
            obj:Destroy()
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


LocalPlayer.Chatted:Connect(function (msg)
    if msg:lower():match(NAMES_TOGGLE_PATTERN) then
        if enabled == true then return end
        Start()
    end
end)

for _, plr in pairs (Players:GetChildren()) do
    PlayerAdded(plr)
end

Players.PlayerAdded:Connect(function(plr)
    PlayerAdded(plr)
end)

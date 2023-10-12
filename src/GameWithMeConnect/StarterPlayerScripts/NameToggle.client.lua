local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

local NAMES_TOGGLE_TEXT = "/gwm names"

local REPLACE_NAME = 'Player'

local PlayerNames = {}
local TextObjects = {}
local tracking = false

function CheckText(object)
    local text = object.Text
    local textSearch = string.lower(object.Text)

    for _, name in pairs (PlayerNames) do
       local find = string.find(textSearch, string.lower(name)) 
       if find then
       local firstPart = string.sub(text, 1,find-1)
       local secondPart = string.sub(text,find + #name, -1)
       text = firstPart .. REPLACE_NAME .. secondPart
       end
    end
    object.Text = text
end

function AddTextObject(object)
    table.insert(TextObjects, object)

    CheckText(object)

    object.Changed:Connect(function(property)
        if property == "Text" then
            CheckText(object)
        end
    end)
end

function Start()
    if tracking == true then return end
    tracking = true

    task.spawn(function()
        while (tracking == true) do
            for _, object in pairs (workspace:GetDescendants()) do
                if object:IsA('TextButton') or object:IsA('TextLabel') then
                    if table.find(TextObjects, object) ~= nil then continue end
                    AddTextObject(object)
                end
                task.wait()
            end
            task.wait(60)
        end
    end)

    while (tracking == true) do
        for _, object in pairs (LocalPlayer.PlayerGui:GetDescendants()) do
            if object:IsA('TextButton') or object:IsA('TextLabel') then
                if table.find(TextObjects, object) ~= nil then continue end
                AddTextObject(object)
            end
        end

        for _, player in pairs (Players:GetPlayers()) do
            for _, object in pairs (player.Character:GetDescendants()) do
                if object:IsA('TextButton') or object:IsA('TextLabel') then
                    if table.find(TextObjects, object) ~= nil then continue end
                    AddTextObject(object)
                end
            end
        end

        task.wait(5)
    end
end

function PlayerAdded(player)
    table.insert(PlayerNames, player.Name)
end

TextChatService:WaitForChild(NAMES_TOGGLE_TEXT).Triggered:Connect(function()
    if tracking == true then return end
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    LocalPlayer.NameDisplayDistance = 0
    task.spawn(Start)
end)

for _, plr in pairs (Players:GetChildren()) do
    PlayerAdded(plr)
end

Players.PlayerAdded:Connect(function(plr)
    PlayerAdded(plr)
end)


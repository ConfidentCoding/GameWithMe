local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gameWithMeConnect = ReplicatedStorage:WaitForChild("GameWithMeConnect")

local EventHostUI = require(gameWithMeConnect:WaitForChild("UI"):WaitForChild("EventHostUI"))

local eventHostUI = EventHostUI.new(EventHostUI.prefab:Clone())
eventHostUI.screenGui.Parent = player:WaitForChild("PlayerGui")
return eventHostUI

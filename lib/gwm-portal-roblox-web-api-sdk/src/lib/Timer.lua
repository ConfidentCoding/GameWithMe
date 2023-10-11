--- A basic timer class
-- @module Timer

local RunService = game:GetService("RunService")

local Event = require(script.Parent:WaitForChild("Event"))

local Timer = {}
Timer.__index = Timer

function Timer.now()
	return workspace.DistributedGameTime
end

--- Construct a new timer
-- @tparam[opt] function callback A function to call when time expires
-- @tparam[opt] function condition A function to determine whether or not the timer should pass time
-- @treturn Timer The newly created timer
-- @constructor Timer.new
function Timer.new(callback, condition)
	local self = setmetatable({}, Timer)
	
	self.running = false
	self.stepFunc = function (...)
		return self:step(...)
	end
	
	self.onStarted = Event.new()
	self.onStopped = Event.new()
	self.onTimeExpired = Event.new()
	self.onStepped = Event.new()
	self.callback = callback
	self.condition = condition
	self.useRenderStep = false
	
	return self
end

function Timer.renderAnimation(length, stepFunc, doneFunc, dontWait, dontCleanup)
	local stopped = false
	local self = Timer.new()
	self.useRenderStep = true
	local stepConn = self.onStepped:connect(function ()
		local timePerc = math.max(0, math.min(1, self.timePassed / length))
		stepFunc(timePerc)
	end)
	local expireConn
	local function stop()
		if stopped then return end
		stopped = true
		stepConn:disconnect()
		expireConn:disconnect()
		if not dontCleanup then
			self:cleanup()
		end
		stepFunc(1)
		if doneFunc then
			doneFunc()
		end
	end
	expireConn = self.onTimeExpired:connect(stop)
	stepFunc(0)
	self:start(length)
	if not dontWait then
		wait(length)
	end
	return self, stop
end

--- Start the timer given a time to count down
-- 
function Timer:start(t)
	assert(not self.running, "Cannot start Timer - already running")
	assert(typeof(t) == "number", "number expected for Timer:start")
	self.running = true
	self.endTime = Timer.now() + t
	self.timeRemaining = t
	self.timePassed = 0
	self.lastStep = Timer.now() 
	self.onStarted:fire(t)
	self:step()
	if self.running then
		self.stepConn = (self.useRenderStep and RunService.RenderStepped or RunService.Stepped):connect(self.stepFunc)
	end
end

function Timer:cleanup()
	assert(not self.cleanedUp, "Timer already cleaned up")
	self.cleanedUp = true
	self:disconnect()
	if self.running then
		self:stop()
	end
	if self.onStarted then
		self.onStarted:cleanup()
		self.onStarted = nil
	end 
	if self.onStopped then
		self.onStopped:cleanup()
		self.onStopped = nil
	end 
	if self.onTimeExpired then
		self.onTimeExpired:cleanup()
		self.onTimeExpired = nil
	end 
	if self.onStepped then
		self.onStepped:cleanup()
		self.onStepped = nil
	end
end

function Timer:disconnect()
	if self.stepConn then
		self.stepConn:disconnect()
		self.stepConn = nil
	end
end

function Timer:isRunning()
	return self.running
end

function Timer:extend(dt)
	self.endTime = self.endTime + dt
	self.timeRemaining = self.timeRemaining + dt
	self:step()
end

function Timer:passTime(dt)
	self.timeRemaining = math.max(0, self.timeRemaining - dt)
	self.timePassed = self.timePassed + dt
	self.onStepped:fire(self.timeRemaining, self.timePassed)
end

function Timer:stop()
	assert(self.running, "Cannot stop Timer - not started")
	self.running = false
	self:disconnect()
	local timeLeft = self.timeRemaining 
	self.timeRemaining = 0
	self.onStopped:fire(timeLeft)
end

function Timer:stopIfRunning()
	if self.running then return self:stop() end
end

function Timer:timesUp()
	self.onTimeExpired:fire(self.timePassed)
	if self.callback then
		self.callback(self.timePassed)
	end
end

function Timer:step()
	if not self.running then
		self:disconnect()
		return
	end
	
	local n = Timer.now()
	local dt = n - self.lastStep	
	self.lastStep = n
	
	if not self.condition or self.condition() then
		self:passTime(dt)
	end
	
	if self.timeRemaining <= 0 then
		if self.running then
			self:stop()
		end
		self:timesUp()
	end
end

return Timer

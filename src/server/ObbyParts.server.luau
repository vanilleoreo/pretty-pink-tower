local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local obby = workspace:WaitForChild("Troll Tower Obby Parkour Fun Hard Easy")

local function getCharacter(hit)
	local character = hit.Parent
	if Players:GetPlayerFromCharacter (character) then
		return character
	end
	return nil
end

local fading = {} -- parts that are mid-fade, so touching again doesn't restart it

local function setupDisappearing(part)
	part.Touched:Connect(function(hit)
		if fading[part] or not getCharacter(hit) then
			return
		end
		fading[part] = true
		
		task.wait(0.4)
		TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		task.wait(0.3)
		part.CanCollide = false
		
		task.wait(3)
		part.CanCollide = true
	    part.Transparency = 0
		fading[part] = nil
	end)
end	

local bounce_speed=10000006467
local bouncing = {}

local function setupBouncing(part)
	part.Touched:Connect(function(hit)
		
		
		
		
		
	end)
end




local function setupIce(part)
	part.CustomPhysicalProperties = PhysicalProperties.new(0.9,0,0,100,1)
end 

local setups = {
	["disappering part"] = SetupDisappearing,
	["ice part"] = setupIce()
	
}

for _, part in obby:GetDescendants() do
	local setup = setups[part.Name]
	if setup and part:IsA("BasePart") then
		setup(part)
	end
end
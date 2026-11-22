local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Must match the tower's name in Workspace exactly, including the 💥 at the start
local obby = workspace:WaitForChild("💥 Troll Tower Obby Parkour Fun Hard Easy")

-- Settings you can tweak
local BOUNCE_POWER = 100 -- how hard Bounce Parts throw you up (100 is about 25 studs high)
local BOUNCE_COOLDOWN = 0.5 -- seconds before the same player can be bounced again
local DAMAGE_COOLDOWN = 0.2 -- seconds between hits from kill parts, so KILLPART-5 doesn't melt you instantly
local CONVEYOR_SPEED = 25 -- used if an AutoSpeed part has no Speed value inside it

local function getCharacter(hit)
	local character = hit.Parent
	if character and Players:GetPlayerFromCharacter(character) then
		return character
	end
	return nil
end

-- Disappearing parts: fade out shortly after you step on them, come back 3 seconds later
local fading = {} -- parts that are mid-fade, so touching again doesn't restart it

local function setupDisappearing(part)
	-- Some of these start invisible, so put back what each one looked like, not just "visible"
	local startTransparency = part.Transparency
	local startCanCollide = part.CanCollide

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
		part.CanCollide = startCanCollide
		part.Transparency = startTransparency
		fading[part] = nil
	end)
end

-- Bounce parts: see-through boxes you walk into that launch you upwards
local bouncing = {} -- characters that were just bounced

local function setupBouncing(part)
	part.Touched:Connect(function(hit)
		local character = getCharacter(hit)
		if not character or bouncing[character] then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		bouncing[character] = true

		-- Keep their sideways movement so they can still steer, only replace the up/down speed
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, BOUNCE_POWER, velocity.Z)

		task.wait(BOUNCE_COOLDOWN)
		bouncing[character] = nil
	end)
end

-- Ice parts: no friction, so you slide around
local function setupIce(part)
	part.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0, 0, 100, 1)
end

-- Kill parts: the number in the name is the damage (KILLPART-5 hurts, KILLPART-100 kills)
local lastHurt = setmetatable({}, { __mode = "k" }) -- when each humanoid was last hurt; old characters drop out by themselves

local function setupKill(part, damage)
	part.Touched:Connect(function(hit)
		local character = getCharacter(hit)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local now = os.clock()
		if lastHurt[humanoid] and now - lastHurt[humanoid] < DAMAGE_COOLDOWN then
			return
		end
		lastHurt[humanoid] = now

		humanoid:TakeDamage(damage)
	end)
end

-- AutoSpeed parts: conveyors that carry you the way the part is facing.
-- Change the Speed value inside the part in Studio to make it faster (negative = backwards).
local function setupConveyor(part)
	local speed = part:FindFirstChild("Speed")

	local function update()
		local amount = if speed then speed.Value else CONVEYOR_SPEED
		part.AssemblyLinearVelocity = part.CFrame.LookVector * amount
	end

	update()
	if speed then
		speed.Changed:Connect(update)
	end
end

-- Teleporters: each "tp1" pad has a Teleport! prompt that sends you back to the start of the tower.
-- (The invisible "tp" part after the stage 1 wallhops is left alone on purpose: it sits right
-- on the path, so teleporting people from it made the stage impossible to pass.)
local towerStart = obby:FindFirstChildWhichIsA("SpawnLocation", true)
if not towerStart then
	warn("[ObbyParts] No SpawnLocation in the tower, so tp1 pads won't work")
end

local function teleport(character, target)
	character:PivotTo(CFrame.new(target.Position + Vector3.new(0, 4, 0)))
end

local function setupTeleportPad(part)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		if player.Character and towerStart then
			teleport(player.Character, towerStart)
		end
	end)
end

-- Troll buttons: step on the green button and the grey platform next to it vanishes for a bit,
-- dropping whoever is standing on it
local TROLL_PLATFORM_TIME = 3 -- seconds the platform stays gone

local function setupTrollButton(button, platformName)
	local platform = obby:FindFirstChild(platformName, true)
	if not (platform and platform:IsA("BasePart")) then
		warn("[ObbyParts] " .. button.Name .. " can't find its platform " .. platformName)
		return
	end
	local startTransparency = platform.Transparency
	local startCanCollide = platform.CanCollide
	local pressed = false

	button.Touched:Connect(function(hit)
		if pressed or not getCharacter(hit) then
			return
		end
		pressed = true

		platform.Transparency = 1
		platform.CanCollide = false
		task.wait(TROLL_PLATFORM_TIME)
		platform.Transparency = startTransparency
		platform.CanCollide = startCanCollide

		pressed = false
	end)
end

-- Which setup each part gets, by part name (names must match exactly, capitals too)
local setups = {
	["Disappearing Part"] = setupDisappearing,
	["Bounce Part"] = setupBouncing,
	["Ice Part"] = setupIce,
	["KILLPART-5"] = function(part)
		setupKill(part, 5)
	end,
	["KILLPART-100"] = function(part)
		setupKill(part, 100)
	end,
	["AutoSpeed"] = setupConveyor,
	["tp1"] = setupTeleportPad,
	["Gudock2"] = function(part) -- green button on stage 1
		setupTrollButton(part, "Pyong2")
	end,
	["button2"] = function(part) -- green button next to the pit, higher up
		setupTrollButton(part, "Pyong3")
	end,
}

local count = 0
for _, part in obby:GetDescendants() do
	local setup = setups[part.Name]
	if setup and part:IsA("BasePart") then
		setup(part)
		count += 1
	end
end
print("[ObbyParts] Set up " .. count .. " obby parts")

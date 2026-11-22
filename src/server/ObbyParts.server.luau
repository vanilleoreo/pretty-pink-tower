local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Must match the tower's name in Workspace exactly, including the 💥 at the start
local obby = workspace:WaitForChild("💥 Troll Tower Obby Parkour Fun Hard Easy")

-- Settings you can tweak
local DAMAGE_COOLDOWN = 0.2 -- seconds between hits from kill parts, so KILLPART-5 doesn't melt you instantly
local CONVEYOR_SPEED = 25 -- used if an AutoSpeed part has no Speed value inside it
local DISAPPEAR_DELAY = 0.4 -- seconds after you step on a disappearing part before it starts to fade

-- The final stage to the sofa: the black disappearing blocks after the door room
local FINAL_BLOCK_WIDTH = 6 -- studs across (they used to be tiny 1 x 1 stud blocks)
local FINAL_BLOCK_DEPTH = 4 -- studs along the path; the blocks are 7 studs apart, so this leaves 3-stud gaps
local FINAL_BLOCK_DELAY = 1.2 -- more time on them before they fade

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

		task.wait(part:GetAttribute("DisappearDelay") or DISAPPEAR_DELAY)
		TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		task.wait(0.3)
		part.CanCollide = false

		task.wait(3)
		part.CanCollide = startCanCollide
		part.Transparency = startTransparency
		fading[part] = nil
	end)
end

-- (Bounce Parts, the see-through boxes, are fly zones now: see src/client/FlyZones.client.luau)

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
-- dropping whoever is standing on it. The red/cyan button brings it back straight away.
local TROLL_PLATFORM_TIME = 3 -- seconds the platform stays gone

local platformLooks = {} -- what each troll platform normally looks like, so it can be put back
local platformHiddenAt = {} -- when each platform was made to vanish (nil while it's there)

local function findTrollPlatform(button, platformName)
	local platform = obby:FindFirstChild(platformName, true)
	if not (platform and platform:IsA("BasePart")) then
		warn("[ObbyParts] " .. button.Name .. " can't find its platform " .. platformName)
		return nil
	end
	if not platformLooks[platform] then
		platformLooks[platform] = { Transparency = platform.Transparency, CanCollide = platform.CanCollide }
	end
	return platform
end

local function showPlatform(platform)
	local look = platformLooks[platform]
	platform.Transparency = look.Transparency
	platform.CanCollide = look.CanCollide
	platformHiddenAt[platform] = nil
end

local function setupTrollButton(button, platformName)
	local platform = findTrollPlatform(button, platformName)
	if not platform then
		return
	end

	button.Touched:Connect(function(hit)
		if platformHiddenAt[platform] or not getCharacter(hit) then
			return
		end
		local hiddenAt = os.clock()
		platformHiddenAt[platform] = hiddenAt
		platform.Transparency = 1
		platform.CanCollide = false

		task.wait(TROLL_PLATFORM_TIME)
		-- Skip if a red/cyan button already brought it back (and it hasn't vanished again since)
		if platformHiddenAt[platform] == hiddenAt then
			showPlatform(platform)
		end
	end)
end

local function setupReturnButton(button, platformName)
	local platform = findTrollPlatform(button, platformName)
	if not platform then
		return
	end

	button.Touched:Connect(function(hit)
		if platformHiddenAt[platform] and getCharacter(hit) then
			showPlatform(platform)
		end
	end)
end

-- Which setup each part gets, by part name (names must match exactly, capitals too)
local setups = {
	["Disappearing Part"] = setupDisappearing,
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
	["Re2"] = function(part) -- red button on stage 1
		setupReturnButton(part, "Pyong2")
	end,
	["Re3"] = function(part) -- cyan button past the pit
		setupReturnButton(part, "Pyong3")
	end,
}

-- Make the final stage to the sofa easier: the 8 black blocks between the door room and the
-- sofa platform become proper little platforms (gaps of 3 studs instead of 6), and wait longer
-- before they vanish. They're the only tiny disappearing parts up at the top.
local finalBlocks = 0
for _, part in obby:GetDescendants() do
	if
		part:IsA("BasePart")
		and part.Name == "Disappearing Part"
		and part.Size.X <= 1.5
		and part.Size.Z <= 1.5
		and part.Position.Y > 390
	then
		-- The path runs along Z. These blocks are turned sideways, so check which way the part's own
		-- X side points before choosing which side gets the width and which the depth.
		-- (A part grows around its middle, so the top stays at the same height.)
		local sideways = math.abs(part.CFrame.RightVector.Z) > math.abs(part.CFrame.RightVector.X)
		part.Size = if sideways
			then Vector3.new(FINAL_BLOCK_DEPTH, part.Size.Y, FINAL_BLOCK_WIDTH)
			else Vector3.new(FINAL_BLOCK_WIDTH, part.Size.Y, FINAL_BLOCK_DEPTH)
		part:SetAttribute("DisappearDelay", FINAL_BLOCK_DELAY)
		finalBlocks += 1
	end
end
print("[ObbyParts] Made the " .. finalBlocks .. " final blocks to the sofa bigger")

local count = 0
for _, part in obby:GetDescendants() do
	local setup = setups[part.Name]
	if setup and part:IsA("BasePart") then
		setup(part)
		count += 1
	end
end
print("[ObbyParts] Set up " .. count .. " obby parts")

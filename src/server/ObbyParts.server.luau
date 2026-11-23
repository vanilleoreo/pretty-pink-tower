local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Must match the tower's name in Workspace exactly, including the 💥 at the start
local obby = workspace:WaitForChild("💥 Troll Tower Obby Parkour Fun Hard Easy")

-- Settings you can tweak
local DAMAGE_COOLDOWN = 0.2 -- seconds between hits from kill parts, so KILLPART-5 doesn't melt you instantly
local CONVEYOR_SPEED = 25 -- used if an AutoSpeed part has no Speed value inside it
local DISAPPEAR_DELAY = 0.4 -- seconds after you step on a disappearing part before it starts to fade

-- The final stage (the purple top floor and the path to the sofa) is made easy below
local EASY_PATH_COLOR = Color3.fromRGB(255, 160, 205) -- colour of the parts added to make it easy
local FINAL_BLOCK_WIDTH = 6 -- the black blocks to the sofa: studs across (they used to be 1 x 1)
local FINAL_BLOCK_DEPTH = 7 -- studs along the path: they're 7 apart, so they join into one path

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

		task.wait(DISAPPEAR_DELAY)
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

-- Easy final stage ------------------------------------------------------------------
-- The purple top floor of the tower and the path to the sofa were really hard, so:
--   * the red kill blocks up there are gone (on the purple floor and on the rainbow bridge)
--   * pink parts fill the gaps, so you can walk almost the whole way
--   * two pink climbing ladders: one up the corner, and one up to the rainbow bridge instead
--     of the disappearing platforms (they were 8 studs apart, too high to jump)
--   * the black blocks to the sofa join up into one path and don't disappear any more
-- All the new parts go in a folder called "EasyFinalStage" inside the tower.

-- Each filler is { one corner, the opposite corner }, measured from the place file
local FILLERS = {
	-- purple floor: steps between the stairs up the west wall, and on to the corner
	{ Vector3.new(-138.954, 351.29, 181.263), Vector3.new(-128.954, 352.29, 186.263) },
	{ Vector3.new(-138.954, 353.29, 196.263), Vector3.new(-128.954, 354.29, 201.263) },
	{ Vector3.new(-138.954, 355.29, 211.263), Vector3.new(-128.954, 356.29, 216.263) },
	{ Vector3.new(-138.954, 356.29, 226.263), Vector3.new(-128.954, 357.29, 231.263) },
	-- purple floor: the three gaps along the north side
	{ Vector3.new(-128.454, 374.34, 231.263), Vector3.new(-123.454, 375.34, 237.263) },
	{ Vector3.new(-112.454, 374.34, 231.263), Vector3.new(-107.454, 375.34, 237.263) },
	{ Vector3.new(-96.454, 374.34, 231.263), Vector3.new(-91.454, 375.34, 237.263) },
	-- purple floor: a wide walkway next to the thin beam on the east side
	{ Vector3.new(-86.454, 374.34, 170.263), Vector3.new(-81.454, 375.34, 231.263) },
	-- purple floor: a bigger landing in the south-east corner, up to the ladder
	{ Vector3.new(-98.454, 374.34, 171.263), Vector3.new(-86.454, 375.34, 176.263) },
	{ Vector3.new(-98.454, 374.34, 170.263), Vector3.new(-95.454, 375.34, 171.263) },
	-- rainbow bridge: the gaps between the coloured parts, and on to the door room
	{ Vector3.new(-112.454, 398.34, 156.263), Vector3.new(-98.454, 399.34, 158.263) },
	{ Vector3.new(-112.454, 398.34, 143.263), Vector3.new(-98.454, 399.34, 145.263) },
	{ Vector3.new(-112.454, 398.34, 130.263), Vector3.new(-98.454, 399.34, 132.263) },
	{ Vector3.new(-112.454, 398.34, 117.263), Vector3.new(-98.454, 399.34, 119.263) },
	{ Vector3.new(-112.454, 398.34, 104.263), Vector3.new(-98.454, 399.34, 106.263) },
	{ Vector3.new(-112.454, 398.34, 91.263), Vector3.new(-98.454, 399.34, 93.263) },
	{ Vector3.new(-112.454, 398.34, 78.263), Vector3.new(-98.454, 399.34, 80.263) },
	{ Vector3.new(-112.454, 398.34, 65.263), Vector3.new(-98.454, 399.34, 67.263) },
	-- black path to the sofa: from the door room to the first block, and from the last block to the sofa
	{ Vector3.new(-108.454, 398.34, 19.263), Vector3.new(-102.454, 399.34, 22.263) },
	{ Vector3.new(-108.454, 398.34, -39.737), Vector3.new(-102.454, 399.34, -36.737) },
}

-- Climbing ladders: { bottom middle, height }
local LADDERS = {
	{ Vector3.new(-133.954, 357.29, 230.263), 20 }, -- up the corner of the purple floor
	{ Vector3.new(-99.454, 375.34, 171.263), 26 }, -- from the south-east corner up to the rainbow bridge
}

local easyStage = Instance.new("Folder")
easyStage.Name = "EasyFinalStage"

local function smooth(part: BasePart)
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = EASY_PATH_COLOR
	part.Parent = easyStage
end

for _, corners in FILLERS do
	local filler = Instance.new("Part")
	filler.Name = "EasyPath"
	filler.Size = corners[2] - corners[1]
	filler.CFrame = CFrame.new((corners[1] + corners[2]) / 2)
	smooth(filler)
end

for _, info in LADDERS do
	local bottom, height = info[1], info[2]
	local ladder = Instance.new("TrussPart")
	ladder.Name = "EasyLadder"
	ladder.Size = Vector3.new(2, height, 2)
	ladder.CFrame = CFrame.new(bottom + Vector3.new(0, height / 2, 0))
	smooth(ladder)
end

local removedKillParts, finalBlocks = 0, 0
for _, part in obby:GetDescendants() do
	if not part:IsA("BasePart") then
		continue
	end
	if string.find(part.Name, "KILLPART", 1, true) and part.Position.Y > 370 then
		-- the red kill blocks on the purple floor and the red strips on the rainbow bridge
		part:Destroy()
		removedKillParts += 1
	elseif part.Name == "Disappearing Part" and part.Size.X <= 1.5 and part.Size.Z <= 1.5 and part.Position.Y > 390 then
		-- the tiny black blocks to the sofa: make them big enough to join into one path. The path
		-- runs along Z and these blocks are turned sideways, so check which way the part's own
		-- X side points. (A part grows around its middle, so the top stays at the same height.)
		local sideways = math.abs(part.CFrame.RightVector.Z) > math.abs(part.CFrame.RightVector.X)
		part.Size = if sideways
			then Vector3.new(FINAL_BLOCK_DEPTH, part.Size.Y, FINAL_BLOCK_WIDTH)
			else Vector3.new(FINAL_BLOCK_WIDTH, part.Size.Y, FINAL_BLOCK_DEPTH)
		part.Name = "Final Block" -- a new name, so it isn't set up as a disappearing part below
		finalBlocks += 1
	end
end

easyStage.Parent = obby
print(
	`[ObbyParts] Easy final stage: {#FILLERS} pink path parts, {#LADDERS} ladders, `
		.. `{removedKillParts} kill parts removed, {finalBlocks} black blocks joined into a path`
)

local count = 0
for _, part in obby:GetDescendants() do
	local setup = setups[part.Name]
	if setup and part:IsA("BasePart") then
		setup(part)
		count += 1
	end
end
print("[ObbyParts] Set up " .. count .. " obby parts")
obby:SetAttribute("ObbyReady", true) -- the cherry blossoms wait for this, so none end up on the new parts

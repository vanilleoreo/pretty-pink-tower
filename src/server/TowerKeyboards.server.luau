-- Pink ASMR keyboards in the tower: two on the ground floor (one each side of the cherry tree),
-- a keyboard rug in front of the sofa at the finish, and keyboards on the platforms of every
-- level up the tower (a different pink on each level). Each one has a border and some sparkly
-- keys in a second shade, like a real keyboard.
--
-- The keys are copies of the keycaps from the big keyboard in the keyboard room, put in the same
-- folder, so they sink and click when you walk on them just like those (Keyboard.client.luau).
local KEYBOARDS = {
	{
		name = "Hot pink (ground floor, west)",
		from = Vector2.new(-135.5, 176), -- corners, as (x, z)
		to = Vector2.new(-120.5, 224),
		floorSearchFrom = 30, -- start looking for the floor from this high
		main = Color3.fromRGB(255, 105, 180), -- hot pink
		accent = Color3.fromRGB(255, 190, 220), -- light pink
	},
	{
		name = "Baby pink (ground floor, east)",
		from = Vector2.new(-96, 176),
		to = Vector2.new(-85, 224),
		floorSearchFrom = 30,
		main = Color3.fromRGB(255, 194, 216), -- baby pink
		accent = Color3.fromRGB(255, 128, 184), -- bubblegum pink
	},
	{
		name = "Raspberry (finish, in front of the sofa)",
		from = Vector2.new(-119, -55),
		to = Vector2.new(-92, -42),
		floorSearchFrom = 410, -- under the finish room's roof
		main = Color3.fromRGB(232, 84, 150), -- raspberry pink
		accent = Color3.fromRGB(255, 226, 240), -- blush white
	},
}
local SPACING = 1.34 -- studs between keys, the same as the big keyboard
local SPARKLE_KEYS = 0.07 -- share of the keys inside the border that get the second shade

local keyboardSystem = workspace:WaitForChild("KeyboardSystem", 30)
local keycaps = keyboardSystem and keyboardSystem:WaitForChild("Keycaps", 30)
local template = keycaps and keycaps:FindFirstChildWhichIsA("MeshPart", true)
if not template then
	warn("[TowerKeyboards] Couldn't find a keycap to copy in KeyboardSystem.Keycaps, so no keyboards in the tower")
	return
end

local rng = Random.new(77) -- same pattern of sparkly keys in every server

local folder = Instance.new("Folder")
folder.Name = "TowerKeyboards"

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.FilterDescendantsInstances = { folder, keycaps }
floorParams.RespectCanCollide = true

local keyHeight = template.Size.Y
local total, made = 0, 0

for _, keyboard in KEYBOARDS do
	local center = (keyboard.from + keyboard.to) / 2
	local hit = workspace:Raycast(
		Vector3.new(center.X, keyboard.floorSearchFrom, center.Y),
		Vector3.new(0, -60, 0),
		floorParams
	)
	if not hit then
		warn(`[TowerKeyboards] No floor under the {keyboard.name} keyboard: skipped`)
		continue
	end

	-- as many keys as fit, centred in the area
	local size = keyboard.to - keyboard.from
	local columns = math.floor(math.abs(size.X) / SPACING)
	local rows = math.floor(math.abs(size.Y) / SPACING)
	local startX = center.X - (columns - 1) * SPACING / 2
	local startZ = center.Y - (rows - 1) * SPACING / 2
	local y = hit.Position.Y + keyHeight / 2 + 0.05 -- sitting just on the floor

	local board = Instance.new("Folder")
	board.Name = keyboard.name
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local onBorder = column == 0 or row == 0 or column == columns - 1 or row == rows - 1
			local key = template:Clone()
			key.Name = "keycap"
			key.Anchored = true
			key.CanCollide = false
			key.CanTouch = false
			key.CFrame = CFrame.new(startX + column * SPACING, y, startZ + row * SPACING) * template.CFrame.Rotation
			key.Color = if onBorder or rng:NextNumber() < SPARKLE_KEYS then keyboard.accent else keyboard.main
			key.Parent = board
			total += 1
		end
	end
	board.Parent = folder
	made += 1
end

-- in the big keyboard's folder, so its script makes these keys sink and click too
folder.Parent = keycaps
print(`[TowerKeyboards] Made {made} pink keyboards in the tower with {total} keys`)

-- Keyboards on the levels up the tower --------------------------------------------------
-- Every plain platform inside the tower that's big enough gets a keyboard on top. Platforms with
-- anything on or just above them (kill blocks, fly zones, teleports, the next platform) are left
-- alone, and so are special parts (ice, disappearing, conveyors, troll platforms), because
-- only parts called "Part" are used. Each level has its own shade of pink.

local TOWER_NAME = "💥 Troll Tower Obby Parkour Fun Hard Easy"
local INSIDE = { minX = -139.6, maxX = -71.3, minZ = 170.1, maxZ = 238.4 } -- inside the tower's walls
local LEVEL_HEIGHT = 50
local LEVEL_SHADES = { -- { main, border and sparkles }, from level 1 at the bottom to level 8 at the top
	{ Color3.fromRGB(255, 209, 224), Color3.fromRGB(255, 140, 180) }, -- 1 blush
	{ Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 230, 242) }, -- 2 bubblegum
	{ Color3.fromRGB(252, 142, 172), Color3.fromRGB(255, 214, 226) }, -- 3 flamingo
	{ Color3.fromRGB(255, 188, 217), Color3.fromRGB(240, 98, 160) }, -- 4 cotton candy
	{ Color3.fromRGB(255, 145, 164), Color3.fromRGB(255, 222, 228) }, -- 5 salmon pink
	{ Color3.fromRGB(255, 102, 153), Color3.fromRGB(255, 205, 225) }, -- 6 rose
	{ Color3.fromRGB(242, 140, 210), Color3.fromRGB(255, 225, 245) }, -- 7 orchid pink
	{ Color3.fromRGB(230, 70, 150), Color3.fromRGB(255, 190, 225) }, -- 8 magenta
}
local MIN_PLATFORM_SIZE = 6 -- studs; smaller platforms don't get a keyboard
local LEVEL_PRESS_DEPTH = 0.6 -- the platforms are thin, so these keys only sink a little

local tower = workspace:WaitForChild(TOWER_NAME, 30)
if not tower then
	return
end
-- wait for ObbyParts to finish (it removes the kill blocks on the top floor first)
local waited = 0
while not tower:GetAttribute("ObbyReady") and waited < 15 do
	waited += task.wait(0.2)
end

local levels = Instance.new("Folder")
levels.Name = "Tower levels"

local aboveParams = OverlapParams.new()
aboveParams.FilterType = Enum.RaycastFilterType.Exclude
aboveParams.FilterDescendantsInstances = { keycaps, levels }

local function hasKeyboardSpace(part: BasePart): boolean
	if part.Name ~= "Part" or part.ClassName ~= "Part" or (part :: Part).Shape ~= Enum.PartType.Block then
		return false
	end
	if not part.CanCollide or part.Transparency >= 0.5 or part.CFrame.UpVector.Y < 0.99 then
		return false -- see-through, not solid, or not lying flat
	end
	local size, position = part.Size, part.Position
	if size.Y > 2.1 or size.X < MIN_PLATFORM_SIZE or size.Z < MIN_PLATFORM_SIZE then
		return false -- a wall or block, or too small
	end
	local top = position.Y + size.Y / 2
	if top < 20 or top > 398 then
		return false -- the ground floor has its own keyboards; the top of the tower is the way out
	end
	-- (the platform is flat, so it's only turned around the vertical; check its corners are inside)
	local halfX = math.abs(part.CFrame.RightVector.X) * size.X / 2 + math.abs(part.CFrame.LookVector.X) * size.Z / 2
	local halfZ = math.abs(part.CFrame.RightVector.Z) * size.X / 2 + math.abs(part.CFrame.LookVector.Z) * size.Z / 2
	if
		position.X - halfX < INSIDE.minX
		or position.X + halfX > INSIDE.maxX
		or position.Z - halfZ < INSIDE.minZ
		or position.Z + halfZ > INSIDE.maxZ
	then
		return false
	end
	-- nothing sitting on it or hanging just above it
	aboveParams.FilterDescendantsInstances = { keycaps, levels, part }
	local above = workspace:GetPartBoundsInBox(
		part.CFrame * CFrame.new(0, size.Y / 2 + 2.52, 0),
		Vector3.new(size.X - 0.1, 5, size.Z - 0.1),
		aboveParams
	)
	return #above == 0
end

local levelKeys, levelBoards = 0, 0
for _, part in tower:GetDescendants() do
	if not part:IsA("BasePart") or not hasKeyboardSpace(part) then
		continue
	end
	local top = part.Position.Y + part.Size.Y / 2
	local level = math.clamp(math.floor((top + 1) / LEVEL_HEIGHT) + 1, 1, #LEVEL_SHADES)
	local main, accent = LEVEL_SHADES[level][1], LEVEL_SHADES[level][2]

	local columns = math.floor((part.Size.X - 0.2) / SPACING)
	local rows = math.floor((part.Size.Z - 0.2) / SPACING)
	local board = Instance.new("Folder")
	board.Name = `Level {level}`
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local onBorder = column == 0 or row == 0 or column == columns - 1 or row == rows - 1
			local key = template:Clone()
			key.Name = "keycap"
			key.Anchored = true
			key.CanCollide = false
			key.CanTouch = false
			key.CFrame = part.CFrame
				* CFrame.new(
					(column - (columns - 1) / 2) * SPACING,
					part.Size.Y / 2 + keyHeight / 2 + 0.05,
					(row - (rows - 1) / 2) * SPACING
				)
			key.Color = if onBorder or rng:NextNumber() < SPARKLE_KEYS then accent else main
			key:SetAttribute("PressDepth", LEVEL_PRESS_DEPTH)
			key.Parent = board
			levelKeys += 1
		end
	end
	board.Parent = levels
	levelBoards += 1
end

levels.Parent = folder
print(`[TowerKeyboards] Made {levelBoards} keyboards on the levels up the tower with {levelKeys} keys`)

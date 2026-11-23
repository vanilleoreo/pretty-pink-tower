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

-- Keyboards everywhere on every stage of the tower ------------------------------------------
-- Every platform in the tower gets keys on top, all the way up to the path to the sofa. A key is
-- left out only where something is right on that spot (a wall, the next ladder rung, a
-- checkpoint...) and near kill parts, so the red danger stays easy to see. Keys on disappearing
-- and troll-button platforms vanish together with their platform. Each level has its own pink.

local PLATFORM_NAMES = { -- which parts count as platforms (kill parts and the finish don't)
	["Part"] = true,
	["Ice Part"] = true,
	["Disappearing Part"] = true,
	["AutoSpeed"] = true, -- conveyors
	["Pyong2"] = true, -- troll platforms (a button hides them)
	["Pyong3"] = true,
	["gnoyP"] = true,
	["gnopq"] = true,
	["EasyPath"] = true, -- the pink parts of the easy final stage
	["Final Block"] = true, -- the black path to the sofa
}
local VANISHING = { ["Disappearing Part"] = true, ["Pyong2"] = true, ["Pyong3"] = true }
local TOWER_NAME = "💥 Troll Tower Obby Parkour Fun Hard Easy"
local LEVEL_HEIGHT = 50
local LEVEL_SHADES = { -- { main, border and sparkles }, from level 1 at the bottom upwards
	{ Color3.fromRGB(255, 209, 224), Color3.fromRGB(255, 140, 180) }, -- 1 blush
	{ Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 230, 242) }, -- 2 bubblegum
	{ Color3.fromRGB(252, 142, 172), Color3.fromRGB(255, 214, 226) }, -- 3 flamingo
	{ Color3.fromRGB(255, 188, 217), Color3.fromRGB(240, 98, 160) }, -- 4 cotton candy
	{ Color3.fromRGB(255, 145, 164), Color3.fromRGB(255, 222, 228) }, -- 5 salmon pink
	{ Color3.fromRGB(255, 102, 153), Color3.fromRGB(255, 205, 225) }, -- 6 rose
	{ Color3.fromRGB(242, 140, 210), Color3.fromRGB(255, 225, 245) }, -- 7 orchid pink
	{ Color3.fromRGB(230, 70, 150), Color3.fromRGB(255, 190, 225) }, -- 8 magenta
	{ Color3.fromRGB(255, 182, 207), Color3.fromRGB(255, 105, 180) }, -- the final stage to the sofa: pearl pink
}
local KEY_SCALE = 1.5 -- tower keys are 1.5 times bigger than the keyboard room's, so there aren't too many
local LEVEL_PRESS_DEPTH = 0.6 -- platforms can be thin, so these keys only sink a little
local KEEP_CLEAR = 0.4 -- studs around a key that have to be empty
local KILL_CLEARANCE = 1.5 -- studs of no keys around kill parts

local tower = workspace:WaitForChild(TOWER_NAME, 30)
if not tower then
	return
end
-- wait for ObbyParts to finish (it adds the easy final stage and removes some kill parts first)
local waited = 0
while not tower:GetAttribute("ObbyReady") and waited < 15 do
	waited += task.wait(0.2)
end

local levels = Instance.new("Folder")
levels.Name = "Tower levels"

local killParts = {}
for _, part in tower:GetDescendants() do
	if part:IsA("BasePart") and string.find(part.Name, "KILLPART", 1, true) then
		table.insert(killParts, part)
	end
end

local spotParams = OverlapParams.new()
spotParams.FilterType = Enum.RaycastFilterType.Exclude
local killParams = OverlapParams.new()
killParams.FilterType = Enum.RaycastFilterType.Include
killParams.FilterDescendantsInstances = killParts

local keySize = template.Size * Vector3.new(KEY_SCALE, 1.2, KEY_SCALE)
local pitch = SPACING * KEY_SCALE

local function isPlatform(part: BasePart): boolean
	if not PLATFORM_NAMES[part.Name] or part.ClassName ~= "Part" or (part :: Part).Shape ~= Enum.PartType.Block then
		return false
	end
	if not part.Anchored or not part.CanCollide or part.Transparency >= 0.5 then
		return false -- swinging, not solid, or see-through
	end
	if part.CFrame.UpVector.Y < 0.99 or part.Size.X < pitch or part.Size.Z < pitch then
		return false -- not lying flat, or too small for even one key
	end
	local top = part.Position.Y + part.Size.Y / 2
	return top > 1 and top < 401 -- the ground floor has its own keyboards
end

local levelKeys, levelBoards, built = 0, 0, 0
for _, part in tower:GetDescendants() do
	if not part:IsA("BasePart") or not isPlatform(part) then
		continue
	end
	local top = part.Position.Y + part.Size.Y / 2
	local level = math.clamp(math.floor((top + 1) / LEVEL_HEIGHT) + 1, 1, #LEVEL_SHADES)
	local main, accent = LEVEL_SHADES[level][1], LEVEL_SHADES[level][2]
	spotParams.FilterDescendantsInstances = { keycaps, levels, part }

	local columns = math.floor((part.Size.X - 0.2) / pitch)
	local rows = math.floor((part.Size.Z - 0.2) / pitch)
	local keys = {}
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local spot = part.CFrame
				* CFrame.new((column - (columns - 1) / 2) * pitch, part.Size.Y / 2 + keySize.Y / 2 + 0.05, (row - (rows - 1) / 2) * pitch)
			-- is this spot free, and not close to a kill part?
			local busy = workspace:GetPartBoundsInBox(
				spot * CFrame.new(0, 0.15, 0),
				Vector3.new(pitch + KEEP_CLEAR * 2, keySize.Y + 0.3, pitch + KEEP_CLEAR * 2),
				spotParams
			)
			if #busy > 0 then
				continue
			end
			local danger = workspace:GetPartBoundsInBox(
				spot,
				Vector3.new(pitch + KILL_CLEARANCE * 2, 3, pitch + KILL_CLEARANCE * 2),
				killParams
			)
			if #danger > 0 then
				continue
			end

			local onBorder = column == 0 or row == 0 or column == columns - 1 or row == rows - 1
			local key = template:Clone()
			key.Name = "keycap"
			key.Anchored = true
			key.CanCollide = false
			key.CanTouch = false
			key.Size = keySize
			key.CFrame = spot
			key.Color = if onBorder or rng:NextNumber() < SPARKLE_KEYS then accent else main
			key:SetAttribute("PressDepth", LEVEL_PRESS_DEPTH)
			table.insert(keys, key)
		end
	end
	if #keys == 0 then
		continue
	end

	local board = Instance.new("Folder")
	board.Name = `Level {level}`
	for _, key in keys do
		key.Parent = board
	end
	board.Parent = levels
	levelKeys += #keys
	levelBoards += 1

	-- keys on disappearing and troll platforms disappear and come back with them
	if VANISHING[part.Name] then
		part:GetPropertyChangedSignal("Transparency"):Connect(function()
			for _, key in keys do
				key.Transparency = part.Transparency
			end
		end)
	end

	built += 1
	if built % 20 == 0 then
		task.wait() -- give the server a breather while building thousands of keys
	end
end

levels.Parent = folder
print(`[TowerKeyboards] Made {levelBoards} keyboards on every stage of the tower with {levelKeys} keys`)

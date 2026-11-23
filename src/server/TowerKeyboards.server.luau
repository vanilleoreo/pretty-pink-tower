-- Pink ASMR keyboards in the tower: two on the ground floor (one each side of the cherry tree)
-- and a keyboard rug in front of the sofa at the finish. Each one is a different shade of pink,
-- with a border and some sparkly keys in a second shade, like a real keyboard.
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

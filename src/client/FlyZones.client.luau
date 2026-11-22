-- Fly zones: the see-through boxes in the Troll Tower (named "Bounce Part").
-- Step into one and you float up to its top, which lines up with the next platform,
-- then hover there until you walk off. This runs on your own computer because that's
-- what moves your character, so it's smooth and has no lag.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FLY_SPEED = 25 -- how fast you rise, in studs per second
local HOVER_HEIGHT = 0.5 -- how far above the top of the box your feet float
local FEET_BELOW_ROOT = 3 -- distance from the middle of a character down to its feet

local player = Players.LocalPlayer
local tower = workspace:WaitForChild("💥 Troll Tower Obby Parkour Fun Hard Easy")

local zones = {}

local function addZone(part)
	if part.Name == "Bounce Part" and part:IsA("BasePart") then
		zones[part] = true
	end
end

for _, part in tower:GetDescendants() do
	addZone(part)
end
tower.DescendantAdded:Connect(addZone) -- parts load in as you get close (streaming)

-- Returns the zone your feet are in, and where your feet are inside it
local function findZone(feet)
	for zone in zones do
		if not zone:IsDescendantOf(workspace) then
			zones[zone] = nil -- unloaded because you went far away
			continue
		end
		local offset = zone.CFrame:PointToObjectSpace(feet)
		local half = zone.Size / 2
		-- A bit of extra room above the top so you can hover level with the next platform
		if
			math.abs(offset.X) <= half.X
			and math.abs(offset.Z) <= half.Z
			and offset.Y >= -half.Y
			and offset.Y <= half.Y + HOVER_HEIGHT + 1
		then
			return zone, offset.Y, half.Y
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) or humanoid.Health <= 0 then
		return
	end

	local feet = root.Position - Vector3.new(0, FEET_BELOW_ROOT, 0)
	local zone, feetHeight, halfHeight = findZone(feet)
	if not zone then
		return
	end

	-- Lift off if standing on the floor, so walking doesn't hold you down
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	-- Rise at FLY_SPEED, slowing down as you reach the hover height so you stop smoothly
	local distanceToGo = halfHeight + HOVER_HEIGHT - feetHeight
	local rise = math.clamp(distanceToGo * 6, -FLY_SPEED, FLY_SPEED)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, rise, velocity.Z)
end)

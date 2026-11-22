local Players = game:GetService("Players")

-- New checkpoints in the Troll Tower, one every 3 levels (each level is 50 studs tall).
-- These pads are made when the game starts, so you'll only see them in Play mode.
-- If you ever move the tower, move these positions with it.
local TOWER_CHECKPOINTS = {
	Vector3.new(-76.45, 152.34, 223.3), -- start of level 4: green platform after the wall steps
	Vector3.new(-78.45, 299.34, 246.76), -- start of level 7: landing before the rainbow stairs
}

local lastCheckpoint = {} -- [player] = the checkpoint they touched last

local function setupCheckpoint(part)
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			lastCheckpoint[player] = part
		end
	end)
end

-- The pink "Checkpoint" pads already in Workspace: take over from their old scripts so every
-- checkpoint uses this one system
for _, part in workspace:GetChildren() do
	if part.Name == "Checkpoint" and part:IsA("BasePart") then
		for _, old in part:GetChildren() do
			if old:IsA("Script") then
				old.Enabled = false
				old:Destroy()
			end
		end
		setupCheckpoint(part)
	end
end

-- The new tower checkpoints: flat pink pads you walk through, so they don't change any jumps
local folder = Instance.new("Folder")
folder.Name = "TowerCheckpoints"
folder.Parent = workspace

for _, position in TOWER_CHECKPOINTS do
	local pad = Instance.new("Part")
	pad.Name = "Checkpoint"
	pad.Anchored = true
	pad.CanCollide = false
	pad.CastShadow = false
	pad.Size = Vector3.new(8, 0.2, 4)
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(255, 105, 180)
	pad.Transparency = 0.3
	pad.Position = position + Vector3.new(0, 0.1, 0)
	pad.Parent = folder
	setupCheckpoint(pad)
end

-- Put players back on their last checkpoint every time they respawn
local function onCharacterAdded(player, character)
	local checkpoint = lastCheckpoint[player]
	if not (checkpoint and checkpoint.Parent) then
		return
	end
	character:WaitForChild("HumanoidRootPart")
	local target = checkpoint.Position + Vector3.new(0, 4, 0)

	-- Streaming is on, so load the area for them first, or they'd fall through the platform
	pcall(player.RequestStreamAroundAsync, player, target, 5)
	if character.Parent then
		character:PivotTo(CFrame.new(target))
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastCheckpoint[player] = nil
end)

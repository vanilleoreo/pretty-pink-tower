-- The giant keyboard (Workspace.KeyboardSystem): keys you step on sink down and click.
-- This is the keyboard's own script, moved here because LocalScripts don't run in Workspace.
-- It only moves keys on your own screen, the same as the original.
-- It also works for the pink keyboards in the tower (TowerKeyboards.server.luau), because those
-- keys are put inside KeyboardSystem.Keycaps too.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local keyboard = workspace:WaitForChild("KeyboardSystem")
local keycaps = keyboard:WaitForChild("Keycaps")
local soundFolder = keyboard:WaitForChild("Sounds")

local CONFIG = {
	BASE_DETECTION_SIZE = Vector3.new(2.5, 5, 2.5),
	LERP_SPEED_DOWN = 20,
	LERP_SPEED_UP = 8,
	HOLD_TIME = 0.15,
	VELOCITY_PADDING = 1.2,
	SOUND_COOLDOWN = 0.03,
	PRESS_DEPTH = 1.4, -- keys can have their own "PressDepth" attribute instead (the tower ones sink less)
	VOLUME = 1,
}

local randomGenerator = Random.new()
local activeKeys = {} -- keys that are pressed or still springing back
local keyStates = {}
local lastSoundPlayTime = 0

local soundIds = {}
for _, child in soundFolder:GetChildren() do
	if child:IsA("Sound") and child.SoundId ~= "" then
		table.insert(soundIds, child.SoundId)
	end
end

local function newSound()
	local sound = Instance.new("Sound")
	sound.RollOffMaxDistance = 100
	sound.RollOffMinDistance = 10
	return sound
end

local soundPool = {}
for i = 1, 40 do
	soundPool[i] = newSound()
end
local soundPoolIndex = 1

local function playClick(part)
	if #soundIds == 0 or CONFIG.VOLUME <= 0 then
		return
	end
	local sound = soundPool[soundPoolIndex]
	-- If the key it was last played on unloaded (streaming), the old sound is gone, so make a new one
	if not pcall(function()
		sound.Parent = part
	end) then
		sound = newSound()
		soundPool[soundPoolIndex] = sound
		sound.Parent = part
	end
	soundPoolIndex = (soundPoolIndex % #soundPool) + 1

	sound.SoundId = soundIds[randomGenerator:NextInteger(1, #soundIds)]
	sound.Volume = CONFIG.VOLUME
	sound:Play()
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams:AddToFilter(keycaps)

RunService.RenderStepped:Connect(function(deltaTime)
	local currentTime = os.clock()
	local character = LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if rootPart then
		-- Look a bit further ahead when moving fast, so keys don't get skipped
		local velocity = rootPart.AssemblyLinearVelocity
		local extraWidthX = math.abs(velocity.X) * deltaTime * CONFIG.VELOCITY_PADDING
		local extraWidthZ = math.abs(velocity.Z) * deltaTime * CONFIG.VELOCITY_PADDING
		local detectionBoxSize = CONFIG.BASE_DETECTION_SIZE + Vector3.new(extraWidthX, 0, extraWidthZ)

		local detectedParts =
			workspace:GetPartBoundsInBox(rootPart.CFrame * CFrame.new(0, -2.5, 0), detectionBoxSize, overlapParams)

		for _, part in detectedParts do
			local state = keyStates[part]
			if not state then
				state = {
					currentAlpha = 0,
					targetAlpha = 0,
					lastHit = 0,
					originalCF = part.CFrame,
					depth = part:GetAttribute("PressDepth") or CONFIG.PRESS_DEPTH,
				}
				keyStates[part] = state
			end

			if state.targetAlpha == 0 and currentTime - lastSoundPlayTime >= CONFIG.SOUND_COOLDOWN then
				playClick(part)
				lastSoundPlayTime = currentTime
			end

			state.targetAlpha = 1
			state.lastHit = currentTime
			activeKeys[part] = true
		end
	end

	local partsToMove = {}
	local targetCFrames = {}

	for part in activeKeys do
		local state = keyStates[part]

		-- Keys far away can unload (streaming); forget them instead of moving them
		if not part:IsDescendantOf(workspace) then
			activeKeys[part] = nil
			keyStates[part] = nil
			continue
		end

		if currentTime - state.lastHit > CONFIG.HOLD_TIME then
			state.targetAlpha = 0
		end

		local lerpSpeed = if state.targetAlpha == 1 then CONFIG.LERP_SPEED_DOWN else CONFIG.LERP_SPEED_UP
		state.currentAlpha += (state.targetAlpha - state.currentAlpha) * math.clamp(deltaTime * lerpSpeed, 0, 1)

		local nextCFrame
		if state.targetAlpha == 0 and state.currentAlpha < 0.01 then
			state.currentAlpha = 0
			nextCFrame = state.originalCF
			activeKeys[part] = nil
		else
			nextCFrame = state.originalCF * CFrame.new(0, -state.currentAlpha * state.depth, 0)
		end

		table.insert(partsToMove, part)
		table.insert(targetCFrames, nextCFrame)
	end

	if #partsToMove > 0 then
		workspace:BulkMoveTo(partsToMove, targetCFrames)
	end
end)

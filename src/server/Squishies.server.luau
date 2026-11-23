-- Squishy jumps in the tower: on every level, some jumps are big soft squishies (the Needoh from the
-- ASMR area) instead of plain platforms. When anyone lands on one, it squashes down, bulges out
-- and wobbles back with a squish sound and a little puff. (Squishies.client.luau does the squish
-- on everyone's screen, so it looks smooth.)
--
-- The real platform stays exactly where it was, just invisible, so every jump is exactly as long
-- and as high as before. The squishy sitting on it is only for looks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TOWER_NAME = "💥 Troll Tower Obby Parkour Fun Hard Easy"
-- The top middle of each platform that becomes a squishy, its colour, and (where there isn't much
-- room under the platform) how tall the squishy is; otherwise it's about half as tall as it's wide
local SQUISHIES = {
	{ Vector3.new(-122.45, 29.34, 233.26), Color3.fromRGB(255, 170, 205) }, -- level 1: pink
	{ Vector3.new(-100.45, 59.34, 175.26), Color3.fromRGB(200, 170, 255) }, -- level 2: lilac
	{ Vector3.new(-76.45, 51.34, 231.26), Color3.fromRGB(215, 190, 255), 2.2 }, -- level 2: lavender cushion
	{ Vector3.new(-76.45, 53.34, 175.26), Color3.fromRGB(255, 150, 200), 4.2 }, -- level 2: bubblegum
	{ Vector3.new(-107.45, 115.34, 185.26), Color3.fromRGB(165, 235, 200) }, -- level 3: mint
	{ Vector3.new(-77.45, 102.34, 225.26), Color3.fromRGB(150, 220, 255), 3.2 }, -- level 3: sky blue
	{ Vector3.new(-127.45, 115.34, 185.26), Color3.fromRGB(255, 185, 140), 4.4 }, -- level 3: apricot
	{ Vector3.new(-128.45, 159.5, 175.26), Color3.fromRGB(255, 200, 160) }, -- level 4: peach
	{ Vector3.new(-76.45, 159.5, 175.95), Color3.fromRGB(150, 240, 220), 5.5 }, -- level 4: seafoam
	{ Vector3.new(-128.45, 175.5, 232.26), Color3.fromRGB(255, 120, 160), 5.5 }, -- level 4: rose
	{ Vector3.new(-133.45, 230.34, 190.26), Color3.fromRGB(165, 210, 255) }, -- level 5: baby blue
	{ Vector3.new(-76.45, 199.34, 233.26), Color3.fromRGB(180, 180, 255), 5.5 }, -- level 5: periwinkle
	{ Vector3.new(-131.45, 202.34, 175.26), Color3.fromRGB(255, 245, 200), 3.2 }, -- level 5: cream
	{ Vector3.new(-98.95, 264.34, 199.76), Color3.fromRGB(255, 236, 150) }, -- level 6: lemon
	{ Vector3.new(-124.45, 286.34, 230.26), Color3.fromRGB(255, 190, 210), 5.5 }, -- level 6: strawberry milk
	{ Vector3.new(-133.95, 343.29, 175.76), Color3.fromRGB(255, 140, 170) }, -- level 7: coral
	{ Vector3.new(-101.95, 375.34, 234.26), Color3.fromRGB(230, 150, 255) }, -- level 8: orchid
	{ Vector3.new(-133.95, 353.29, 191.26), Color3.fromRGB(200, 150, 255), 4.2 }, -- level 8: grape
	{ Vector3.new(-133.95, 355.29, 206.26), Color3.fromRGB(190, 255, 170), 5.5 }, -- level 8: melon
}
local SQUISH_SOUND = "rbxassetid://119626733196698" -- the same squish sound as the Needohs
local SINK = 0.35 -- how far your feet sink into the top of a squishy
local SQUISH_COOLDOWN = 0.35 -- seconds before the same squishy can squish again

local tower = workspace:WaitForChild(TOWER_NAME, 30)
if not tower then
	return
end

local squishEvent = Instance.new("RemoteEvent") -- (the squishy) to everyone: "this one got squished"
squishEvent.Name = "Squish"
squishEvent.Parent = ReplicatedStorage

local function finish()
	tower:SetAttribute("SquishiesReady", true) -- the tower keyboards wait for this, so they skip squishies
end

local needoh = workspace:FindFirstChild("Needoh")
if not (needoh and needoh:IsA("MeshPart")) then
	warn("[Squishies] Couldn't find a Needoh to copy, so no squishy jumps")
	finish()
	return
end

-- Find each platform by where its top middle is
local platforms: { [number]: BasePart } = {}
for _, part in tower:GetDescendants() do
	if part:IsA("BasePart") and part.Name == "Part" then
		local top = part.Position.Y + part.Size.Y / 2
		for index, info in SQUISHIES do
			local spot = info[1]
			if
				math.abs(part.Position.X - spot.X) < 0.3
				and math.abs(part.Position.Z - spot.Z) < 0.3
				and math.abs(top - spot.Y) < 0.3
			then
				platforms[index] = part
			end
		end
	end
end

local folder = Instance.new("Folder")
folder.Name = "Squishies"

local function makeSquishy(platform: BasePart, color: Color3, tallness: number?): MeshPart
	local size = platform.Size
	local height = tallness or math.clamp(math.min(size.X, size.Z) * 0.55, 3.5, 6)
	local top = platform.Position.Y + size.Y / 2

	local squishy = needoh:Clone()
	for _, child in squishy:GetChildren() do
		child:Destroy() -- leave the Needoh's own squish script behind
	end
	squishy.Name = "Squishy"
	squishy.Anchored = true
	squishy.CanCollide = false -- you stand on the invisible platform underneath
	squishy.CanTouch = false
	squishy.CanQuery = false
	squishy.Size = Vector3.new(size.X * 1.08, height, size.Z * 1.08)
	squishy.CFrame = CFrame.new(platform.Position.X, top + SINK - height / 2, platform.Position.Z)
		* platform.CFrame.Rotation
	squishy.Color = color
	squishy.Material = Enum.Material.SmoothPlastic

	-- the sound and puff, played by Squishies.client.luau
	local effects = Instance.new("Attachment")
	effects.Name = "SquishEffects"
	effects.Position = Vector3.new(0, height / 2 - 0.2, 0)
	effects.Parent = squishy

	local sound = Instance.new("Sound")
	sound.Name = "SquishSound"
	sound.SoundId = SQUISH_SOUND
	sound.Volume = 0.8
	sound.RollOffMaxDistance = 60
	sound.Parent = effects

	local puff = Instance.new("ParticleEmitter")
	puff.Name = "SquishPuff"
	puff.Enabled = false
	puff.Rate = 0
	puff.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	puff.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	puff.Lifetime = NumberRange.new(0.3, 0.6)
	puff.Speed = NumberRange.new(4, 9)
	puff.SpreadAngle = Vector2.new(70, 70)
	puff.EmissionDirection = Enum.NormalId.Top
	puff.Drag = 4
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	puff.LightEmission = 0.4
	puff.Parent = effects

	squishy.Parent = folder
	return squishy
end

local made = 0
for index, info in SQUISHIES do
	local platform = platforms[index]
	if not platform then
		warn(`[Squishies] Couldn't find the platform for squishy {index}: skipped`)
		continue
	end
	local squishy = makeSquishy(platform, info[2], info[3])

	-- hide the plain platform (it still holds you up) and give it a new name, so the tower
	-- keyboards don't cover it in keys
	platform.Transparency = 1
	for _, child in platform:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = 1
		end
	end
	platform.Name = "Squishy Platform"

	-- landing on it squishes it
	local top = platform.Position.Y + platform.Size.Y / 2
	local lastSquish = 0
	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		if root.Position.Y < top then
			return -- bumped it from the side or below, not landed on it
		end
		local now = os.clock()
		if now - lastSquish < SQUISH_COOLDOWN then
			return
		end
		lastSquish = now
		squishEvent:FireAllClients(squishy)
	end)
	made += 1
end

folder.Parent = tower
finish()
print(`[Squishies] Made {made} squishy jumps in the tower`)

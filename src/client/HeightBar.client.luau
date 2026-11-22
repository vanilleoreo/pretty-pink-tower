-- Rainbow height bar on the right of the screen: shows how high up the Troll Tower every
-- player is, with their face on it. Bottom = start of the tower, top = the finish.
-- Your own face is bigger, outlined in pink, and shows how far up you are in percent.
-- (The heights come from the TowerHeight server script.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 105, 180)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance: any = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

local function round()
	return make("UICorner", { CornerRadius = UDim.new(1, 0) })
end

-- The bar ---------------------------------------------------------------------

local gui = make("ScreenGui", { Name = "HeightBar", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

local bar = make("Frame", {
	Name = "Bar",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.42, 0),
	Size = UDim2.new(0, 12, 0.5, 0),
	BackgroundColor3 = WHITE,
}, {
	round(),
	make("UIStroke", { Color = WHITE, Thickness = 2 }),
	make("UISizeConstraint", { MinSize = Vector2.new(12, 160), MaxSize = Vector2.new(12, 360) }),
	make("UIGradient", {
		Rotation = -90, -- red at the bottom, purple at the top
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 165, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 230, 80)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 220, 120)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(90, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
		}),
	}),
})
bar.Parent = gui

make("TextLabel", {
	Name = "Finish",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -6),
	Size = UDim2.fromOffset(28, 28),
	BackgroundTransparency = 1,
	Text = "🏁",
	TextSize = 22,
}).Parent = bar

-- One face per player -------------------------------------------------------

local markers = {} -- [player] = { frame, shown }

local percentLabel = make("TextLabel", {
	Name = "Percent",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0, -4, 0.5, 0),
	Size = UDim2.fromOffset(46, 22),
	BackgroundColor3 = PINK,
	Font = FONT,
	Text = "0%",
	TextSize = 16,
	TextColor3 = WHITE,
}, { round() })

local function addMarker(other: Player)
	local isMe = other == player
	local size = if isMe then 36 else 28

	local frame = make("ImageLabel", {
		Name = other.Name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -6, 1, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE,
		Visible = false,
		ZIndex = if isMe then 3 else 2, -- your face goes on top of everyone else's
	}, {
		round(),
		make("UIStroke", { Color = if isMe then PINK else WHITE, Thickness = if isMe then 3 else 2 }),
	})
	if isMe then
		percentLabel.Parent = frame
	end
	frame.Parent = bar
	markers[other] = { frame = frame, shown = nil }

	task.spawn(function()
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			other.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size48x48
		)
		if ok then
			frame.Image = image
		end
	end)
end

local function removeMarker(other: Player)
	local marker = markers[other]
	if marker then
		marker.frame:Destroy()
		markers[other] = nil
	end
end

Players.PlayerAdded:Connect(addMarker)
Players.PlayerRemoving:Connect(removeMarker)
for _, other in Players:GetPlayers() do
	addMarker(other)
end

-- Slide each face smoothly towards its player's latest height
RunService.RenderStepped:Connect(function(deltaTime)
	for other, marker in markers do
		local target = other:GetAttribute("TowerProgress")
		if typeof(target) ~= "number" then
			marker.frame.Visible = false
			marker.shown = nil
			continue
		end

		local shown = if marker.shown then marker.shown + (target - marker.shown) * math.min(1, deltaTime * 8) else target
		marker.shown = shown
		marker.frame.Visible = true
		marker.frame.Position = UDim2.new(0, -6, 1 - shown, 0)
		if other == player then
			percentLabel.Text = math.round(shown * 100) .. "%"
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")

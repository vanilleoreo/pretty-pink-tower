-- The admin panel: a cute "Admin" button (only for the owner and other admins) that opens a panel
-- with buttons for all the admin commands (AdminCommands.server.luau).
--
-- Pick who at the top (Me, All, Others or a player), then press a button. The number box is for
-- Speed, Jump and Size, and the message box is for Announce and the kick reason. The server
-- checks every button press, so nobody else can use it even if they mess with their screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Only admins get the panel at all
while not player:GetAttribute("IsAdmin") do
	player:GetAttributeChangedSignal("IsAdmin"):Wait()
end

local remotes = ReplicatedStorage:WaitForChild("Admin")
local runEvent = remotes:WaitForChild("Run") :: RemoteEvent
local messageEvent = remotes:WaitForChild("Message") :: RemoteEvent

local COLORS = {
	Plum = Color3.fromRGB(110, 45, 85), -- writing
	Muted = Color3.fromRGB(175, 125, 155),
	Pink = Color3.fromRGB(255, 105, 180),
	HotPink = Color3.fromRGB(255, 80, 160),
	SoftPink = Color3.fromRGB(255, 170, 215),
	Blush = Color3.fromRGB(255, 238, 247),
	Lavender = Color3.fromRGB(240, 230, 255),
	White = Color3.new(1, 1, 1),
	Danger = Color3.fromRGB(255, 160, 170),
	DangerText = Color3.fromRGB(165, 30, 60),
}
local SECTION_COLORS = { -- { buttons, label }
	Moves = { Color3.fromRGB(255, 190, 220), Color3.fromRGB(255, 110, 175) },
	Health = { Color3.fromRGB(190, 240, 205), Color3.fromRGB(80, 185, 120) },
	Teleport = { Color3.fromRGB(190, 215, 255), Color3.fromRGB(95, 145, 240) },
	Fun = { Color3.fromRGB(222, 200, 255), Color3.fromRGB(155, 105, 240) },
	Give = { Color3.fromRGB(255, 218, 180), Color3.fromRGB(240, 145, 65) },
	Server = { Color3.fromRGB(222, 222, 236), Color3.fromRGB(135, 135, 170) },
}
local FONT = Enum.Font.FredokaOne
local BOUNCE = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- The buttons: { label, command, what it needs, red?, item } in sections.
-- needs: "who" = the picked player(s), "number" = also the number box, "message" = the message
-- box, "item" = a fixed item to give, "nothing" = just the command
local SECTIONS = {
	{
		name = "Moves",
		emoji = "🏃",
		buttons = {
			{ "🕊️ Fly", "fly", "who" },
			{ "🛬 Land", "unfly", "who" },
			{ "⚡ Speed", "speed", "number" },
			{ "🦘 Jump", "jump", "number" },
			{ "🍄 Size", "size", "number" },
			{ "🙂 Normal", "normal", "who" },
		},
	},
	{
		name = "Health",
		emoji = "💖",
		buttons = {
			{ "🛡️ God mode", "god", "who" },
			{ "🫧 God off", "ungod", "who" },
			{ "💖 Heal", "heal", "who" },
			{ "🔄 Respawn", "respawn", "who" },
			{ "💥 Kill", "kill", "who", true },
		},
	},
	{
		name = "Teleport",
		emoji = "🌀",
		buttons = {
			{ "👣 Go to them", "to", "who" },
			{ "🧲 Bring them", "bring", "who" },
			{ "🛋️ Sofa", "sofa", "who" },
			{ "🏠 Lobby", "lobby", "who" },
			{ "🗼 Tower", "tower", "who" },
		},
	},
	{
		name = "Fun",
		emoji = "🎀",
		buttons = {
			{ "🧊 Freeze", "freeze", "who" },
			{ "🔥 Unfreeze", "unfreeze", "who" },
			{ "👻 Invisible", "invisible", "who" },
			{ "👀 Visible", "visible", "who" },
			{ "✨ Sparkles", "sparkles", "who" },
			{ "🚫 No sparkles", "unsparkles", "who" },
			{ "☀️ Day", "day", "nothing" },
			{ "🌙 Night", "night", "nothing" },
		},
	},
	{
		name = "Give",
		emoji = "🎁",
		buttons = {
			{ "🌀 Gravity coil", "give", "item", false, "coil" },
			{ "⚡ Speed coil", "give", "item", false, "speed" },
			{ "🌈 Carpet", "give", "item", false, "carpet" },
			{ "📻 Boombox", "give", "item", false, "boombox" },
			{ "🔫 Laser gun", "give", "item", false, "laser" },
		},
	},
	{
		name = "Server",
		emoji = "📢",
		buttons = {
			{ "📢 Announce", "announce", "message" },
			{ "👢 Kick", "kick", "message", true },
		},
	},
}

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

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function gradient(top: Color3, bottom: Color3, rotation: number?)
	return make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end

-- A button with a shiny gradient behind its writing. (A gradient on the button itself would tint
-- the writing and the emojis too, so it goes on a background layer instead.)
local function shinyButton(
	props: { [string]: any },
	top: Color3,
	bottom: Color3,
	radius: number,
	text: { [string]: any },
	strokeThickness: number?
): TextButton
	local rotation = props.GradientRotation -- (not a real button setting, so take it out)
	props.GradientRotation = nil
	props.Text = ""
	props.BackgroundTransparency = 1
	props.AutoButtonColor = false
	local button = make("TextButton", props)
	make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.White,
		ZIndex = 1,
	}, {
		corner(radius),
		gradient(top, bottom, rotation),
		make("UIStroke", {
			Color = COLORS.White,
			Thickness = strokeThickness or 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}).Parent = button
	text.Name = "Label"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.ZIndex = 2
	text.Font = FONT
	make("TextLabel", text, {
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	}).Parent = button
	return button
end

-- Grows a little when you point at it and squishes when you press it
local function bouncy(button: GuiButton)
	local scale = make("UIScale", {})
	scale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, BOUNCE, { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, BOUNCE, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, BOUNCE, { Scale = 1 }):Play()
	end)
end

-- The screen -------------------------------------------------------------------------

local gui = make("ScreenGui", { Name = "AdminPanel", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

local openButton = shinyButton({
	Name = "OpenAdmin",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 112), -- under the Shop and Donate buttons
	Size = UDim2.fromOffset(120, 46),
	GradientRotation = 0,
}, Color3.fromRGB(255, 140, 200), Color3.fromRGB(190, 130, 255), 23, {
	Text = "👑 Admin",
	TextSize = 24,
	TextColor3 = COLORS.White,
	TextStrokeColor3 = COLORS.HotPink,
	TextStrokeTransparency = 0.4,
}, 3)
bouncy(openButton)
openButton.Parent = gui

-- The window: a soft shadow behind the panel, both inside a frame that pops open
local window = make("Frame", {
	Name = "Window",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.94, 0.86),
	BackgroundTransparency = 1,
}, {
	make("UISizeConstraint", { MaxSize = Vector2.new(580, 520) }),
})
local windowScale = make("UIScale", {})
windowScale.Parent = window
window.Parent = gui

make("Frame", {
	Name = "Shadow",
	Position = UDim2.fromOffset(6, 8),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.Pink,
	BackgroundTransparency = 0.78,
}, { corner(26) }).Parent = window

local panel = make("Frame", {
	Name = "Panel",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.White,
}, {
	corner(26),
	gradient(COLORS.Blush, COLORS.Lavender),
	make("UIStroke", { Color = COLORS.White, Thickness = 4 }),
})
panel.Parent = window

-- A pink banner with the title
local header = make("Frame", {
	Name = "Header",
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(1, -20, 0, 52),
	BackgroundColor3 = COLORS.White,
}, {
	corner(20),
	gradient(Color3.fromRGB(255, 120, 190), Color3.fromRGB(255, 175, 215), 0),
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -70, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "👑 Admin Panel",
		TextSize = 28,
		TextColor3 = COLORS.White,
		TextStrokeColor3 = COLORS.HotPink,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	make("TextLabel", { -- little decorations
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0.5, 0),
		Size = UDim2.fromOffset(90, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "🌸 ✨ 💗",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
	}),
})
header.Parent = panel

local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = COLORS.White,
	Font = FONT,
	Text = "✕",
	TextSize = 18,
	TextColor3 = COLORS.HotPink,
}, { corner(17) })
bouncy(closeButton)
closeButton.Parent = header

-- Who: Me, All, Others and every player (with their avatar face) ------------------------------

make("TextLabel", {
	Position = UDim2.fromOffset(18, 70),
	Size = UDim2.fromOffset(50, 36),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "Who?",
	TextSize = 18,
	TextColor3 = COLORS.Plum,
	TextXAlignment = Enum.TextXAlignment.Left,
}).Parent = panel

local whoList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(68, 68),
	Size = UDim2.new(1, -80, 0, 42),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = COLORS.SoftPink,
	ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}),
	make("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 4) }),
})
whoList.Parent = panel

local picked = "me" -- what gets sent as the player: "me", "all", "others" or a player's name
local chips: { [string]: TextButton } = {}

local function paintChips()
	for word, chip in chips do
		local selected = word == picked
		chip.BackgroundColor3 = if selected then COLORS.Pink else COLORS.White
		chip.TextColor3 = if selected then COLORS.White else COLORS.Pink
	end
end

local function addChip(word: string, label: string, order: number, userId: number?)
	local chip = make("TextButton", {
		Name = word,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COLORS.White,
		Font = FONT,
		Text = label,
		TextSize = 17,
		TextColor3 = COLORS.Pink,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, {
		corner(17),
		make("UIStroke", { Color = COLORS.SoftPink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIPadding", {
			PaddingLeft = UDim.new(0, if userId then 36 else 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})
	if userId then
		-- their avatar's face in a little circle
		local face = make("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -32, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = COLORS.Blush,
		}, { corner(13) })
		face.Parent = chip
		task.spawn(function()
			local ok, image = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
			if ok then
				face.Image = image
			end
		end)
	end
	bouncy(chip)
	chip.Activated:Connect(function()
		picked = word
		paintChips()
	end)
	chip.Parent = whoList
	chips[word] = chip
	paintChips()
end

addChip("me", "🙋 Me", 1)
addChip("all", "🌍 All", 2)
addChip("others", "👯 Others", 3)

local function addPlayer(other: Player)
	if other ~= player then
		addChip(other.Name, other.DisplayName, 10, other.UserId)
	end
end
local function removePlayer(other: Player)
	local chip = chips[other.Name]
	if chip then
		chip:Destroy()
		chips[other.Name] = nil
		if picked == other.Name then
			picked = "me"
			paintChips()
		end
	end
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, other in Players:GetPlayers() do
	addPlayer(other)
end

-- The number and message boxes ----------------------------------------------------------------

local function box(placeholder: string, position: UDim2, size: UDim2): TextBox
	local textBox = make("TextBox", {
		Position = position,
		Size = size,
		BackgroundColor3 = COLORS.White,
		Font = FONT,
		PlaceholderText = placeholder,
		PlaceholderColor3 = COLORS.Muted,
		Text = "",
		TextSize = 16,
		TextColor3 = COLORS.Plum,
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, {
		corner(18),
		make("UIStroke", { Color = COLORS.SoftPink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	textBox.Parent = panel
	return textBox
end

local numberBox = box("🔢 Number (speed, jump, size)", UDim2.fromOffset(16, 118), UDim2.new(0.4, -20, 0, 36))
local messageBox = box("💌 Message (announce, kick reason)", UDim2.new(0.4, 6, 0, 118), UDim2.new(0.6, -22, 0, 36))

-- What happened, in a little speech bubble at the bottom --------------------------------------

local statusBubble = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -32, 0, 30),
	BackgroundColor3 = COLORS.White,
}, {
	corner(15),
	make("UIStroke", { Color = COLORS.SoftPink, Thickness = 2 }),
})
statusBubble.Parent = panel
local status = make("TextLabel", {
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.new(1, -24, 1, 0),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "💬 Pick who, then press a button!",
	TextSize = 15,
	TextColor3 = COLORS.Plum,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
status.Parent = statusBubble

-- The command buttons ----------------------------------------------------------------------

local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 164),
	Size = UDim2.new(1, -24, 1, -212),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.SoftPink,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
	}),
})
list.Parent = panel

local function press(command: string, needs: string, item: string?)
	local words = {}
	if needs == "who" then
		words = { picked }
	elseif needs == "number" then
		local number = tonumber(numberBox.Text)
		words = if number then { picked, tostring(number) } else { picked }
	elseif needs == "item" then
		words = { picked, item or "" }
	elseif needs == "message" then
		local message = messageBox.Text
		if command == "announce" then
			if message == "" then
				status.Text = "💌 Write your message in the message box first"
				return
			end
			words = { message }
		elseif command == "kick" then
			if picked == "me" or picked == "all" or picked == "others" then
				status.Text = "👆 Pick one player at the top to kick"
				return
			end
			words = { picked, message }
		end
	end
	status.Text = "💭 ..."
	runEvent:FireServer(command, words)
end

for order, section in SECTIONS do
	local buttonColor, labelColor = SECTION_COLORS[section.name][1], SECTION_COLORS[section.name][2]
	local holder = make("Frame", {
		Name = section.name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("TextLabel", { -- a coloured pill with the section's name
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = labelColor,
			Font = FONT,
			Text = `{section.emoji} {section.name}`,
			TextSize = 16,
			TextColor3 = COLORS.White,
		}, {
			corner(13),
			make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		}),
	})
	local grid = make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 40),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	grid.Parent = holder

	for index, button in section.buttons do
		local label, command, needs, danger, item = button[1], button[2], button[3], button[4], button[5]
		local color = if danger then COLORS.Danger else buttonColor
		local commandButton = shinyButton({ LayoutOrder = index }, color:Lerp(COLORS.White, 0.35), color, 14, {
			Text = label,
			TextScaled = true,
			TextColor3 = if danger then COLORS.DangerText else COLORS.Plum,
		})
		make("UITextSizeConstraint", { MaxTextSize = 17 }).Parent = commandButton:FindFirstChild("Label")
		bouncy(commandButton)
		commandButton.Activated:Connect(function()
			press(command, needs, item)
		end)
		commandButton.Parent = grid
	end
	holder.Parent = list
end

-- What happened (the same replies that show up in the chat)
messageEvent.OnClientEvent:Connect(function(text: string)
	status.Text = "✨ " .. (string.match(text, "[^\n]+") or text)
end)

-- Opening and closing, with a little pop ---------------------------------------------------

local function setOpen(open: boolean)
	if open then
		window.Visible = true
		windowScale.Scale = 0.8
		TweenService:Create(windowScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	else
		local shrink = TweenService:Create(windowScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 0.85 })
		shrink:Play()
		shrink.Completed:Wait()
		window.Visible = false
	end
end

openButton.Activated:Connect(function()
	setOpen(not window.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

gui.Parent = player:WaitForChild("PlayerGui")

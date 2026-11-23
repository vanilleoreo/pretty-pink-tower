-- The admin panel: an "Admin" button (only for the owner and other admins) that opens a panel
-- with buttons for all the admin commands (AdminCommands.server.luau).
--
-- Pick who at the top (Me, All, Others or a player), then press a button. The number box is for
-- Speed, Jump and Size, and the message box is for Announce and the kick reason. The server
-- checks every button press, so nobody else can use it even if they mess with their screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Only admins get the panel at all
while not player:GetAttribute("IsAdmin") do
	player:GetAttributeChangedSignal("IsAdmin"):Wait()
end

local remotes = ReplicatedStorage:WaitForChild("Admin")
local runEvent = remotes:WaitForChild("Run") :: RemoteEvent
local messageEvent = remotes:WaitForChild("Message") :: RemoteEvent

local COLORS = {
	Background = Color3.fromRGB(255, 235, 245),
	Pink = Color3.fromRGB(255, 105, 180),
	Text = Color3.fromRGB(110, 45, 85),
	Muted = Color3.fromRGB(165, 115, 145),
	White = Color3.new(1, 1, 1),
	Danger = Color3.fromRGB(235, 80, 100),
	Section = {
		Moves = Color3.fromRGB(255, 120, 190),
		Health = Color3.fromRGB(120, 200, 150),
		Teleport = Color3.fromRGB(120, 170, 255),
		Fun = Color3.fromRGB(190, 140, 255),
		Give = Color3.fromRGB(255, 170, 90),
		Server = Color3.fromRGB(150, 150, 175),
	},
}
local FONT = Enum.Font.FredokaOne

-- The buttons: { label, command, what it needs } in sections.
-- needs: "who" = the picked player(s), "number" = also the number box, "message" = the message
-- box, "item" = a fixed item to give, "nothing" = just the command
local SECTIONS = {
	{
		name = "Moves",
		buttons = {
			{ "Fly", "fly", "who" },
			{ "Stop flying", "unfly", "who" },
			{ "Speed", "speed", "number" },
			{ "Jump", "jump", "number" },
			{ "Size", "size", "number" },
			{ "Normal", "normal", "who" },
		},
	},
	{
		name = "Health",
		buttons = {
			{ "God mode", "god", "who" },
			{ "God off", "ungod", "who" },
			{ "Heal", "heal", "who" },
			{ "Respawn", "respawn", "who" },
			{ "Kill", "kill", "who", true },
		},
	},
	{
		name = "Teleport",
		buttons = {
			{ "Go to them", "to", "who" },
			{ "Bring them", "bring", "who" },
			{ "To the sofa", "sofa", "who" },
			{ "To the lobby", "lobby", "who" },
			{ "To the tower", "tower", "who" },
		},
	},
	{
		name = "Fun",
		buttons = {
			{ "Freeze", "freeze", "who" },
			{ "Unfreeze", "unfreeze", "who" },
			{ "Invisible", "invisible", "who" },
			{ "Visible", "visible", "who" },
			{ "Sparkles", "sparkles", "who" },
			{ "No sparkles", "unsparkles", "who" },
			{ "Day", "day", "nothing" },
			{ "Night", "night", "nothing" },
		},
	},
	{
		name = "Give",
		buttons = {
			{ "Gravity coil", "give", "item", false, "coil" },
			{ "Speed coil", "give", "item", false, "speed" },
			{ "Magic carpet", "give", "item", false, "carpet" },
			{ "Boombox", "give", "item", false, "boombox" },
			{ "Laser gun", "give", "item", false, "laser" },
		},
	},
	{
		name = "Server",
		buttons = {
			{ "Announce", "announce", "message" },
			{ "Kick", "kick", "message", true },
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

-- The screen -------------------------------------------------------------------------

local gui = make("ScreenGui", { Name = "AdminPanel", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

local openButton = make("TextButton", {
	Name = "OpenAdmin",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 112), -- under the Shop and Donate buttons
	Size = UDim2.fromOffset(120, 46),
	BackgroundColor3 = COLORS.Text,
	Font = FONT,
	Text = "👑 Admin",
	TextSize = 24,
	TextColor3 = COLORS.White,
}, {
	corner(14),
	make("UIStroke", { Color = COLORS.Pink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
openButton.Parent = gui

local panel = make("Frame", {
	Name = "Panel",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.94, 0.86),
	BackgroundColor3 = COLORS.Background,
}, {
	corner(18),
	make("UIStroke", { Color = COLORS.Pink, Thickness = 3 }),
	make("UISizeConstraint", { MaxSize = Vector2.new(580, 500) }),
	make("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 38),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "Admin 👑",
		TextSize = 30,
		TextColor3 = COLORS.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
})
panel.Parent = gui

local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = COLORS.Pink,
	Font = FONT,
	Text = "X",
	TextSize = 20,
	TextColor3 = COLORS.White,
}, { corner(17) })
closeButton.Parent = panel

-- Who: Me, All, Others and every player -------------------------------------------------

make("TextLabel", {
	Position = UDim2.fromOffset(16, 52),
	Size = UDim2.fromOffset(46, 34),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "Who:",
	TextSize = 18,
	TextColor3 = COLORS.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
}).Parent = panel

local whoList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(64, 50),
	Size = UDim2.new(1, -76, 0, 40),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = COLORS.Pink,
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

local function addChip(word: string, label: string, order: number)
	local chip = make("TextButton", {
		Name = word,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COLORS.White,
		Font = FONT,
		Text = label,
		TextSize = 17,
		TextColor3 = COLORS.Pink,
	}, {
		corner(16),
		make("UIStroke", { Color = COLORS.Pink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	chip.Activated:Connect(function()
		picked = word
		paintChips()
	end)
	chip.Parent = whoList
	chips[word] = chip
	paintChips()
end

addChip("me", "Me", 1)
addChip("all", "All", 2)
addChip("others", "Others", 3)

local function addPlayer(other: Player)
	if other ~= player then
		addChip(other.Name, other.DisplayName, 10)
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
		TextColor3 = COLORS.Text,
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, {
		corner(10),
		make("UIStroke", { Color = COLORS.Pink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	textBox.Parent = panel
	return textBox
end

local numberBox = box("Number (speed, jump, size)", UDim2.fromOffset(16, 98), UDim2.new(0.38, -20, 0, 36))
local messageBox = box("Message (announce, kick reason)", UDim2.new(0.38, 6, 0, 98), UDim2.new(0.62, -22, 0, 36))

-- The command buttons ----------------------------------------------------------------------

local status = make("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -8),
	Size = UDim2.new(1, -32, 0, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "Pick who, then press a button",
	TextSize = 15,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
status.Parent = panel

local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 144),
	Size = UDim2.new(1, -24, 1, -180),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.Pink,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingRight = UDim.new(0, 8) }),
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
				status.Text = "Write your message in the message box first"
				return
			end
			words = { message }
		elseif command == "kick" then
			if picked == "me" or picked == "all" or picked == "others" then
				status.Text = "Pick one player at the top to kick"
				return
			end
			words = { picked, message }
		end
	end
	status.Text = "..."
	runEvent:FireServer(command, words)
end

for order, section in SECTIONS do
	local color = COLORS.Section[section.name]
	local holder = make("Frame", {
		Name = section.name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = section.name,
			TextSize = 18,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
	local grid = make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 38),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	grid.Parent = holder

	for index, button in section.buttons do
		local label, command, needs, danger, item = button[1], button[2], button[3], button[4], button[5]
		local commandButton = make("TextButton", {
			LayoutOrder = index,
			BackgroundColor3 = if danger then COLORS.Danger else color,
			Font = FONT,
			Text = label,
			TextScaled = true,
			TextColor3 = COLORS.White,
		}, {
			corner(10),
			make("UITextSizeConstraint", { MaxTextSize = 18 }),
			make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		})
		commandButton.Activated:Connect(function()
			press(command, needs, item)
		end)
		commandButton.Parent = grid
	end
	holder.Parent = list
end

-- What happened (the same replies that show up in the chat)
messageEvent.OnClientEvent:Connect(function(text: string)
	status.Text = string.match(text, "[^\n]+") or text
end)

-- Opening and closing -------------------------------------------------------------------------

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)

gui.Parent = player:WaitForChild("PlayerGui")

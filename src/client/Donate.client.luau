-- Donate button (under the Shop button) and the donate menu.
-- The menu also opens when you walk up to the donation stand in the lobby.
-- When you donate, confetti rains down your screen and a big "thank you" pops up.
-- When someone else donates, you see a small thank-you message at the top of the screen.
-- Developers own every gamepass in their own game, so for them a gamepass button does a free
-- test donation (confetti and pop-up, no Robux) instead of a purchase.
-- (The amounts and the stand come from the Donations server script.)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local COLORS = {
	Background = Color3.fromRGB(255, 235, 245),
	Pink = Color3.fromRGB(255, 105, 180),
	Text = Color3.fromRGB(110, 45, 85),
	Muted = Color3.fromRGB(165, 115, 145),
	Donated = Color3.fromRGB(110, 195, 135),
	White = Color3.new(1, 1, 1),
}
local FONT = Enum.Font.FredokaOne

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local donations = ReplicatedStorage:WaitForChild("Donations")
local options = donations:WaitForChild("Options")
local thanks = donations:WaitForChild("Thanks") :: RemoteEvent
local testDonation = donations:WaitForChild("TestDonation") :: RemoteEvent
local isDeveloper = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IsDeveloper"))

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

-- The screen ---------------------------------------------------------------

local gui = make("ScreenGui", { Name = "Donate", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

local openButton = make("TextButton", {
	Name = "OpenDonate",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 56), -- just under the Shop button
	Size = UDim2.fromOffset(120, 46),
	BackgroundColor3 = COLORS.Pink,
	Font = FONT,
	Text = "Donate",
	TextSize = 26,
	TextColor3 = COLORS.White,
}, {
	corner(14),
	make("UIStroke", { Color = COLORS.White, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
openButton.Parent = gui

local panel = make("Frame", {
	Name = "Panel",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.75),
	BackgroundColor3 = COLORS.Background,
}, {
	corner(18),
	make("UIStroke", { Color = COLORS.Pink, Thickness = 3 }),
	make("UISizeConstraint", { MaxSize = Vector2.new(420, 380) }),
	make("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 40),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "Donate 💖",
		TextSize = 32,
		TextColor3 = COLORS.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	make("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.fromOffset(18, 50),
		Size = UDim2.new(1, -36, 0, 40),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "Every Robux helps make Cherry Blossom Tower even better. Thank you!",
		TextSize = 16,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}),
})
panel.Parent = gui

local closeButton = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = COLORS.Pink,
	Font = FONT,
	Text = "X",
	TextSize = 22,
	TextColor3 = COLORS.White,
}, { corner(18) })
closeButton.Parent = panel

local grid = make("ScrollingFrame", {
	Name = "Amounts",
	Position = UDim2.fromOffset(12, 100),
	Size = UDim2.new(1, -24, 1, -112),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.Pink,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
	make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 56),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
	make("UIPadding", { PaddingRight = UDim.new(0, 8) }),
})
grid.Parent = panel

local message = make("TextLabel", {
	Name = "Message",
	Position = UDim2.fromOffset(12, 110),
	Size = UDim2.new(1, -24, 0, 60),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "Loading...",
	TextSize = 20,
	TextColor3 = COLORS.Text,
	TextWrapped = true,
})
message.Parent = panel

-- One button per amount ------------------------------------------------------

local passButtons: { [number]: TextButton } = {} -- gamepass ID -> its button
local boughtNow: { [number]: boolean } = {} -- passes bought this session (Roblox can take a moment to notice)

-- A gamepass can only be bought once, so after that its button says thanks instead
local function markDonated(button: TextButton)
	button.Text = "Donated 💖"
	button.BackgroundColor3 = COLORS.Donated
	button.AutoButtonColor = false
	button:SetAttribute("Donated", true)
end

local function addAmount(value: Instance)
	if not value:IsA("IntValue") then
		return
	end
	local id = value.Value
	local isPass = value:GetAttribute("Kind") == "pass"
	local button = make("TextButton", {
		Name = value.Name,
		LayoutOrder = value:GetAttribute("Order") or value.Value,
		BackgroundColor3 = COLORS.Pink,
		Font = FONT,
		Text = value.Name, -- "R$ 10"
		TextSize = 24,
		TextColor3 = COLORS.White,
	}, { corner(14) })
	button.Activated:Connect(function()
		if button:GetAttribute("Donated") then
			return
		elseif isPass and isDeveloper(player) then
			testDonation:FireServer(id) -- you can't buy your own gamepass, so this is a free test
		elseif isPass then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	button.Parent = grid

	if isPass then
		passButtons[id] = button
		if boughtNow[id] then
			markDonated(button)
		else
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
				-- (developers own all their own gamepasses, so for them it doesn't mean they donated)
				if ok and owns and not isDeveloper(player) then
					markDonated(button)
				end
			end)
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, passId, purchased)
	if who ~= player or not purchased then
		return
	end
	boughtNow[passId] = true
	local button = passButtons[passId]
	if button then
		markDonated(button)
	end
end)

for _, value in options:GetChildren() do
	addAmount(value)
end
options.ChildAdded:Connect(addAmount)

local function updateMessage()
	local status = donations:GetAttribute("Status")
	if status == "ready" then
		message.Visible = false
	else
		message.Visible = true
		message.Text = if status == "loading" then "Loading..." else "Donations are coming soon 💖"
	end
end
updateMessage()
donations:GetAttributeChangedSignal("Status"):Connect(updateMessage)

-- Opening and closing ---------------------------------------------------------

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		-- don't show the Shop on top of the donate menu
		local shop = playerGui:FindFirstChild("Shop")
		local shopPanel = shop and shop:FindFirstChild("Panel")
		if shopPanel and shopPanel:IsA("GuiObject") then
			shopPanel.Visible = false
		end
	end
end

openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

-- Walking up to the donation stand and pressing E (or tapping) opens the menu too
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who == player and prompt.Name == "DonatePrompt" then
		setOpen(true)
	end
end)

-- Small thank-you message when someone else donates ------------------------------------

local banner = make("TextLabel", {
	Name = "Thanks",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -80),
	Size = UDim2.new(0.9, 0, 0, 52),
	BackgroundColor3 = COLORS.Pink,
	Font = FONT,
	Text = "",
	TextScaled = true,
	TextColor3 = COLORS.White,
	Visible = false,
}, {
	corner(16),
	make("UIStroke", { Color = COLORS.White, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	make("UISizeConstraint", { MaxSize = Vector2.new(620, 52) }),
	make("UITextSizeConstraint", { MaxTextSize = 26 }),
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	}),
})
banner.Parent = gui

local bannerShownAt = 0
local SLIDE = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function showBanner(text: string)
	banner.Text = text
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -80)
	TweenService:Create(banner, SLIDE, { Position = UDim2.new(0.5, 0, 0, 12) }):Play()

	local myTurn = os.clock()
	bannerShownAt = myTurn
	task.delay(5, function()
		if bannerShownAt == myTurn then -- a newer donation didn't replace this message
			TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		end
	end)
end

-- Confetti + big "thank you" when YOU donate --------------------------------------------

-- Its own screen layer, drawn on top of all the other buttons and menus
local party = make("ScreenGui", {
	Name = "DonateParty",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- confetti starts right at the top edge of the screen
	DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local confetti = require(script.Parent:WaitForChild("Confetti")) -- the shared confetti (Confetti.luau)

local popupScale = make("UIScale", { Scale = 0 })
local popupAmount = make("TextLabel", {
	Name = "Amount",
	Position = UDim2.fromOffset(20, 116),
	Size = UDim2.new(1, -40, 0, 34),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextScaled = true,
	TextColor3 = COLORS.Muted,
}, { make("UITextSizeConstraint", { MaxTextSize = 26 }) })

local popup = make("Frame", {
	Name = "ThankYou",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(0.86, 0, 0, 170),
	BackgroundColor3 = COLORS.White,
	Visible = false,
	ZIndex = 2, -- in front of the confetti
}, {
	corner(24),
	popupScale,
	make("UIStroke", { Color = COLORS.Pink, Thickness = 5 }),
	make("UISizeConstraint", { MaxSize = Vector2.new(560, 170) }),
	make("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(20, 20),
		Size = UDim2.new(1, -40, 0, 90),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "Thank you for supporting our game! 💖",
		TextScaled = true,
		TextColor3 = COLORS.Pink,
	}, { make("UITextSizeConstraint", { MaxTextSize = 42 }) }),
	popupAmount,
})
popup.Parent = party

local popupShownAt = 0

local function celebrate(amount: number, isTest: boolean)
	confetti()

	popupAmount.Text = if isTest
		then "Just a test: Roblox doesn't let you buy your own gamepasses"
		else "You donated R$ " .. amount
	popup.Visible = true
	popupScale.Scale = 0
	TweenService:Create(popupScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local myTurn = os.clock()
	popupShownAt = myTurn
	task.delay(4.5, function()
		if popupShownAt ~= myTurn then -- another donation restarted the pop-up
			return
		end
		local shrink =
			TweenService:Create(popupScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		shrink:Play()
		shrink.Completed:Wait()
		if popupShownAt == myTurn then
			popup.Visible = false
		end
	end)
end

thanks.OnClientEvent:Connect(function(name: string, amount: number, userId: number, isTest: boolean?)
	if userId == player.UserId then
		setOpen(false) -- close the donate menu so the pop-up is easy to see
		celebrate(amount, isTest == true)
	else
		showBanner("💖 " .. name .. " donated R$ " .. amount .. "! Thank you! 💖")
	end
end)

party.Parent = playerGui
gui.Parent = playerGui

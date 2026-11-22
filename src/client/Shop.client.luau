-- Shop button: opens a list of every gamepass with a Buy button.
-- Pass IDs live in src/shared/Passes.luau. Prices and icons come live from the Creator Hub,
-- so changing a price there updates the shop by itself.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Passes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Passes"))

local SHOP_ORDER = { "SpeedCoil", "GravityCoil", "RainbowMagicCarpet" } -- top to bottom

local COLORS = {
	Background = Color3.fromRGB(255, 235, 245),
	Row = Color3.fromRGB(255, 255, 255),
	Pink = Color3.fromRGB(255, 105, 180),
	Text = Color3.fromRGB(110, 45, 85),
	Muted = Color3.fromRGB(165, 115, 145),
	Owned = Color3.fromRGB(110, 195, 135),
	Disabled = Color3.fromRGB(205, 190, 200),
	White = Color3.new(1, 1, 1),
}
local FONT = Enum.Font.FredokaOne

local player = Players.LocalPlayer

-- Small helper so building the screen doesn't take hundreds of lines
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

local gui = make("ScreenGui", { Name = "Shop", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

local openButton = make("TextButton", {
	Name = "OpenShop",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(120, 46),
	BackgroundColor3 = COLORS.Pink,
	Font = FONT,
	Text = "Shop",
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
		Text = "Shop",
		TextSize = 32,
		TextColor3 = COLORS.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
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

local list = make("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(12, 60),
	Size = UDim2.new(1, -24, 1, -72),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.Pink,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingRight = UDim.new(0, 8) }),
})
list.Parent = panel

-- One row per pass ----------------------------------------------------------

local rows = {}

local function setButton(row, text: string, color: Color3, canBuy: boolean)
	row.button.Text = text
	row.button.BackgroundColor3 = color
	row.button.AutoButtonColor = canBuy
	row.canBuy = canBuy
end

for order, key in SHOP_ORDER do
	local pass = Passes[key]
	if not pass then
		continue
	end

	local frame = make("Frame", {
		Name = key,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundColor3 = COLORS.Row,
	}, { corner(14) })

	local icon = make("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = COLORS.Background,
		ScaleType = Enum.ScaleType.Fit,
	}, { corner(10) })
	icon.Parent = frame

	make("TextLabel", {
		Position = UDim2.fromOffset(76, 10),
		Size = UDim2.new(1, -196, 0, 28),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = pass.name,
		TextSize = 22,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}).Parent = frame

	make("TextLabel", {
		Position = UDim2.fromOffset(76, 38),
		Size = UDim2.new(1, -196, 0, 28),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = pass.description,
		TextSize = 15,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}).Parent = frame

	local button = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(100, 44),
		BackgroundColor3 = COLORS.Disabled,
		Font = FONT,
		Text = "...",
		TextScaled = true,
		TextColor3 = COLORS.White,
	}, {
		corner(12),
		make("UITextSizeConstraint", { MaxTextSize = 20 }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
	button.Parent = frame

	local row = { pass = pass, button = button, icon = icon, canBuy = false }
	table.insert(rows, row)

	button.Activated:Connect(function()
		if row.canBuy and pass.id then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
	end)

	frame.Parent = list
end

-- Prices, icons and "Owned" -----------------------------------------------

local boughtNow = {} -- passes bought this session (Roblox can take a moment to notice)

local function refreshRow(row)
	local id = row.pass.id
	if not id then
		setButton(row, "Soon", COLORS.Disabled, false)
		return
	end
	setButton(row, "...", COLORS.Disabled, false)

	local ownsOk, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	local infoOk, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, Enum.InfoType.GamePass)

	if infoOk and info.IconImageAssetId and info.IconImageAssetId ~= 0 then
		row.icon.Image = "rbxassetid://" .. info.IconImageAssetId
	end

	if boughtNow[id] or (ownsOk and owns) then
		setButton(row, "Owned", COLORS.Owned, false)
	elseif not infoOk then
		setButton(row, "Try later", COLORS.Disabled, false)
	elseif not info.IsForSale or not info.PriceInRobux then
		setButton(row, "Off sale", COLORS.Disabled, false)
	else
		setButton(row, "R$ " .. info.PriceInRobux, COLORS.Pink, true)
	end
end

local function refreshAll()
	for _, row in rows do
		task.spawn(refreshRow, row)
	end
end

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refreshAll() -- fetch prices each time, in case they changed
		-- don't show the donate menu on top of the shop
		local donate = player.PlayerGui:FindFirstChild("Donate")
		local donatePanel = donate and donate:FindFirstChild("Panel")
		if donatePanel and donatePanel:IsA("GuiObject") then
			donatePanel.Visible = false
		end
	end
end)

closeButton.Activated:Connect(function()
	panel.Visible = false
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, passId, purchased)
	if who ~= player or not purchased then
		return
	end
	boughtNow[passId] = true
	for _, row in rows do
		if row.pass.id == passId then
			setButton(row, "Owned", COLORS.Owned, false)
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")

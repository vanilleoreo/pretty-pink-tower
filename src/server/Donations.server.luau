-- Donation stand + donations.
--
-- Builds a pink donation stand next to the item givers in the lobby. Walking up to it (or
-- pressing the Donate button on the screen) opens the donate menu (Donate.client.luau).
--
-- The donation amounts come from the game's Developer Products on the Creator Hub: every
-- developer product with "Donate" in its name shows up as a button, cheapest first.
-- So to add, change or remove an amount, just change the products on the Creator Hub.
--
-- Want the stand somewhere else? In Studio, put a Part called "DonationStandSpot" in Workspace
-- where it should go (its front = the way the stand faces). The part itself is hidden in game.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAME_MATCH = "donat" -- products whose name contains this (any capitals) are donations
local DEFAULT_SPOT = CFrame.lookAt(Vector3.new(-108, -0.8, 146), Vector3.new(-108, -0.8, 140)) -- left of the givers, facing the spawn

local PINK = Color3.fromRGB(255, 105, 180)
local LIGHT_PINK = Color3.fromRGB(255, 190, 220)
local WHITE = Color3.new(1, 1, 1)
local TEXT = Color3.fromRGB(110, 45, 85)
local FONT = Enum.Font.FredokaOne

-- Shared with the players' screens ------------------------------------------------

local donations = Instance.new("Folder")
donations.Name = "Donations"
donations:SetAttribute("Status", "loading") -- loading / ready / none / error
donations:SetAttribute("Raised", 0)

local options = Instance.new("Folder") -- one IntValue per amount: Value = product ID
options.Name = "Options"
options.Parent = donations

local thanks = Instance.new("RemoteEvent") -- (donor name, amount, donor UserId) to everyone
thanks.Name = "Thanks"
thanks.Parent = donations

donations.Parent = ReplicatedStorage

-- The stand ------------------------------------------------------------------

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Text that shrinks to fit its box (the height sets the biggest size it can be)
local function label(parent: Instance, text: string, y: number, height: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 16, 0, y)
	l.Size = UDim2.new(1, -32, 0, height)
	l.Font = FONT
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.Parent = parent
	return l
end

local function surface(target: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

local spotPart = workspace:FindFirstChild("DonationStandSpot")
local spot = DEFAULT_SPOT
if spotPart and spotPart:IsA("BasePart") then
	-- stand on the floor under the marker part, facing where its front faces
	local flatLook = Vector3.new(spotPart.CFrame.LookVector.X, 0, spotPart.CFrame.LookVector.Z)
	local floor = spotPart.Position - Vector3.new(0, spotPart.Size.Y / 2, 0)
	spot = CFrame.lookAt(floor, floor + (if flatLook.Magnitude > 0.01 then flatLook else Vector3.new(0, 0, -1)))
	spotPart.Transparency = 1
	spotPart.CanCollide = false
	spotPart.CanTouch = false
	spotPart.CanQuery = false
end

local stand = Instance.new("Model")
stand.Name = "DonationStand"

-- Local layout: x = left/right, y = up, -z = the front (towards the players)
local counter = part(stand, "Counter", Vector3.new(10, 3.8, 3), spot * CFrame.new(0, 1.9, 0), PINK)
part(stand, "CounterTop", Vector3.new(10.6, 0.4, 3.6), spot * CFrame.new(0, 4, 0), WHITE)
for _, x in { -5, 5 } do
	part(stand, "Post", Vector3.new(0.6, 11.4, 0.6), spot * CFrame.new(x, 9.9, 1.2), WHITE)
end
for i = 0, 5 do -- striped awning, lower at the front
	local x = -4.75 + i * 1.9
	local awning = part(
		stand,
		"Awning",
		Vector3.new(1.9, 0.25, 4.6),
		spot * CFrame.new(x, 10.6, -0.4) * CFrame.Angles(math.rad(-18), 0, 0),
		if i % 2 == 0 then PINK else WHITE
	)
	awning.CanCollide = false
end
local sign = part(stand, "Sign", Vector3.new(11.2, 4.2, 0.4), spot * CFrame.new(0, 13.6, 0.7), WHITE)

-- Counter front: big DONATE
local counterGui = surface(counter)
label(counterGui, "💖 DONATE 💖", 50, 90, WHITE)

-- Sign: how much has been raised and who donated last
local signGui = surface(sign)
local frame = Instance.new("Frame")
frame.Position = UDim2.fromOffset(6, 6)
frame.Size = UDim2.new(1, -12, 1, -12)
frame.BackgroundColor3 = LIGHT_PINK
frame.Parent = signGui
local stroke = Instance.new("UIStroke")
stroke.Color = PINK
stroke.Thickness = 6
stroke.Parent = frame
label(frame, "Support Pretty Pink Tower!", 12, 60, PINK)
local raisedLabel = label(frame, "Thank you for every Robux!", 80, 54, TEXT)
local lastLabel = label(frame, "Be the first to donate 💖", 142, 44, TEXT)

-- Walk up to it to open the donate menu (the players' screens listen for this prompt)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "DonatePrompt"
prompt.ActionText = "Donate"
prompt.ObjectText = "Donation Stand"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Parent = counter

-- Hearts that burst out when someone donates
local sparkles = Instance.new("ParticleEmitter")
sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkles.Color = ColorSequence.new(PINK, WHITE)
sparkles.Size = NumberSequence.new(1.2, 0)
sparkles.Lifetime = NumberRange.new(1, 2)
sparkles.Speed = NumberRange.new(8, 14)
sparkles.SpreadAngle = Vector2.new(60, 60)
sparkles.Acceleration = Vector3.new(0, -6, 0)
sparkles.LightEmission = 0.6
sparkles.Rate = 0
sparkles.EmissionDirection = Enum.NormalId.Top
sparkles.Parent = sign

stand.PrimaryPart = counter
stand.Parent = workspace

local function showTotals(raised: number, lastName: string?, lastAmount: number?)
	donations:SetAttribute("Raised", raised)
	raisedLabel.Text = if raised > 0 then "R$ " .. raised .. " raised 💖" else "Thank you for every Robux!"
	if lastName and lastAmount then
		lastLabel.Text = "Last: " .. lastName .. " (R$ " .. lastAmount .. ")"
	end
end

-- Total raised (kept between servers) ----------------------------------------------

local store = DataStoreService:GetDataStore("Donations")
local STORE_KEY = "Totals"
type Totals = { Raised: number?, LastName: string?, LastAmount: number? }
local totals: Totals = { Raised = 0 }

task.spawn(function()
	local ok, saved = pcall(store.GetAsync, store, STORE_KEY)
	if ok and typeof(saved) == "table" then
		totals = saved
		showTotals(totals.Raised or 0, totals.LastName, totals.LastAmount)
	elseif not ok then
		warn("[Donations] Couldn't load the total raised:", saved)
	end
end)

-- Donation amounts from the Creator Hub ----------------------------------------------

local productsById: { [number]: number } = {} -- product ID -> price
local loaded = false

-- The product list doesn't always spell its fields the same way, so try each spelling
local function field(entry: { [string]: any }, ...: string): any
	for _, key in { ... } do
		if entry[key] ~= nil then
			return entry[key]
		end
	end
	return nil
end

local function loadProducts()
	local found = {}
	local ok, err = pcall(function()
		local pages = MarketplaceService:GetDeveloperProductsAsync()
		while true do
			for _, product in pages:GetCurrentPage() do
				local id = tonumber(field(product, "ProductId", "productId"))
				local name = field(product, "Name", "displayName", "name")
				local price = tonumber(field(product, "PriceInRobux", "priceInRobux"))
				if id and (name == nil or price == nil) then
					local infoOk, info =
						pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, Enum.InfoType.Product)
					if infoOk then
						name = name or info.Name
						price = price or tonumber(info.PriceInRobux)
					end
				end
				if id and price and string.find(string.lower(tostring(name or "")), NAME_MATCH, 1, true) then
					table.insert(found, { id = id, price = price })
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)

	if not ok then
		warn("[Donations] Couldn't load the developer products:", err)
		donations:SetAttribute("Status", "error")
		return
	end

	table.sort(found, function(a, b)
		return a.price < b.price
	end)
	for order, product in found do
		productsById[product.id] = product.price
		local value = Instance.new("IntValue")
		value.Name = "R$ " .. product.price
		value.Value = product.id
		value:SetAttribute("Price", product.price)
		value:SetAttribute("Order", order)
		value.Parent = options
	end

	if #found == 0 then
		warn('[Donations] No donation amounts yet. On the Creator Hub, make Developer Products named like "Donate 10".')
		donations:SetAttribute("Status", "none")
	else
		local prices = {}
		for _, product in found do
			table.insert(prices, "R$ " .. product.price)
		end
		print("[Donations] Donation amounts:", table.concat(prices, ", "))
		donations:SetAttribute("Status", "ready")
	end
end

task.spawn(function()
	loadProducts()
	loaded = true
end)

-- When someone donates -------------------------------------------------------

local function recordDonation(userId: number, amount: number)
	local donor = Players:GetPlayerByUserId(userId)
	local name = if donor then donor.DisplayName else "Someone"

	thanks:FireAllClients(name, amount, userId)
	sparkles:Emit(60)

	-- Studio test purchases are free, so they don't count towards the real total
	if RunService:IsStudio() then
		local raised = (totals.Raised or 0) + amount
		totals.Raised, totals.LastName, totals.LastAmount = raised, name, amount
		showTotals(raised, name, amount)
		return
	end

	local ok, result = pcall(store.UpdateAsync, store, STORE_KEY, function(saved)
		saved = if typeof(saved) == "table" then saved else {}
		saved.Raised = (saved.Raised or 0) + amount
		saved.LastName = name
		saved.LastAmount = amount
		return saved
	end)
	if ok and typeof(result) == "table" then
		totals = result
	else
		warn("[Donations] Couldn't save the donation total:", result)
		totals.Raised = (totals.Raised or 0) + amount
		totals.LastName, totals.LastAmount = name, amount
	end
	showTotals(totals.Raised or 0, totals.LastName, totals.LastAmount)
end

-- Roblox calls this for every developer product bought in this game.
-- (Only one script in the whole game may set this. This is the one.)
MarketplaceService.ProcessReceipt = function(receipt)
	local waited = 0
	while not loaded and waited < 30 do
		waited += task.wait(0.5)
	end

	local price = productsById[receipt.ProductId]
	if not price then
		-- Not a donation (or the products didn't load): Roblox will try again later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	task.spawn(recordDonation, receipt.PlayerId, receipt.CurrencySpent or price)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

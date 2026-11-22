local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

-- Gamepasses for the "Robux Items" pads
local GRAVITY_COIL_PASS_ID = 2058431498
local SPEED_COIL_PASS_ID = nil -- paste your Speed Coil gamepass ID here once you've made one

-- Every giver pad this script runs. "inside" is the name of the model the giver sits in, because
-- some givers share a name but give different things. "forSale" pads need their gamepass.
-- (The Rainbow Magic Carpet pads aren't here: their own scripts already work.)
local GIVERS = {
	{ inside = "Robux Items", name = "Speed Coil Giver", item = 99119158, forSale = true, pass = SPEED_COIL_PASS_ID },
	{ inside = "Robux Items", name = "Gravity Coil Giver", item = 16688968, forSale = true, pass = GRAVITY_COIL_PASS_ID },
	{ inside = "Model", name = "Speed Coil Giver", item = 99119158 },
	{ inside = "Model", name = "Gravity Coil Giver", item = 16688968 },
	{ inside = "Givers", name = "Gravity Coil Giver", item = 130113146 }, -- shows a laser gun and gives one
	{ inside = "Givers", name = "Boombox Giver", item = 212641536 },
	{ inside = "Workspace", name = "Hyper Laser Gun Giver", item = 130113146 },
	{ inside = "Workspace", name = "Red Hyper Laser Gun Giver", item = 212296936 },
}

local templates = {} -- [item id] = the tool, loaded once and copied for each player
local owners = {} -- [player] = { [pass id] = true } for passes bought this session

local function getTemplate(itemId)
	if templates[itemId] == nil then
		local ok, model = pcall(InsertService.LoadAsset, InsertService, itemId)
		if ok then
			templates[itemId] = model:FindFirstChildWhichIsA("Tool") or false
		else
			warn("[Givers] Couldn't load item " .. itemId .. ": " .. tostring(model))
			return nil -- try again next time
		end
	end
	return templates[itemId] or nil
end

local function giveItem(player, itemId)
	local tool = getTemplate(itemId)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not tool or not backpack then
		return
	end

	-- Don't give a second one if they already have it
	local character = player.Character
	if backpack:FindFirstChild(tool.Name) or (character and character:FindFirstChild(tool.Name)) then
		return
	end

	local copy = tool:Clone()
	local handle = copy:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.Anchored = false
	end
	copy.Parent = backpack
end

local function hasPass(player, passId)
	-- Roblox won't report a pass bought in this server until they rejoin
	if owners[player] and owners[player][passId] then
		return true
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and owns
end

local function setupGiver(pad, giver)
	local busy = {} -- players whose touch is being handled, so standing on the pad doesn't spam
	local warnedLocked = false

	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or busy[player] then
			return
		end
		busy[player] = true

		if giver.forSale and not giver.pass then
			if not warnedLocked then
				warn("[Givers] The " .. giver.name .. " pad is locked until you set its gamepass ID in Givers")
				warnedLocked = true
			end
		elseif giver.pass and not hasPass(player, giver.pass) then
			MarketplaceService:PromptGamePassPurchase(player, giver.pass)
		else
			giveItem(player, giver.item)
		end

		task.wait(2)
		busy[player] = nil
	end)
end

-- Find the giver pads and take over from their old free-model scripts, which could stop working
-- for the whole server and handed out a new copy every 2 seconds
local count = 0
for _, model in workspace:GetDescendants() do
	if not model:IsA("Model") or not model.Parent then
		continue
	end
	for _, giver in GIVERS do
		if model.Name == giver.name and model.Parent.Name == giver.inside then
			local pad = model:FindFirstChild("Giver")
			if pad and pad:IsA("BasePart") then
				for _, old in pad:GetChildren() do
					if old:IsA("Script") then
						old.Enabled = false
						old:Destroy()
					end
				end
				setupGiver(pad, giver)
				count += 1
			end
		end
	end
end
print("[Givers] Set up " .. count .. " giver pads")

-- Just bought a pass: give its item straight away
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for _, giver in GIVERS do
		if giver.pass == passId then
			owners[player] = owners[player] or {}
			owners[player][passId] = true
			giveItem(player, giver.item)
			return
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	owners[player] = nil
end)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local PASS_ID = 2045738837
local ITEM_ID = 225921000 -- the gear to give (Rainbow Magic Carpet)

local owners = {} -- players who bought the pass this session
local template = nil

local function hasPass(player)
	-- Roblox won't report a pass bought in this server until they rejoin
	if owners[player] then
		return true
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, PASS_ID)
	return ok and owns
end

-- Loads the gear once, then hands back the same copy every time so it
-- doesn't have to download again for each player. Clone it before giving it out.
local function getTemplate()
	if not template then
		local ok, model = pcall(InsertService.LoadAsset, InsertService, ITEM_ID)
		if ok then
			template = model:FindFirstChildWhichIsA("Tool")
		else
			warn("Couldn't load item! " .. ITEM_ID .. ": " .. tostring(model))
		end
	end
	return template
end

local function giveItem(player)
	local tool = getTemplate()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not tool or not backpack then
		return
	end

	-- Don't give a second one if they already have it
	local character = player.Character
	if backpack:FindFirstChild(tool.Name) or (character and character:FindFirstChild(tool.Name)) then
		return
	end

	tool:Clone().Parent = backpack
end

-- Pass owners get the carpet every time they spawn
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		if hasPass(player) then
			giveItem(player)
		end
	end)
	if player.Character and hasPass(player) then
		giveItem(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Remember buyers so they keep getting it after respawning this session
-- (the giver pad's Buy Script hands over the first one)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == PASS_ID then
		owners[player] = true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	owners[player] = nil
end)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PassID = 2045738837

local function hasPass(player)
	local ok, hasPass = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, PassID)
	return ok and hasPass
end

local InsertService = game:GetService("InsertService")
local ITEM_ID = 225921000 -- the gear to give (Rainbow Magic Carpet)
local template = nil
-- Loads the gear once, then hands back the same copy every time so it
-- doesn't have to download again for each player. Clone it before giving it out.
local function getTemplate()
	if not template then
		local ok, model = pcall(InsertService.LoadAsset, InsertService, ITEM_ID)
		if ok then
			template = model:FindFirstChildWhichIsA("Tool")
		else
			warn("Couldn't load item " .. ITEM_ID .. ": " .. tostring(model))
		end
	end
	return template
end

local function giveItem(player)
	local tool = getTemplate()
	local backpack = player:FindFirstChildOfClass("Backpack")= to Player

end

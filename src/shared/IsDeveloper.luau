-- Is this player a developer of the game? That's the owner (or, for a group game, the group's
-- owner). In Studio everyone counts, because everyone in a Studio test is working on the game.
local RunService = game:GetService("RunService")

local cache: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isDeveloper(player: Player): boolean
	local known = cache[player]
	if known ~= nil then
		return known
	end

	local result = RunService:IsStudio()
	if not result then
		if game.CreatorType == Enum.CreatorType.Group then
			local ok, rank = pcall(player.GetRankInGroupAsync, player, game.CreatorId)
			result = ok and rank == 255
		else
			result = player.UserId == game.CreatorId
		end
	end

	cache[player] = result
	return result
end

return isDeveloper

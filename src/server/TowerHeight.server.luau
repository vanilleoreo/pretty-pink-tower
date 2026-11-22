-- Tells everyone how high up the Troll Tower each player is, for the rainbow height bar.
-- Sets a "TowerProgress" attribute on each Player: 0 at the start of the tower, 1 at the finish.
-- This runs on the server because, with streaming on, your screen doesn't load players far away.
local Players = game:GetService("Players")

local FEET_BELOW_ROOT = 3 -- distance from the middle of a character down to its feet

local tower = workspace:WaitForChild("💥 Troll Tower Obby Parkour Fun Hard Easy")
local start = tower:FindFirstChildWhichIsA("SpawnLocation", true)
local finish = tower:FindFirstChild("end", true) -- the big platform at the top

local bottom = if start then start.Position.Y + start.Size.Y / 2 else 0
local top = if finish and finish:IsA("BasePart") then finish.Position.Y + finish.Size.Y / 2 else 400

while true do
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local progress = nil
		if root and root:IsA("BasePart") then
			local feet = root.Position.Y - FEET_BELOW_ROOT
			progress = math.clamp((feet - bottom) / (top - bottom), 0, 1)
			progress = math.round(progress * 200) / 200 -- steps of half a percent are plenty
		end
		player:SetAttribute("TowerProgress", progress)
	end
	task.wait(0.2)
end

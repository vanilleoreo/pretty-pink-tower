-- Players used to spawn with a one-shot gun and a knife from StarterPack.
-- Removing them here means nobody gets them. You can also delete "gun mm2" and "Knife"
-- from StarterPack in Studio; then this script just has nothing left to do.
local StarterPack = game:GetService("StarterPack")

for _, name in { "gun mm2", "Knife" } do
	local tool = StarterPack:FindFirstChild(name)
	if tool then
		tool:Destroy()
	end
end

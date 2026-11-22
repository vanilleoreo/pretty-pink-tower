-- Every gamepass in the game, in one place. The shop and the giver pads both read this.
-- Make passes and set their prices on the Creator Hub:
--   create.roblox.com → Creations → pretty pink tower → Monetization → Passes
-- then put each pass's ID here (replace nil with the number, e.g. id = 1234567890).
local Passes: { [string]: { name: string, description: string, id: number? } } = {
	SpeedCoil = {
		name = "Speed Coil",
		description = "Run super fast",
		id = nil, -- paste the Speed Coil pass ID here once you've made it
	},
	GravityCoil = {
		name = "Gravity Coil",
		description = "Jump really high",
		id = 2058431498,
	},
	RainbowMagicCarpet = {
		name = "Rainbow Magic Carpet",
		description = "Fly anywhere on a rainbow carpet",
		id = 2045738837,
	},
}

return Passes

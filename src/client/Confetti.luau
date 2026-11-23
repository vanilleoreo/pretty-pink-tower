-- Confetti raining down the screen, for when someone donates or an admin types /confetti.
-- Usage, from a LocalScript next to this one:  require(script.Parent.Confetti)()
local RunService = game:GetService("RunService")

local player = game:GetService("Players").LocalPlayer

local CONFETTI_PIECES = 160
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 105, 180), -- pink
	Color3.fromRGB(255, 70, 70), -- red
	Color3.fromRGB(255, 165, 60), -- orange
	Color3.fromRGB(255, 230, 80), -- yellow
	Color3.fromRGB(100, 220, 120), -- green
	Color3.fromRGB(90, 170, 255), -- blue
	Color3.fromRGB(190, 110, 255), -- purple
	Color3.new(1, 1, 1), -- white
}

-- Its own screen layer, on top of the buttons and menus (but under the donation thank-you pop-up)
local party = Instance.new("ScreenGui")
party.Name = "Confetti"
party.ResetOnSpawn = false
party.IgnoreGuiInset = true -- confetti starts right at the top edge of the screen
party.DisplayOrder = 49
party.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
party.Parent = player:WaitForChild("PlayerGui")

local function make(className: string, props: { [string]: any }): any
	local instance: any = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	return instance
end

local function confetti()
	local pieces = {}
	for _ = 1, CONFETTI_PIECES do
		local width, height = math.random(6, 10), math.random(10, 18)
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(width, height),
			BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			Position = UDim2.fromScale(0.5, -0.1),
		})
		frame.Parent = party
		table.insert(pieces, {
			frame = frame,
			width = width,
			height = height,
			x = math.random(),
			y = -0.05 - math.random() * 0.7, -- some start higher up, so they keep coming for a while
			fall = 0.22 + math.random() * 0.22, -- screens per second
			sway = 0.01 + math.random() * 0.025,
			swaySpeed = 2 + math.random() * 2,
			flipSpeed = 4 + math.random() * 6,
			phase = math.random() * math.pi * 2,
			spin = math.random(-300, 300),
		})
	end

	local time = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		time += deltaTime
		local falling = 0
		for _, piece in pieces do
			if not piece.frame.Parent then
				continue
			end
			piece.y += piece.fall * deltaTime
			if piece.y > 1.1 then
				piece.frame:Destroy()
				continue
			end
			falling += 1
			local x = piece.x + math.sin(time * piece.swaySpeed + piece.phase) * piece.sway
			piece.frame.Position = UDim2.fromScale(x, piece.y)
			piece.frame.Rotation += piece.spin * deltaTime
			-- squash it sideways and back, so it looks like it's flipping over as it falls
			local flip = math.abs(math.cos(time * piece.flipSpeed + piece.phase))
			piece.frame.Size = UDim2.fromOffset(math.max(1, piece.width * flip), piece.height)
		end
		if falling == 0 then
			connection:Disconnect()
		end
	end)
end

return confetti

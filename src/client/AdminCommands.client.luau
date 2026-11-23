-- The screen side of the admin commands (AdminCommands.server.luau):
--   * replies to the admin's commands show up in their chat
--   * /announce shows a big message at the top of everyone's screen, /confetti rains confetti
--   * /fly lets you fly where your camera looks (Space to go up, Ctrl or Q to go down). While
--     you fly there's a Land button, and admins can press F to start or stop flying
--   * /noclip (fly through walls), /infjump (jump in the air) and /clicktp (Ctrl + click)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FLY_SPEED = 60 -- studs per second
local PINK = Color3.fromRGB(255, 105, 180)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Admin")
local messageEvent = remotes:WaitForChild("Message") :: RemoteEvent
local announceEvent = remotes:WaitForChild("Announce") :: RemoteEvent
local runEvent = remotes:WaitForChild("Run") :: RemoteEvent
local landEvent = remotes:WaitForChild("Land") :: RemoteEvent
local confettiEvent = remotes:WaitForChild("Confetti") :: RemoteEvent
local confetti = require(script.Parent:WaitForChild("Confetti"))

-- Replies in the chat ---------------------------------------------------------------

messageEvent.OnClientEvent:Connect(function(text: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
	if channel and channel:IsA("TextChannel") then
		for line in string.gmatch(text, "[^\n]+") do
			channel:DisplaySystemMessage(`<font color="#ff69b4">[Admin]</font> {line}`)
		end
	end
end)

-- Announcements ----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "AdminAnnouncement"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, -120)
banner.Size = UDim2.new(0.8, 0, 0, 90)
banner.BackgroundColor3 = Color3.new(1, 1, 1)
banner.TextColor3 = PINK
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.TextWrapped = true
banner.Text = ""
banner.Visible = false
banner.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = banner
local stroke = Instance.new("UIStroke")
stroke.Color = PINK
stroke.Thickness = 4
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = banner
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(760, 90)
limit.Parent = banner
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 18)
padding.PaddingRight = UDim.new(0, 18)
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = banner

gui.Parent = player:WaitForChild("PlayerGui")

local shownAt = 0
announceEvent.OnClientEvent:Connect(function(text: string, from: string)
	banner.Text = `📢 {from}: {text}`
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -120)
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	local myTurn = os.clock()
	shownAt = myTurn
	task.delay(6, function()
		if shownAt == myTurn then
			TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -120) }):Play()
		end
	end)
end)

-- Flying -------------------------------------------------------------------------------

-- (Which way you're steering comes from your character's MoveDirection, which works with a
-- keyboard, a phone's joystick and a controller. It used to come from Roblox's PlayerModule,
-- but this game doesn't have one there, so the script waited forever and flying never started.)
local stopFlying: (() -> ())? = nil

local function startFlying()
	if stopFlying then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "AdminFly"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attachment
	turn.MaxTorque = math.huge
	turn.Responsiveness = 25
	turn.Parent = root
	humanoid.PlatformStand = true

	local connection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		-- the way you're steering (flat, already turned to match the camera)
		local move = humanoid.MoveDirection
		-- going forwards also goes up or down with the camera, so you fly where you look
		local forwards = if flatLook.Magnitude > 0.01 then math.max(move:Dot(flatLook.Unit), 0) else 0
		local direction = move + Vector3.new(0, look.Y * forwards * 1.5, 0)
		local up = (if UserInputService:IsKeyDown(Enum.KeyCode.Space) then 1 else 0)
			- (
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q)
					then 1
					else 0
			)
		direction += Vector3.new(0, up, 0)
		velocity.VectorVelocity = if direction.Magnitude > 0.01 then direction.Unit * FLY_SPEED else Vector3.zero
		if flatLook.Magnitude > 0.01 then
			turn.CFrame = CFrame.lookAt(Vector3.zero, flatLook) -- stay upright, facing where the camera faces
		end
	end)

	stopFlying = function()
		connection:Disconnect()
		velocity:Destroy()
		turn:Destroy()
		attachment:Destroy()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
		stopFlying = nil
	end
end

local function updateFlying()
	if player:GetAttribute("AdminFlying") then
		startFlying()
	elseif stopFlying then
		stopFlying()
	end
end

player:GetAttributeChangedSignal("AdminFlying"):Connect(updateFlying)
player.CharacterAdded:Connect(function(character)
	if stopFlying then
		stopFlying() -- the old character is gone
	end
	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("Humanoid")
	updateFlying() -- keep flying after a respawn
end)
updateFlying()

-- Landing: a Land button while you fly, and the F key ------------------------------------------

local landGui = Instance.new("ScreenGui")
landGui.Name = "AdminLand"
landGui.ResetOnSpawn = false
landGui.DisplayOrder = 30

local landButton = Instance.new("TextButton")
landButton.AnchorPoint = Vector2.new(0.5, 1)
landButton.Position = UDim2.new(0.5, 0, 1, -24)
landButton.Size = UDim2.fromOffset(170, 50)
landButton.BackgroundColor3 = PINK
landButton.Font = Enum.Font.FredokaOne
landButton.Text = "🛬 Land  (F)"
landButton.TextSize = 24
landButton.TextColor3 = Color3.new(1, 1, 1)
landButton.Visible = false
local landCorner = Instance.new("UICorner")
landCorner.CornerRadius = UDim.new(0, 25)
landCorner.Parent = landButton
local landStroke = Instance.new("UIStroke")
landStroke.Color = Color3.new(1, 1, 1)
landStroke.Thickness = 3
landStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
landStroke.Parent = landButton
landButton.Parent = landGui
landGui.Parent = player:WaitForChild("PlayerGui")

local function land()
	landEvent:FireServer()
end

landButton.Activated:Connect(land)

local function showLandButton()
	landButton.Visible = player:GetAttribute("AdminFlying") == true
end
player:GetAttributeChangedSignal("AdminFlying"):Connect(showLandButton)
showLandButton()

UserInputService.InputBegan:Connect(function(input, typing)
	if typing or input.KeyCode ~= Enum.KeyCode.F then
		return
	end
	if player:GetAttribute("AdminFlying") then
		land()
	elseif player:GetAttribute("IsAdmin") then
		runEvent:FireServer("fly", { "me" }) -- the server checks you're an admin
	end
end)

-- Noclip: nothing stops you while it's on (you fly too, so you don't fall through the floor) -------

local solidParts: { [BasePart]: boolean } = {} -- parts we made see-through-able, to put back

RunService.Stepped:Connect(function()
	local character = player.Character
	if player:GetAttribute("AdminNoclip") and character then
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				solidParts[part] = true
				part.CanCollide = false
			end
		end
	elseif next(solidParts) then
		for part in solidParts do
			if part.Parent then
				part.CanCollide = true
			end
		end
		table.clear(solidParts)
	end
end)

-- Air jumps: jump again while you're in the air ---------------------------------------------

UserInputService.JumpRequest:Connect(function()
	if not player:GetAttribute("AdminInfJump") then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

-- Click teleport: hold Ctrl and click somewhere to go there -------------------------------------

UserInputService.InputBegan:Connect(function(input, overButton)
	if overButton or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if not player:GetAttribute("AdminClickTP") then
		return
	end
	if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if hit then
		character:PivotTo(CFrame.new(hit.Position + Vector3.new(0, 3, 0)) * root.CFrame.Rotation)
	end
end)

-- Confetti for everyone ---------------------------------------------------------------------

confettiEvent.OnClientEvent:Connect(function()
	confetti()
end)

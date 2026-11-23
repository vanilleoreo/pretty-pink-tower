-- Admin commands for the owner of the game. Type them in the chat, starting with / (or ;),
-- for example "/fly", "/speed 50" or "/bring bob". Type "/cmds" in the game to see them all.
-- Admins also get an Admin button with a panel for all of them (AdminPanel.client.luau).
--
-- Only the owner can use them (and everyone in a Studio test, which is just you). To give a
-- friend admin too, put their UserId in EXTRA_ADMINS. Other players can't see the commands,
-- and nothing happens if they try one.
--
-- Most commands work on you, or on someone else if you add their name (the start of it is
-- enough), "all" or "others": "/speed 50", "/speed bob 50", "/god all".
local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local isDeveloper = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IsDeveloper"))

local EXTRA_ADMINS: { [number]: boolean } = {
	-- [123456789] = true, -- a friend's UserId (find it in the link of their Roblox profile)
}

local GEAR = { -- things /give can give
	coil = 16688968, -- gravity coil
	gravity = 16688968,
	speed = 99119158, -- speed coil
	carpet = 225921000, -- rainbow magic carpet
	boombox = 212641536,
	laser = 130113146, -- hyper laser gun
}

local PLACES = { -- where /sofa, /lobby and /tower take you
	sofa = Vector3.new(-105.5, 403, -45), -- the finish, by the sofa
	lobby = Vector3.new(-74, 4, 120), -- the spawn
	tower = Vector3.new(-76.5, 8, 178.3), -- the bottom of the tower
}

local function isAdmin(player: Player): boolean
	return EXTRA_ADMINS[player.UserId] == true or isDeveloper(player)
end

-- Remote events for the admin's screen ----------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Admin"
local messageEvent = Instance.new("RemoteEvent") -- (text) to one admin: shows up in their chat
messageEvent.Name = "Message"
messageEvent.Parent = remotes
local announceEvent = Instance.new("RemoteEvent") -- (text, from) to everyone: big message on screen
announceEvent.Name = "Announce"
announceEvent.Parent = remotes
local runEvent = Instance.new("RemoteEvent") -- (command name, words) from the admin panel
runEvent.Name = "Run"
runEvent.Parent = remotes
local landEvent = Instance.new("RemoteEvent") -- from anyone who's flying: "let me land"
landEvent.Name = "Land"
landEvent.Parent = remotes
local confettiEvent = Instance.new("RemoteEvent") -- to everyone: confetti on the screen
confettiEvent.Name = "Confetti"
confettiEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

local function tell(player: Player, text: string)
	messageEvent:FireClient(player, text)
end

-- Helpers --------------------------------------------------------------------------

-- "me", "all", "others", "random", or (the start of) someone's name or display name
local function findPlayers(speaker: Player, word: string?): { Player }
	if not word or word == "" or word:lower() == "me" then
		return { speaker }
	end
	local lower = word:lower()
	local everyone = Players:GetPlayers()
	if lower == "all" or lower == "everyone" then
		return everyone
	elseif lower == "others" then
		local others = {}
		for _, player in everyone do
			if player ~= speaker then
				table.insert(others, player)
			end
		end
		return others
	elseif lower == "random" then
		return { everyone[math.random(1, #everyone)] }
	end
	for _, player in everyone do
		if player.Name:lower() == lower or player.DisplayName:lower() == lower then
			return { player }
		end
	end
	local matches = {}
	for _, player in everyone do
		if player.Name:lower():sub(1, #lower) == lower or player.DisplayName:lower():sub(1, #lower) == lower then
			table.insert(matches, player)
		end
	end
	return matches
end

-- For commands like "/speed 50" (you) and "/speed bob 50" (bob)
local function playersAndNumber(speaker: Player, args: { string }, default: number): ({ Player }, number)
	if #args >= 2 then
		return findPlayers(speaker, args[1]), tonumber(args[2]) or default
	elseif #args == 1 and tonumber(args[1]) then
		return { speaker }, tonumber(args[1]) :: number
	end
	return findPlayers(speaker, args[1]), default
end

local function parts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return character:FindFirstChildOfClass("Humanoid"), if root and root:IsA("BasePart") then root else nil
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if not character then
		return
	end
	pcall(player.RequestStreamAroundAsync, player, position, 5) -- load the area first
	character:PivotTo(CFrame.new(position))
end

local function names(players: { Player }): string
	if #players == 0 then
		return "nobody (no one with that name)"
	end
	local list = {}
	for _, player in players do
		table.insert(list, player.DisplayName)
	end
	return table.concat(list, ", ")
end

local function eachHumanoid(targets: { Player }, action: (Humanoid, Player) -> ())
	for _, player in targets do
		local humanoid = parts(player)
		if humanoid then
			action(humanoid, player)
		end
	end
end

local gearCache: { [number]: Tool } = {}
local function gearTool(id: number): Tool?
	if gearCache[id] then
		return gearCache[id]
	end
	local ok, model = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok then
		return nil
	end
	local tool = model:FindFirstChildWhichIsA("Tool", true)
	if tool then
		gearCache[id] = tool
	end
	return tool
end

-- The commands -----------------------------------------------------------------------

type Command = { usage: string, help: string, run: (speaker: Player, args: { string }) -> () }
local COMMANDS: { [string]: Command } = {}
local ORDER: { string } = {} -- for the /cmds list

local function command(name: string, usage: string, help: string, run: (Player, { string }) -> ())
	COMMANDS[name] = { usage = usage, help = help, run = run }
	table.insert(ORDER, name)
end

command("cmds", "/cmds", "this list", function(speaker)
	local lines = { "Admin commands (add a name, all or others to use them on someone else):" }
	for _, name in ORDER do
		table.insert(lines, `{COMMANDS[name].usage}  {COMMANDS[name].help}`)
	end
	tell(speaker, table.concat(lines, "\n"))
end)

command("fly", "/fly [name]", "fly where your camera looks (Space up, Ctrl or Q down)", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		player:SetAttribute("AdminFlying", true)
	end
	tell(speaker, `Flying: {names(targets)}`)
end)

command("unfly", "/unfly [name]", "stop flying (or press F, or the Land button)", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		player:SetAttribute("AdminFlying", false)
		player:SetAttribute("AdminNoclip", false)
	end
	tell(speaker, `Stopped flying: {names(targets)}`)
end)

command("speed", "/speed [name] [number]", "walk speed (normal is 16)", function(speaker, args)
	local targets, speed = playersAndNumber(speaker, args, 50)
	speed = math.clamp(speed, 0, 500)
	eachHumanoid(targets, function(humanoid)
		humanoid.WalkSpeed = speed
	end)
	tell(speaker, `Speed {speed}: {names(targets)}`)
end)

command("jump", "/jump [name] [number]", "jump power (normal is 50)", function(speaker, args)
	local targets, power = playersAndNumber(speaker, args, 100)
	power = math.clamp(power, 0, 1000)
	eachHumanoid(targets, function(humanoid)
		humanoid.UseJumpPower = true
		humanoid.JumpPower = power
	end)
	tell(speaker, `Jump {power}: {names(targets)}`)
end)

-- (/normal is further down: it turns every power off, so it needs them all)

command("god", "/god [name]", "can't get hurt", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local character = player.Character
		if character and not character:FindFirstChild("AdminGod") then
			local shield = Instance.new("ForceField")
			shield.Name = "AdminGod"
			shield.Visible = false
			shield.Parent = character
		end
	end
	tell(speaker, `God mode: {names(targets)}`)
end)

command("ungod", "/ungod [name]", "can get hurt again", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local shield = player.Character and player.Character:FindFirstChild("AdminGod")
		if shield then
			shield:Destroy()
		end
	end
	tell(speaker, `God mode off: {names(targets)}`)
end)

command("heal", "/heal [name]", "full health", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	eachHumanoid(targets, function(humanoid)
		humanoid.Health = humanoid.MaxHealth
	end)
	tell(speaker, `Healed: {names(targets)}`)
end)

command("kill", "/kill [name]", "knock them out", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	eachHumanoid(targets, function(humanoid)
		humanoid.Health = 0
	end)
	tell(speaker, `Killed: {names(targets)}`)
end)

local function respawn(speaker: Player, args: { string })
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		player:LoadCharacter()
	end
	tell(speaker, `Respawned: {names(targets)}`)
end
command("respawn", "/respawn [name]", "respawn (also /re)", respawn)
COMMANDS.re = { usage = "/re [name]", help = "respawn", run = respawn }

command("to", "/to name", "teleport to someone", function(speaker, args)
	local target = findPlayers(speaker, args[1])[1]
	local root: BasePart? = nil
	if target then
		root = select(2, parts(target))
	end
	if not target or target == speaker or not root then
		tell(speaker, "Who? Type /to and the start of their name.")
		return
	end
	teleport(speaker, root.Position + root.CFrame.LookVector * -4)
	tell(speaker, `Teleported to {target.DisplayName}`)
end)

command("bring", "/bring name", "bring someone to you", function(speaker, args)
	local _, root = parts(speaker)
	if not root then
		return
	end
	local targets = findPlayers(speaker, args[1] or "others")
	for index, player in targets do
		if player ~= speaker then
			teleport(player, root.Position + root.CFrame.LookVector * 4 + Vector3.new(index * 2, 0, 0))
		end
	end
	tell(speaker, `Brought: {names(targets)}`)
end)

command("tp", "/tp name1 name2", "teleport name1 to name2", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	local to = findPlayers(speaker, args[2])[1]
	local root: BasePart? = nil
	if to then
		root = select(2, parts(to))
	end
	if not to or not root then
		tell(speaker, "Type /tp, who to move, then who to move them to.")
		return
	end
	for _, player in targets do
		if player ~= to then
			teleport(player, root.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
		end
	end
	tell(speaker, `Teleported {names(targets)} to {to.DisplayName}`)
end)

for place, position in PLACES do
	command(place, `/{place} [name]`, `teleport to the {place}`, function(speaker, args)
		local targets = findPlayers(speaker, args[1])
		for _, player in targets do
			teleport(player, position)
		end
		tell(speaker, `To the {place}: {names(targets)}`)
	end)
end

command("freeze", "/freeze [name]", "can't move", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local _, root = parts(player)
		if root then
			root.Anchored = true
		end
	end
	tell(speaker, `Frozen: {names(targets)}`)
end)

command("unfreeze", "/unfreeze [name]", "can move again", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local _, root = parts(player)
		if root then
			root.Anchored = false
		end
	end
	tell(speaker, `Unfrozen: {names(targets)}`)
end)

local function setInvisible(player: Player, invisible: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, thing in character:GetDescendants() do
		if (thing:IsA("BasePart") and thing.Name ~= "HumanoidRootPart") or thing:IsA("Decal") then
			if invisible then
				if thing:GetAttribute("AdminTransparency") == nil then
					thing:SetAttribute("AdminTransparency", (thing :: any).Transparency)
				end
				(thing :: any).Transparency = 1
			else
				local was = thing:GetAttribute("AdminTransparency")
				if typeof(was) == "number" then
					(thing :: any).Transparency = was
					thing:SetAttribute("AdminTransparency", nil)
				end
			end
		end
	end
end

command("invisible", "/invisible [name]", "nobody can see you", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		setInvisible(player, true)
	end
	tell(speaker, `Invisible: {names(targets)}`)
end)

command("visible", "/visible [name]", "visible again", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		setInvisible(player, false)
	end
	tell(speaker, `Visible: {names(targets)}`)
end)

command("size", "/size [name] [number]", "bigger or smaller (normal is 1)", function(speaker, args)
	local targets, scale = playersAndNumber(speaker, args, 2)
	scale = math.clamp(scale, 0.25, 5)
	for _, player in targets do
		if player.Character then
			player.Character:ScaleTo(scale)
		end
	end
	tell(speaker, `Size {scale}: {names(targets)}`)
end)

command("sparkles", "/sparkles [name]", "pink sparkles", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local _, root = parts(player)
		if root and not root:FindFirstChild("AdminSparkles") then
			local sparkles = Instance.new("Sparkles")
			sparkles.Name = "AdminSparkles"
			sparkles.SparkleColor = Color3.fromRGB(255, 105, 180)
			sparkles.Parent = root
		end
	end
	tell(speaker, `Sparkles: {names(targets)}`)
end)

command("unsparkles", "/unsparkles [name]", "no more sparkles", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local _, root = parts(player)
		local sparkles = root and root:FindFirstChild("AdminSparkles")
		if sparkles then
			sparkles:Destroy()
		end
	end
	tell(speaker, `Sparkles off: {names(targets)}`)
end)

command("give", "/give [name] coil|speed|carpet|boombox|laser", "give an item", function(speaker, args)
	local itemName = (args[#args] or ""):lower()
	local id = GEAR[itemName]
	if not id then
		tell(speaker, "Give what? Try /give coil, /give speed, /give carpet, /give boombox or /give laser.")
		return
	end
	local targets = if #args >= 2 then findPlayers(speaker, args[1]) else { speaker }
	local tool = gearTool(id)
	if not tool then
		tell(speaker, "Couldn't load that item right now, try again.")
		return
	end
	for _, player in targets do
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			tool:Clone().Parent = backpack
		end
	end
	tell(speaker, `Gave {itemName} to {names(targets)}`)
end)

command("kick", "/kick name [reason]", "kick someone out of the game", function(speaker, args)
	local who = (args[1] or ""):lower()
	if who == "all" or who == "others" or who == "everyone" or who == "random" then
		tell(speaker, "Pick one player to kick.") -- so nobody kicks the whole server by mistake
		return
	end
	local targets = findPlayers(speaker, args[1])
	if not args[1] or #targets == 0 then
		tell(speaker, "Kick who? Type /kick and the start of their name.")
		return
	end
	local reason = table.concat(args, " ", 2)
	for _, player in targets do
		if player ~= speaker then
			player:Kick(if reason ~= "" then reason else "Kicked by the owner")
		end
	end
	tell(speaker, `Kicked: {names(targets)}`)
end)

command("announce", "/announce message", "big message on everyone's screen", function(speaker, args)
	local text = table.concat(args, " ")
	if text == "" then
		tell(speaker, "Type /announce and then your message.")
		return
	end
	-- Roblox needs everything players write to go through its chat filter before others see it
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, speaker.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		tell(speaker, "Couldn't send that right now, try again.")
		return
	end
	announceEvent:FireAllClients(filtered, speaker.DisplayName)
end)

command("day", "/day", "daytime", function(speaker)
	Lighting.ClockTime = 14
	tell(speaker, "It's daytime")
end)

command("night", "/night", "night time", function(speaker)
	Lighting.ClockTime = 0
	tell(speaker, "It's night time")
end)

-- More powers -----------------------------------------------------------------------------

-- Powers that the player's own screen does (AdminCommands.client.luau), switched on and off
-- with an attribute on the player
local function screenPower(name: string, usage: string, help: string, attribute: string, on: boolean, done: string)
	command(name, usage, help, function(speaker, args)
		local targets = findPlayers(speaker, args[1])
		for _, player in targets do
			player:SetAttribute(attribute, on)
			if attribute == "AdminNoclip" and on then
				player:SetAttribute("AdminFlying", true) -- noclip flies through walls
			end
		end
		tell(speaker, `{done}: {names(targets)}`)
	end)
end

screenPower("noclip", "/noclip [name]", "fly through walls", "AdminNoclip", true, "Noclip")
screenPower("clip", "/clip [name]", "stop going through walls", "AdminNoclip", false, "Solid again")
screenPower("infjump", "/infjump [name]", "jump again in the air, forever", "AdminInfJump", true, "Air jumps")
screenPower("uninfjump", "/uninfjump [name]", "normal jumping", "AdminInfJump", false, "No more air jumps")
screenPower("clicktp", "/clicktp [name]", "Ctrl + click somewhere to teleport there", "AdminClickTP", true, "Click teleport")
screenPower("unclicktp", "/unclicktp [name]", "no more click teleport", "AdminClickTP", false, "Click teleport off")

-- Something stuck to a player's HumanoidRootPart (a trail, fire, a spin...): add or remove it
local function rootPower(
	name: string,
	usage: string,
	help: string,
	done: string,
	add: ((root: BasePart, humanoid: Humanoid?) -> ())?,
	itemName: string
)
	command(name, usage, help, function(speaker, args)
		local targets = findPlayers(speaker, args[1])
		for _, player in targets do
			local humanoid, root = parts(player)
			if not root then
				continue
			end
			if add then
				if not root:FindFirstChild(itemName) then
					add(root, humanoid)
				end
			else
				for _, child in root:GetChildren() do
					if child.Name == itemName or child.Name == itemName .. "Attachment" then
						child:Destroy()
					end
				end
				if itemName == "AdminSpin" and humanoid then
					humanoid.AutoRotate = true
				end
			end
		end
		tell(speaker, `{done}: {names(targets)}`)
	end)
end

rootPower("trail", "/trail [name]", "a pink trail behind you", "Trail", function(root)
	local top = Instance.new("Attachment")
	top.Name = "AdminTrailAttachment"
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "AdminTrailAttachment"
	bottom.Position = Vector3.new(0, -1.2, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "AdminTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 105, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 200, 255)),
	})
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.7
	trail.LightEmission = 0.4
	trail.Parent = root
end, "AdminTrail")
rootPower("untrail", "/untrail [name]", "no more trail", "Trail off", nil, "AdminTrail")

rootPower("fire", "/fire [name]", "pink fire (it doesn't hurt)", "Fire", function(root)
	local fire = Instance.new("Fire")
	fire.Name = "AdminFire"
	fire.Color = Color3.fromRGB(255, 105, 180)
	fire.SecondaryColor = Color3.fromRGB(255, 225, 240)
	fire.Size = 6
	fire.Parent = root
end, "AdminFire")
rootPower("unfire", "/unfire [name]", "put the fire out", "Fire out", nil, "AdminFire")

rootPower("spin", "/spin [name]", "spin around and around", "Spinning", function(root, humanoid)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AdminSpinAttachment"
	attachment.Parent = root
	local spin = Instance.new("AngularVelocity")
	spin.Name = "AdminSpin"
	spin.Attachment0 = attachment
	spin.MaxTorque = math.huge
	spin.AngularVelocity = Vector3.new(0, 12, 0)
	spin.RelativeTo = Enum.ActuatorRelativeTo.World
	spin.Parent = root
	if humanoid then
		humanoid.AutoRotate = false -- otherwise walking turns you back
	end
end, "AdminSpin")
rootPower("unspin", "/unspin [name]", "stop spinning", "Stopped spinning", nil, "AdminSpin")

command("shield", "/shield [name]", "a bubble shield you can see (can't get hurt)", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local character = player.Character
		if character and not character:FindFirstChild("AdminShield") then
			local shield = Instance.new("ForceField")
			shield.Name = "AdminShield"
			shield.Visible = true
			shield.Parent = character
		end
	end
	tell(speaker, `Shield: {names(targets)}`)
end)

command("unshield", "/unshield [name]", "no more shield", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		local shield = player.Character and player.Character:FindFirstChild("AdminShield")
		if shield then
			shield:Destroy()
		end
	end
	tell(speaker, `Shield off: {names(targets)}`)
end)

-- Rainbow: the body changes colour all the time
local rainbows: { [Player]: boolean } = {}
local function setRainbow(player: Player, on: boolean)
	if on then
		if rainbows[player] then
			return
		end
		rainbows[player] = true
		task.spawn(function()
			local hue = 0
			while rainbows[player] and player.Parent do
				local character = player.Character
				if character then
					hue = (hue + 0.03) % 1
					local color = Color3.fromHSV(hue, 0.5, 1)
					for _, part in character:GetChildren() do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
							if part:GetAttribute("AdminColor") == nil then
								part:SetAttribute("AdminColor", part.Color) -- to put it back later
							end
							part.Color = color
						end
					end
				end
				task.wait(0.1)
			end
		end)
	else
		rainbows[player] = nil
		local character = player.Character
		if character then
			for _, part in character:GetChildren() do
				local was = part:GetAttribute("AdminColor")
				if part:IsA("BasePart") and typeof(was) == "Color3" then
					part.Color = was
					part:SetAttribute("AdminColor", nil)
				end
			end
		end
	end
end
Players.PlayerRemoving:Connect(function(player)
	rainbows[player] = nil
end)

command("rainbow", "/rainbow [name]", "rainbow colours", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		setRainbow(player, true)
	end
	tell(speaker, `Rainbow: {names(targets)}`)
end)

command("unrainbow", "/unrainbow [name]", "normal colours again", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		setRainbow(player, false)
	end
	tell(speaker, `Colours back: {names(targets)}`)
end)

command("gravity", "/gravity [number]", "gravity for everyone (normal is 196, the moon is about 50)", function(speaker, args)
	local gravity = math.clamp(tonumber(args[1]) or 50, 0, 1000)
	workspace.Gravity = gravity
	tell(speaker, `Gravity is {gravity}{if gravity < 100 then " (moon jumps!)" else ""}`)
end)

command("confetti", "/confetti", "confetti on everyone's screen", function(speaker)
	confettiEvent:FireAllClients()
	tell(speaker, "Confetti!")
end)

-- /normal: everything back to normal, every power off
command("normal", "/normal [name]", "everything back to normal (all powers off)", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		for _, attribute in { "AdminFlying", "AdminNoclip", "AdminInfJump", "AdminClickTP" } do
			player:SetAttribute(attribute, false)
		end
		setRainbow(player, false)
		setInvisible(player, false)
		local humanoid, root = parts(player)
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.UseJumpPower = true
			humanoid.JumpPower = 50
			humanoid.AutoRotate = true
		end
		if root then
			root.Anchored = false
			for _, child in root:GetChildren() do
				if string.sub(child.Name, 1, 5) == "Admin" then
					child:Destroy() -- trail, fire, spin, sparkles
				end
			end
		end
		local character = player.Character
		if character then
			for _, name in { "AdminGod", "AdminShield" } do
				local shield = character:FindFirstChild(name)
				if shield then
					shield:Destroy()
				end
			end
			if character:GetScale() ~= 1 then
				character:ScaleTo(1)
			end
		end
	end
	tell(speaker, `Back to normal: {names(targets)}`)
end)

-- Anyone who's flying can land themselves (the Land button and the F key)
landEvent.OnServerEvent:Connect(function(player)
	player:SetAttribute("AdminFlying", false)
	player:SetAttribute("AdminNoclip", false)
end)

-- Hook them up to the chat -------------------------------------------------------------

local chatCommands = Instance.new("Folder")
chatCommands.Name = "AdminCommands"
chatCommands.Parent = TextChatService

for name, info in COMMANDS do
	local chatCommand = Instance.new("TextChatCommand")
	chatCommand.Name = "Admin_" .. name
	chatCommand.PrimaryAlias = "/" .. name
	chatCommand.SecondaryAlias = ";" .. name
	pcall(function()
		(chatCommand :: any).AutocompleteVisible = false -- other players don't see them in the chat
	end)
	chatCommand.Parent = chatCommands

	chatCommand.Triggered:Connect(function(textSource, text)
		local speaker = Players:GetPlayerByUserId(textSource.UserId)
		if not speaker then
			return
		end
		if not isAdmin(speaker) then
			tell(speaker, "Only the owner can use admin commands.")
			return
		end
		local args = {}
		for word in string.gmatch(text, "%S+") do
			table.insert(args, word)
		end
		table.remove(args, 1) -- the command itself
		local ok, problem = pcall(info.run, speaker, args)
		if not ok then
			warn(`[Admin] /{name} didn't work: {problem}`)
			tell(speaker, `/{name} didn't work, sorry.`)
		end
	end)
end

-- The admin panel ------------------------------------------------------------------------

-- Tell each player's screen whether they're an admin, so only admins get the panel
local function markAdmin(player: Player)
	player:SetAttribute("IsAdmin", isAdmin(player))
end
Players.PlayerAdded:Connect(markAdmin)
for _, player in Players:GetPlayers() do
	task.spawn(markAdmin, player)
end

-- A button in the panel was pressed. Check again that it's really an admin: never trust a
-- player's screen on its own.
runEvent.OnServerEvent:Connect(function(player, name, words)
	if not isAdmin(player) or typeof(name) ~= "string" or not COMMANDS[name] then
		return
	end
	local args = {}
	if typeof(words) == "table" then
		for index = 1, 10 do
			local word = words[index]
			if typeof(word) ~= "string" then
				break
			end
			table.insert(args, word:sub(1, 200))
		end
	end
	local ok, problem = pcall(COMMANDS[name].run, player, args)
	if not ok then
		warn(`[Admin] {name} didn't work: {problem}`)
		tell(player, `{name} didn't work, sorry.`)
	end
end)

print(`[Admin] {#ORDER + 1} admin commands ready (type /cmds in the chat, or use the Admin button)`)

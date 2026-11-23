-- Admin commands for the owner of the game. Type them in the chat, starting with / (or ;),
-- for example "/fly", "/speed 50" or "/bring bob". Type "/cmds" in the game to see them all.
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

command("unfly", "/unfly [name]", "stop flying", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	for _, player in targets do
		player:SetAttribute("AdminFlying", false)
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

command("normal", "/normal [name]", "normal speed and jump again", function(speaker, args)
	local targets = findPlayers(speaker, args[1])
	eachHumanoid(targets, function(humanoid)
		humanoid.WalkSpeed = 16
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
	end)
	tell(speaker, `Back to normal: {names(targets)}`)
end)

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

print(`[Admin] {#ORDER + 1} admin commands ready (type /cmds in the chat)`)

-- toxic hub | auto levi only | wind ui
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local character, humanoid, humanoidRootPart

local function refreshChar(c)
	character = c or Player.Character
	if not character then return end
	humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
end
refreshChar(Player.Character)
Player.CharacterAdded:Connect(function(c) task.wait(0.4) refreshChar(c) end)

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function CommF(...)
	local r = Remotes and Remotes:FindFirstChild("CommF_")
	if not r then return end
	local a = {...}
	local ok, res = pcall(function() return r:InvokeServer(unpack(a)) end)
	return ok and res or nil
end

getgenv().ToxicLevi = getgenv().ToxicLevi or {}
local L = getgenv().ToxicLevi
L.SelectedBoat = L.SelectedBoat or (Player.Name .. " Boat")
L.AutoFind = L.AutoFind or false
L.BoatSpeed = L.BoatSpeed or 250
L.BoatHeight = L.BoatHeight or 25
L.FoundLevi = false

local function isBoat(obj)
	if not obj then return false end
	local n = string.lower(obj.Name)
	if n:find("boat") or n:find("ship") or n:find("pirate") or n:find("marine") then return true end
	if obj:GetAttribute("Owner") or obj:FindFirstChild("Owner") then return true end
	if obj:FindFirstChild("VehicleSeat") or obj:FindFirstChildWhichIsA("VehicleSeat", true) then return true end
	return false
end

local function boatOwnerName(boat)
	if not boat then return nil end
	local attr = boat:GetAttribute("Owner")
	if typeof(attr) == "string" then return attr end
	if typeof(attr) == "Instance" and attr:IsA("Player") then return attr.Name end
	local own = boat:FindFirstChild("Owner")
	if own then
		if own:IsA("ObjectValue") and own.Value then
			if own.Value:IsA("Player") then return own.Value.Name end
			return tostring(own.Value)
		end
		if own:IsA("StringValue") then return own.Value end
	end
	-- name patterns: "PlayerName's Boat", "Boat_PlayerName"
	local name = boat.Name
	for _, plr in ipairs(Players:GetPlayers()) do
		if name:find(plr.Name, 1, true) then return plr.Name end
	end
	return nil
end

local function getBoatRoot(boat)
	if not boat then return nil end
	if boat:IsA("BasePart") then return boat end
	return boat:FindFirstChild("HumanoidRootPart")
		or boat:FindFirstChild("PrimaryPart")
		or boat.PrimaryPart
		or boat:FindFirstChildWhichIsA("VehicleSeat", true)
		or boat:FindFirstChildWhichIsA("BasePart", true)
end

local function scanBoats()
	local list, labels = {}, {}
	local folders = {
		Workspace:FindFirstChild("Boats"),
		Workspace:FindFirstChild("Boat"),
		Workspace:FindFirstChild("Vehicles"),
		Workspace:FindFirstChild("Sea"),
		Workspace,
	}
	local seen = {}
	for _, folder in ipairs(folders) do
		if not folder then continue end
		local children = folder == Workspace and folder:GetChildren() or folder:GetDescendants()
		if folder == Workspace then
			for _, obj in ipairs(folder:GetChildren()) do
				if isBoat(obj) and not seen[obj] then
					seen[obj] = true
					local owner = boatOwnerName(obj) or "Unknown"
					local label = owner .. " | " .. obj.Name
					if owner == Player.Name then label = "[YOU] " .. label end
					table.insert(list, { boat = obj, label = label, owner = owner })
					table.insert(labels, label)
				end
			end
		else
			for _, obj in ipairs(folder:GetChildren()) do
				if (isBoat(obj) or obj:IsA("Model")) and not seen[obj] then
					-- prefer models that look like boats
					if isBoat(obj) or obj:FindFirstChildWhichIsA("VehicleSeat", true) then
						seen[obj] = true
						local owner = boatOwnerName(obj) or "Unknown"
						local label = owner .. " | " .. obj.Name
						if owner == Player.Name then label = "[YOU] " .. label end
						table.insert(list, { boat = obj, label = label, owner = owner })
						table.insert(labels, label)
					end
				end
			end
		end
	end
	-- always include self option even if boat not found yet
	local hasSelf = false
	for _, e in ipairs(list) do if e.owner == Player.Name then hasSelf = true break end end
	if not hasSelf then
		local label = "[YOU] " .. Player.Name .. " | (spawn boat)"
		table.insert(list, 1, { boat = nil, label = label, owner = Player.Name })
		table.insert(labels, 1, label)
	end
	table.sort(list, function(a, b)
		if a.owner == Player.Name and b.owner ~= Player.Name then return true end
		if b.owner == Player.Name and a.owner ~= Player.Name then return false end
		return a.label < b.label
	end)
	labels = {}
	for _, e in ipairs(list) do table.insert(labels, e.label) end
	return list, labels
end

local boatCache = {}
local function resolveSelectedBoat()
	local list = scanBoats()
	for _, e in ipairs(list) do
		if e.label == L.SelectedBoat then
			if e.boat and e.boat.Parent then return e.boat end
		end
	end
	-- fallback: boat owned by local player
	for _, e in ipairs(list) do
		if e.owner == Player.Name and e.boat and e.boat.Parent then return e.boat end
	end
	return nil
end

local function sitOnBoat(boat)
	if not boat or not humanoid then return end
	local seat = boat:FindFirstChildWhichIsA("VehicleSeat", true) or boat:FindFirstChildWhichIsA("Seat", true)
	if seat and humanoidRootPart then
		if (seat.Position - humanoidRootPart.Position).Magnitude > 20 then
			humanoidRootPart.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
			task.wait(0.15)
		end
		pcall(function() seat:Sit(humanoid) end)
	end
end

-- Levi detection
local function findLeviathan()
	local names = { "Leviathan", "leviathan", "Levi", "FrozenLeviathan" }
	local folders = {
		Workspace:FindFirstChild("Enemies"),
		Workspace:FindFirstChild("Monsters"),
		Workspace:FindFirstChild("Sea"),
		Workspace:FindFirstChild("Map"),
		Workspace,
	}
	for _, folder in ipairs(folders) do
		if not folder then continue end
		for _, obj in ipairs(folder:GetDescendants()) do
			if obj:IsA("Model") or obj:IsA("BasePart") then
				local n = obj.Name
				for _, key in ipairs(names) do
					if n == key or n:lower():find("leviathan") then
						local hum = obj:FindFirstChildOfClass("Humanoid")
						local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart", true)
						if hum and hum.Health <= 0 then break end
						if root then return obj, root end
						if obj:IsA("BasePart") then return obj, obj end
					end
				end
			end
		end
	end
	return nil, nil
end

-- boat drive
local boatBV, boatBG
local function clearBoatForce()
	if boatBV then pcall(function() boatBV:Destroy() end) boatBV = nil end
	if boatBG then pcall(function() boatBG:Destroy() end) boatBG = nil end
end

local function driveBoat(boat, direction)
	local root = getBoatRoot(boat)
	if not root then return end
	if not boatBV or boatBV.Parent ~= root then
		clearBoatForce()
		boatBV = Instance.new("BodyVelocity")
		boatBV.Name = "ToxicLeviBV"
		boatBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		boatBV.P = 5000
		boatBV.Parent = root
		boatBG = Instance.new("BodyGyro")
		boatBG.Name = "ToxicLeviBG"
		boatBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		boatBG.P = 3000
		boatBG.Parent = root
	end
	local speed = math.clamp(L.BoatSpeed or 250, 10, 400)
	local height = L.BoatHeight or 25
	local pos = root.Position
	-- keep height above "floor" / sea level approx
	local targetY = math.max(pos.Y, height)
	if direction.Magnitude > 0 then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 0 then flat = flat.Unit end
		boatBV.Velocity = flat * speed + Vector3.new(0, (targetY - pos.Y) * 2, 0)
		boatBG.CFrame = CFrame.lookAt(pos, pos + flat + Vector3.new(0, 0.01, 0))
	else
		boatBV.Velocity = Vector3.new(0, (targetY - pos.Y) * 2, 0)
	end
	-- hard height correct
	if math.abs(pos.Y - height) > 8 then
		root.CFrame = CFrame.new(pos.X, height, pos.Z) * (root.CFrame - root.CFrame.Position)
	end
end

-- search pattern (spiral / rotate scan over sea)
local searchAngle, searchRadius = 0, 0
local function nextSearchDir(rootPos)
	searchAngle += 0.35
	searchRadius = math.min(searchRadius + 2, 2000)
	local x = math.cos(searchAngle) * searchRadius
	local z = math.sin(searchAngle) * searchRadius
	local target = Vector3.new(rootPos.X + x, L.BoatHeight or 25, rootPos.Z + z)
	return (target - rootPos)
end

local function resetSearch()
	searchAngle, searchRadius = 0, 0
	L.FoundLevi = false
end

-- MAIN LOOP
task.spawn(function()
	while true do
		if L.AutoFind and not L.FoundLevi then
			local boat = resolveSelectedBoat()
			if not boat then
				-- try spawn / claim boat via remote (common)
				pcall(function() CommF("BuyBoat", "Pirate") end)
				pcall(function() CommF("Boat", "Spawn") end)
				task.wait(1)
			else
				sitOnBoat(boat)
				local levi, leviRoot = findLeviathan()
				if levi and leviRoot then
					L.FoundLevi = true
					L.AutoFind = false
					clearBoatForce()
					-- face / move close once
					local root = getBoatRoot(boat)
					if root then
						root.CFrame = CFrame.new(Vector3.new(leviRoot.Position.X, L.BoatHeight or 25, leviRoot.Position.Z))
					end
					pcall(function()
						game:GetService("StarterGui"):SetCore("SendNotification", {
							Title = "Toxic Hub Levi",
							Text = "Leviathan FOUND!",
							Duration = 5,
						})
					end)
				else
					local root = getBoatRoot(boat)
					if root then
						local dir = nextSearchDir(root.Position)
						driveBoat(boat, dir)
					end
				end
			end
			task.wait(0.1)
		else
			if not L.AutoFind then clearBoatForce() end
			task.wait(0.25)
		end
	end
end)

Player.Idled:Connect(function()
	pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
end)

-- UI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "Toxic Hub",
	Icon = "waves",
	Author = "Auto Levi",
	Folder = "ToxicLevi",
	Size = UDim2.fromOffset(460, 320),
	Transparent = true,
	Theme = "Dark",
	SideBarWidth = 120,
})

local TabMain = Window:Tab({ Title = "Main", Icon = "ship" })

local boatList, boatLabels = scanBoats()
L.SelectedBoat = boatLabels[1] or L.SelectedBoat

local boatDropdown
boatDropdown = TabMain:Dropdown({
	Title = "Boat / Player",
	Values = #boatLabels > 0 and boatLabels or { Player.Name },
	Value = L.SelectedBoat,
	Callback = function(v)
		L.SelectedBoat = v
		L.FoundLevi = false
	end,
})

TabMain:Button({
	Title = "Refresh Boat List",
	Callback = function()
		boatList, boatLabels = scanBoats()
		L.SelectedBoat = boatLabels[1] or L.SelectedBoat
		WindUI:Notify({
			Title = "Toxic Hub",
			Content = "Boats: " .. tostring(#boatLabels),
			Duration = 2,
		})
	end,
})

TabMain:Toggle({
	Title = "Auto Find Levi",
	Value = L.AutoFind,
	Callback = function(v)
		L.AutoFind = v
		if v then
			resetSearch()
			WindUI:Notify({ Title = "Toxic Hub", Content = "Searching Leviathan...", Duration = 2 })
		else
			clearBoatForce()
		end
	end,
})

TabMain:Slider({
	Title = "Boat Speed",
	Value = { Min = 50, Max = 400, Default = L.BoatSpeed },
	Callback = function(v) L.BoatSpeed = v end,
})

TabMain:Slider({
	Title = "Boat Height",
	Value = { Min = 5, Max = 120, Default = L.BoatHeight },
	Callback = function(v) L.BoatHeight = v end,
})

TabMain:Paragraph({
	Title = "Status",
	Desc = "Select your spawned boat (or [YOU]), set speed/height, enable Auto Find Levi. Stops when Leviathan is found.",
})

-- refresh labels periodically
task.spawn(function()
	while true do
		task.wait(5)
		pcall(function()
			boatList, boatLabels = scanBoats()
		end)
	end
end)

WindUI:Notify({ Title = "Toxic Hub", Content = "Auto Levi loaded", Duration = 3 })
print("[Toxic Hub] Auto Levi ready")

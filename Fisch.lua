        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Lighting = game:GetService("Lighting")
        local LocalPlayer = Players.LocalPlayer
        if not LocalPlayer then
            local t = os.clock()
            repeat task.wait(0.5); LocalPlayer = Players.LocalPlayer
            until LocalPlayer or os.clock() - t > 30
            if not LocalPlayer then error("[Fisch] LocalPlayer not found") end
        end

        local Mouse = LocalPlayer:GetMouse()
        local Camera = workspace.CurrentCamera

        local V2 = Vector2.new
        local C3 = Color3.fromRGB
        local floor = math.floor
        local insert = table.insert

        local settingsLock = false

        local Settings = {
            Enabled = false,

            AutoShake = false, 
            AutoReel = true, 
            AutoCast = false,

            ShakeDelay = 0.001, 

            ReelPollRate = 0.003,
            MemorySize = 12, 
            PredictionFrames = 1,
            SlideCompensation = 1, 
            ErrorMemorySize = 5,
            ErrorPredictionTime = 0.2, 
            DirectionChangeCooldown = 0.02,

            AutoTotem = false, 
            DayTotem = "Sundial Totem", 
            NightTotem = "Aurora Totem",

            AutoPerfectCast = false, 
            PerfectCastHoldTime = 1.2,
        }

        local isReeling = false
        local isShaking = false
        local isHolding = false

        local fishMemory = {}
        local barMemory = {}
        local fishVelocity = 0
        local fishAccel = 0
        local barVelocity = 0
        local predictedFishX = 0
        local errorMemory = {}
        local errorVelocity = 0
        local lastDirection = nil
        local lastDirectionChangeTime = 0

        local lastReelSeen = 0

        local reelVersion = 0
        local castVersion = 0
        local totemVersion = 0
        local lastFishScanTime = 0

        local threadHeartbeats = { reel = 0, cast = 0, shake = 0 }
        local threadActive = { reel = false, cast = false, shake = false }
        local HEARTBEAT_TIMEOUT = 8

        local currentRod = nil
        local rodStats = { Name = "None", Control = 0.2, Resilience = 0, Source = "default" }

        local currentFish = { Name = "None", Rarity = "-" }

        local Stats = {
            SessionStart = os.clock(), TotalCatches = 0,
            ShinyCount = 0, MutationCount = 0, BestCatch = "None",
        }

        local VK_MOUSE1 = 0x01

        local availableTotems = {
            "None", "Sundial Totem", "Meteor Totem", "Smokescreen Totem",
            "Windset Totem", "Tempest Totem", "Eclipse Totem", "Avalanche Totem",
            "Aurora Totem", "Starfall Totem", "Cursed Storm Totem", "Blue Moon Totem",
            "Blizzard Totem", "Frost Moon Totem", "Poseidon's Wrath Totem",
            "Zeus's Storm Totem", "Clear Cast Totem",
        }
        local lastTotemUse = 0
        local lastCycleWasDay = nil

        local TeleportLocations = {
            {Name = "Moosewood",          Position = Vector3.new(500, 161, 235),      Cat = "Surface"},
            {Name = "Roslit Bay",         Position = Vector3.new(-1720, 148, 733),    Cat = "Surface"},
            {Name = "Mushgrove",          Position = Vector3.new(2459, 131, -646),    Cat = "Surface"},
            {Name = "Snowcap",            Position = Vector3.new(2649, 156, 2402),    Cat = "Surface"},
            {Name = "Terrapin",           Position = Vector3.new(-223, 155, 1996),    Cat = "Surface"},
            {Name = "Ancient Isle",       Position = Vector3.new(5965, 259, 225),     Cat = "Surface"},
            {Name = "Lost Jungle",        Position = Vector3.new(-2717, 154, -2026),  Cat = "Surface"},
            {Name = "Forsaken Shores",    Position = Vector3.new(-2810, 211, 1539),   Cat = "Surface"},
            {Name = "Sunstone",           Position = Vector3.new(-930, 226, -993),    Cat = "Surface"},
            {Name = "Northern Expedition",Position = Vector3.new(19939, 1212, 5277),  Cat = "Surface"},
            {Name = "Boreal Pines",       Position = Vector3.new(21577, 135, 4136),   Cat = "Surface"},
            {Name = "Treasure Island",    Position = Vector3.new(8197, 230, -17186),  Cat = "Surface"},
            {Name = "Castaway Cliffs",    Position = Vector3.new(549, 310, -2037),    Cat = "Surface"},
            {Name = "Scoria Reach",       Position = Vector3.new(-5095, 146, -1500),  Cat = "Surface"},
            {Name = "Grand Reef",         Position = Vector3.new(-3591, 146, 494),    Cat = "Surface"},
            {Name = "Clouds",             Position = Vector3.new(1495, 2601, -1727),  Cat = "Surface"},
            {Name = "Everturn Forest",    Position = Vector3.new(2530, 185, -2619),   Cat = "Surface"},

            {Name = "The Depths",         Position = Vector3.new(946, -711, 1232),    Cat = "Deep"},
            {Name = "Atlantis",           Position = Vector3.new(-4301, -603, 1816),  Cat = "Deep"},
            {Name = "Tidefall",           Position = Vector3.new(2877, -1100, -50),   Cat = "Deep"},
            {Name = "Keepers Altar",      Position = Vector3.new(1350, -805, -62),    Cat = "Deep"},
            {Name = "Desolate Deep",      Position = Vector3.new(-1658, -214, -2847), Cat = "Deep"},
            {Name = "Crystal Cove",       Position = Vector3.new(1349, -596, 2331),   Cat = "Deep"},
            {Name = "Mineshaft",          Position = Vector3.new(-739, -864, -158),   Cat = "Deep"},
            {Name = "Vertigo",            Position = Vector3.new(-126, -515, 1143),   Cat = "Deep"},
            {Name = "Luminescent Cavern", Position = Vector3.new(-1093, -336, -4128), Cat = "Deep"},
            {Name = "Toxic Grove",        Position = Vector3.new(-2516, -276, -2354), Cat = "Deep"},
            {Name = "Living Garden",      Position = Vector3.new(-2387, -316, -2769), Cat = "Deep"},

            {Name = "Forgotten Temple",   Position = Vector3.new(-4862, -1792, -10114),Cat = "Special"},
            {Name = "Calm Zone",          Position = Vector3.new(-4221, -11175, 3874), Cat = "Special"},
            {Name = "Abyssal Zenith",     Position = Vector3.new(-13454, -11035, 197), Cat = "Special"},
            {Name = "Veil of Forsaken",   Position = Vector3.new(-2528, -11220, 6943), Cat = "Special"},
            {Name = "Challenger's Deep",  Position = Vector3.new(-759, -3283, -665),   Cat = "Special"},
            {Name = "Cultist Lair",       Position = Vector3.new(4468, -2687, -4675),  Cat = "Special"},
            {Name = "Volcanic Vents",     Position = Vector3.new(-3474, -2257, 3847),  Cat = "Special"},
            {Name = "The Void",           Position = Vector3.new(-32096, 9997, -23304),Cat = "Special"},
        }

        local warpCategories = {"Surface", "Deep", "Special"}

        local function getPlayerGui()
            return LocalPlayer:FindFirstChildOfClass("PlayerGui")
        end

        local function addToMemory(memory, value, maxSize)
            table.insert(memory, value)
            while #memory > maxSize do
                table.remove(memory, 1)
            end
        end

        local function calculateVelocity(memory)
            if #memory < 2 then return 0 end
            local total = 0
            for i = 2, #memory do
                total = total + (memory[i] - memory[i - 1])
            end
            return total / (#memory - 1)
        end

        local function calculateAcceleration(memory)
            if #memory < 3 then return 0 end
            local vel1 = memory[#memory] - memory[#memory - 1]
            local vel2 = memory[#memory - 1] - memory[#memory - 2]
            return vel1 - vel2
        end

        local function predictPosition(pos, vel, accel, frames)
            return pos + (vel * frames) + (0.5 * accel * frames * frames)
        end

        local function resetMemory()
            fishMemory = {}
            barMemory = {}
            fishVelocity = 0
            fishAccel = 0
            barVelocity = 0
            predictedFishX = 0
            errorMemory = {}
            errorVelocity = 0
            lastDirection = nil
            lastDirectionChangeTime = 0
        end

        local function formatTime(seconds)
            local h = math.floor(seconds / 3600)
            local m = math.floor((seconds % 3600) / 60)
            local s = math.floor(seconds % 60)
            return string.format("%02d:%02d:%02d", h, m, s)
        end

        local RodDatabase = {

            {p = "tryhard",                 Control = -0.17, Resilience = -500},
            {p = "duskwire",                Control = -0.20, Resilience = 175},
            {p = "long",                    Control = -0.10, Resilience = 20},
            {p = "firefly",                 Control = -0.01, Resilience = 25},
            {p = "spirit of the forest",    Control = -0.02, Resilience = 10},
            {p = "splitbranch",             Control = -0.1, Resilience = 45},
            {p = "flimsy",                  Control = 0.00,  Resilience = 0},
            {p = "plastic",                 Control = 0.00,  Resilience = 10},
            {p = "fabulous",                Control = 0.00,  Resilience = 60},
            {p = "verdant",                 Control = 0.12,  Resilience = 87},
            {p = "plaguereaver",            Control = 0.28,  Resilience = 0},
            {p = "thalassar",               Control = -0.2,  Resilience = -75},
            {p = "carbon",                  Control = 0.05,  Resilience = 10},
            {p = "fast",                    Control = 0.05,  Resilience = -5},
            {p = "magnet",                  Control = 0.05,  Resilience = 0},
            {p = "trident",                 Control = 0.05,  Resilience = 0},
            {p = "mythical",                Control = 0.05,  Resilience = 15},
            {p = "frost warden",            Control = 0.05,  Resilience = 15},
            {p = "steady",                  Control = 0.05,  Resilience = 30},
            {p = "astral",                  Control = 0.05,  Resilience = 5},
            {p = "event horizon",           Control = 0.05,  Resilience = 5},
            {p = "frog",                    Control = 0.05,  Resilience = 5},
            {p = "stone",                   Control = 0.05,  Resilience = 5},
            {p = "wind elemental",          Control = 0.055, Resilience = 55},

            {p = "aurora",        Control = 0.06,  Resilience = 16},
            {p = "lucky",         Control = 0.07,  Resilience = 7},
            {p = "ruinous",       Control = 0.08,  Resilience = 25},
            {p = "luminescent",   Control = 0.10,  Resilience = 12},
            {p = "reinforced",    Control = 0.10,  Resilience = 15},
            {p = "requiem",       Control = 0.10,  Resilience = 63},
            {p = "sunken",        Control = 0.15,  Resilience = 15},
            {p = "kings",         Control = 0.15,  Resilience = 35},
            {p = "great dreamer", Control = 0.17,  Resilience = 17},
            {p = "wildflower",    Control = 0.17,  Resilience = 17},
            {p = "onirifalx",     Control = 0.19,  Resilience = -999},
            {p = "training",      Control = 0.20,  Resilience = 20},
            {p = "destiny",       Control = 0.20,  Resilience = 10},
            {p = "kraken",        Control = 0.20,  Resilience = 15},
            {p = "celestial",     Control = 0.21,  Resilience = 25},
            {p = "no%-life",      Control = 0.23,  Resilience = 10},
            {p = "dreambreaker",  Control = 0.23,  Resilience = 66},
            {p = "astraeus",      Control = 0.30,  Resilience = 20},
            {p = "bamboo",        Control = 0.05,  Resilience = 5},
            {p = "wooden",        Control = 0.05,  Resilience = 5},
            {p = "starter",       Control = 0.05,  Resilience = 5},
            {p = "stabilizer",    Control = 0.10,  Resilience = 20},
            {p = "enchanted",     Control = 0.10,  Resilience = 15},
            {p = "rod of",        Control = 0.15,  Resilience = 15},
            {p = "sanguine",      Control = 0.10,  Resilience = 15},
            {p = "chrysalis",     Control = 0.10,  Resilience = 15},
            {p = "polaris",       Control = 0.10,  Resilience = 15},
            {p = "eternal",       Control = 0.15,  Resilience = 20},
            {p = "poseidon",      Control = 0.15,  Resilience = 20},
            {p = "evil",          Control = 0.10,  Resilience = 10},
            {p = "pitchfork",     Control = 0.10,  Resilience = 10},
            {p = "shadow",        Control = 0.10,  Resilience = 15},
            {p = "wingripper",    Control = 0.10,  Resilience = 15},
            {p = "sword",         Control = 0.10,  Resilience = 10},
            {p = "rainbow",       Control = 0.10,  Resilience = 15},
            {p = "coral",         Control = 0.10,  Resilience = 15},
            {p = "brine",         Control = 0.10,  Resilience = 15},
            {p = "cursed",        Control = -0.05, Resilience = 10},
            {p = "corrupted",     Control = -0.05, Resilience = 10},
            {p = "infernal",      Control = 0.05,  Resilience = 10},
            {p = "gingerbread",   Control = 0.05,  Resilience = 10},
            {p = "candy cane",    Control = 0.05,  Resilience = 10},
            {p = "fischmas",      Control = 0.05,  Resilience = 10},
            {p = "jinglestar",    Control = 0.05,  Resilience = 10},
            {p = "north%-star",   Control = 0.05,  Resilience = 10},
            {p = "brick",         Control = 0.05,  Resilience = 10},
            {p = "adventurer",    Control = 0.05,  Resilience = 10},
            {p = "antler",        Control = 0.05,  Resilience = 10},
            {p = "brothers",      Control = 0.05,  Resilience = 10},
            {p = "buddy",         Control = 0.05,  Resilience = 10},
            {p = "fixer",         Control = 0.05,  Resilience = 10},
            {p = "superstar",     Control = 0.05,  Resilience = 10},
            {p = "patriot",       Control = 0.05,  Resilience = 10},
            {p = "demon",         Control = 0.10,  Resilience = 15},
            {p = "experimental",  Control = 0.10,  Resilience = 15},
            {p = "mission",       Control = 0.05,  Resilience = 10},
            {p = "paleontolog",   Control = 0.05,  Resilience = 10},
            {p = "frostfire",     Control = 0.05,  Resilience = 15},
            {p = "smurf",         Control = 0.05,  Resilience = 10},
            {p = "divine",        Control = 0.15,  Resilience = 20},
            {p = "masterline",    Control = 0.15,  Resilience = 20},
            {p = "zeus",          Control = 0.15,  Resilience = 20},
        }

        local function detectEquippedRod()
            local character = LocalPlayer.Character
            if not character then return nil end
            return character:FindFirstChildOfClass("Tool")
        end

        local function readRodStats(rod)
            if not rod then
                return {Name = "None", Control = 0.2, Resilience = 0, Source = "default"}
            end

            local stats = {Name = rod.Name or "Unknown", Control = 0.2, Resilience = 0, Source = "default"}

            pcall(function()
                local attrs = rod:GetAttributes()
                if attrs then
                    local ctrl = attrs.Control or attrs.control or attrs.ControlLevel
                    if ctrl then
                        stats.Control = tonumber(ctrl) or 0.2
                        stats.Source = "attribute"
                    end
                end
            end)
            if stats.Source == "attribute" then return stats end

            pcall(function()
                for _, child in ipairs(rod:GetChildren()) do
                    local cname = string.lower(child.Name or "")
                    if cname == "control" or cname == "controllevel" or cname == "controlstat" then
                        if child:IsA("NumberValue") or child:IsA("IntValue") then
                            stats.Control = child.Value
                            stats.Source = "child_value"
                        end
                    end
                end
            end)
            if stats.Source == "child_value" then return stats end

            pcall(function()
                local paths = {
                    ReplicatedStorage:FindFirstChild("Rods"),
                    ReplicatedStorage:FindFirstChild("rods"),
                    ReplicatedStorage:FindFirstChild("RodData"),
                    ReplicatedStorage:FindFirstChild("Items"),
                    ReplicatedStorage:FindFirstChild("Config"),
                }
                for _, folder in ipairs(paths) do
                    if folder then
                        local data = folder:FindFirstChild(rod.Name)
                        if data then
                            local ctrl = data:FindFirstChild("Control") or data:FindFirstChild("control")
                            if ctrl and (ctrl:IsA("NumberValue") or ctrl:IsA("IntValue")) then
                                stats.Control = ctrl.Value
                                stats.Source = "replicated"
                                return
                            end
                            local ac = nil
                            pcall(function() ac = data:GetAttribute("Control") or data:GetAttribute("control") end)
                            if ac then
                                stats.Control = tonumber(ac) or 0.2
                                stats.Source = "replicated"
                                return
                            end
                        end
                    end
                end
            end)
            if stats.Source == "replicated" then return stats end

            local nameLower = ""
            pcall(function() nameLower = string.lower(rod.Name) end)
            for _, entry in ipairs(RodDatabase) do
                if string.find(nameLower, entry.p) then
                    stats.Control = entry.Control
                    stats.Resilience = entry.Resilience or 0
                    stats.Source = "database"
                    return stats
                end
            end

            stats.Source = "default"
            return stats
        end

        local function isUIActive(element)
            if not element then return false end
            local ok, pos = pcall(function() return element.AbsolutePosition end)
            return ok and pos and (pos.X > 0 or pos.Y > 0)
        end

        local function findActiveReel()
            local pg = getPlayerGui()
            if not pg then return nil, nil, nil, nil, "no_playerGui" end
            local reelGui = pg:FindFirstChild("reel")
            if not reelGui then return nil, nil, nil, nil, "no_reelGui" end
            local bar = reelGui:FindFirstChild("bar")
            if not bar then return nil, nil, nil, nil, "no_bar" end
            if not isUIActive(bar) then return nil, nil, nil, nil, "bar_inactive" end
            local playerbar = bar:FindFirstChild("playerbar")
            local fish = bar:FindFirstChild("fish")
            local progress = bar:FindFirstChild("progress")
            if playerbar and fish then return playerbar, fish, bar, progress, nil end
            return nil, nil, nil, nil, "missing_elements"
        end

        local function scanCurrentFish()
            pcall(function()
                local pg = getPlayerGui()
                if not pg then return end
                local reelGui = pg:FindFirstChild("reel")
                if not reelGui then return end

                local fishLabel = reelGui:FindFirstChild("fish")
                if fishLabel and fishLabel:IsA("TextLabel") then
                    currentFish.Name = fishLabel.Text or "Unknown"
                end

                local bar = reelGui:FindFirstChild("bar")
                if bar then
                    for _, obj in ipairs(bar:GetDescendants()) do
                        local n = string.lower(obj.Name or "")
                        if string.find(n, "spark") or string.find(n, "shiny") then
                            currentFish.Rarity = "Shiny"; return
                        elseif string.find(n, "mutat") then
                            currentFish.Rarity = "Mutation"; return
                        end
                    end
                    local fishElem = bar:FindFirstChild("fish")
                    if fishElem and fishElem.BackgroundColor3 then
                        local c = fishElem.BackgroundColor3
                        if c.R > 0.8 and c.G < 0.3 and c.B < 0.3 then currentFish.Rarity = "Legendary"
                        elseif c.R > 0.5 and c.G < 0.3 and c.B > 0.5 then currentFish.Rarity = "Mythical"
                        elseif c.B > 0.6 and c.R < 0.3 then currentFish.Rarity = "Rare"
                        elseif c.G > 0.6 and c.R < 0.4 and c.B < 0.4 then currentFish.Rarity = "Uncommon"
                        else currentFish.Rarity = "Common" end
                    end
                end
            end)
        end

        local function teleportTo(position)
            pcall(function()
                local character = LocalPlayer.Character
                if not character then
                    local t = os.clock()
                    repeat task.wait(0.1); character = LocalPlayer.Character
                    until character or os.clock() - t > 10
                end
                if not character then return end
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    local t = os.clock()
                    repeat task.wait(0.1); hrp = character:FindFirstChild("HumanoidRootPart")
                    until hrp or os.clock() - t > 5
                end
                if hrp then hrp.Position = Vector3.new(position.X, position.Y, position.Z) end
            end)
        end

        local function getGameClock()
            local ok, hour, timeStr = pcall(function()
                local world = ReplicatedStorage:FindFirstChild("world")
                if world then
                    local cycle = world:FindFirstChild("cycle")
                    if cycle and cycle:IsA("StringValue") then
                        local v = string.lower(cycle.Value or "")
                        if v == "day" then return 12, "Day" end
                        if v == "night" then return 0, "Night" end
                    end
                end
                local ct = Lighting.ClockTime
                if ct and type(ct) == "number" then
                    local h = math.floor(ct)
                    local m = math.floor((ct - h) * 60)
                    return ct, string.format("%02d:%02d", h, m)
                end
                local tod = Lighting.TimeOfDay
                if tod and type(tod) == "string" and tod ~= "" then
                    local h, mn = string.match(tod, "^(%d+):(%d+)")
                    if h then return tonumber(h) + (tonumber(mn) or 0) / 60, string.format("%02d:%02d", h, mn) end
                end
                local mam = Lighting:GetMinutesAfterMidnight()
                if mam and type(mam) == "number" then
                    local h = math.floor(mam / 60)
                    local mn = math.floor(mam % 60)
                    return mam / 60, string.format("%02d:%02d", h, mn)
                end
                return nil, "Unknown"
            end)
            if ok and hour then return hour, timeStr end
            return nil, "Unknown"
        end

        local function isDaytime()
            local hour = getGameClock()
            if hour == nil then return true end
            return hour >= 6 and hour < 18
        end

        local function findTotemHotbarSlot(totemName)
            if totemName == "None" then return nil end
            local search = string.lower(string.gsub(totemName, " Totem", ""))
            local pg = getPlayerGui()
            if not pg then return nil end
            local backpack = pg:FindFirstChild("backpack")
            if not backpack then return nil end
            local hotbar = backpack:FindFirstChild("hotbar")
            if not hotbar then return nil end
            local slot = 0
            for _, btn in ipairs(hotbar:GetChildren()) do
                if btn:IsA("ImageButton") and btn.Name == "ItemTemplate" then
                    slot = slot + 1
                    local label = btn:FindFirstChild("ItemName")
                    if label and label:IsA("TextLabel") then
                        if label.Text ~= "" and string.find(string.lower(label.Text), search) then
                            return slot
                        end
                    end
                end
            end
            return nil
        end

        local function useTotem(totemName)
            if totemName == "None" then return false end
            local slot = findTotemHotbarSlot(totemName)
            if not slot then return false end
            local success = false
            pcall(function()
                local keys = {[1]=0x31,[2]=0x32,[3]=0x33,[4]=0x34,[5]=0x35,[6]=0x36,[7]=0x37,[8]=0x38,[9]=0x39}
                local key = keys[slot]
                if not key then return end
                keypress(key); task.wait(0.15); keyrelease(key); task.wait(0.6)
                mouse1press(); task.wait(0.15); mouse1release(); task.wait(2.0)
                lastTotemUse = os.clock()
                success = true
            end)
            return success
        end

        local function switchToRod()
            pcall(function() keypress(0x31); task.wait(0.1); keyrelease(0x31); task.wait(0.5) end)
        end

        local handleAutoReel, handleAutoCast

        local function handleAutoTotem(myVersion)
            while myVersion == totemVersion do
                if Settings.AutoTotem then
                    local isDay = isDaytime()
                    if lastCycleWasDay == nil or lastCycleWasDay ~= isDay then
                        lastCycleWasDay = isDay
                        local totem = isDay and Settings.DayTotem or Settings.NightTotem
                        if totem and totem ~= "None" then
                            local wasEnabled = Settings.Enabled
                            if wasEnabled then
                                Settings.Enabled = false
                                reelVersion = reelVersion + 1; castVersion = castVersion + 1
                                if isHolding then pcall(mouse1release); isHolding = false end
                                task.wait(0.5)
                            end
                            useTotem(totem)
                            switchToRod()
                            if wasEnabled then
                                Settings.Enabled = true
                                reelVersion = reelVersion + 1; castVersion = castVersion + 1
                                local rv, cv = reelVersion, castVersion
                                if Settings.AutoReel then task.spawn(function() handleAutoReel(rv) end) end
                                if Settings.AutoCast then task.spawn(function() handleAutoCast(cv) end) end
                            end
                        end
                    end
                end
                task.wait(5)
            end
        end

        local lastShakeClick = 0
        local shakeRunning = false
        local function startShakeThread()
            if shakeRunning then return end
            shakeRunning = true
            task.spawn(function()
                while true do
                    local ok, err = pcall(function()
                        while true do
                            threadHeartbeats.shake = os.clock()
                            if Settings.Enabled and Settings.AutoShake and isrbxactive() then
                                local pg = getPlayerGui()
                                if pg then
                                    local shakeGui = pg:FindFirstChild("shakeui")
                                    if shakeGui and shakeGui:IsA("ScreenGui") then
                                        local safezone = shakeGui:FindFirstChild("safezone")
                                        if safezone then
                                            isShaking = true
                                            if os.clock() - lastShakeClick >= 0.08 then
                                                keypress(0x0D); task.wait(0.01); keyrelease(0x0D)
                                                lastShakeClick = os.clock()
                                                task.wait(0.1)
                                            end
                                        else isShaking = false end
                                    else isShaking = false end
                                end
                                task.wait(0.02)
                            else
                                isShaking = false
                                task.wait(0.2)
                            end
                        end
                    end)
                    if not ok then warn("[Fisch] Shake crashed: " .. tostring(err)) end
                    task.wait(1)
                end
            end)
        end
        startShakeThread()

        handleAutoCast = function(myVersion)
            local crashes = 0
            threadActive.cast = true
            while myVersion == castVersion do
                local ok, err = pcall(function()
                    while Settings.AutoCast and myVersion == castVersion do
                        threadHeartbeats.cast = os.clock()

                        if not isReeling and not isShaking then
                            local character = LocalPlayer.Character
                            if character and character:FindFirstChildOfClass("Tool") then
                                local playerbar, _, _, _, _ = findActiveReel()
                                local shakeActive = false
                                local pg = getPlayerGui()
                                if pg then
                                    local sg = pg:FindFirstChild("shakeui")
                                    if sg and sg:IsA("ScreenGui") and sg:FindFirstChild("safezone") then
                                        shakeActive = true
                                    end
                                end
                                if not playerbar and not shakeActive and not isReeling then
                                    if isrbxactive() then
                                        if Settings.AutoPerfectCast then
                                            pcall(mouse1press); task.wait(Settings.PerfectCastHoldTime); pcall(mouse1release)
                                        else
                                            pcall(mouse1press); task.wait(0.5); pcall(mouse1release)
                                        end
                                        task.wait(2.5)
                                    end
                                end
                            end
                        end
                        task.wait(0.5)
                    end
                end)
                if ok then break end
                crashes = crashes + 1
                warn("[Fisch] Cast crashed (#" .. crashes .. "): " .. tostring(err))
                if crashes > 50 then warn("[Fisch] Cast giving up"); break end
                task.wait(1)
            end
            threadActive.cast = false
        end

        handleAutoReel = function(myVersion)
            isHolding = false
            resetMemory()
            local reelStartTime = 0
            local crashes = 0
            threadActive.reel = true
            local startupFrames = 0
            local MISSING_TIMEOUT = 0.3
            local lastDebugLog = 0
            local consecutiveMissing = 0
            while myVersion == reelVersion do
                local ok, err = pcall(function()
                    while Settings.AutoReel and myVersion == reelVersion do
                        startupFrames = startupFrames + 1
                        threadHeartbeats.reel = os.clock()
                        local playerbar, fish, bar, progress, failReason = findActiveReel()

                        if playerbar and fish then
                            lastReelSeen = os.clock()
                            consecutiveMissing = 0

                            if not isReeling then
                                isReeling = true
                                reelStartTime = os.clock()
                                currentFish = {Name = "Unknown", Rarity = "-"}
                                resetMemory()
                                print("[Fisch] Started reeling")
                            end

                            if isReeling and (os.clock() - reelStartTime) > 180 then
                                warn("[Fisch] Reel stuck for 3min, force resetting")
                                isReeling = false
                                pcall(function() if isHolding then mouse1release(); isHolding = false end end)
                                resetMemory()
                                reelStartTime = os.clock()
                            end

                            if os.clock() - lastFishScanTime >= 0.5 then
                                scanCurrentFish()
                                lastFishScanTime = os.clock()
                            end

                            local playerCenterX = playerbar.AbsolutePosition.X + (playerbar.AbsoluteSize.X / 2)
                            local fishCenterX = fish.AbsolutePosition.X + (fish.AbsoluteSize.X / 2)

                            addToMemory(fishMemory, fishCenterX, Settings.MemorySize)
                            addToMemory(barMemory, playerCenterX, Settings.MemorySize)

                            fishVelocity = calculateVelocity(fishMemory)
                            fishAccel = calculateAcceleration(fishMemory)
                            barVelocity = calculateVelocity(barMemory)

                            predictedFishX = predictPosition(fishCenterX, fishVelocity, fishAccel, Settings.PredictionFrames)

                            local slideOffset = isHolding and Settings.SlideCompensation or -Settings.SlideCompensation / 2
                            local effectiveDiff = predictedFishX - (playerCenterX + slideOffset)

                            addToMemory(errorMemory, effectiveDiff, Settings.ErrorMemorySize)
                            errorVelocity = calculateVelocity(errorMemory)

                            local errorPredictionFrames = Settings.ErrorPredictionTime / Settings.ReelPollRate
                            local predictedError = effectiveDiff + (errorVelocity * errorPredictionFrames)

                            local controlError = predictedError
                            local dynamicDeadzone = math.max(1, math.min(10, math.abs(fishVelocity) * 0.5))

                            local desiredDirection = nil
                            if controlError > dynamicDeadzone then
                                desiredDirection = true
                            elseif controlError < -dynamicDeadzone then
                                desiredDirection = false
                            end

                            if desiredDirection ~= nil and lastDirection ~= nil and desiredDirection ~= lastDirection then
                                local timeSinceLastChange = os.clock() - lastDirectionChangeTime
                                if timeSinceLastChange < Settings.DirectionChangeCooldown then
                                    desiredDirection = lastDirection
                                else
                                    lastDirectionChangeTime = os.clock()
                                end
                            elseif desiredDirection ~= nil then
                                lastDirectionChangeTime = os.clock()
                            end

                            if desiredDirection == true then
                                if not isHolding then
                                    pcall(mouse1press)
                                    isHolding = true
                                end
                            elseif desiredDirection == false then
                                if isHolding then
                                    pcall(mouse1release)
                                    isHolding = false
                                end
                            end

                            if desiredDirection ~= nil then lastDirection = desiredDirection end

                            if os.clock() - lastDebugLog > 1 then
                                lastDebugLog = os.clock()
                                local dir = desiredDirection == true and "HOLD" or (desiredDirection == false and "RELEASE" or "NONE")
                                print(string.format("[DEBUG] fishX=%.0f barX=%.0f vel=%.1f diff=%.1f dir=%s hold=%s",
                                    fishCenterX, playerCenterX, fishVelocity, effectiveDiff, dir, tostring(isHolding)))
                            end

                        else
                            if startupFrames <= 5 then
                                task.wait(Settings.ReelPollRate)
                            elseif isReeling then
                                consecutiveMissing = consecutiveMissing + 1
                                local elapsed = os.clock() - lastReelSeen
                                if elapsed > MISSING_TIMEOUT then
                                    print("[Fisch] Reel ended (UI missing " .. consecutiveMissing .. " frames, " .. string.format("%.2f", elapsed) .. "s)")
                                    isReeling = false
                                    Stats.TotalCatches = Stats.TotalCatches + 1
                                    if currentFish.Rarity == "Shiny" then Stats.ShinyCount = Stats.ShinyCount + 1
                                    elseif currentFish.Rarity == "Mutation" then Stats.MutationCount = Stats.MutationCount + 1 end
                                    if currentFish.Rarity ~= "-" and currentFish.Rarity ~= "Common" then
                                        Stats.BestCatch = currentFish.Name .. " (" .. currentFish.Rarity .. ")"
                                    end
                                    currentFish = {Name = "None", Rarity = "-"}
                                    if isHolding then pcall(mouse1release); isHolding = false end
                                    resetMemory()
                                    startupFrames = 0
                                    consecutiveMissing = 0
                                end
                            else
                                if isHolding then pcall(mouse1release); isHolding = false end
                            end
                        end

                        task.wait(Settings.ReelPollRate)
                    end
                end)
                if ok then break end
                crashes = crashes + 1
                warn("[Fisch] Reel crashed (#" .. crashes .. "): " .. tostring(err))
                pcall(function() if isHolding then mouse1release(); isHolding = false end end)
                isReeling = false
                resetMemory()
                if crashes > 50 then warn("[Fisch] Reel giving up"); break end
                task.wait(0.3)
            end

            threadActive.reel = false
            pcall(function() if isHolding then mouse1release(); isHolding = false end end)
            isReeling = false
            resetMemory()
        end

        local function emergencyStop()
            Settings.Enabled = false
            Settings.AutoReel = false
            Settings.AutoCast = false
            Settings.AutoTotem = false
            reelVersion = reelVersion + 1; castVersion = castVersion + 1; totemVersion = totemVersion + 1
            pcall(function() if isHolding then mouse1release(); isHolding = false end end)
            isReeling = false; isShaking = false
            resetMemory()
            print("[Fisch] EMERGENCY STOP")
        end

        local fischKb = nil
        local kbLoopStarted = false

        UI.AddTab("Fisch", function(tab)
            local autoSec = tab:Section("Auto", "Left")
            autoSec:Toggle("fisch_enabled", "Auto Fish", false, function(state)
                while settingsLock do task.wait(0.01) end
                settingsLock = true
                Settings.Enabled = state
                settingsLock = false
                if Settings.Enabled then
                    print("[Fisch] AutoFish ON")
                    if Settings.AutoReel then
                        reelVersion = reelVersion + 1
                        task.spawn(function() handleAutoReel(reelVersion) end)
                    end
                    if Settings.AutoCast then
                        castVersion = castVersion + 1
                        task.spawn(function() handleAutoCast(castVersion) end)
                    end
                else
                    print("[Fisch] AutoFish OFF")
                    reelVersion = reelVersion + 1; castVersion = castVersion + 1
                    pcall(function() if isHolding then mouse1release(); isHolding = false end end)
                    resetMemory()
                end
            end)
            fischKb = autoSec:Keybind("fisch_kb", 0x06, "toggle")
            fischKb:AddToHotkey("Auto Fish", "fisch_enabled")

            if not kbLoopStarted and fischKb then
                kbLoopStarted = true
                task.spawn(function()
                    local lastKbState = false
                    while true do
                        pcall(function()
                            if fischKb then
                                local currentState = fischKb:IsEnabled()
                                if currentState ~= lastKbState then
                                    lastKbState = currentState
                                    if currentState then
                                        while settingsLock do task.wait(0.01) end
                                        settingsLock = true
                                        if not Settings.Enabled then
                                            Settings.Enabled = true
                                            settingsLock = false
                                            UI.SetValue("fisch_enabled", true)
                                            print("[Fisch] AutoFish ON (Keybind)")
                                            if Settings.AutoReel then
                                                reelVersion = reelVersion + 1
                                                task.spawn(function() handleAutoReel(reelVersion) end)
                                            end
                                            if Settings.AutoCast then
                                                castVersion = castVersion + 1
                                                task.spawn(function() handleAutoCast(castVersion) end)
                                            end
                                        else
                                            settingsLock = false
                                        end
                                    else
                                        while settingsLock do task.wait(0.01) end
                                        settingsLock = true
                                        if Settings.Enabled then
                                            Settings.Enabled = false
                                            settingsLock = false
                                            UI.SetValue("fisch_enabled", false)
                                            print("[Fisch] AutoFish OFF (Keybind)")
                                            reelVersion = reelVersion + 1; castVersion = castVersion + 1
                                            pcall(function() if isHolding then mouse1release(); isHolding = false end end)
                                            resetMemory()
                                        else
                                            settingsLock = false
                                        end
                                    end
                                end
                            end
                        end)
                        task.wait()
                    end
                end)
            end

            autoSec:Toggle("fisch_autocast", "Auto Cast", Settings.AutoCast, function(state)
                Settings.AutoCast = state
                castVersion = castVersion + 1
                if Settings.AutoCast and Settings.Enabled then
                    task.spawn(function() handleAutoCast(castVersion) end)
                end
            end)
            autoSec:Toggle("fisch_autoshake", "Auto Shake", Settings.AutoShake, function(state)
                Settings.AutoShake = state
            end)
            autoSec:Toggle("fisch_autoreel", "Auto Reel", Settings.AutoReel, function(state)
                Settings.AutoReel = state
                reelVersion = reelVersion + 1
                if Settings.AutoReel and Settings.Enabled then
                    task.spawn(function() handleAutoReel(reelVersion) end)
                end
            end)
            autoSec:Toggle("fisch_perfectcast", "Perfect Cast", Settings.AutoPerfectCast, function(state)
                Settings.AutoPerfectCast = state
            end)

            autoSec:Spacing()
            autoSec:Text("--- Rod Info ---")
            autoSec:Text("Rod: " .. rodStats.Name)
            autoSec:Text("Control: " .. string.format("%.3f", rodStats.Control))

            autoSec:Spacing()
            autoSec:Text("--- Status ---")
            autoSec:Text("Fish: " .. currentFish.Name)
            autoSec:Text("Rarity: " .. currentFish.Rarity)
            autoSec:Text("Catches: " .. tostring(Stats.TotalCatches))
            autoSec:Text("Specials: " .. Stats.ShinyCount .. "S / " .. Stats.MutationCount .. "M")
            autoSec:Text("Uptime: " .. formatTime(os.clock() - Stats.SessionStart))

            autoSec:Spacing()
            autoSec:Button("EMERGENCY STOP", function()
                emergencyStop()
                UI.SetValue("fisch_enabled", false)
                UI.SetValue("fisch_autocast", false)
                UI.SetValue("fisch_autoshake", false)
                UI.SetValue("fisch_autoreel", false)
            end)

            local totemSec = tab:Section("Totem", "Left")
            totemSec:Toggle("totem_auto", "Auto Totem", Settings.AutoTotem, function(state)
                Settings.AutoTotem = state
                totemVersion = totemVersion + 1
                if Settings.AutoTotem then
                    task.spawn(function() handleAutoTotem(totemVersion) end)
                end
            end)
            totemSec:Spacing()
            totemSec:Text("Day Totem")
            totemSec:Combo("totem_day", "Day Totem", availableTotems, 1, function(idx, name)
                Settings.DayTotem = name
            end)
            totemSec:Text("Night Totem")
            totemSec:Combo("totem_night", "Night Totem", availableTotems, 8, function(idx, name)
                Settings.NightTotem = name
            end)
            totemSec:Spacing()
            totemSec:Text("--- Game Time ---")
            totemSec:Text("Cycle: " .. (isDaytime() and "DAY" or "NIGHT"))
            local _, timeStr = getGameClock()
            totemSec:Text("Time: " .. (timeStr or "--:--"))

            local warpSec = tab:Section("Warp", "Right", {"Surface", "Deep", "Special"}, 400)
            if warpSec.page == 0 then
                for _, loc in ipairs(TeleportLocations) do
                    if loc.Cat == "Surface" then
                        warpSec:Button(loc.Name, function()
                            teleportTo(loc.Position)
                        end)
                    end
                end
            elseif warpSec.page == 1 then
                for _, loc in ipairs(TeleportLocations) do
                    if loc.Cat == "Deep" then
                        warpSec:Button(loc.Name, function()
                            teleportTo(loc.Position)
                        end)
                    end
                end
            elseif warpSec.page == 2 then
                for _, loc in ipairs(TeleportLocations) do
                    if loc.Cat == "Special" then
                        warpSec:Button(loc.Name, function()
                            teleportTo(loc.Position)
                        end)
                    end
                end
            end
        end)

        local function safeSetEnabled(state)
            while settingsLock do task.wait(0.01) end
            settingsLock = true
            Settings.Enabled = state
            settingsLock = false
        end

        task.spawn(function()
            while true do
                pcall(function()
                    if not settingsLock then
                        if UI.GetValue("fisch_autocast") ~= Settings.AutoCast then
                            Settings.AutoCast = UI.GetValue("fisch_autocast")
                            castVersion = castVersion + 1
                            if Settings.AutoCast and Settings.Enabled then
                                task.spawn(function() handleAutoCast(castVersion) end)
                            end
                        end
                        if UI.GetValue("fisch_autoshake") ~= Settings.AutoShake then
                            Settings.AutoShake = UI.GetValue("fisch_autoshake")
                        end
                        if UI.GetValue("fisch_autoreel") ~= Settings.AutoReel then
                            Settings.AutoReel = UI.GetValue("fisch_autoreel")
                            reelVersion = reelVersion + 1
                            if Settings.AutoReel and Settings.Enabled then
                                task.spawn(function() handleAutoReel(reelVersion) end)
                            end
                        end
                        if UI.GetValue("fisch_perfectcast") ~= Settings.AutoPerfectCast then
                            Settings.AutoPerfectCast = UI.GetValue("fisch_perfectcast")
                        end
                        if UI.GetValue("totem_auto") ~= Settings.AutoTotem then
                            Settings.AutoTotem = UI.GetValue("totem_auto")
                            totemVersion = totemVersion + 1
                            if Settings.AutoTotem then
                                task.spawn(function() handleAutoTotem(totemVersion) end)
                            end
                        end
                    end
                end)
                task.wait(1)
            end
        end)

        local lastRodName = ""
        task.spawn(function()
            while true do
                pcall(function()
                    local rod = detectEquippedRod()
                    local name = rod and rod.Name or "None"
                    if name ~= lastRodName then
                        lastRodName = name; currentRod = rod; rodStats = readRodStats(rod)
                        print(string.format("[Fisch] Rod: %s | Control: %.3f (%s)", rodStats.Name, rodStats.Control, rodStats.Source))
                    end
                end)
                task.wait(2)
            end
        end)

        task.spawn(function()
            task.wait(3)
            while true do
                pcall(function()
                    local now = os.clock()
                    if Settings.Enabled then
                        if Settings.AutoReel and threadActive.reel and threadHeartbeats.reel > 0 and (now - threadHeartbeats.reel) > HEARTBEAT_TIMEOUT then
                            warn("[Watchdog] Reel dead (heartbeat stalled), restarting"); reelVersion = reelVersion + 1; threadHeartbeats.reel = now
                            threadActive.reel = false
                            task.spawn(function() handleAutoReel(reelVersion) end)
                        elseif Settings.AutoReel and not threadActive.reel and Settings.Enabled then
                            warn("[Watchdog] Reel not running but should be, restarting")
                            reelVersion = reelVersion + 1
                            task.spawn(function() handleAutoReel(reelVersion) end)
                        end
                        if Settings.AutoCast and threadActive.cast and threadHeartbeats.cast > 0 and (now - threadHeartbeats.cast) > HEARTBEAT_TIMEOUT then
                            warn("[Watchdog] Cast dead (heartbeat stalled), restarting"); castVersion = castVersion + 1; threadHeartbeats.cast = now
                            threadActive.cast = false
                            task.spawn(function() handleAutoCast(castVersion) end)
                        elseif Settings.AutoCast and not threadActive.cast and Settings.Enabled then
                            warn("[Watchdog] Cast not running but should be, restarting")
                            castVersion = castVersion + 1
                            task.spawn(function() handleAutoCast(castVersion) end)
                        end
                        if Settings.AutoShake and threadHeartbeats.shake > 0 and (now - threadHeartbeats.shake) > HEARTBEAT_TIMEOUT then
                            warn("[Watchdog] Shake dead, restarting"); threadHeartbeats.shake = now; shakeRunning = false; startShakeThread()
                        end
                    end
                end)
                task.wait(5)
            end
        end)

        task.spawn(function()
            while true do pcall(collectgarbage, "step", 50); task.wait(5) end
        end)

        print("[Fisch] Loaded")

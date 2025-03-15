getgenv().Settings = {

	["Raid Settings"] = {
		Enabled = true, --// false --> Will Farm Main Area (if FarmArea = true)

		JoinRaid = "Username", --// Join an alts raid (or just delete this).
		Difficulty = "Max", --// "Max", 1-...
		Type = "Solo", --// "Solo", "Friends", "Friends & Clan", "Open"
		
		LeaveRaid = {}, --// Rejoin raid if any of these are found.
		OpenLeprechaunChest = false,
		
		["Egg Settings"] = {
			Enabled = false, --// false --> Will leave and keep farming Raids.
			MinimumEggMulti = 250, --// 20 --> 20x
			MinimumLuckyCoins = "50m",
			MaxOpenTime = 1, --// 60 --> 60 minutes.
		},
	},

	["Main Area Settings"] = {
		FarmArea = false,
		PurchaseUpgrades = true,
	},

	[[ Created by System Exodus // Jxnt ]]
}













local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
repeat task.wait() 
    LocalPlayer = Players.LocalPlayer
until LocalPlayer and LocalPlayer.GetAttribute and LocalPlayer:GetAttribute("__LOADED")
if not LocalPlayer.Character then 
    LocalPlayer.CharacterAdded:Wait() 
end
local HumanoidRootPart = LocalPlayer.Character.HumanoidRootPart


local NLibrary = game.ReplicatedStorage.Library
local Network = require(NLibrary.Client.Network)
local PlayerSave = require(NLibrary.Client.Save) 

local RaidCmds = require(NLibrary.Client.RaidCmds)
local RaidInstance = require(NLibrary.Client.RaidCmds.RaidInstance)
local CurrentRaid = RaidInstance.GetByOwner(game.Players.LocalPlayer)
local EventUpgradeCmds = require(NLibrary.Client.EventUpgradeCmds)
local EventUpgrades = require(NLibrary.Directory.EventUpgrades)
local Functions = require(NLibrary.Functions)
local Items = require(NLibrary.Items)
local PetNetworking = require(NLibrary.Client.PetNetworking)
local InstancingCmds = require(NLibrary.Client.InstancingCmds)
local EggCmds = require(NLibrary.Client.EggCmds)
local MapCmds = require(NLibrary.Client.MapCmds)
local CurrencyCmds = require(NLibrary.Client.CurrencyCmds)
local CustomEggsCmds = require(NLibrary.Client.CustomEggsCmds)
local CalcEggPrice = require(NLibrary.Balancing.CalcEggPrice)
local MasteryCmds = require(NLibrary.Client.MasteryCmds)
local Functions = require(NLibrary.Functions)
local EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game:WaitForChild("Egg Opening Frontend"))

local function EnterInstance(Name)
	if InstancingCmds.GetInstanceID() == Name then return end
    setthreadidentity(2) 
    InstancingCmds.Enter(Name) 
    setthreadidentity(8)
	task.wait(0.25)
	if InstancingCmds.GetInstanceID() ~= Name then
		EnterInstance(Name)
	end
end

local SuffixesLower = {"k", "m", "b", "t"}
local SuffixesUpper = {"K", "M", "B", "T"}
local function RemoveSuffix(Amount)
	local a, Suffix = Amount:gsub("%a", ""), Amount:match("%a")	
	local b = table.find(SuffixesUpper, Suffix) or table.find(SuffixesLower, Suffix) or 0
	return tonumber(a) * math.pow(10, b * 3)
end

local ActiveInstances = workspace.__THINGS.__INSTANCE_CONTAINER.Active
local Raid = Settings["Raid Settings"]
local Main = Settings["Main Area Settings"]
if type(Raid["Egg Settings"].MinimumLuckyCoins) ~= "numer" then
	Raid["Egg Settings"].MinimumLuckyCoins = RemoveSuffix(Raid["Egg Settings"].MinimumLuckyCoins)
end

--// Breakable & Pet Equip Gathering \\--
local BreakablesFolder = workspace.__THINGS.Breakables
local BreakablesList = {}
for _,v in pairs(BreakablesFolder:GetChildren()) do
    if v:IsA("Model") then
        local UID, Zone = v:GetAttribute("BreakableUID"), v:GetAttribute("ParentID")
        if (Raid.Enabled and Zone == "LuckyRaid") or (not Raid.Enabled and Zone == "LuckyEventWorld") then
			BreakablesList[UID] = v
        end
    end
end
BreakablesFolder.ChildAdded:Connect(function(Breakable)
    task.wait()
    if Breakable:IsA("Model") then
        local UID, Zone, Name = Breakable:GetAttribute("BreakableUID"), Breakable:GetAttribute("ParentID"), Breakable:GetAttribute("BreakableID")
        if (Raid.Enabled and Zone == "LuckyRaid") or (not Raid.Enabled and Zone == "LuckyEventWorld") then
            BreakablesList[UID] = Breakable
        end
    end
end)
BreakablesFolder.ChildRemoved:Connect(function(Breakable)
    task.wait()
    local UID = Breakable:GetAttribute("BreakableUID")
    if BreakablesList[UID] then
        BreakablesList[UID] = nil
    end
end)

local EquippedPets = {}
for _,v in pairs(PetNetworking.EquippedPets()) do
    if not EquippedPets[v.euid] then
        table.insert(EquippedPets, v.euid)
    end
end
Network.Fired("Pets_LocalPetsUpdated"):Connect(function(Pet)
    for _,v in pairs(Pet) do
        if not EquippedPets[v.ePet.euid] then
            table.insert(EquippedPets, v.ePet.euid)
        end
    end
end)
Network.Fired("Pets_LocalPetsUnequipped"):Connect(function(Pet)
    for _,v in pairs(Pet) do
        if EquippedPets[v] then
            EquippedPets[v] = nil
        end
    end
end)
Network.Fired("Orbs: Create"):Connect(function(Orbs)
    local Collect = {}
    for _, v in ipairs(Orbs) do
        local ID = tonumber(v.id)
        if ID then
            table.insert(Collect, ID)
        end
    end
    if #Collect > 0 then
        Network.Fire("Orbs: Collect", Collect)
        for _, ID in ipairs(Collect) do
            local Orb = workspace.__THINGS.Orbs:FindFirstChild(tostring(ID))
            if Orb then
                Orb:Destroy()
            end
        end
    end
end)

local function GetUpgradeTypes(ID)
    if ID:find("XP") then return "XP" end
    if ID:find("Damage") then return "Damage" end
    if ID:find("AttackSpeed") then return "AttackSpeed" end
    if ID:find("Pets") then return "Pets" end
    return "Other"
end
local RequiredUpgrades = {XP = false, Damage = false, AttackSpeed = false, Pets = false}

--// Gather & Purchase LuckyRaid Upgrades \\--
local LuckyUpgrades = {}
for ID, Data in next, EventUpgrades do
    if ID:find("LuckyRaid") then
        LuckyUpgrades[ID] = Data
    end
end
local Orb = Items.Misc("Lucky Raid Orb")
local function PurchaseUpgrades()
    local Upgrade, LowestCost = nil, math.huge
	for ID, Data in next, LuckyUpgrades do
        local UpgradeType = GetUpgradeTypes(ID)
        local Tier = EventUpgradeCmds.GetTier(ID)
        if not Data.TierCosts[Tier + 1] or not Data.TierCosts[Tier + 1]._data then
			if table.find(RequiredUpgrades, UpgradeType) then
            	RequiredUpgrades[UpgradeType] = true
			end
			continue
		end
		if UpgradeType ~= "Other" or (UpgradeType == "Other" and RequiredUpgrades["XP"] and RequiredUpgrades["Damage"] and RequiredUpgrades["AttackSpeed"] and RequiredUpgrades["Pets"]) then
            local Cost = Data.TierCosts[Tier + 1]._data._am or 1
            if Cost and Cost < LowestCost and Orb:CountExact() >= Cost then
                LowestCost = Cost
                Upgrade = ID
            end
        end
    end
	if Upgrade then
		EventUpgradeCmds.Purchase(Upgrade)
	end
    return Upgrade
end

local function FarmBreakables()
    local RemoteList = {}
    
    local PetArray = {}
    for _,ID in pairs(EquippedPets) do
        table.insert(PetArray, ID)
    end

    local BreakableArray = {}
    for UID, Breakable in pairs(BreakablesList) do
        table.insert(BreakableArray, UID)
    end

    local PetIndex = 1
    local BreakableIndex = 1
    local BreakableCount = #BreakableArray
    local PetCount = #PetArray

    if PetCount == 0 or BreakableCount == 0 then
        return
    end
    while PetIndex <= PetCount do
        local PetID = PetArray[PetIndex]
        local BreakableUID = BreakableArray[BreakableIndex]
        RemoteList[PetID] = BreakableUID

        PetIndex = PetIndex + 1
        BreakableIndex = BreakableIndex + 1
        if BreakableIndex > BreakableCount then
            BreakableIndex = 1
        end
    end
    if next(RemoteList) then
		Network.UnreliableFire("Breakables_PlayerDealDamage", BreakableArray[1])
		Network.Fire("Breakables_JoinPetBulk", RemoteList)
    end
end

--// Translate "Solo" into respected ID for remote
local PortalIDs = {
	["Solo"] = 1,
	["Friends"] = 2,
	["Friends & Clan"] = 3,
	["Open"] = 4,
}

--// Anti AFK
LocalPlayer.PlayerScripts.Scripts.Core["Server Closing"].Enabled = false
LocalPlayer.PlayerScripts.Scripts.Core["Idle Tracking"].Enabled = false
Network.Fire("Idle Tracking: Stop Timer")
LocalPlayer.Idled:Connect(function() 
	VirtualUser:CaptureController() 
	VirtualUser:ClickButton2(Vector2.new()) 
end)

--// Remove Egg Animation
EggFrontend.PlayEggAnimation = function(...)
    return
end

if Raid.Enabled then
	while task.wait() and Raid.Enabled do
		EnterInstance("LuckyEventWorld")

		--// Purchase Upgrades
		if Main and Main.PurchaseUpgrades then
			PurchaseUpgrades()
		end

		--// Find open raid (if any)
		local CurrentRaid = RaidInstance.GetByOwner(LocalPlayer)
		local JoinRaid = Raid.JoinRaid and Raid.JoinRaid ~= "Username" and Raid.JoinRaid ~= "" and Raid.JoinRaid
		if not JoinRaid and (not CurrentRaid or (CurrentRaid and (CurrentRaid._completed or LeftOnPurpose))) then
			LeftOnPurpose = false

			--// Grab Current Raid Level
			local Level = RaidCmds.GetLevel()
			local OpenPortal;
			--// Loop through every portal to find an open slot or users own portal (dont judge.)
			for i = 1,10 do
				local Portal = RaidInstance.GetByPortal(i)
				if not Portal or (Portal and Portal._owner == game.Players.LocalPlayer) then
					OpenPortal = i
					break
				end
			end
			--// Create portal using user params.
			Network.Invoke("Raids_RequestCreate", {
				["Difficulty"] = (type(Raid.Difficulty) == "number" and Level >= Raid.Difficulty and Raid.Difficulty) or Level,
				["Portal"] = OpenPortal,
				["PartyMode"] = PortalIDs[Raid.Type]
			})
		end
		--// Wait until game registers a portal.
		repeat task.wait(0.25)
			CurrentRaid = RaidInstance.GetByOwner(JoinRaid or LocalPlayer)
		until CurrentRaid
		if CurrentRaid then

			--// Farming Raids \\--
			local RaidID = CurrentRaid._id
			Network.Invoke("Raids_Join", RaidID)
			repeat task.wait() until ActiveInstances:FindFirstChild("LuckyRaid")
			local StartingTime = os.time()
			local Name;
			repeat task.wait(0.1)
				local _, v = next(BreakablesList)
				if not v and (os.time()-StartingTime) >= 15 then
					--// Breakables most likely didn't spawn, restarting raid
					LeftOnPurpose = true;
					break 
				end
				if not MapCmds.IsInDottedBox() and v:FindFirstChildOfClass("MeshPart") then
					Name = v:GetAttribute("BreakableID")
					Name = (Name:gsub("LuckyRaid", ""):gsub("(%l)(%u)", "%1 %2"))
					if Raid.LeaveRaid and table.find(Raid.LeaveRaid, Name) then
						--// Breakable is part of banned breakable list, leave/restart
						LeftOnPurpose = true
						break
					end
					HumanoidRootPart.CFrame = v:FindFirstChildOfClass("MeshPart").CFrame * CFrame.new(0,2,0)
				end
				FarmBreakables()
			until ActiveInstances.LuckyRaid.INTERACT:FindFirstChild("LootChest")
			
			--// Loop through every chest the player can open, really stupid but not terrible lmao
			for _, Chest in pairs(ActiveInstances.LuckyRaid.INTERACT:GetChildren()) do
				if Chest.Name:find("Sign") or (Chest.Name:find("Leprechaun") and (not Raid.OpenLeprechaunChest or Library.Items.Misc("Lucky Key"):CountExact() < 1)) then
					continue
				end
				local Success;
				HumanoidRootPart.CFrame = Chest:FindFirstChildOfClass("MeshPart").CFrame
				repeat task.wait(0.25)
					Success = Network.Invoke("Raids_OpenChest", Chest.Name)
				until Success
			end

			--// Opening Raid Egg \\--
			if Raid["Egg Settings"].Enabled and PlayerSave.Get().RaidEggMultiplier and PlayerSave.Get().RaidEggMultiplier >= Raid["Egg Settings"].MinimumEggMulti and CurrencyCmds.CanAfford("LuckyCoins", Raid["Egg Settings"].MinimumLuckyCoins) then
				EnterInstance("LuckyEgg")

				local LuckyEgg;
				local EggPrice;
				--// Find and Calculate the Custom Egg Price w/ Upgrades
				repeat task.wait()
					for UID, Info in next, CustomEggsCmds.All() do
						if workspace.__THINGS.CustomEggs:FindFirstChild(UID) then
							local Power = EventUpgradeCmds.GetPower("LuckyRaidEggCost")
							local CheaperEggs = MasteryCmds.HasPerk("Eggs", "CheaperEggs") and MasteryCmds.GetPerkPower("Eggs", "CheaperEggs") or 0
							EggPrice = CalcEggPrice(Info._dir) * (1 - Power / 100) * (1 - CheaperEggs / 100)
							LuckyEgg = UID
							break
						end
					end
				until LuckyEgg and EggPrice
				local StartingTime = os.time()
				local MaxEggHatch = EggCmds.GetMaxHatch()
				local NeedsPrice = EggPrice * MaxEggHatch
				repeat task.wait(0.1)
					Network.Invoke("CustomEggs_Hatch", LuckyEgg, MaxEggHatch)
				until not CurrencyCmds.CanAfford("LuckyCoins", NeedsPrice) or (os.time() - StartingTime) >= (Raid["Egg Settings"].MaxOpenTime * 60)
			end
		end
	end
else
    while task.wait() and Main.FarmArea do
        FarmBreakables()
        if not MapCmds.IsInDottedBox() then
			local _, v = next(BreakablesList)
			if v and v:FindFirstChildOfClass("MeshPart") then
				HumanoidRootPart.CFrame = v:FindFirstChildOfClass("MeshPart").CFrame * CFrame.new(0,2,0)
			end
		end
    end
end

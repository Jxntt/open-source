if not Settings or not LPH_OBFUSCATED then
    getgenv().Settings = {
        CombineOres = false,
        BlockPriority = {"Onyx", "Topaz", "Quartz", "Rainbow", "Amethyst", "Emerald", "Ruby", "EpicChest", "RareChest", "BasicChest"},
        --// Prioritizes ores in order, will ONLY target these said ores.
        
        Debug = {
            DisableUI = true
        }
    }
end

Debug = Settings.Debug or {}

getgenv().Mining = {
    Blocks = {}
}


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local LocalPlayer = Players.LocalPlayer
if not game:IsLoaded() then 
    game.Loaded:Wait()
end
repeat task.wait() 
    LocalPlayer = Players.LocalPlayer
until LocalPlayer and LocalPlayer.GetAttribute and LocalPlayer:GetAttribute("__LOADED")
if not LocalPlayer.Character then 
    LocalPlayer.CharacterAdded:Wait() 
end

local Character = LocalPlayer.Character
local HumanoidRootPart = Character.HumanoidRootPart
local NLibrary = ReplicatedStorage.Library
local PlayerScripts = LocalPlayer.PlayerScripts.Scripts
local StartingTime = os.time()

local Onyx = Library.Items.Misc("Onyx Gem")
local StartingOnyx = Onyx:CountExact()
print("Onyx Gems: "..StartingOnyx.." (+0)")





function Mining.UpdateBlocks(InRange)
    if not InRange then
        --[[local Blocks;
        repeat task.wait()
            Blocks = workspace.__THINGS.BlockWorlds["Blocks_"..World.Id]
        until Blocks
        if Mining.AddedConnection and Mining.RemovedConnection then
            Mining.AddedConnection:Disconnect()
            Mining.RemovedConnection:Disconnect()
        end
        for _,v in next, Blocks:GetChildren() do
            table.insert(Mining.Blocks, v)
        end
        Mining.AddedConnection = Blocks.ChildAdded:Connect(function(Block)
            table.insert(Mining.Blocks, Block)
        end)
        Mining.RemovedConnection = Blocks.ChildRemoved:Connect(function(Block)
            if Mining.Blocks[Block] then
                Mining.Blocks[Block] = nil
            end
        end)]]--
    else
        local RegionMin = HumanoidRootPart.Position - Vector3.new(15, 15, 15)
        local RegionMax = HumanoidRootPart.Position + Vector3.new(15, 15, 15)
        local Region = Region3.new(RegionMin, RegionMax)
        --Region = Region:ExpandToGrid(4)

        local Parts = workspace:FindPartsInRegion3WithIgnoreList(Region, {Character}, 50)
        for _, Part in ipairs(Parts) do
            if Part.Parent.Parent == workspace.__THINGS.BlockWorlds then
                table.insert(Mining.Blocks, Part)
            end
        end
    end
end

function Mining.GetBlockBreakTime(Block)
    local SelectedPickaxe = Library.MiningUtil.GetSelectedPickaxe(LocalPlayer)
    local BestPickaxe = Library.MiningUtil.GetBestPickaxe(LocalPlayer, true)
    if not SelectedPickaxe or not BestPickaxe then 
        return 0
    end

    local BlockData = Block:GetDirectory()
    local UserDamage = Library.MiningUtil.ComputeDamage(LocalPlayer, SelectedPickaxe, BestPickaxe, BlockData)
    local UserSpeed = Library.MiningUtil.ComputeSpeed(LocalPlayer, SelectedPickaxe)
    local DamagePerSecond = UserDamage * UserSpeed

    local BreakTime = (BlockData.Strength / DamagePerSecond) or 0
    if Block and Block.Dir and Block.Dir._id and Block.Dir._id == "RareChest" then
        BreakTime += 0.1
    end
    return BreakTime
end

function Mining.TeleportToZone(SpecificZone)
    local CurrentZone = SpecificZone or Library.InstanceZoneCmds.GetMaximumOwnedZoneNumber()
    local InstanceData = Library.InstancingCmds.Get()
    local Teleports = InstanceData.model:FindFirstChild("Teleports")
    local TeleportPad = Teleports:FindFirstChild(tostring(CurrentZone))
    HumanoidRootPart.CFrame = TeleportPad.CFrame
    task.wait(1)
    World = Library.BlockWorldClient.GetLocal()
    if not Settings.TargetDiamonds then
        Mining.UpdateBlocks()
    end
end

function Mining.EnterInstance(Name)
	if Library.InstancingCmds.GetInstanceID() == Name then return end
    setthreadidentity(2) 
    Library.InstancingCmds.Enter(Name) 
    setthreadidentity(8)
	task.wait(0.25)
	if Library.InstancingCmds.GetInstanceID() ~= Name then
		EnterInstance(Name)
	end
end

local RemoteCounter = 0
function Mining.MineBlock(Block, Teleport)
    if not Block or not Block.Part or not Block.Part.Parent then return end
    local BreakTime;
    local Distance = (HumanoidRootPart.Position - Block.CFrame.Position).Magnitude
    if Distance >= 41 then 
        if Teleport then
            HumanoidRootPart.CFrame = Block.CFrame
            BreakTime = Mining.GetBlockBreakTime(Block) 
            task.wait(BreakTime >= 1 and 0.2 or 0.15)
        else
            return
        end
    end
    if not BreakTime then
        BreakTime = Mining.GetBlockBreakTime(Block) 
    end
    print("Mining: "..Block.Dir._id)
    print("Breaking: "..tostring(Block.Pos))
    if Block.Dir._id == "Onyx" then
        local CurrentOnyx = Onyx:CountExact()
        print("Onyx Gems: "..CurrentOnyx.." (+"..((CurrentOnyx-StartingOnyx)+1)..")")
    end
    --print("[System Exodus]: Mining: "..Block.Dir._id.." ("..BreakTime..")")
    Library.Network.Fire("BlockWorlds_Target", Block.Pos, RemoteCounter, false)
    task.wait(BreakTime)
    Library.Network.Fire("BlockWorlds_Break", Block.Pos, RemoteCounter)
    RemoteCounter += 1
end

function Mining.GetGateQuest()
    local Instance = Library.InstancingCmds.Get()
    local ActiveQuest = Instance:GetSavedValue("QuestActive")
    if not ActiveQuest then return end

    local ToDo = {}
    if ActiveQuest.Amount > ActiveQuest.Progress then
        ToDo[ActiveQuest.OreID or "Blocks"] = (ActiveQuest.Amount - ActiveQuest.Progress) 
    else
        return true
    end
    return ToDo
end

function Mining.GetPickaxeQuests(Type)
    local OGPath = Library.Save.Get().NPCQuests
    local NewPath;
    local QuestName;
    local BestPickaxeQuest = 0
    for Quest, Data in next, OGPath do
        if Quest:find("PickaxeQuest") and not Data.Completed then
            local PickaxeQuestType = tonumber(Quest:match("%d"))
            if PickaxeQuestType >= BestPickaxeQuest then
                BestPickaxeQuest = PickaxeQuestType
                NewPath = OGPath[Quest]
                QuestName = Quest
            end
        end
    end
    if Library.InstanceZoneCmds.GetMaximumOwnedZoneNumber() < BestPickaxeQuest then
        return
    end

    local ToDo = {}
    local Remaining = 0
    if NewPath and NewPath.Quests then
        for Quest, Data in pairs(NewPath.Quests) do
            if Data.Amount > Data.Progress then
                ToDo[Data.OreID or "Blocks"] = (Data.Amount - Data.Progress) 
                Remaining = Remaining + 1
            end
        end
    end
    return ToDo, QuestName, Remaining
end


function Mining.LoadLayerDown(Ore)    
    print("Loading Layer Downwards.")
    --warn("[System Exodus]: Loading Layer Downwards.")
    local Count = 0
    local Region = World:GetRegion()
    for y = Region.Min.Y, Region.Max.Y, 2 do
        for x = Region.Min.X, Region.Max.X, 3 do
            for z = Region.Min.Z, Region.Max.Z, 3 do
                local Block = World:GetBlock(Vector3int16.new(x, y, z))
                if not Block then continue end
                if Ore and Block.Dir._id == Ore then continue end
                Mining.MineBlock(Block, true)
                Count += 1
                return
            end
        end
    end
    return Count
end

Mining.EnterInstance("MiningEvent")
Mining.TeleportToZone()

for i, Ore in ipairs(Settings.BlockPriority) do
    Settings.BlockPriority[Ore] = i
end

local BreakTimes = {}
function Mining.TargetBlock(Args)
    if not Args.Amount then Args.Amount = 999999 end
    if not Args.Type then Args.Type = "N/A" end

    if not Args.OreID and not Args.BlockPriority then
        Mining.TeleportToZone(1)
    elseif World.Id ~= Library.InstanceZoneCmds.GetMaximumOwnedZoneNumber() then
        Mining.TeleportToZone()
    end

    local Blocks = {}
    for _, Block in pairs(World.Blocks) do
        if not Args.OreID or (Args.OreID and Block.Dir and Block.Dir._id and Block.Dir._id == Args.OreID) then
            if not Args.BlockPriority or Args.BlockPriority and Settings.BlockPriority[Block.Dir._id] then
                table.insert(Blocks, Block)
                if Args.Amount and #Blocks >= Args.Amount then break end
            end
        end
    end
    
    table.sort(Blocks, function(a, b)
        if a.Dir.Tier == b.Dir.Tier then
            local DistanceA = (a.CFrame.Position - HumanoidRootPart.Position).Magnitude
            local DistanceB = (b.CFrame.Position - HumanoidRootPart.Position).Magnitude
            return DistanceA < DistanceB
        else
            return a.Dir.Tier > b.Dir.Tier
        end
    end)
    
    if #Blocks == 0 then
        task.wait(0.5)
        Mining.FocusBlocks(10)
        return Mining.TargetBlock(Args)
    end

    local Count = 0
    for _, Block in pairs(Blocks) do
        if Count > Args.Amount then break end
        if not Block or not Block.Part or not Block.Part.Parent then continue end
        --print("[System Exodus]: (Quest: "..Args.Type.." "..Count.."/"..Args.Amount..")")
        Count = Count + 1
        Mining.MineBlock(Block, true)
    end
end

function Mining.FocusBlocks(Amount)
    local Counter = 0;
    repeat task.wait()
        for _,Block in next, World.Blocks do
            if not Block or not Block.Part or not Block.Part.Parent then continue end
            HumanoidRootPart.CFrame = Block.CFrame
            task.wait(0.1)
            break
        end
        Mining.UpdateBlocks(true)
        for _,v in next, Mining.Blocks do
            local BlockPos = World:WorldToBlockPos(v.Position)
            local Block = World:GetBlock(BlockPos)
            Counter += 1
            Mining.MineBlock(Block)
        end
    until Counter > Amount
end



if Debug.DisableUI then
    local Blocks;
    repeat task.wait()
        Blocks = workspace.__THINGS.BlockWorlds["Blocks_"..World.Id]
    until Blocks
    if Mining.AddedConnection then
        Mining.AddedConnection:Disconnect()
    end
    for _,v in next, Blocks:GetChildren() do
        v.CanCollide = false
        v.CollisionGroup = "BlockDisp"
        local Part = v:FindFirstChildOfClass("Part")
        if Part then
            Part.CanCollide = false
        end
        local ID = v:GetAttribute("id")
        if not Settings.BlockPriority[ID] then
            v.Transparency = 0.9
        end
    end
    Mining.AddedConnection = Blocks.ChildAdded:Connect(function(v)
        v.CanCollide = false
        v.CollisionGroup = "BlockDisp"
        local Part = v:FindFirstChildOfClass("Part")
        if Part then
            Part.CanCollide = false
        end
        local ID = v:GetAttribute("id")
        if not Settings.BlockPriority[ID] then
            v.Transparency = 0.9
        end
    end)
end

--[[Module.Noclip()
if not Debug.DisableUI then
    Module.Optimize(40)
end]]--

local TimesExecuted = 0
local LastExecute;
function Mining.OreMining()
    local Blocks = {}
    for _, Block in pairs(World.Blocks) do
        if Settings.BlockPriority[Block.Dir._id] then
            table.insert(Blocks, Block)
        end
    end

    table.sort(Blocks, function(a, b)
        if a.Dir.Tier == b.Dir.Tier then
            local DistanceA = (a.CFrame.Position - HumanoidRootPart.Position).Magnitude
            local DistanceB = (b.CFrame.Position - HumanoidRootPart.Position).Magnitude
            return DistanceA < DistanceB
        else
            return a.Dir.Tier > b.Dir.Tier
        end
    end)

    if Blocks[1] and Blocks[1].CFrame then
        HumanoidRootPart.CFrame = Blocks[1].CFrame
        if Mining.GetBlockBreakTime(Blocks[1]) >= 0.5 then
            task.wait(0.1)
        end
    end

    for _, Block in pairs(Blocks) do
        if not Block or not Block.Part or not Block.Part.Parent then continue end
        --print("[System Exodus]: (Quest: "..Args.Type.." "..Count.."/"..Args.Amount..")")
        Mining.MineBlock(Block)
    end

    if #Blocks == 0 then
        Mining.LoadLayerDown()
    end
end

local Upgrades = {}
local RequiredUpgrades = {MiningEventLessPetsRequiredPetsToComboThem2 = false, MiningEventIncreaseTierUpChance2 = false}
local Quartz = Library.Items.Misc("Quartz Gem")
for ID, Data in next, Library.EventUpgrades do
    if ID:find("Mining") and ID:find("2") then
        Upgrades[ID] = Data
    end
end
function Mining.Upgrade()
    for ID, Data in next, Upgrades do
        if RequiredUpgrades[ID] then continue end
        for i = 1,5 do
            local Tier = Library.EventUpgradeCmds.GetTier(ID)
            if not Data.TierCosts[Tier + 1] or not Data.TierCosts[Tier + 1]._data then
                RequiredUpgrades[ID] = true
                continue
            end
            local Cost = Data.TierCosts[Tier + 1]._data._am or 1
            if Quartz:CountExact() >= Cost then
                Library.EventUpgradeCmds.Purchase(ID)
            end
        end
    end
end


while task.wait() do
    print("Session Time: ")
    Mining.OreMining()

    if workspace.__THINGS.BlockWorlds["Occlusion_8"].Part.Transparency == 0 then
        print("Mine is RESETTING (can take a bit)! Combining ores if enabled.")
        if Settings.CombineOres then
            Mining.Upgrade()
            if RequiredUpgrades[1] and RequiredUpgrades[2] then 
                HumanoidRootPart.CFrame = CFrame.new(20606, 22, -19940)
                task.wait(0.5)
                for _, Recipe in next, Library.PetCraftingMachines.MiningCraftMachine.Recipes do
                    local Item = Recipe.Ingredients[1].Item
                    local ID = Item:GetId()
                    local Amount = Item:CountExact()
                    if Amount >= 10 and Recipe.Result:GetId():find("Gem") then
                        local MaxCraft = math.min(10000, math.round(Amount/10))
                        local Success;
                        repeat task.wait()
                            Success = Library.Network.Invoke("PetCraftingachine_Craft", "MiningCraftMachine", Recipe.RecipeIndex, MaxAmount, {["shiny"] = false, ["pet"] = 0})
                        until Success
                    end
                end
            end
        end
        repeat task.wait(0.5) until workspace.__THINGS.BlockWorlds["Occlusion_8"].Part.Transparency ~= 0
    end
end

--[[
while task.wait() do
    warn("!!!")
    













    local PickaxeQuests, QuestName, Remaining = Mining.GetPickaxeQuests()
    local BreakFunction;
    if (not PickaxeQuests or Remaining == 0) and QuestName then
        Library.Network.Invoke("NPC Quests: Redeem", QuestName)
        warn("[System Exodus]: Claimed Upgraded Pickaxe")
    elseif QuestName then
        for Ore, Amount in pairs(PickaxeQuests) do
            if Ore == "Blocks" then
                Mining.TeleportToZone(1)
                Mining.FocusBlocks(Amount)
            else
                BreakFunction = Mining.TargetBlock({Type = "Pickaxe", OreID = Ore, Amount = Amount})
                if #PickaxeQuests == 1 and BreakFunction then
                    break
                end
            end
        end
        if not BreakFunction then
            continue
        end
    end

    local GateQuest = Mining.GetGateQuest()
    if GateQuest and type(GateQuest) == "table" then
        for Ore, Amount in pairs(GateQuest) do
            if Ore == "Blocks" then
                Mining.TeleportToZone(1)
                Mining.FocusBlocks(Amount)
            else
                Mining.TargetBlock({Type = "Gate", OreID = Ore, Amount = Amount})
            end
        end
    elseif GateQuest then
        local NextZone = Library.InstanceZoneCmds.GetMaximumOwnedZoneNumber() + 1
        local InstanceData = Library.InstancingCmds.Get()
        local CurrencyData = InstanceData.instanceZones[NextZone] and InstanceData.instanceZones[NextZone]
        if CurrencyData and Library.CurrencyCmds.CanAfford(CurrencyData.CurrencyId, CurrencyData.CurrencyCost) then
            warn("[System Exodus]: Unlocking Zone: "..NextZone)
            Library.Network.Invoke("InstanceZones_RequestPurchase", Library.InstancingCmds.GetInstanceID(), NextZone)
            task.wait(2)
            Mining.TeleportToZone()
            task.wait(2)
            local Cost, Egg;
            for UID, Info in next, Library.CustomEggsCmds.All() do
                if workspace.__THINGS.CustomEggs:FindFirstChild(UID) then
                    setthreadidentity(2)
                    Cost = Library.CalcEggPricePlayer(Info._dir)
                    Egg = UID
                    setthreadidentity(8)
                    break
                end
            end
            if Cost and Egg then
                HumanoidRootPart.CFrame = workspace.__THINGS.CustomEggs[Egg].Egg.CFrame
                local MaxEggHatch = Library.EggCmds.GetMaxHatch()
                if Library.CurrencyCmds.CanAfford("MiningCoins", (Cost * MaxEggHatch) * 5) then
                    for i = 1, 5 do
                        local Success;
                        repeat task.wait(0.1)
                            Success = Library.Network.Invoke("CustomEggs_Hatch", Egg, MaxEggHatch)
                        until Success
                    end
                end
            end
        end
        if not CurrencyData then
            GateQuest = nil
        end
    end

    if not GateQuest and not QuestName then
        break
    end

    if Settings.TargetDiamonds then
        for _,Block in next, World.Blocks do
            HumanoidRootPart.CFrame = Block.CFrame
            task.wait(0.1)
            break
        end
        Mining.UpdateBlocks(true)
        for _,v in next, Mining.Blocks do
            local BlockPos = World:WorldToBlockPos(v.Position)
            local Block = World:GetBlock(BlockPos)
            Mining.MineBlock(Block)
        end
    else
        Mining.TargetBlock({BlockPriority = true})
    end

end
]]--

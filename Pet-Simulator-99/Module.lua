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

local LoadModules = function(Path, IsOne, LoadItself)
    if IsOne then
        local Status, Module = pcall(require, Path)
        if Status then
            getgenv().Library[Path.Name] = Module
        end
        return
    end
    if LoadItself then
        local Status, Module = pcall(require, Path)
        if Status then
            getgenv().Library[Path.Name] = Module
        end
    end
    for _,v in next, Path:GetChildren() do
        if v:IsA("ModuleScript") and not v:GetAttribute("NOLOAD") and v.Name ~= "ToRomanNum" then
            local Status, Module = pcall(require, v)
            if Status then
                getgenv().Library[v.Name] = Module
            end
        end
    end
end
if not getgenv().Library then
    getgenv().Library = {}
    for _,v in next, {NLibrary, NLibrary.Directory, NLibrary.Client, NLibrary.Util, NLibrary.Items, NLibrary.Functions, NLibrary.Modules, NLibrary.Balancing} do
        LoadModules(v)
    end
    LoadModules(NLibrary.Shared.Variables, true)
    LoadModules(NLibrary.Client.OrbCmds.Orb, true)
    LoadModules(NLibrary.Client.MiningCmds.BlockWorldClient, true)
end
local BreakablesScript = PlayerScripts.Game:FindFirstChild("Breakables Frontend") and getsenv(PlayerScripts.Game["Breakables Frontend"]) or Library.BreakablesFrontend

--// Handle Breakables
local Breakables = {}
local function CreateBreakable(Breakable)
    pcall(function()
        Breakables[Breakable.u] = {
            UID = Breakable.u,
            CFrame = Breakable.cf,
            ID = Breakable.id,
            Zone = Breakable.pid,
        }
    end)
end
local function CleanBreakable(Breakable)
    pcall(function()
        Breakables[Breakable] = nil
    end)
end

local Events = {
    ["Created"] = CreateBreakable,
    ["Ping"] = CreateBreakable,
    ["Destroyed"] = CleanBreakable,
    ["Cleanup"] = CleanBreakable,
    ["StageChange"] = function(...) end
},

for Action, Func in pairs(Events) do
    local Event = Category .. "_" .. Action
    local Handler = Func
        
    Handler = LPH_NO_VIRTUALIZE(function(Data)
        for i = 1, #Data do 
            Func(unpack(Data[i])) 
        end
    end)
    Library.Network.Fired(Event):Connect(Handler)
end
for _, v in next, workspace.__THINGS.Breakables:GetChildren() do
    if v:IsA("Model") then
        local UID = v:GetAttribute("BreakableUID")
        local CFrame = v:GetPivot()
        local ID = v:GetAttribute("BreakableID")
        local Zone = v:GetAttribute("ParentID")
        Breakables[UID] = { 
            UID = UID,
            CFrame = CFrame,
            ID = ID,
            Zone = Zone,
        }
    end
end

--// Pet Equip Handling
local Pets = {}
for _,v in pairs(Library.PetNetworking.EquippedPets()) do
    if not Pets[v.euid] then
        table.insert(Pets, v.euid)
    end
end
Library.Network.Fired("Pets_LocalPetsUpdated"):Connect(function(Pet)
    for _,v in pairs(Pet) do
        if not Pets[v.ePet.euid] then
            table.insert(Pets, v.ePet.euid)
        end
    end
end)
Library.Network.Fired("Pets_LocalPetsUnequipped"):Connect(function(Pet)
    for _,v in pairs(Pet) do
        if Pets[v] then
            Pets[v] = nil
        end
    end
end)

--// Orb Creation Handling & Optimization
Library.Orb.new = function(...) return end
Library.Orb.ComputeInitialCFrame = function(...) return CFrame.new() end
Library.Network.Fired("Orbs: Create"):Connect(function(Orbs)
    local OrbsToCollect = {}
    for _, v in next, Orbs do
        table.insert(OrbsToCollect, tonumber(v.id))
    end
    Library.Network.Fire("Orbs: Collect", OrbsToCollect)
end)
workspace.__THINGS.Orbs.ChildAdded:Connect(function(Orb)
    if Orb then
        Orb:Destroy()
    end
end)

--// Anti AFK
LocalPlayer.PlayerScripts.Scripts.Core["Server Closing"].Enabled = false
LocalPlayer.PlayerScripts.Scripts.Core["Idle Tracking"].Enabled = false
Library.Network.Fire("Idle Tracking: Stop Timer")
LocalPlayer.Idled:Connect(function() 
	VirtualUser:CaptureController() 
	VirtualUser:ClickButton2(Vector2.new()) 
end)

local Module = {}
Module.GetBreakables = function()
    return Breakables
end

Module.GetEquippedPets = function()
    return Pets
end

Module.RemoveEggAnimations = function()
    local EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game:WaitForChild("Egg Opening Frontend"))
    EggFrontend.PlayEggAnimation = function(...)
        return
    end
end

Module.SetPetSpeed = function(Speed)
    Library.PlayerPet.CalculateSpeedMultiplier = function()
        return tonumber(Speed)
    end
end

Module.Noclip = function()
    local function Noclip()
        for _,v in next, LocalPlayer.Character:GetDescendants() do
            if v:IsA("BasePart") and v.CanCollide == true then
                v.CanCollide = false
            end
        end
    end
    
    if not HumanoidRootPart:FindFirstChild("LinearVelocity") then
        Attachment0 = Instance.new("Attachment", HumanoidRootPart)
        LinearVelocity = Instance.new("LinearVelocity", HumanoidRootPart)
        LinearVelocity.MaxForce = math.huge
        LinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
        LinearVelocity.Attachment0 = HumanoidRootPart.Attachment
    else
        LinearVelocity = HumanoidRootPart:FindFirstChild("LinearVelocity")
    end

    task.spawn(function()
        while task.wait() do
            if not NoclipVariable then
                NoclipVariable = RunService.Stepped:Connect(Noclip)
            end
            LinearVelocity.Parent = HumanoidRootPart
        end
    end)
end

Module.FarmBreakables = function(...)
    local Args = {...}

    local RemoteList = {}
    local PetArray = {}
    for _,ID in pairs(Pets) do
        table.insert(PetArray, ID)
    end

    local BreakableArray = {}
    for UID, Breakable in pairs(Breakables) do
		if Args.IgnoreIDs and type(Ignore) == "table" and table.find(Args.IgnoreIDs, Breakable.ID) then
			continue
        end
        if Args.IgnoreZones and type(Ignore) == "table" and table.find(Args.IgnoreZones, Breakable.Zone) then
			continue
        end
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
		Library.Network.UnreliableFire("Breakables_PlayerDealDamage", BreakableArray[1])
		Library.Network.Fire("Breakables_JoinPetBulk", RemoteList)
    end
end

local RomanNumerals = {
    {value = 40, numeral = "XL"},
    {value = 10, numeral = "X"},
    {value = 9, numeral = "IX"},
    {value = 5, numeral = "V"},
    {value = 4, numeral = "IV"},
    {value = 1, numeral = "I"}
}
local RomanMapping = {
    I = 1,
    V = 5,
    X = 10,
    L = 50,
    C = 100,
    D = 500,
    M = 1000
}
Module.ConvertToRoman = function(Number)
    local result = ""
    for _, entry in ipairs(RomanNumerals) do
        while Number >= entry.value do
            result = result .. entry.numeral
            Number = Number - entry.value
        end
    end
    return result
end
Module.ConvertToNumerals = function(Roman)
    local Total = 0
    local OldValue = 0
    for i = #Roman, 1, -1 do
        local CurrentValue = RomanMapping[Roman:sub(i, i)]
        if not CurrentValue then return nil end
        if CurrentValue < OldValue then
            Total = Total - CurrentValue
        else
            Total = Total + CurrentValue
        end
        OldValue = CurrentValue
    end
    return Total
end

local SuffixesLower = {"k", "m", "b", "t"}
local SuffixesUpper = {"K", "M", "B", "T"}
Module.AddSuffix = function(Amount)
    local a = math.floor(math.log(Amount, 1e3))
    local b = math.pow(10, a * 3)
    return ("%.2f"):format(Amount / b):gsub("%.?0+$", "") .. (SuffixesLower[a] or "")
end
Module.RemoveSuffix = function(Amount)
    local a, Suffix = Amount:gsub("%a", ""), Amount:match("%a")	
    local b = table.find(SuffixesUpper, Suffix) or table.find(SuffixesLower, Suffix) or 0
    return tonumber(a) * math.pow(10, b * 3)
end

Module.AddCommas = function(Amount)
    local Add = Amount
    while task.wait() do  
        Add, b = string.gsub(Add, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (b == 0) then
            break
        end
    end
    return Add
end

Module.ConvertTime = function(Seconds)
        local Days = math.floor(Seconds / (24 * 3600))
        Seconds = Seconds % (24 * 3600)
        local Hours = math.floor(Seconds / 3600)
        Seconds = Seconds % 3600
        local Minutes = math.floor(Seconds / 60)
        Seconds = Seconds % 60
        local Time = ""
        if Days > 0 then
            Time = Time .. Days .. "d "
        end
        if Hours > 0 then
            Time = Time .. Hours .. "h "
        end
        if Minutes > 0 then
            Time = Time .. Minutes .. "m "
        end
        Time = Time .. Seconds .. "s"
        return Time
end

Module.EnterInstance = function(Name)
	if Library.InstancingCmds.GetInstanceID() == Name then return end
    setthreadidentity(2) 
    Library.InstancingCmds.Enter(Name) 
    setthreadidentity(8)
	task.wait(0.25)
	if Library.InstancingCmds.GetInstanceID() ~= Name then
		EnterInstance(Name)
	end
end

Module.Optimize = function(FPS)
    --// User Settings & Properties
    UserSettings():GetService("UserGameSettings").GraphicsQualityLevel = 1
    UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    UserSettings():GetService("UserGameSettings").MasterVolume = 0
    settings().Rendering.QualityLevel = 1
    settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    sethiddenproperty(Terrain, "Decoration", false)
    sethiddenproperty(Lighting, "Technology", 2)
    --// Lighting
    for _,v in Lighting:GetChildren() do
        v:Destroy()
    end
    Lighting.GlobalShadows = false
    Lighting.ShadowSoftness = 1
    Lighting.Brightness = 0
    Lighting.Ambient = Color3.new(0, 0, 0)
    Lighting.FogEnd = 0
    Lighting.FogStart = 0
    Lighting.Technology = Enum.Technology.Voxel
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
    end
    local function ClearItem(v)
        if v.Name == "SystemExodus" then return end
        if v:IsA("Model") and v.Parent == workspace and v.Name ~= LocalPlayer.Name then
            v:Destroy()
        elseif v:IsA("Workspace") then
            v.Terrain.WaterWaveSize = 0
            v.Terrain.WaterWaveSpeed = 0
            v.Terrain.Elasticity = 0
            v.Terrain.WaterReflectance = 0
            v.Terrain.WaterTransparency = 1
            sethiddenproperty(v, "StreamingTargetRadius", 64)
            sethiddenproperty(v, "StreamingPauseMode", 2)
            sethiddenproperty(v.Terrain, "Decoration", false)
        elseif v:IsA("Model") then
            sethiddenproperty(v, "LevelOfDetail", 1)
        elseif v:IsA("TextButton") or v:IsA("TextLabel") or v:IsA("ImageLabel")  then
            v.Visible = false
        elseif v:IsA("BasePart")  then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
            v.Transparency = 1
        elseif v:IsA("MeshPart") then
            v.Transparency = 0
            v.CanCollide = false
        elseif v:IsA("Texture") or v:IsA("Decal") then
            v.Texture = ""
            v.Transparency = 1
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        elseif v:IsA("ShirtGraphic") then
            v.Graphic = 1
        elseif v:IsA("Lighting") then
            sethiddenproperty(v, "Technology", 2)
            v.GlobalShadows = false
            v.FogEnd = 0
            v.Brightness = 0
        elseif v:IsA("Shirt") or v:IsA("Pants") then
            v[v.ClassName .. "Template"] = ""
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Lifetime = NumberRange.new(0)
            v.Enabled = false
        elseif v:IsA("NetworkClient") then
            v:SetOutgoingKBPSLimit(100)
        elseif v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("UIGradient") or v:IsA("UIStroke") or v:IsA("PointLight") or v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Beam") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") or v:IsA("ScreenGui") then
            v.Enabled = false
        elseif v:IsA("Highlight") then
            v.OutlineTransparency = 1
            v.FillTransparency = 1
        elseif v:IsA("Explosion") then
            v.BlastPressure = 0
            v.BlastRadius = 0
            v.Visible = false
            v.Position = Vector3.new(0, 0, 0)
        elseif v:IsA("Sound") then
            v.Playing = false
            v.Volume = 0
        elseif v:IsA('CharacterMesh') then
            v.BaseTextureId = ""
            v.MeshId = ""
            v.OverlayTextureId = ""
        end
    end
    for _,v in next, workspace:GetDescendants() do
        ClearItem(v)
    end
    for _,v in next, Players:GetChildren() do
        if v ~= LocalPlayer then
            ClearItem(v)
        end
    end
    local RainbowShinyFlag = LocalPlayer.PlayerScripts.Scripts.Game:FindFirstChild("Rainbow & Shiny Flag") and getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Rainbow & Shiny Flag"])
    local PetRepManager = LocalPlayer.PlayerScripts.Scripts.Game.Pets:FindFirstChild("Pet Replication Manager") and getsenv(LocalPlayer.PlayerScripts.Scripts.Game.Pets["Pet Replication Manager"])
    for i,v in next, {RainbowShinyFlag, PetRepManager, Library.Leaderboards, Library.PlayerPet, Library.CustomPet, Library.NotificationCmds, require(NLibrary.Client.NotificationCmds.NotificationInstance), require(NLibrary.Client.NotificationCmds.Item), require(ReplicatedStorage.Assets.Pets.PetRendering)} do
        if v then
            for i2,v2 in next, v do
                if type(v2) == "function" then
                    v[i2] = function()
                        return
                    end
                end
            end
        end
    end
    local Blacklisted = {"Pet Replication Manager", "Relics", "Breakables Frontend", "Hidden Gifts", "Flying Gifts", "Scripts", "Leveling XP Bar", "Legacy Merchants", "Chat Nametags", "Core", "Event", "GUIs", "Game", "Misc", "Test"}
    for _,v in next, LocalPlayer.PlayerScripts:GetDescendants() do
        if not table.find(Blacklisted, v.Name) then
            v:Destroy()
        end
    end
    for _,v in next, ReplicatedStorage:GetDescendants() do
        ClearItem(v)
    end
    workspace.DescendantAdded:Connect(function(v)
        ClearItem(v)
    end)
    for _,v in next, {"Random Events: Coin Jar Data", "NPC Quests: Update Total Progress", "Item Index: Add", "TNT_Spawn", "HatchScreens_Update", "Breakables_UpdatePets", "Pets_ReplicateChanges", "Breakables_UpdateHealth", "Instance Quests: Set State", "Eggs_ConsumableVFX", "Thieving_Animation", "BreakableQuests_IncrementOne"} do
        if ReplicatedStorage.Network:FindFirstChild(v) then
            ReplicatedStorage.Network[v].OnClientEvent:Connect(function() end)
        end
    end
    for _,v in next, LocalPlayer.PlayerGui:GetChildren() do
        if v.Name ~= "System Exodus" then
            v.Enabled = false
        end
    end
    for _,v in next, CoreGui:GetChildren() do
        if v.Name ~= "DevConsoleMaster" and v:IsA("ScreenGui") then
            v.Enabled = false
        end
    end
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
    GuiService.TouchControlsEnabled = false
    setfpscap(FPS or 10)
end


return Module

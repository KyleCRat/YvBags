local _, NS = ...

local Inventory = {}
NS.Inventory = Inventory

local Categories = NS.Categories
local Containers = NS.Containers
local ItemModel = NS.ItemModel

local SCAN_DELAY_SECONDS = 0.2

-- Inventory state
Inventory.containers = {}
Inventory.containerByID = {}
Inventory.items = {}
Inventory.itemsByLocation = {}
Inventory.emptySlots = {}
Inventory.pendingItemIDs = {}
Inventory.pendingItems = {}
Inventory.stats = {}
Inventory.updateCallbacks = {}
Inventory.categoryLabels = Categories.GetLabels()

-- Pending item diagnostics
local function RequestPendingItemLoad(itemID, itemInfo)
    if not C_Item or not C_Item.RequestLoadItemDataByID then
        return false
    end

    if itemID then
        C_Item.RequestLoadItemDataByID(itemID)
        return true
    end

    if itemInfo then
        C_Item.RequestLoadItemDataByID(itemInfo)
        return true
    end

    return false
end

local function TrackPendingItemInfo(item, itemInfo, containerItemInfo)
    if item.itemID then
        Inventory.pendingItemIDs[item.itemID] = true
    end

    Inventory.pendingItems[#Inventory.pendingItems + 1] = {
        locationKey = item.locationKey,
        bagID = item.bagID,
        slotIndex = item.slotIndex,
        bagSlotText = item.bagSlotText,
        itemID = item.itemID,
        name = item.name,
        link = item.link,
        count = item.count,
        quality = item.quality,
        type = item.type,
        subtype = item.subtype,
        classID = item.classID,
        subclassID = item.subclassID,
        categoryKey = item.categoryKey,
        categoryName = item.categoryName,
        bindType = item.bindType,
        bindingKey = item.bindingKey,
        expansionID = item.expansionID,
        sellValue = item.sellValue,
        itemLevel = item.itemLevel,
        requiredLevel = item.requiredLevel,
        professionQuality = item.professionQuality,
        linkType = item.linkType,
        linkOptions = item.linkOptions,
        isKeystone = item.isKeystone,
        keystoneLevel = item.keystoneLevel,
        keystoneMapID = item.keystoneMapID,
        keystoneMapName = item.keystoneMapName,
        isBattlePet = item.isBattlePet,
        battlePetSpeciesID = item.battlePetSpeciesID,
        battlePetLevel = item.battlePetLevel,
        battlePetQuality = item.battlePetQuality,
        containerItemName = containerItemInfo.itemName,
        containerQuality = containerItemInfo.quality,
        hasContainerHyperlink = containerItemInfo.hyperlink ~= nil,
        itemInfoType = type(itemInfo),
        itemInfoText = tostring(itemInfo or ""),
        usedStaticItemInfoFallback = item.usedStaticItemInfoFallback,
        requestedLoad = RequestPendingItemLoad(item.itemID, itemInfo),
    }
end

-- Scanner update notifications
local function NotifyUpdateCallbacks()
    for _, callback in ipairs(Inventory.updateCallbacks) do
        callback(Inventory)
    end
end

-- Event handlers
local function OnPlayerLogin()
    Inventory:ScheduleScan("PLAYER_LOGIN")
end

local function OnPlayerEnteringWorld()
    Inventory:ScheduleScan("PLAYER_ENTERING_WORLD")
end

local function OnBagUpdate(_, bagID)
    if Containers.IsPlayerContainerID(bagID) then
        Inventory:ScheduleScan("BAG_UPDATE")
    end
end

local function OnBagUpdateDelayed()
    Inventory:ScheduleScan("BAG_UPDATE_DELAYED")
end

local function OnItemLockChanged(_, bagOrSlotIndex, slotIndex)
    if slotIndex and Containers.IsPlayerContainerID(bagOrSlotIndex) then
        Inventory:ScheduleScan("ITEM_LOCK_CHANGED")
    end
end

local function OnItemInfoReceived(_, itemID, success)
    if success and Inventory.pendingItemIDs[itemID] then
        Inventory.pendingItemIDs[itemID] = nil
        Inventory:ScheduleScan("GET_ITEM_INFO_RECEIVED")
    end
end

-- Container discovery
function Inventory:DiscoverContainers()
    wipe(self.containers)
    wipe(self.containerByID)

    local containers, containerByID = Containers.DiscoverPlayerContainers()

    for _, container in ipairs(containers) do
        self.containers[#self.containers + 1] = container
    end

    for containerID, container in pairs(containerByID) do
        self.containerByID[containerID] = container
    end
end

-- Bag scan lifecycle
function Inventory:ScanNow(reason)
    wipe(self.items)
    wipe(self.itemsByLocation)
    wipe(self.emptySlots)
    wipe(self.pendingItemIDs)
    wipe(self.pendingItems)
    wipe(self.stats)

    self:DiscoverContainers()

    self.stats.containerCount = #self.containers
    self.stats.totalSlots = 0
    self.stats.freeSlots = 0
    self.stats.usedSlots = 0
    self.stats.emptySlots = 0
    self.stats.itemCount = 0
    self.stats.pendingItemInfoCount = 0
    self.stats.lastScanReason = reason or "manual"
    self.stats.lastScanTime = GetTime and GetTime() or 0

    for _, container in ipairs(self.containers) do
        self.stats.totalSlots = self.stats.totalSlots + container.numSlots
        self.stats.freeSlots = self.stats.freeSlots + container.freeSlotCount

        for slotIndex = 1, container.numSlots do
            local containerItemInfo = C_Container.GetContainerItemInfo(container.id, slotIndex)
            if containerItemInfo then
                local item, itemInfo = ItemModel.Normalize(container, slotIndex, containerItemInfo)
                self.items[#self.items + 1] = item
                self.itemsByLocation[item.locationKey] = item
                container.usedSlots = container.usedSlots + 1
                self.stats.usedSlots = self.stats.usedSlots + 1
                self.stats.itemCount = self.stats.itemCount + 1

                if item.isPendingItemInfo then
                    TrackPendingItemInfo(item, itemInfo, containerItemInfo)
                end
            else
                local emptySlot = Containers.CreateEmptySlot(container, slotIndex)
                self.emptySlots[#self.emptySlots + 1] = emptySlot
                container.emptySlots[#container.emptySlots + 1] = emptySlot
                container.emptySlotCount = container.emptySlotCount + 1
                self.stats.emptySlots = self.stats.emptySlots + 1
            end
        end
    end

    self.stats.pendingItemInfoCount = #self.pendingItems
    self.initialScanComplete = true

    NotifyUpdateCallbacks()
end

function Inventory:ScheduleScan(reason)
    self.pendingScanReason = reason or self.pendingScanReason or "unknown"

    if self.scanScheduled then
        return
    end

    self.scanScheduled = true

    if C_Timer and C_Timer.After then
        C_Timer.After(SCAN_DELAY_SECONDS, function()
            if not Inventory.scanScheduled then
                return
            end

            local pendingReason = Inventory.pendingScanReason
            Inventory.pendingScanReason = nil
            Inventory.scanScheduled = false
            Inventory:ScanNow(pendingReason)
        end)
    else
        self.scanScheduled = false
        self:ScanNow(self.pendingScanReason)
        self.pendingScanReason = nil
    end
end

-- Public inventory API
function Inventory:RegisterUpdateCallback(callback)
    if type(callback) ~= "function" then
        error("Usage: Inventory:RegisterUpdateCallback(callback)", 2)
    end

    self.updateCallbacks[#self.updateCallbacks + 1] = callback
end

function Inventory:GetItems()
    return self.items
end

function Inventory:GetItemByLocation(bagID, slotIndex)
    return self.itemsByLocation[Containers.MakeLocationKey(bagID, slotIndex)]
end

function Inventory:GetContainers()
    return self.containers
end

function Inventory:GetContainer(containerID)
    return self.containerByID[containerID]
end

function Inventory:GetEmptySlots()
    return self.emptySlots
end

function Inventory:GetStats()
    return self.stats
end

function Inventory:GetPendingItems()
    return self.pendingItems
end

function Inventory:IsPlayerContainer(containerID)
    return Containers.IsPlayerContainerID(containerID)
end

-- Initialization
function Inventory:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true

    NS:RegisterEventHandler("PLAYER_LOGIN", OnPlayerLogin)
    NS:RegisterEventHandler("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
    NS:RegisterEventHandler("BAG_UPDATE", OnBagUpdate)
    NS:RegisterEventHandler("BAG_UPDATE_DELAYED", OnBagUpdateDelayed)
    NS:RegisterEventHandler("ITEM_LOCK_CHANGED", OnItemLockChanged)
    NS:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", OnItemInfoReceived)

    self:ScheduleScan("init")
end

NS:RegisterInitCallback(function()
    Inventory:Initialize()
end)

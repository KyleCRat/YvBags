local _, NS = ...

-- Live player-inventory state, targeted refreshes, and reconciliation scans.
local Inventory = {}
NS.Inventory = Inventory

local Categories = NS.Categories
local Containers = NS.Containers
local Pins = NS.ItemPins
local ItemModel = NS.ItemModel

local SCAN_DELAY_SECONDS = 0.2

Inventory.UpdateReasons = {
    Categories = "categories",
}

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
        isPinned = item.isPinned,
        bindType = item.bindType,
        bindingKey = item.bindingKey,
        isAccountBound = item.isAccountBound,
        isAccountUntilEquipped = item.isAccountUntilEquipped,
        expansionID = item.expansionID,
        sellValue = item.sellValue,
        itemLevel = item.itemLevel,
        requiredLevel = item.requiredLevel,
        professionQuality = item.professionQuality,
        linkType = item.linkType,
        linkOptions = item.linkOptions,
        isCosmetic = item.isCosmetic,
        collectionKind = item.collectionKind,
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

local function RebuildPendingItemIDIndex()
    wipe(Inventory.pendingItemIDs)

    for _, item in ipairs(Inventory.pendingItems) do
        if item.itemID then
            Inventory.pendingItemIDs[item.itemID] = true
        end
    end
end

local function RemovePendingItemsForContainer(containerID)
    local removed = false

    for index = #Inventory.pendingItems, 1, -1 do
        if Inventory.pendingItems[index].bagID == containerID then
            table.remove(Inventory.pendingItems, index)
            removed = true
        end
    end

    if removed then
        RebuildPendingItemIDIndex()
    end
end

-- Scanner update notifications
local function NotifyUpdateCallbacks(reason)
    for _, callback in ipairs(Inventory.updateCallbacks) do
        callback(Inventory, reason)
    end
end

-- Container scan helpers
local function ResetContainerUsage(container)
    container.usedSlots = 0
    container.emptySlotCount = 0
    container.emptySlots = container.emptySlots or {}
    wipe(container.emptySlots)
end

local function RemoveContainerEntries(inventory, containerID)
    for index = #inventory.items, 1, -1 do
        local item = inventory.items[index]
        if item.bagID == containerID then
            inventory.itemsByLocation[item.locationKey] = nil
            table.remove(inventory.items, index)
        end
    end

    for index = #inventory.emptySlots, 1, -1 do
        if inventory.emptySlots[index].bagID == containerID then
            table.remove(inventory.emptySlots, index)
        end
    end

    RemovePendingItemsForContainer(containerID)
end

local function ScanContainerSlots(inventory, container)
    ResetContainerUsage(container)

    for slotIndex = 1, container.numSlots do
        local containerItemInfo = C_Container.GetContainerItemInfo(container.id, slotIndex)
        if containerItemInfo then
            local item, itemInfo = ItemModel.Normalize(container, slotIndex, containerItemInfo)
            inventory.items[#inventory.items + 1] = item
            inventory.itemsByLocation[item.locationKey] = item
            container.usedSlots = container.usedSlots + 1

            if item.isPendingItemInfo then
                TrackPendingItemInfo(item, itemInfo, containerItemInfo)
            end
        else
            local emptySlot = Containers.CreateEmptySlot(container, slotIndex)
            inventory.emptySlots[#inventory.emptySlots + 1] = emptySlot
            container.emptySlots[#container.emptySlots + 1] = emptySlot
            container.emptySlotCount = container.emptySlotCount + 1
        end
    end
end

local function ReplaceContainer(inventory, container)
    inventory.containerByID[container.id] = container

    for index, existingContainer in ipairs(inventory.containers) do
        if existingContainer.id == container.id then
            inventory.containers[index] = container
            return true
        end
    end

    return false
end

local function CompareLocation(left, right)
    local leftBagID = left.bagID or 0
    local rightBagID = right.bagID or 0
    if leftBagID ~= rightBagID then
        return leftBagID < rightBagID
    end

    return (left.slotIndex or 0) < (right.slotIndex or 0)
end

local function SortInventoryEntries(inventory)
    table.sort(inventory.items, CompareLocation)
    table.sort(inventory.emptySlots, CompareLocation)
    table.sort(inventory.pendingItems, CompareLocation)
end

local function RebuildStats(inventory, reason)
    wipe(inventory.stats)

    inventory.stats.containerCount = #inventory.containers
    inventory.stats.totalSlots = 0
    inventory.stats.freeSlots = 0
    inventory.stats.usedSlots = 0
    inventory.stats.emptySlots = 0
    inventory.stats.itemCount = 0
    inventory.stats.pendingItemInfoCount = #inventory.pendingItems
    inventory.stats.lastScanReason = reason or "manual"
    inventory.stats.lastScanTime = GetTime and GetTime() or 0

    for _, container in ipairs(inventory.containers) do
        inventory.stats.totalSlots = inventory.stats.totalSlots + (container.numSlots or 0)
        inventory.stats.freeSlots = inventory.stats.freeSlots + (container.freeSlotCount or 0)
        inventory.stats.usedSlots = inventory.stats.usedSlots + (container.usedSlots or 0)
        inventory.stats.emptySlots = inventory.stats.emptySlots + (container.emptySlotCount or 0)
    end

    inventory.stats.itemCount = inventory.stats.usedSlots
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
        Inventory:RefreshContainerNow(bagID, "BAG_UPDATE")
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
    self.scanScheduled = false
    self.pendingScanReason = nil

    wipe(self.items)
    wipe(self.itemsByLocation)
    wipe(self.emptySlots)
    wipe(self.pendingItemIDs)
    wipe(self.pendingItems)
    wipe(self.stats)

    self:DiscoverContainers()

    for _, container in ipairs(self.containers) do
        ScanContainerSlots(self, container)
    end

    SortInventoryEntries(self)
    RebuildStats(self, reason)
    self.initialScanComplete = true

    NotifyUpdateCallbacks()
end

function Inventory:RefreshContainerNow(containerID, reason)
    if not self.initialScanComplete then
        self:ScanNow(reason or "container-refresh")
        return
    end

    local existingContainer = self.containerByID[containerID]
    local nextContainer = Containers.CreateContainer(containerID)
    if not existingContainer or not nextContainer or existingContainer.numSlots ~= nextContainer.numSlots then
        self:ScanNow(reason or "container-layout-changed")
        return
    end

    RemoveContainerEntries(self, containerID)
    ReplaceContainer(self, nextContainer)
    ScanContainerSlots(self, nextContainer)
    SortInventoryEntries(self)
    RebuildStats(self, reason or "container-refresh")

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

function Inventory:RefreshCategories(changeType, categoryID)
    if changeType == Categories.ChangeTypes.Created then
        return
    end

    if changeType == Categories.ChangeTypes.Moved then
        NotifyUpdateCallbacks(Inventory.UpdateReasons.Categories)
        return
    end

    local refreshAll = changeType == Categories.ChangeTypes.Reset
        or changeType == Categories.ChangeTypes.Changed
        or changeType == Categories.ChangeTypes.ProfileChanged
        or changeType == Categories.ChangeTypes.ProfileReset
    local refreshedItem = false

    for _, item in ipairs(self.items) do
        if refreshAll or item.categoryKey == categoryID then
            ItemModel.RefreshCategory(item)
            refreshedItem = true
        end
    end

    for _, pendingItem in ipairs(self.pendingItems) do
        if refreshAll or pendingItem.categoryKey == categoryID then
            local item = self.itemsByLocation[pendingItem.locationKey]
            if item then
                pendingItem.categoryKey = item.categoryKey
                pendingItem.categoryName = item.categoryName
            end
        end
    end

    if (refreshAll or refreshedItem)
        and changeType ~= Categories.ChangeTypes.ProfileChanged
        and changeType ~= Categories.ChangeTypes.ProfileReset then
        NotifyUpdateCallbacks(Inventory.UpdateReasons.Categories)
    end
end

function Inventory:ToggleItemPin(item)
    local isPinned, pinKey = Pins.Toggle(item)
    if isPinned == nil then
        return nil
    end

    for _, candidate in ipairs(self.items) do
        if Pins.GetKey(candidate) == pinKey then
            ItemModel.RefreshPin(candidate)
        end
    end

    for _, pendingItem in ipairs(self.pendingItems) do
        if Pins.GetKey(pendingItem) == pinKey then
            local currentItem = self.itemsByLocation[pendingItem.locationKey]
            if currentItem then
                pendingItem.isPinned = currentItem.isPinned
            end
        end
    end

    NotifyUpdateCallbacks()
    return isPinned
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

    Categories.RegisterCallback(function(_, changeType, categoryID)
        self:RefreshCategories(changeType, categoryID)
    end)

    self:ScheduleScan("init")
end

NS:RegisterInitCallback(function()
    Inventory:Initialize()
end)

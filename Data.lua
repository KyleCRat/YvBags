local _, NS = ...

local Inventory = {}
NS.Inventory = Inventory

local BACKPACK_ID = BACKPACK_CONTAINER or 0
local UNKNOWN_ITEM_ICON = 134400
local SCAN_DELAY_SECONDS = 0.2

local CATEGORY_LABELS = {
    junk = "Junk",
    quest = "Quest",
    consumable = "Consumable",
    container = "Container",
    weapon = "Weapon",
    gem = "Gem",
    armor = "Armor",
    reagent = "Reagent",
    tradegoods = "Trade Goods",
    enhancement = "Enhancement",
    recipe = "Recipe",
    miscellaneous = "Miscellaneous",
    glyph = "Glyph",
    battlepet = "Battle Pet",
    token = "Token",
    profession = "Profession",
    housing = "Housing",
    other = "Other",
    unknown = "Unknown",
}

Inventory.containers = {}
Inventory.containerByID = {}
Inventory.items = {}
Inventory.itemsByLocation = {}
Inventory.emptySlots = {}
Inventory.pendingItemIDs = {}
Inventory.stats = {}
Inventory.updateCallbacks = {}
Inventory.categoryLabels = CATEGORY_LABELS

local function EnumValue(enumName, key, fallback)
    if Enum and Enum[enumName] and Enum[enumName][key] ~= nil then
        return Enum[enumName][key]
    end

    return fallback
end

local ITEM_CLASS_CATEGORIES = {}

local function SetItemClassCategory(enumKey, fallback, categoryKey)
    ITEM_CLASS_CATEGORIES[EnumValue("ItemClass", enumKey, fallback)] = categoryKey
end

SetItemClassCategory("Consumable", 0, "consumable")
SetItemClassCategory("Container", 1, "container")
SetItemClassCategory("Weapon", 2, "weapon")
SetItemClassCategory("Gem", 3, "gem")
SetItemClassCategory("Armor", 4, "armor")
SetItemClassCategory("Reagent", 5, "reagent")
SetItemClassCategory("Tradegoods", 7, "tradegoods")
SetItemClassCategory("ItemEnhancement", 8, "enhancement")
SetItemClassCategory("Recipe", 9, "recipe")
SetItemClassCategory("Questitem", 12, "quest")
SetItemClassCategory("Miscellaneous", 15, "miscellaneous")
SetItemClassCategory("Glyph", 16, "glyph")
SetItemClassCategory("Battlepet", 17, "battlepet")
SetItemClassCategory("WoWToken", 18, "token")
SetItemClassCategory("Profession", 19, "profession")
SetItemClassCategory("Housing", 20, "housing")

local BIND_TYPE_INFO = {}

local function SetBindTypeInfo(enumKey, fallback, key, label)
    BIND_TYPE_INFO[EnumValue("ItemBind", enumKey, fallback)] = {
        key = key,
        label = label,
    }
end

SetBindTypeInfo("None", 0, "none", NONE or "None")
SetBindTypeInfo("OnAcquire", 1, "pickup", ITEM_BIND_ON_PICKUP or "Bind on pickup")
SetBindTypeInfo("OnEquip", 2, "equip", ITEM_BIND_ON_EQUIP or "Bind on equip")
SetBindTypeInfo("OnUse", 3, "use", ITEM_BIND_ON_USE or "Bind on use")
SetBindTypeInfo("Quest", 4, "quest", ITEM_BIND_QUEST or "Quest item")
SetBindTypeInfo("ToWoWAccount", 7, "account", ITEM_BIND_TO_ACCOUNT or "Warbound")
SetBindTypeInfo("ToBnetAccount", 8, "account", ITEM_BIND_TO_BNETACCOUNT or "Account bound")
SetBindTypeInfo("ToBnetAccountUntilEquipped", 9, "accountUntilEquipped", ITEM_BIND_TO_BNETACCOUNT_UNTIL_EQUIPPED or "Account bound until equipped")

local function CountTableKeys(tbl)
    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

local function CopyArray(source)
    local copy = {}

    if source then
        for _, value in ipairs(source) do
            copy[#copy + 1] = value
        end
    end

    return copy
end

local function MakeLocationKey(bagID, slotIndex)
    return ("%d:%d"):format(bagID, slotIndex)
end

local function GetFirstReagentBagID()
    return (NUM_BAG_SLOTS or 4) + 1
end

local function IsPlayerContainerID(containerID)
    if type(containerID) ~= "number" then
        return false
    end

    if containerID == BACKPACK_ID then
        return true
    end

    local normalBagSlots = NUM_BAG_SLOTS or 4
    if containerID >= 1 and containerID <= normalBagSlots then
        return true
    end

    local reagentBagSlots = NUM_REAGENTBAG_SLOTS or 0
    local firstReagentBagID = GetFirstReagentBagID()
    return reagentBagSlots > 0 and containerID >= firstReagentBagID and containerID < firstReagentBagID + reagentBagSlots
end

local function GetContainerInventoryID(containerID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        return C_Container.ContainerIDToInventoryID(containerID)
    end

    if ContainerIDToInventoryID then
        return ContainerIDToInventoryID(containerID)
    end

    return nil
end

local function GetContainerName(containerID)
    if C_Container and C_Container.GetBagName then
        local name = C_Container.GetBagName(containerID)
        if name and name ~= "" then
            return name
        end
    end

    if containerID == BACKPACK_ID then
        return BACKPACK_TOOLTIP or "Backpack"
    end

    return ("Bag %d"):format(containerID)
end

local function GetContainerIcon(containerID)
    if containerID == BACKPACK_ID then
        return "Interface\\Buttons\\Button-Backpack-Up"
    end

    local inventoryID = GetContainerInventoryID(containerID)
    if inventoryID then
        local icon = GetInventoryItemTexture("player", inventoryID)
        if icon then
            return icon
        end
    end

    return UNKNOWN_ITEM_ICON
end

local function GetContainerNumSlots(containerID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(containerID) or 0
    end

    return 0
end

local function GetContainerFreeSlotData(containerID)
    local freeSlots = {}
    local freeSlotCount
    local bagFamily

    if C_Container and C_Container.GetContainerFreeSlots then
        freeSlots = CopyArray(C_Container.GetContainerFreeSlots(containerID))
    end

    if C_Container and C_Container.GetContainerNumFreeSlots then
        freeSlotCount, bagFamily = C_Container.GetContainerNumFreeSlots(containerID)
    end

    if type(freeSlotCount) ~= "number" then
        freeSlotCount = CountTableKeys(freeSlots)
    end

    return freeSlots, freeSlotCount, bagFamily
end

local function GetContainerKind(containerID)
    if containerID == BACKPACK_ID then
        return "backpack"
    end

    if containerID >= GetFirstReagentBagID() then
        return "reagentBag"
    end

    return "bag"
end

local function GetCategoryKey(item)
    if ITEM_CLASS_CATEGORIES[item.classID] == "quest" then
        return "quest"
    end

    if item.quality == EnumValue("ItemQuality", "Poor", 0) and (item.sellValue or 0) > 0 then
        return "junk"
    end

    if item.isCraftingReagent then
        return "reagent"
    end

    return ITEM_CLASS_CATEGORIES[item.classID] or "other"
end

local function GetBindingInfo(bindType, isBound)
    if isBound then
        return "bound", ITEM_SOULBOUND or "Soulbound"
    end

    local info = BIND_TYPE_INFO[bindType]
    if info then
        return info.key, info.label
    end

    return "unknown", UNKNOWN or "Unknown"
end

local function GetProfessionQuality(itemInfo)
    if not itemInfo or not C_TradeSkillUI then
        return nil, nil
    end

    if C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local craftedQuality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemInfo)
        if craftedQuality ~= nil then
            return craftedQuality, "crafted"
        end
    end

    if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local reagentQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemInfo)
        if reagentQuality ~= nil then
            return reagentQuality, "reagent"
        end
    end

    return nil, nil
end

local function GetCurrentBagItemLevel(bagID, slotIndex)
    if not ItemLocation or not ItemLocation.CreateFromBagAndSlot or not C_Item or not C_Item.GetCurrentItemLevel then
        return nil
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
    if itemLocation and itemLocation.IsValid and itemLocation:IsValid() then
        return C_Item.GetCurrentItemLevel(itemLocation)
    end

    return nil
end

local function AddEmptySlot(container, slotIndex)
    local emptySlot = {
        bagID = container.id,
        slotIndex = slotIndex,
        locationKey = MakeLocationKey(container.id, slotIndex),
        containerKind = container.kind,
        containerName = container.name,
    }

    Inventory.emptySlots[#Inventory.emptySlots + 1] = emptySlot
    container.emptySlots[#container.emptySlots + 1] = emptySlot
end

local function TrackPendingItemInfo(itemID)
    if itemID then
        Inventory.pendingItemIDs[itemID] = true
    end
end

local function NormalizeItem(container, slotIndex, containerItemInfo)
    local itemInfo = containerItemInfo.hyperlink or containerItemInfo.itemID
    local instantItemID
    local instantItemType
    local instantItemSubType
    local instantEquipLoc
    local instantIcon
    local instantClassID
    local instantSubClassID

    if C_Item and C_Item.GetItemInfoInstant and itemInfo then
        instantItemID, instantItemType, instantItemSubType, instantEquipLoc, instantIcon, instantClassID, instantSubClassID = C_Item.GetItemInfoInstant(itemInfo)
    end

    local fullName
    local fullLink
    local itemQuality
    local staticItemLevel
    local requiredLevel
    local fullItemType
    local fullItemSubType
    local maxStack
    local fullEquipLoc
    local fullIcon
    local sellValue
    local classID
    local subClassID
    local bindType
    local expansionID
    local setID
    local isCraftingReagent
    local itemDescription

    if C_Item and C_Item.GetItemInfo and itemInfo then
        fullName, fullLink, itemQuality, staticItemLevel, requiredLevel, fullItemType, fullItemSubType, maxStack, fullEquipLoc, fullIcon, sellValue, classID, subClassID, bindType, expansionID, setID, isCraftingReagent, itemDescription = C_Item.GetItemInfo(itemInfo)
    end

    if not fullName then
        TrackPendingItemInfo(containerItemInfo.itemID)
    end

    local actualItemLevel
    local previewLevel
    local sparseItemLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo and itemInfo then
        actualItemLevel, previewLevel, sparseItemLevel = C_Item.GetDetailedItemLevelInfo(itemInfo)
    end

    local professionQuality
    local professionQualityType
    professionQuality, professionQualityType = GetProfessionQuality(itemInfo)

    local currentItemLevel = GetCurrentBagItemLevel(container.id, slotIndex)
    local bindingKey
    local bindingText
    bindingKey, bindingText = GetBindingInfo(bindType, containerItemInfo.isBound)

    local item = {
        locationKey = MakeLocationKey(container.id, slotIndex),
        bagID = container.id,
        slotIndex = slotIndex,
        bagSlotText = ("%d/%d"):format(container.id, slotIndex),
        containerKind = container.kind,
        containerName = container.name,
        itemID = containerItemInfo.itemID or instantItemID,
        name = fullName or containerItemInfo.itemName or (containerItemInfo.itemID and ("Item " .. tostring(containerItemInfo.itemID))) or "Unknown Item",
        link = fullLink or containerItemInfo.hyperlink,
        icon = fullIcon or containerItemInfo.iconFileID or instantIcon or UNKNOWN_ITEM_ICON,
        count = containerItemInfo.stackCount or 1,
        quality = itemQuality or containerItemInfo.quality,
        itemLevel = currentItemLevel or actualItemLevel or staticItemLevel,
        currentItemLevel = currentItemLevel,
        actualItemLevel = actualItemLevel,
        previewItemLevel = previewLevel,
        sparseItemLevel = sparseItemLevel or staticItemLevel,
        requiredLevel = requiredLevel,
        type = fullItemType or instantItemType,
        subtype = fullItemSubType or instantItemSubType,
        classID = classID or instantClassID,
        subclassID = subClassID or instantSubClassID,
        equipLoc = fullEquipLoc or instantEquipLoc,
        maxStack = maxStack,
        bindType = bindType,
        bindingKey = bindingKey,
        bindingText = bindingText,
        isBound = containerItemInfo.isBound,
        sellValue = sellValue or 0,
        totalSellValue = (sellValue or 0) * (containerItemInfo.stackCount or 1),
        expansionID = expansionID,
        setID = setID,
        isCraftingReagent = isCraftingReagent,
        itemDescription = itemDescription,
        professionQuality = professionQuality,
        professionQualityType = professionQualityType,
        isLocked = containerItemInfo.isLocked,
        isReadable = containerItemInfo.isReadable,
        hasLoot = containerItemInfo.hasLoot,
        hasNoValue = containerItemInfo.hasNoValue,
        isFiltered = containerItemInfo.isFiltered,
        isPendingItemInfo = fullName == nil,
    }

    item.categoryKey = GetCategoryKey(item)
    item.categoryName = CATEGORY_LABELS[item.categoryKey] or CATEGORY_LABELS.other

    return item
end

local function NotifyUpdateCallbacks()
    for _, callback in ipairs(Inventory.updateCallbacks) do
        callback(Inventory)
    end
end

local function OnPlayerLogin()
    Inventory:ScheduleScan("PLAYER_LOGIN")
end

local function OnPlayerEnteringWorld()
    Inventory:ScheduleScan("PLAYER_ENTERING_WORLD")
end

local function OnBagUpdate(_, bagID)
    if IsPlayerContainerID(bagID) then
        Inventory:ScheduleScan("BAG_UPDATE")
    end
end

local function OnBagUpdateDelayed()
    Inventory:ScheduleScan("BAG_UPDATE_DELAYED")
end

local function OnItemLockChanged(_, bagOrSlotIndex, slotIndex)
    if slotIndex and IsPlayerContainerID(bagOrSlotIndex) then
        Inventory:ScheduleScan("ITEM_LOCK_CHANGED")
    end
end

local function OnItemInfoReceived(_, itemID, success)
    if success and Inventory.pendingItemIDs[itemID] then
        Inventory.pendingItemIDs[itemID] = nil
        Inventory:ScheduleScan("GET_ITEM_INFO_RECEIVED")
    end
end

function Inventory:DiscoverContainers()
    wipe(self.containers)
    wipe(self.containerByID)

    local function AddContainer(containerID)
        local numSlots = GetContainerNumSlots(containerID)
        if containerID ~= BACKPACK_ID and numSlots <= 0 then
            return
        end

        local freeSlots, freeSlotCount, bagFamily = GetContainerFreeSlotData(containerID)
        local container = {
            id = containerID,
            kind = GetContainerKind(containerID),
            name = GetContainerName(containerID),
            icon = GetContainerIcon(containerID),
            inventoryID = GetContainerInventoryID(containerID),
            numSlots = numSlots,
            freeSlots = freeSlots,
            freeSlotCount = freeSlotCount or 0,
            bagFamily = bagFamily,
            usedSlots = 0,
            emptySlotCount = 0,
            emptySlots = {},
        }

        self.containers[#self.containers + 1] = container
        self.containerByID[containerID] = container
    end

    AddContainer(BACKPACK_ID)

    for containerID = 1, NUM_BAG_SLOTS or 4 do
        AddContainer(containerID)
    end

    local firstReagentBagID = GetFirstReagentBagID()
    for containerID = firstReagentBagID, firstReagentBagID + (NUM_REAGENTBAG_SLOTS or 0) - 1 do
        AddContainer(containerID)
    end
end

function Inventory:ScanNow(reason)
    wipe(self.items)
    wipe(self.itemsByLocation)
    wipe(self.emptySlots)
    wipe(self.pendingItemIDs)
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
                local item = NormalizeItem(container, slotIndex, containerItemInfo)
                self.items[#self.items + 1] = item
                self.itemsByLocation[item.locationKey] = item
                container.usedSlots = container.usedSlots + 1
                self.stats.usedSlots = self.stats.usedSlots + 1
                self.stats.itemCount = self.stats.itemCount + 1
            else
                AddEmptySlot(container, slotIndex)
                container.emptySlotCount = container.emptySlotCount + 1
                self.stats.emptySlots = self.stats.emptySlots + 1
            end
        end
    end

    self.stats.pendingItemInfoCount = CountTableKeys(self.pendingItemIDs)
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
    return self.itemsByLocation[MakeLocationKey(bagID, slotIndex)]
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

function Inventory:IsPlayerContainer(containerID)
    return IsPlayerContainerID(containerID)
end

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

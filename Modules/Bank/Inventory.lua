local _, NS = ...

-- Session-only Character and Warband bank inventory state.
local BankInventory = {}
NS.BankInventory = BankInventory

local Categories = NS.Categories
local Containers = NS.Containers
local ItemModel = NS.ItemModel
local Pins = NS.ItemPins

local CHARACTER_BANK = Enum.BankType.Character
local ACCOUNT_BANK = Enum.BankType.Account
local SCAN_DELAY_SECONDS = 0.2
local CATEGORY_RULE_REFRESH_DELAY_SECONDS = 0.1

BankInventory.UpdateReasons = {
    Categories = "categories",
    Loading = "loading",
    Locks = "locks",
    Pins = "pins",
    Tabs = "tabs",
    Updated = "updated",
}

local function CreateState(bankType)
    return {
        bankType = bankType,
        containers = {},
        containerByID = {},
        items = {},
        itemsByLocation = {},
        emptySlots = {},
        pendingItemIDs = {},
        stats = {},
        isLoaded = false,
        isLoading = false,
        scanGeneration = 0,
    }
end

BankInventory.states = {
    [CHARACTER_BANK] = CreateState(CHARACTER_BANK),
    [ACCOUNT_BANK] = CreateState(ACCOUNT_BANK),
}
BankInventory.tabBankTypes = {}
BankInventory.viewableBankTypes = {}
BankInventory.updateCallbacks = {}
BankInventory.delayedScanBankTypes = {}

local function NotifyUpdateCallbacks(reason, bankType, ...)
    for index = 1, #BankInventory.updateCallbacks do
        BankInventory.updateCallbacks[index](
            BankInventory,
            reason,
            bankType,
            ...
        )
    end
end

local function CompareLocation(left, right)
    if left.bagID ~= right.bagID then
        return left.bagID < right.bagID
    end

    return left.slotIndex < right.slotIndex
end

local function SortEntries(state)
    table.sort(state.items, CompareLocation)
    table.sort(state.emptySlots, CompareLocation)
end

local function RebuildPendingItemIDs(state)
    wipe(state.pendingItemIDs)

    for index = 1, #state.items do
        local item = state.items[index]
        if item.isPendingItemInfo and item.itemID then
            state.pendingItemIDs[item.itemID] = true
        end
    end
end

local function RebuildStats(state, reason)
    local stats = state.stats
    wipe(stats)

    stats.containerCount = #state.containers
    stats.totalSlots = 0
    stats.usedSlots = 0
    stats.emptySlots = 0
    stats.freeSlots = 0
    stats.itemCount = 0
    stats.pendingItemInfoCount = 0
    stats.lastScanReason = reason or "bank-refresh"
    stats.lastScanTime = GetTime()

    for index = 1, #state.containers do
        local container = state.containers[index]
        stats.totalSlots = stats.totalSlots + container.numSlots
        stats.usedSlots = stats.usedSlots + container.usedSlots
        stats.emptySlots = stats.emptySlots + container.emptySlotCount
    end

    for index = 1, #state.items do
        if state.items[index].isPendingItemInfo then
            stats.pendingItemInfoCount = stats.pendingItemInfoCount + 1
        end
    end

    stats.freeSlots = stats.emptySlots
    stats.itemCount = stats.usedSlots
end

local function CreateContainer(bankType, tabData)
    local tabID = tabData.ID
    return {
        id = tabID,
        bankType = bankType,
        kind = bankType == ACCOUNT_BANK
            and "warbandBankTab"
            or "characterBankTab",
        name = tabData.name,
        icon = tabData.icon,
        depositFlags = tabData.depositFlags,
        tabData = tabData,
        numSlots = C_Container.GetContainerNumSlots(tabID) or 0,
        freeSlotCount = 0,
        usedSlots = 0,
        emptySlotCount = 0,
        emptySlots = {},
    }
end

local function CreateEmptySlot(container, slotIndex)
    return {
        bagID = container.id,
        slotIndex = slotIndex,
        locationKey = Containers.MakeLocationKey(container.id, slotIndex),
        containerKind = container.kind,
        containerName = container.name,
        bankType = container.bankType,
    }
end

local function ScanContainer(target, container)
    for slotIndex = 1, container.numSlots do
        local containerItemInfo = C_Container.GetContainerItemInfo(
            container.id,
            slotIndex
        )

        if containerItemInfo then
            local item = ItemModel.Normalize(
                container,
                slotIndex,
                containerItemInfo
            )
            target.items[#target.items + 1] = item
            target.itemsByLocation[item.locationKey] = item
            container.usedSlots = container.usedSlots + 1

            if item.isPendingItemInfo and item.itemID then
                target.pendingItemIDs[item.itemID] = true
                C_Item.RequestLoadItemDataByID(item.itemID)
            end
        else
            local emptySlot = CreateEmptySlot(container, slotIndex)
            target.emptySlots[#target.emptySlots + 1] = emptySlot
            container.emptySlots[#container.emptySlots + 1] = emptySlot
            container.emptySlotCount = container.emptySlotCount + 1
        end
    end

    container.freeSlotCount = container.emptySlotCount
end

local function DiscoverContainers(bankType)
    local containers = {}
    local tabData = C_Bank.FetchPurchasedBankTabData(bankType)

    for index = 1, #tabData do
        local container = CreateContainer(bankType, tabData[index])
        containers[#containers + 1] = container
        BankInventory.tabBankTypes[container.id] = bankType
    end

    return containers
end

local function CreateScanTarget(bankType)
    local target = CreateState(bankType)
    if C_Bank.FetchBankLockedReason(bankType) == nil then
        target.containers = DiscoverContainers(bankType)
    end

    for index = 1, #target.containers do
        local container = target.containers[index]
        target.containerByID[container.id] = container
    end

    return target
end

local function CommitScan(state, target, reason)
    local rescanAfterLoad = state.rescanAfterLoad
    state.rescanAfterLoad = nil

    -- Categories and account-wide pins can change from the concurrently open
    -- bag/settings UI while a multi-frame bank scan is in progress.
    for index = 1, #target.items do
        ItemModel.RefreshClassification(target.items[index])
    end

    state.containers = target.containers
    state.containerByID = target.containerByID
    state.items = target.items
    state.itemsByLocation = target.itemsByLocation
    state.emptySlots = target.emptySlots
    state.pendingItemIDs = target.pendingItemIDs
    state.stats = target.stats
    state.scanTarget = nil
    state.isLoading = false
    state.isLoaded = true

    SortEntries(state)
    RebuildStats(state, reason)
    NotifyUpdateCallbacks(
        BankInventory.UpdateReasons.Updated,
        state.bankType
    )

    if rescanAfterLoad then
        BankInventory:ScheduleScan(
            state.bankType,
            "bank-update-during-load"
        )
    end
end

local function ScanNextContainer(state, target, index, reason, generation)
    if not BankInventory.isOpen or state.scanGeneration ~= generation then
        return
    end

    local container = target.containers[index]
    if not container then
        CommitScan(state, target, reason)
        return
    end

    ScanContainer(target, container)
    C_Timer.After(0, function()
        ScanNextContainer(state, target, index + 1, reason, generation)
    end)
end

local function StartScan(bankType, reason)
    local state = BankInventory.states[bankType]
    if not state or not BankInventory.isOpen then
        return
    end

    if state.scanTimer then
        state.scanTimer:Cancel()
        state.scanTimer = nil
    end
    state.pendingScanReason = nil
    state.rescanAfterLoad = nil

    for tabID, mappedBankType in pairs(BankInventory.tabBankTypes) do
        if mappedBankType == bankType then
            BankInventory.tabBankTypes[tabID] = nil
        end
    end

    state.scanGeneration = state.scanGeneration + 1
    state.isLoading = true
    local generation = state.scanGeneration
    local target = CreateScanTarget(bankType)
    state.scanTarget = target

    NotifyUpdateCallbacks(
        BankInventory.UpdateReasons.Loading,
        bankType
    )
    ScanNextContainer(state, target, 1, reason, generation)
end

local function RemoveContainerEntries(state, tabID)
    for index = #state.items, 1, -1 do
        local item = state.items[index]
        if item.bagID == tabID then
            state.itemsByLocation[item.locationKey] = nil
            table.remove(state.items, index)
        end
    end

    for index = #state.emptySlots, 1, -1 do
        if state.emptySlots[index].bagID == tabID then
            table.remove(state.emptySlots, index)
        end
    end
end

local function FindPurchasedTabData(bankType, tabID)
    local tabData = C_Bank.FetchPurchasedBankTabData(bankType)

    for index = 1, #tabData do
        if tabData[index].ID == tabID then
            return tabData[index]
        end
    end

    return nil
end

local function ReplaceContainer(state, nextContainer)
    state.containerByID[nextContainer.id] = nextContainer

    for index = 1, #state.containers do
        if state.containers[index].id == nextContainer.id then
            state.containers[index] = nextContainer
            return
        end
    end

    state.containers[#state.containers + 1] = nextContainer
end

function BankInventory:RefreshContainerNow(tabID, reason)
    local bankType = self.tabBankTypes[tabID]
    local state = bankType and self.states[bankType]
    if not state or not state.isLoaded then
        return
    end

    local tabData = FindPurchasedTabData(bankType, tabID)
    if not tabData then
        StartScan(bankType, reason or "bank-tab-layout-changed")
        return
    end

    local container = CreateContainer(bankType, tabData)
    RemoveContainerEntries(state, tabID)
    ReplaceContainer(state, container)
    ScanContainer(state, container)
    SortEntries(state)
    RebuildPendingItemIDs(state)
    RebuildStats(state, reason)
    NotifyUpdateCallbacks(self.UpdateReasons.Updated, bankType)
end

function BankInventory:ScheduleScan(bankType, reason)
    local state = self.states[bankType]
    if not state or not self.isOpen then
        return
    end

    state.pendingScanReason = reason or state.pendingScanReason
        or "bank-reconcile"
    if state.isLoading then
        state.rescanAfterLoad = true
        return
    end

    if state.scanTimer then
        return
    end

    state.scanTimer = C_Timer.NewTimer(SCAN_DELAY_SECONDS, function()
        state.scanTimer = nil
        local pendingReason = state.pendingScanReason
        state.pendingScanReason = nil
        state.rescanAfterLoad = nil
        state.scanTarget = nil
        StartScan(bankType, pendingReason)
    end)
end

local function IsSupportedBankType(bankType)
    return bankType == CHARACTER_BANK or bankType == ACCOUNT_BANK
end

function BankInventory:RefreshViewableBankTypes()
    wipe(self.viewableBankTypes)

    local viewable = C_Bank.FetchViewableBankTypes()
    for index = 1, #viewable do
        local bankType = viewable[index]
        if IsSupportedBankType(bankType) then
            self.viewableBankTypes[#self.viewableBankTypes + 1] = bankType
        end
    end
end

function BankInventory:IsBankTypeViewable(bankType)
    for index = 1, #self.viewableBankTypes do
        if self.viewableBankTypes[index] == bankType then
            return true
        end
    end

    return false
end

function BankInventory:GetViewableBankTypes()
    return self.viewableBankTypes
end

function BankInventory:Open(preferredBankType)
    self.isOpen = true
    self:RefreshViewableBankTypes()

    if not self:IsBankTypeViewable(preferredBankType) then
        if self:IsBankTypeViewable(CHARACTER_BANK) then
            preferredBankType = CHARACTER_BANK
        else
            preferredBankType = self.viewableBankTypes[1]
        end
    end

    self.activeBankType = preferredBankType
    if preferredBankType then
        StartScan(preferredBankType, "bank-open")
    end

    return preferredBankType
end

function BankInventory:Close()
    self.isOpen = false
    self.activeBankType = nil
    wipe(self.tabBankTypes)
    wipe(self.delayedScanBankTypes)

    if self.categoryRuleRefreshTimer then
        self.categoryRuleRefreshTimer:Cancel()
        self.categoryRuleRefreshTimer = nil
    end

    for _, state in pairs(self.states) do
        state.scanGeneration = state.scanGeneration + 1
        if state.scanTimer then
            state.scanTimer:Cancel()
            state.scanTimer = nil
        end

        state.pendingScanReason = nil
        state.rescanAfterLoad = nil
        state.scanTarget = nil
        wipe(state.containers)
        wipe(state.containerByID)
        wipe(state.items)
        wipe(state.itemsByLocation)
        wipe(state.emptySlots)
        wipe(state.pendingItemIDs)
        wipe(state.stats)
        state.isLoading = false
        state.isLoaded = false
    end
end

function BankInventory:SetActiveBankType(bankType)
    if not self:IsBankTypeViewable(bankType) then
        return false
    end

    self.activeBankType = bankType
    local state = self.states[bankType]
    if not state.isLoaded and not state.isLoading then
        StartScan(bankType, "bank-view-changed")
    end

    return true
end

function BankInventory:GetActiveBankType()
    return self.activeBankType
end

function BankInventory:GetState(bankType)
    return self.states[bankType or self.activeBankType]
end

function BankInventory:GetItems(bankType)
    local state = self:GetState(bankType)
    return state and state.items or {}
end

function BankInventory:GetContainers(bankType)
    local state = self:GetState(bankType)
    return state and state.containers or {}
end

function BankInventory:GetDisplayContainers(bankType)
    local state = self:GetState(bankType)
    if not state then
        return {}
    end

    return state.scanTarget and state.scanTarget.containers
        or state.containers
end

function BankInventory:GetContainer(tabID)
    local bankType = self.tabBankTypes[tabID]
    local state = bankType and self.states[bankType]
    return state and state.containerByID[tabID] or nil
end

function BankInventory:GetStats(bankType)
    local state = self:GetState(bankType)
    return state and state.stats or {}
end

function BankInventory:IsLoading(bankType)
    local state = self:GetState(bankType)
    return state and state.isLoading == true or false
end

function BankInventory:IsLoaded(bankType)
    local state = self:GetState(bankType)
    return state and state.isLoaded == true or false
end

function BankInventory:HasLockedItems(bankType)
    local state = self:GetState(bankType)
    if not state then
        return false
    end

    for index = 1, #state.items do
        if state.items[index].isLocked then
            return true
        end
    end

    return false
end

function BankInventory:IsSlotEmpty(tabID, slotIndex)
    return C_Container.GetContainerItemInfo(tabID, slotIndex) == nil
end

function BankInventory:FindCursorItemEmptySlot(
    _,
    _,
    sourceContainerID,
    sourceSlotIndex
)
    local bankType = self.activeBankType
    local state = self.states[bankType]
    if not state or not state.isLoaded or not C_Bank.CanUseBank(bankType) then
        return nil
    end

    local cursorItemLocation = C_Cursor.GetCursorItem()
    if not cursorItemLocation
        or not C_Bank.IsItemAllowedInBankType(
            bankType,
            cursorItemLocation
        ) then
        return nil
    end

    local sourceFallback
    for index = 1, #state.emptySlots do
        local slot = state.emptySlots[index]
        if slot.bagID == sourceContainerID
            and slot.slotIndex == sourceSlotIndex then
            sourceFallback = slot
        else
            return slot.bagID, slot.slotIndex
        end
    end

    if sourceFallback then
        return sourceFallback.bagID, sourceFallback.slotIndex
    end

    return nil
end

function BankInventory:RegisterUpdateCallback(callback)
    if type(callback) ~= "function" then
        error("Usage: BankInventory:RegisterUpdateCallback(callback)", 2)
    end

    self.updateCallbacks[#self.updateCallbacks + 1] = callback
end

function BankInventory:RefreshItemLockNow(tabID, slotIndex)
    local bankType = self.tabBankTypes[tabID]
    local state = bankType and self.states[bankType]
    if not state then
        return
    end

    local key = Containers.MakeLocationKey(tabID, slotIndex)
    local item = state.itemsByLocation[key]
    local itemInfo = C_Container.GetContainerItemInfo(tabID, slotIndex)
    if not item or not itemInfo or item.itemID ~= itemInfo.itemID then
        return
    end

    item.isLocked = itemInfo.isLocked == true
    NotifyUpdateCallbacks(
        self.UpdateReasons.Locks,
        bankType,
        tabID,
        slotIndex,
        item.isLocked
    )
end

local function RefreshCategories(changeType, categoryID)
    if changeType == Categories.ChangeTypes.RuleMoved
        or changeType == Categories.ChangeTypes.Created then
        return
    end

    if changeType == Categories.ChangeTypes.RulesChanged then
        if BankInventory.categoryRuleRefreshTimer then
            BankInventory.categoryRuleRefreshTimer:Cancel()
        end

        BankInventory.categoryRuleRefreshTimer = C_Timer.NewTimer(
            CATEGORY_RULE_REFRESH_DELAY_SECONDS,
            function()
                BankInventory.categoryRuleRefreshTimer = nil
                RefreshCategories(Categories.ChangeTypes.Changed)
            end
        )
        return
    end

    local refreshAll = changeType == Categories.ChangeTypes.Reset
        or changeType == Categories.ChangeTypes.Changed
        or changeType == Categories.ChangeTypes.Moved
        or changeType == Categories.ChangeTypes.ProfileChanged
        or changeType == Categories.ChangeTypes.ProfileReset

    for bankType, state in pairs(BankInventory.states) do
        local refreshed = false
        for index = 1, #state.items do
            local item = state.items[index]
            if refreshAll or item.categoryKey == categoryID then
                ItemModel.RefreshCategory(item)
                refreshed = true
            end
        end

        if refreshed then
            NotifyUpdateCallbacks(
                BankInventory.UpdateReasons.Categories,
                bankType
            )
        end
    end
end

local function RefreshPins(pinKey)
    for bankType, state in pairs(BankInventory.states) do
        local refreshed = false
        for index = 1, #state.items do
            local item = state.items[index]
            if Pins.GetKey(item) == pinKey then
                ItemModel.RefreshPin(item)
                refreshed = true
            end
        end

        if refreshed then
            NotifyUpdateCallbacks(
                BankInventory.UpdateReasons.Pins,
                bankType
            )
        end
    end
end

local function OnBagUpdate(_, tabID)
    local bankType = BankInventory.tabBankTypes[tabID]
    if bankType then
        BankInventory.delayedScanBankTypes[bankType] = true
        local state = BankInventory.states[bankType]
        if state.isLoading then
            state.rescanAfterLoad = true
        else
            BankInventory:RefreshContainerNow(tabID, "BAG_UPDATE")
        end
    end
end

local function OnBagUpdateDelayed()
    if not BankInventory.isOpen then
        return
    end

    for bankType in pairs(BankInventory.delayedScanBankTypes) do
        BankInventory.delayedScanBankTypes[bankType] = nil
        local state = BankInventory.states[bankType]
        if state and (state.isLoaded or state.isLoading) then
            BankInventory:ScheduleScan(bankType, "BAG_UPDATE_DELAYED")
        end
    end
end

local function OnPlayerBankSlotsChanged()
    BankInventory:ScheduleScan(
        CHARACTER_BANK,
        "PLAYERBANKSLOTS_CHANGED"
    )
end

local function OnAccountBankSlotsChanged()
    BankInventory:ScheduleScan(
        ACCOUNT_BANK,
        "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED"
    )
end

local function OnBankTabsChanged(_, bankType)
    if IsSupportedBankType(bankType) and BankInventory.isOpen then
        StartScan(bankType, "BANK_TABS_CHANGED")
        NotifyUpdateCallbacks(BankInventory.UpdateReasons.Tabs, bankType)
    end
end

local function OnBankTabSettingsUpdated(_, bankType)
    if IsSupportedBankType(bankType) and BankInventory.isOpen then
        StartScan(bankType, "BANK_TAB_SETTINGS_UPDATED")
        NotifyUpdateCallbacks(BankInventory.UpdateReasons.Tabs, bankType)
    end
end

local function OnItemLockChanged(_, tabID, slotIndex)
    if BankInventory.tabBankTypes[tabID] and slotIndex then
        BankInventory:RefreshItemLockNow(tabID, slotIndex)
        BankInventory:ScheduleScan(
            BankInventory.tabBankTypes[tabID],
            "ITEM_LOCK_CHANGED"
        )
    end
end

local function OnItemInfoReceived(_, itemID, success)
    if not success then
        return
    end

    for bankType, state in pairs(BankInventory.states) do
        if state.pendingItemIDs[itemID]
            or (state.scanTarget
                and state.scanTarget.pendingItemIDs[itemID]) then
            BankInventory:ScheduleScan(bankType, "GET_ITEM_INFO_RECEIVED")
        end
    end
end

function BankInventory:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true
    NS:RegisterEventHandler("BAG_UPDATE", OnBagUpdate)
    NS:RegisterEventHandler("BAG_UPDATE_DELAYED", OnBagUpdateDelayed)
    NS:RegisterEventHandler("BANK_TABS_CHANGED", OnBankTabsChanged)
    NS:RegisterEventHandler(
        "BANK_TAB_SETTINGS_UPDATED",
        OnBankTabSettingsUpdated
    )
    NS:RegisterEventHandler("ITEM_LOCK_CHANGED", OnItemLockChanged)
    NS:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", OnItemInfoReceived)
    NS:RegisterEventHandler(
        "PLAYERBANKSLOTS_CHANGED",
        OnPlayerBankSlotsChanged
    )
    NS:RegisterEventHandler(
        "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
        OnAccountBankSlotsChanged
    )

    Categories.RegisterCallback(function(_, changeType, categoryID)
        RefreshCategories(changeType, categoryID)
    end)
    Pins.RegisterCallback(function(_, pinKey)
        RefreshPins(pinKey)
    end)
end

NS:RegisterInitCallback(function()
    BankInventory:Initialize()
end)

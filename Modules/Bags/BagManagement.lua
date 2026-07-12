local _, NS = ...

-- Player bag-slot interaction and asynchronous empty-bag operation contract.
local BagManagement = {}
NS.BagManagement = BagManagement

local Containers = NS.Containers
local ADDON_NAME = NS.ADDON_NAME

local BACKPACK_ID = BACKPACK_CONTAINER or 0
local BACKPACK_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
local UNKNOWN_ITEM_ICON = 134400
local EMPTY_BAG_STEP_DELAY = 0.03
local EMPTY_BAG_LOCKED_RETRY_DELAY = 0.15
local EMPTY_BAG_MOVE_WAIT_POLL_DELAY = 0.1
local EMPTY_BAG_MOVE_WAIT_TIMEOUT = 2
local ERROR_CURSOR_BUSY = "Clear your cursor before emptying a bag."
local ERROR_EMPTY_FAILED = "Could not empty the bag. There is not enough compatible space."
local ERROR_NO_CURSOR_ITEM = "No item is on the cursor."
local ERROR_NO_COMPATIBLE_SLOT = "No compatible bag slot is available."
local ERROR_EMPTY_IN_PROGRESS = ADDON_NAME .. " is already emptying a bag."

local emptyBagOperation

local function AddError(message)
    if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage then
        UIErrorsFrame:AddExternalErrorMessage(message)
    else
        NS:Print(message)
    end
end

local function PickupContainerItem(containerID, slotIndex)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(containerID, slotIndex)
    elseif _G.PickupContainerItem then
        _G.PickupContainerItem(containerID, slotIndex)
    end
end

local function GetContainerItemInfo(containerID, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(containerID, slotIndex)
    elseif _G.GetContainerItemInfo then
        local texture, count, locked, quality, readable, lootable, link = _G.GetContainerItemInfo(containerID, slotIndex)
        if texture then
            return {
                iconFileID = texture,
                stackCount = count,
                isLocked = locked,
                quality = quality,
                isReadable = readable,
                hasLoot = lootable,
                hyperlink = link,
                itemID = link and GetItemInfoInstant and GetItemInfoInstant(link),
            }
        end
    end

    return nil
end

local function GetContainerNumSlots(containerID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(containerID) or 0
    elseif _G.GetContainerNumSlots then
        return _G.GetContainerNumSlots(containerID) or 0
    end

    return 0
end

local function GetContainerFamily(containerID)
    if containerID == BACKPACK_ID then
        return 0
    end

    if C_Container and C_Container.GetContainerNumFreeSlots then
        local _, family = C_Container.GetContainerNumFreeSlots(containerID)
        if type(family) == "number" then
            return family
        end
    elseif _G.GetContainerNumFreeSlots then
        local _, family = _G.GetContainerNumFreeSlots(containerID)
        if type(family) == "number" then
            return family
        end
    end

    local inventoryID = Containers.GetContainerInventoryID(containerID)
    local link = inventoryID and GetInventoryItemLink and GetInventoryItemLink("player", inventoryID)
    if link and GetItemFamily then
        return GetItemFamily(link) or 0
    end

    return 0
end

local function IsFamilyCompatible(itemFamily, containerFamily)
    itemFamily = itemFamily or 0
    containerFamily = containerFamily or 0

    if containerFamily == 0 then
        return true
    end

    if itemFamily == 0 then
        return false
    end

    if bit and bit.band then
        return bit.band(itemFamily, containerFamily) ~= 0
    end

    return itemFamily == containerFamily
end

local function GetCursorItemFamily(itemLink)
    if itemLink and GetItemFamily then
        return GetItemFamily(itemLink) or 0
    end

    return 0
end

local function GetItemMaxStackSize(itemID, itemLink)
    local itemInfo = itemLink or itemID
    if not itemInfo then
        return nil
    end

    local stackSize
    if C_Item and C_Item.GetItemMaxStackSizeByID then
        stackSize = C_Item.GetItemMaxStackSizeByID(itemInfo)
    end

    if (type(stackSize) ~= "number" or stackSize <= 0) and C_Item and C_Item.GetItemInfo then
        stackSize = select(8, C_Item.GetItemInfo(itemInfo))
    end

    if (type(stackSize) ~= "number" or stackSize <= 0) and GetItemInfo then
        stackSize = select(8, GetItemInfo(itemInfo))
    end

    if type(stackSize) == "number" and stackSize > 1 then
        return stackSize
    end

    return nil
end

local function GetPlayerContainerIDs()
    local containerIDs = { BACKPACK_ID }
    local normalBagSlots = NUM_BAG_SLOTS or 4

    for containerID = 1, normalBagSlots do
        if GetContainerNumSlots(containerID) > 0 then
            containerIDs[#containerIDs + 1] = containerID
        end
    end

    local firstReagentBagID = Containers.GetFirstReagentBagID()
    for containerID = firstReagentBagID, firstReagentBagID + (NUM_REAGENTBAG_SLOTS or 0) - 1 do
        if GetContainerNumSlots(containerID) > 0 then
            containerIDs[#containerIDs + 1] = containerID
        end
    end

    return containerIDs
end

local function IsDestinationAllowed(containerID, excludedContainerID, itemFamily)
    if containerID == excludedContainerID then
        return false
    end

    return IsFamilyCompatible(itemFamily, GetContainerFamily(containerID))
end

local function CanMergeCursorIntoStack(info, cursorItemID, cursorItemLink, maxStackSize)
    if not info or info.isLocked or info.itemID ~= cursorItemID then
        return false
    end

    if cursorItemLink and info.hyperlink and info.hyperlink ~= cursorItemLink then
        return false
    end

    local stackCount = info.stackCount or 0
    return maxStackSize and stackCount > 0 and stackCount < maxStackSize
end

local function TryCursorIntoMatchingStacks(containerIDs, cursorItemID, cursorItemLink, itemFamily, excludedContainerID)
    local maxStackSize = GetItemMaxStackSize(cursorItemID, cursorItemLink)
    if not maxStackSize then
        return false
    end

    for _, containerID in ipairs(containerIDs) do
        if IsDestinationAllowed(containerID, excludedContainerID, itemFamily) then
            for slotIndex = 1, GetContainerNumSlots(containerID) do
                local info = GetContainerItemInfo(containerID, slotIndex)
                if CanMergeCursorIntoStack(info, cursorItemID, cursorItemLink, maxStackSize) then
                    PickupContainerItem(containerID, slotIndex)
                    if not CursorHasItem() then
                        return true
                    end
                end
            end
        end
    end

    return not CursorHasItem()
end

local function TryCursorIntoEmptySlots(containerIDs, itemFamily, excludedContainerID)
    for _, containerID in ipairs(containerIDs) do
        if IsDestinationAllowed(containerID, excludedContainerID, itemFamily) then
            for slotIndex = 1, GetContainerNumSlots(containerID) do
                if not GetContainerItemInfo(containerID, slotIndex) then
                    PickupContainerItem(containerID, slotIndex)
                    if not CursorHasItem() then
                        return true
                    end
                end
            end
        end
    end

    return not CursorHasItem()
end

local function GetBagSlotIcon(containerID, inventoryID)
    if containerID == BACKPACK_ID then
        return BACKPACK_ICON
    end

    local icon = inventoryID and GetInventoryItemTexture and GetInventoryItemTexture("player", inventoryID)
    if icon then
        return icon
    end

    return Containers.GetContainerIcon(containerID) or UNKNOWN_ITEM_ICON
end

-- Empty-bag operation state
local function IsReagentBagContainer(containerID)
    local firstReagentBagID = Containers.GetFirstReagentBagID()
    return containerID >= firstReagentBagID
end

local function GetNow()
    return GetTime and GetTime() or 0
end

local function CreateSlotSnapshot(containerID, slotIndex, info)
    info = info or GetContainerItemInfo(containerID, slotIndex)

    return {
        containerID = containerID,
        slotIndex = slotIndex,
        itemID = info and info.itemID,
        hyperlink = info and info.hyperlink,
        stackCount = info and info.stackCount,
        startedAt = GetNow(),
    }
end

local function HasSlotChanged(snapshot)
    local info = GetContainerItemInfo(snapshot.containerID, snapshot.slotIndex)
    if not info then
        return true
    end

    if snapshot.itemID and info.itemID ~= snapshot.itemID then
        return true
    end

    if snapshot.hyperlink and info.hyperlink ~= snapshot.hyperlink then
        return true
    end

    if snapshot.stackCount and info.stackCount ~= snapshot.stackCount then
        return true
    end

    return false
end

local function IsSlotLocked(snapshot)
    local info = GetContainerItemInfo(snapshot.containerID, snapshot.slotIndex)
    return info and info.isLocked
end

local function FindNextMovableSlot(containerID)
    local numSlots = GetContainerNumSlots(containerID)
    local hasLockedItem = false

    for slotIndex = 1, numSlots do
        local info = GetContainerItemInfo(containerID, slotIndex)
        if info then
            if info.isLocked then
                hasLockedItem = true
            else
                return slotIndex
            end
        end
    end

    return nil, hasLockedItem
end

local function FinishEmptyBagOperation(success, message)
    emptyBagOperation = nil

    NS.Inventory:ScheduleScan(success and "empty-bag-complete" or "empty-bag-failed")

    if not success and message then
        AddError(message)
    end
end

local function ScheduleEmptyBagStep(delay)
    if not emptyBagOperation or emptyBagOperation.scheduled then
        return
    end

    emptyBagOperation.scheduled = true

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or EMPTY_BAG_STEP_DELAY, function()
            if not emptyBagOperation then
                return
            end

            emptyBagOperation.scheduled = false
            BagManagement.ContinueEmptyBag()
        end)
    else
        emptyBagOperation.scheduled = false
        BagManagement.ContinueEmptyBag()
    end
end

local function ScheduleMoveConfirmationCheck(delay)
    if not emptyBagOperation or not emptyBagOperation.waitingForMove then
        return
    end

    local token = emptyBagOperation.waitingForMove.token
    if emptyBagOperation.confirmScheduledToken == token then
        return
    end

    emptyBagOperation.confirmScheduledToken = token

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or EMPTY_BAG_MOVE_WAIT_POLL_DELAY, function()
            if not emptyBagOperation or emptyBagOperation.confirmScheduledToken ~= token then
                return
            end

            emptyBagOperation.confirmScheduledToken = nil
            BagManagement.CheckEmptyBagMove()
        end)
    else
        emptyBagOperation.confirmScheduledToken = nil
        BagManagement.CheckEmptyBagMove()
    end
end

local function WaitForSlotMove(snapshot)
    emptyBagOperation.waitToken = (emptyBagOperation.waitToken or 0) + 1
    snapshot.token = emptyBagOperation.waitToken
    emptyBagOperation.waitingForMove = snapshot
    ScheduleMoveConfirmationCheck(EMPTY_BAG_MOVE_WAIT_POLL_DELAY)
end

local function TrackPickupFailure(containerID, slotIndex)
    local failures = emptyBagOperation.pickupFailures
    failures[containerID] = failures[containerID] or {}
    failures[containerID][slotIndex] = (failures[containerID][slotIndex] or 0) + 1
    return failures[containerID][slotIndex]
end

local function OnBagStateChanged(_, bagID)
    if not emptyBagOperation then
        return
    end

    local waiting = emptyBagOperation.waitingForMove
    if not waiting or not bagID or bagID == waiting.containerID or bagID == emptyBagOperation.containerID then
        BagManagement.CheckEmptyBagMove()
    end
end

-- Public bag interaction contract
function BagManagement.GetBagSlots()
    local slots = {}
    local normalBagSlots = NUM_BAG_SLOTS or 4

    slots[#slots + 1] = {
        containerID = BACKPACK_ID,
        inventoryID = nil,
        isBackpack = true,
        isReagentBag = false,
        isEquipped = true,
        icon = GetBagSlotIcon(BACKPACK_ID),
        numSlots = GetContainerNumSlots(BACKPACK_ID),
        name = Containers.GetContainerName(BACKPACK_ID),
    }

    for containerID = 1, normalBagSlots do
        local inventoryID = Containers.GetContainerInventoryID(containerID)
        slots[#slots + 1] = {
            containerID = containerID,
            inventoryID = inventoryID,
            isBackpack = false,
            isReagentBag = false,
            isEquipped = inventoryID and GetInventoryItemTexture and GetInventoryItemTexture("player", inventoryID) ~= nil,
            icon = GetBagSlotIcon(containerID, inventoryID),
            numSlots = GetContainerNumSlots(containerID),
            name = Containers.GetContainerName(containerID),
        }
    end

    local firstReagentBagID = Containers.GetFirstReagentBagID()
    for containerID = firstReagentBagID, firstReagentBagID + (NUM_REAGENTBAG_SLOTS or 0) - 1 do
        local inventoryID = Containers.GetContainerInventoryID(containerID)
        slots[#slots + 1] = {
            containerID = containerID,
            inventoryID = inventoryID,
            isBackpack = false,
            isReagentBag = true,
            isEquipped = inventoryID and GetInventoryItemTexture and GetInventoryItemTexture("player", inventoryID) ~= nil,
            icon = GetBagSlotIcon(containerID, inventoryID),
            numSlots = GetContainerNumSlots(containerID),
            name = Containers.GetContainerName(containerID),
        }
    end

    return slots
end

function BagManagement.PickupBag(containerID)
    local inventoryID = Containers.GetContainerInventoryID(containerID)
    if not inventoryID then
        return false
    end

    if GetInventoryItemTexture and not GetInventoryItemTexture("player", inventoryID) then
        return false
    end

    BagManagement.cursorSourceContainerID = containerID

    if PickupBagFromSlot then
        PickupBagFromSlot(inventoryID)
        return true
    elseif PickupInventoryItem then
        PickupInventoryItem(inventoryID)
        return true
    end

    return false
end

function BagManagement.PutCursorInBagSlot(containerID)
    local inventoryID = Containers.GetContainerInventoryID(containerID)
    if not inventoryID or not PutItemInBag then
        return false
    end

    local placed = PutItemInBag(inventoryID)
    if placed then
        BagManagement.cursorSourceContainerID = nil
    end

    return placed
end

function BagManagement.HandleBagButtonClick(containerID)
    if CursorHasItem and CursorHasItem() then
        return BagManagement.PutCursorInBagSlot(containerID)
    end

    return BagManagement.PickupBag(containerID)
end

function BagManagement.PlaceCursorItemInInventory(excludedContainerID, suppressError)
    local cursorType, cursorItemID, cursorItemLink = GetCursorInfo()
    if cursorType ~= "item" or not CursorHasItem or not CursorHasItem() then
        if not suppressError then
            AddError(ERROR_NO_CURSOR_ITEM)
        end
        return false
    end

    excludedContainerID = excludedContainerID or BagManagement.cursorSourceContainerID

    local itemFamily = GetCursorItemFamily(cursorItemLink)
    local containerIDs = GetPlayerContainerIDs()

    if TryCursorIntoMatchingStacks(containerIDs, cursorItemID, cursorItemLink, itemFamily, excludedContainerID) then
        BagManagement.cursorSourceContainerID = nil
        return true
    end

    if TryCursorIntoEmptySlots(containerIDs, itemFamily, excludedContainerID) then
        BagManagement.cursorSourceContainerID = nil
        return true
    end

    if not suppressError then
        AddError(ERROR_NO_COMPATIBLE_SLOT)
    end
    return false
end

function BagManagement.EmptyBag(containerID)
    if CursorHasItem and CursorHasItem() then
        AddError(ERROR_CURSOR_BUSY)
        return false
    end

    if emptyBagOperation then
        AddError(ERROR_EMPTY_IN_PROGRESS)
        return false
    end

    local numSlots = GetContainerNumSlots(containerID)
    if numSlots <= 0 then
        return true
    end

    emptyBagOperation = {
        containerID = containerID,
        pickupFailures = {},
    }

    ScheduleEmptyBagStep(0)
    return true
end

function BagManagement.CheckEmptyBagMove()
    if not emptyBagOperation or not emptyBagOperation.waitingForMove then
        return
    end

    local waiting = emptyBagOperation.waitingForMove
    if HasSlotChanged(waiting) then
        emptyBagOperation.waitingForMove = nil
        emptyBagOperation.confirmScheduledToken = nil
        emptyBagOperation.pickupFailures = {}
        ScheduleEmptyBagStep(EMPTY_BAG_STEP_DELAY)
        return
    end

    if GetNow() - waiting.startedAt >= EMPTY_BAG_MOVE_WAIT_TIMEOUT then
        FinishEmptyBagOperation(false, ERROR_EMPTY_FAILED)
        return
    end

    ScheduleMoveConfirmationCheck(IsSlotLocked(waiting) and EMPTY_BAG_LOCKED_RETRY_DELAY or EMPTY_BAG_MOVE_WAIT_POLL_DELAY)
end

function BagManagement.ContinueEmptyBag()
    if not emptyBagOperation then
        return
    end

    if emptyBagOperation.waitingForMove then
        BagManagement.CheckEmptyBagMove()
        return
    end

    local containerID = emptyBagOperation.containerID

    if CursorHasItem and CursorHasItem() then
        if BagManagement.PlaceCursorItemInInventory(containerID, true) then
            ScheduleEmptyBagStep(EMPTY_BAG_STEP_DELAY)
        else
            FinishEmptyBagOperation(false, ERROR_EMPTY_FAILED)
        end
        return
    end

    local slotIndex, hasLockedItem = FindNextMovableSlot(containerID)
    if not slotIndex then
        if hasLockedItem then
            ScheduleEmptyBagStep(EMPTY_BAG_LOCKED_RETRY_DELAY)
        else
            FinishEmptyBagOperation(true)
        end
        return
    end

    local sourceInfo = GetContainerItemInfo(containerID, slotIndex)
    local sourceSnapshot = CreateSlotSnapshot(containerID, slotIndex, sourceInfo)

    PickupContainerItem(containerID, slotIndex)
    if CursorHasItem and CursorHasItem() then
        if BagManagement.PlaceCursorItemInInventory(containerID, true) then
            WaitForSlotMove(sourceSnapshot)
        else
            PickupContainerItem(containerID, slotIndex)
            FinishEmptyBagOperation(false, ERROR_EMPTY_FAILED)
        end
    else
        if IsSlotLocked(sourceSnapshot) then
            ScheduleEmptyBagStep(EMPTY_BAG_LOCKED_RETRY_DELAY)
        elseif TrackPickupFailure(containerID, slotIndex) >= 3 then
            FinishEmptyBagOperation(false, ERROR_EMPTY_FAILED)
        else
            ScheduleEmptyBagStep(EMPTY_BAG_LOCKED_RETRY_DELAY)
        end
    end
end

function BagManagement.CleanupBags()
    if C_Container and C_Container.SortBags then
        C_Container.SortBags()
    elseif SortBags then
        SortBags()
    end
end

function BagManagement.IsReagentBag(containerID)
    return IsReagentBagContainer(containerID)
end

NS:RegisterInitCallback(function()
    NS:RegisterEventHandler("BAG_UPDATE", OnBagStateChanged)
    NS:RegisterEventHandler("BAG_UPDATE_DELAYED", OnBagStateChanged)
    NS:RegisterEventHandler("ITEM_LOCK_CHANGED", OnBagStateChanged)
end)

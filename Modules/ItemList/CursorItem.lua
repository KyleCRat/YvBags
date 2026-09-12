local _, NS = ...

-- Transient native cursor-action provenance and read-only stack matching.
local CursorItem = {}
NS.CursorItem = CursorItem

local ACTION_PICKUP = "pickup"
local ACTION_SPLIT = "split"

local currentItem
local revision = 0

local function ClearItem()
    if currentItem then
        currentItem = nil
        revision = revision + 1
    end
end

function CursorItem.Get()
    local cursorType, itemID, itemLink = GetCursorInfo()
    if issecretvalue(cursorType)
        or issecretvalue(itemID)
        or issecretvalue(itemLink)
        or cursorType ~= "item" then
        ClearItem()
        return nil, revision
    end

    local location = C_Cursor.GetCursorItem()
    local bagID, slotIndex
    if location then
        bagID, slotIndex = location:GetBagAndSlot()
    end
    if issecretvalue(bagID) or issecretvalue(slotIndex) then
        ClearItem()
        return nil, revision
    end

    if not currentItem
        or currentItem.itemID ~= itemID
        or currentItem.link ~= itemLink
        or currentItem.bagID ~= bagID
        or currentItem.slotIndex ~= slotIndex then
        currentItem = {
            itemID = itemID,
            link = itemLink,
            bagID = bagID,
            slotIndex = slotIndex,
            location = location,
        }
        revision = revision + 1
    end

    return currentItem, revision
end

local function RecordAction(bagID, slotIndex, action)
    if issecretvalue(bagID) or issecretvalue(slotIndex) then
        return
    end

    local item = CursorItem.Get()
    if not item or item.bagID ~= bagID or item.slotIndex ~= slotIndex then
        return
    end

    -- A failed placement or partial merge must not reinterpret a held split.
    if action == ACTION_SPLIT or not item.action then
        item.action = action
        revision = revision + 1
    end
end

local function OnPickup(bagID, slotIndex)
    RecordAction(bagID, slotIndex, ACTION_PICKUP)
end

local function OnSplit(bagID, slotIndex)
    RecordAction(bagID, slotIndex, ACTION_SPLIT)
end

local function OnCursorChanged()
    CursorItem.Get()
    -- Count changes can leave the item link and source location unchanged.
    revision = revision + 1
end

local function GetMergeItem(item)
    if InCombatLockdown() then
        return nil
    end

    if not item or item.action ~= ACTION_PICKUP
        or type(item.link) ~= "string"
        or not item.bagID or not item.slotIndex then
        return nil
    end

    if not item.mergeInfoLoaded then
        local location = item.location
        if not location or not location:IsValid() then
            return nil
        end

        local maxStack = C_Item.GetItemMaxStackSizeByID(item.link)
        if issecretvalue(maxStack) or type(maxStack) ~= "number" then
            return nil
        end
        local isBound = C_Item.IsBound(location)
        local canBeRefunded = C_Item.CanBeRefunded(location)
        if issecretvalue(isBound) or issecretvalue(canBeRefunded) then
            return nil
        end

        item.maxStack = maxStack
        item.isBound = isBound
        item.canBeRefunded = canBeRefunded
        item.mergeInfoLoaded = true
    end

    -- Refundable items retain the existing native placement/confirmation path.
    if item.maxStack <= 1 or item.canBeRefunded then
        return nil
    end
    return item
end

function CursorItem.CanMerge(cursor)
    return GetMergeItem(cursor) ~= nil
end

local function MatchesStack(cursor, itemID, link, count, isLocked, isBound)
    if issecretvalue(itemID) or issecretvalue(link)
        or issecretvalue(count) or issecretvalue(isLocked)
        or issecretvalue(isBound) then
        return false
    end

    return itemID == cursor.itemID and link == cursor.link
        and isLocked == false and isBound == cursor.isBound
        and type(count) == "number" and count > 0 and count < cursor.maxStack
end

local function GetMergeSlotInfo(cursor, bagID, slotIndex, targetLocation)
    if bagID == cursor.bagID and slotIndex == cursor.slotIndex then
        return nil
    end

    local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
    if not info or not MatchesStack(
        cursor, info.itemID, info.hyperlink, info.stackCount,
        info.isLocked, info.isBound
    ) then
        return nil
    end

    if not targetLocation:IsEqualToBagAndSlot(bagID, slotIndex) then
        targetLocation:SetBagAndSlot(bagID, slotIndex)
    end

    local canBeRefunded = C_Item.CanBeRefunded(targetLocation)
    if issecretvalue(canBeRefunded) or canBeRefunded then
        return nil
    end
    return info
end

function CursorItem.GetMergeSlotInfo(cursor, bagID, slotIndex, targetLocation)
    cursor = GetMergeItem(cursor)
    if cursor then
        return GetMergeSlotInfo(cursor, bagID, slotIndex, targetLocation)
    end
end

function CursorItem.FindMergeSlot(cursor, items, targetLocation, excludedBagID)
    cursor = GetMergeItem(cursor)
    if not cursor then
        return nil
    end

    -- Search the normalized inventory once per invalidation, not per hover.
    -- Recheck only candidate slots against live data before binding a button.
    for index = 1, #items do
        local item = items[index]
        if item.bagID ~= excludedBagID and MatchesStack(
            cursor, item.itemID, item.link, item.count,
            item.isLocked, item.isBound
        ) then
            local info = GetMergeSlotInfo(
                cursor, item.bagID, item.slotIndex, targetLocation
            )
            if info then
                return item.bagID, item.slotIndex, info
            end
        end
    end
end

NS:RegisterInitCallback(function()
    -- Post-hooks observe Blizzard's actions; never replace or invoke them.
    -- Keep this state off native buttons and the shared StackSplitFrame.
    hooksecurefunc(C_Container, "PickupContainerItem", OnPickup)
    hooksecurefunc(C_Container, "SplitContainerItem", OnSplit)
    NS:RegisterEventHandler("CURSOR_CHANGED", OnCursorChanged)
end)

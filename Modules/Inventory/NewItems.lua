local _, NS = ...

-- Transient per-open new-item placement backed by Blizzard's native state.
local NewItems = {}
NS.NewItems = NewItems

-- Bridge separate source/destination bag events without suppressing later loot.
local MOVE_DISMISS_WINDOW_SECONDS = 5

local sessionEntries = {}
local dismissedGUIDs = {}
local guidByLocation = {}
local staleLocations = {}
local sessionActive = false

local function ClearItemState(item)
    item.isNewThisSession = false
    item.isNewUnseen = false
    item.newItemGUID = nil
end

local function GetItemGUID(item)
    local locationKey = item.locationKey
    local itemGUID = guidByLocation[locationKey]
    if itemGUID then
        return itemGUID
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(item.bagID, item.slotIndex)
    if not itemLocation:IsValid() then
        return nil
    end

    itemGUID = C_Item.GetItemGUID(itemLocation)
    guidByLocation[locationKey] = itemGUID
    return itemGUID
end

local function RemoveStaleEntries(itemsByLocation, now)
    wipe(staleLocations)

    for locationKey, entry in pairs(sessionEntries) do
        local item = itemsByLocation[locationKey]
        local itemGUID = item and GetItemGUID(item) or nil
        if not item or (itemGUID and itemGUID ~= entry.itemGUID) then
            dismissedGUIDs[entry.itemGUID] = now + MOVE_DISMISS_WINDOW_SECONDS
            staleLocations[#staleLocations + 1] = locationKey
        end
    end

    for _, locationKey in ipairs(staleLocations) do
        sessionEntries[locationKey] = nil
    end

    return #staleLocations > 0
end

function NewItems.IsSessionActive()
    return sessionActive
end

function NewItems.Reconcile(items, itemsByLocation)
    if not sessionActive then
        return false, false
    end

    wipe(guidByLocation)

    local now = GetTime()
    for itemGUID, expiresAt in pairs(dismissedGUIDs) do
        if expiresAt < now then
            dismissedGUIDs[itemGUID] = nil
        end
    end

    for _, item in ipairs(items) do
        ClearItemState(item)
    end

    local placementChanged = RemoveStaleEntries(itemsByLocation, now)
    local visualsChanged = false

    for _, item in ipairs(items) do
        local locationKey = item.locationKey
        local entry = sessionEntries[locationKey]
        local isNativeNew = C_NewItems.IsNewItem(item.bagID, item.slotIndex)

        if entry then
            item.isNewThisSession = true
            item.isNewUnseen = isNativeNew
            item.newItemGUID = entry.itemGUID

            if entry.isUnseen ~= isNativeNew then
                entry.isUnseen = isNativeNew
                visualsChanged = true
            end
        elseif isNativeNew then
            local itemGUID = GetItemGUID(item)
            if itemGUID then
                if dismissedGUIDs[itemGUID] then
                    C_NewItems.RemoveNewItem(item.bagID, item.slotIndex)
                    dismissedGUIDs[itemGUID] = nil
                else
                    sessionEntries[locationKey] = {
                        itemGUID = itemGUID,
                        isUnseen = true,
                    }
                    item.isNewThisSession = true
                    item.isNewUnseen = true
                    item.newItemGUID = itemGUID
                    placementChanged = true
                end
            end
        end
    end

    return placementChanged, visualsChanged
end

function NewItems.BeginSession(items, itemsByLocation)
    wipe(sessionEntries)
    wipe(dismissedGUIDs)
    sessionActive = true
    NewItems.Reconcile(items, itemsByLocation)
end

function NewItems.EndSession(items)
    sessionActive = false
    wipe(sessionEntries)
    wipe(dismissedGUIDs)
    wipe(guidByLocation)
    wipe(staleLocations)

    for _, item in ipairs(items) do
        ClearItemState(item)
    end
end

function NewItems.MarkSeen(item)
    if not sessionActive or not item.isNewUnseen then
        return false
    end

    local entry = sessionEntries[item.locationKey]
    if not entry or entry.itemGUID ~= item.newItemGUID then
        return false
    end

    entry.isUnseen = false
    item.isNewUnseen = false
    C_NewItems.RemoveNewItem(item.bagID, item.slotIndex)
    return true
end

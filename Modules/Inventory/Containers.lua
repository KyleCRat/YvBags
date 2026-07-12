local _, NS = ...

-- Player-container discovery, metadata, and physical location helpers.
local Containers = {}
NS.Containers = Containers

local BACKPACK_ID = BACKPACK_CONTAINER or 0
local UNKNOWN_ITEM_ICON = 134400

-- Small table helpers
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

-- Location helpers
function Containers.MakeLocationKey(bagID, slotIndex)
    return ("%d:%d"):format(bagID, slotIndex)
end

function Containers.GetFirstReagentBagID()
    return (NUM_BAG_SLOTS or 4) + 1
end

function Containers.IsPlayerContainerID(containerID)
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
    local firstReagentBagID = Containers.GetFirstReagentBagID()
    return reagentBagSlots > 0 and containerID >= firstReagentBagID and containerID < firstReagentBagID + reagentBagSlots
end

-- Container metadata helpers
function Containers.GetContainerInventoryID(containerID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        return C_Container.ContainerIDToInventoryID(containerID)
    end

    if ContainerIDToInventoryID then
        return ContainerIDToInventoryID(containerID)
    end

    return nil
end

function Containers.GetContainerName(containerID)
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

function Containers.GetContainerIcon(containerID)
    if containerID == BACKPACK_ID then
        return "Interface\\Buttons\\Button-Backpack-Up"
    end

    local inventoryID = Containers.GetContainerInventoryID(containerID)
    if inventoryID then
        local icon = GetInventoryItemTexture("player", inventoryID)
        if icon then
            return icon
        end
    end

    return UNKNOWN_ITEM_ICON
end

function Containers.GetContainerNumSlots(containerID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(containerID) or 0
    end

    return 0
end

function Containers.GetContainerFreeSlotData(containerID)
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

function Containers.GetContainerKind(containerID)
    if containerID == BACKPACK_ID then
        return "backpack"
    end

    if containerID >= Containers.GetFirstReagentBagID() then
        return "reagentBag"
    end

    return "bag"
end

-- Container record builders
function Containers.CreateEmptySlot(container, slotIndex)
    return {
        bagID = container.id,
        slotIndex = slotIndex,
        locationKey = Containers.MakeLocationKey(container.id, slotIndex),
        containerKind = container.kind,
        containerName = container.name,
    }
end

function Containers.CreateContainer(containerID)
    local numSlots = Containers.GetContainerNumSlots(containerID)
    if containerID ~= BACKPACK_ID and numSlots <= 0 then
        return nil
    end

    local freeSlots, freeSlotCount, bagFamily = Containers.GetContainerFreeSlotData(containerID)
    return {
        id = containerID,
        kind = Containers.GetContainerKind(containerID),
        name = Containers.GetContainerName(containerID),
        icon = Containers.GetContainerIcon(containerID),
        inventoryID = Containers.GetContainerInventoryID(containerID),
        numSlots = numSlots,
        freeSlots = freeSlots,
        freeSlotCount = freeSlotCount or 0,
        bagFamily = bagFamily,
        usedSlots = 0,
        emptySlotCount = 0,
        emptySlots = {},
    }
end

function Containers.DiscoverPlayerContainers()
    local containers = {}
    local containerByID = {}

    local function AddContainer(containerID)
        local container = Containers.CreateContainer(containerID)
        if not container then
            return
        end

        containers[#containers + 1] = container
        containerByID[containerID] = container
    end

    AddContainer(BACKPACK_ID)

    for containerID = 1, NUM_BAG_SLOTS or 4 do
        AddContainer(containerID)
    end

    local firstReagentBagID = Containers.GetFirstReagentBagID()
    for containerID = firstReagentBagID, firstReagentBagID + (NUM_REAGENTBAG_SLOTS or 0) - 1 do
        AddContainer(containerID)
    end

    return containers, containerByID
end

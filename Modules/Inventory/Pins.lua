local _, NS = ...

-- Account-wide pin state and stable item pin identities.
local Pins = {}
NS.ItemPins = Pins

local DB_SECTION = "pins"
local DB_ITEMS_KEY = "items"
local ITEM_PIN_PREFIX = "item:"
local KEYSTONE_PIN_KEY = "kind:keystone"

Pins.DisplayModes = {
    Top = "top",
    Group = "group",
    TopOfGroups = "topOfGroups",
    Normal = "normal",
}

local VALID_DISPLAY_MODES = {
    [Pins.DisplayModes.Top] = true,
    [Pins.DisplayModes.Group] = true,
    [Pins.DisplayModes.TopOfGroups] = true,
    [Pins.DisplayModes.Normal] = true,
}

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function GetItemIDPinKey(itemID)
    if IsSecretValue(itemID) or type(itemID) ~= "number" then
        return nil
    end

    return ITEM_PIN_PREFIX .. tostring(itemID)
end

function Pins.GetKey(item)
    if IsSecretValue(item) or type(item) ~= "table" then
        return nil
    end

    if item.isKeystone then
        return KEYSTONE_PIN_KEY
    end

    return GetItemIDPinKey(item.itemID)
end

function Pins.IsPinned(item)
    local pinKey = Pins.GetKey(item)
    return pinKey ~= nil and NS.globalDB:Get(DB_SECTION, DB_ITEMS_KEY, pinKey) == true
end

function Pins.Toggle(item)
    local pinKey = Pins.GetKey(item)
    if not pinKey then
        return nil, nil
    end

    local isPinned = NS.globalDB:Get(DB_SECTION, DB_ITEMS_KEY, pinKey) ~= true
    if isPinned then
        NS.globalDB:Set(DB_SECTION, DB_ITEMS_KEY, pinKey, true)
    else
        NS.globalDB:Delete(DB_SECTION, DB_ITEMS_KEY, pinKey)
    end

    return isPinned, pinKey
end

function Pins.NormalizeDisplayMode(displayMode)
    if VALID_DISPLAY_MODES[displayMode] then
        return displayMode
    end

    return NS.defaults.profile.pins.displayMode
end

function Pins.GetDisplayMode()
    return Pins.NormalizeDisplayMode(NS.db:Get(DB_SECTION, "displayMode"))
end

function Pins.SetDisplayMode(displayMode)
    displayMode = Pins.NormalizeDisplayMode(displayMode)
    NS.db:Set(DB_SECTION, "displayMode", displayMode)
    return displayMode
end

local _, NS = ...

local ListModel = {}
NS.ItemListModel = ListModel

local Categories = NS.Categories

local ROW_TYPE_ITEM = "item"
local ROW_TYPE_GROUP = "group"
local NO_GROUP_KEY = "none"
local NO_SECONDARY_SORT_KEY = "none"
local DEFAULT_SORT_KEY = "name"
local DEFAULT_GROUP_KEY = "category"

local SORT_KEY_LIST = {
    "name",
    "quality",
    "itemLevel",
    "requiredLevel",
    "quantity",
    "type",
    "sellValue",
    "location",
    "expansion",
    "professionQuality",
    "binding",
    "category",
}

local SECONDARY_SORT_KEY_LIST = {
    NO_SECONDARY_SORT_KEY,
    "name",
    "quality",
    "itemLevel",
    "requiredLevel",
    "quantity",
    "type",
    "sellValue",
    "location",
    "expansion",
    "professionQuality",
    "binding",
    "category",
}

local GROUP_KEY_LIST = {
    NO_GROUP_KEY,
    "category",
    "type",
    "inventorySlot",
    "quality",
    "binding",
    "expansion",
}

local GROUP_KEY_LABELS = {
    none = "No Grouping",
    category = "Category",
    type = "Item Type",
    inventorySlot = "Inventory Slot",
    quality = "Rarity",
    binding = "Binding",
    expansion = "Expansion",
}

local VALID_SORT_KEYS = {
    name = true,
    quality = true,
    itemLevel = true,
    requiredLevel = true,
    quantity = true,
    type = true,
    sellValue = true,
    location = true,
    expansion = true,
    professionQuality = true,
    binding = true,
    category = true,
}

local VALID_SECONDARY_SORT_KEYS = {
    none = true,
    name = true,
    quality = true,
    itemLevel = true,
    requiredLevel = true,
    quantity = true,
    type = true,
    sellValue = true,
    location = true,
    expansion = true,
    professionQuality = true,
    binding = true,
    category = true,
}

local VALID_GROUP_KEYS = {
    none = true,
    category = true,
    type = true,
    inventorySlot = true,
    quality = true,
    binding = true,
    expansion = true,
}

local SORT_KEY_ALIASES = {
    none = NO_SECONDARY_SORT_KEY,
    off = NO_SECONDARY_SORT_KEY,
    disabled = NO_SECONDARY_SORT_KEY,
    count = "quantity",
    qty = "quantity",
    ilvl = "itemLevel",
    itemlevel = "itemLevel",
    req = "requiredLevel",
    required = "requiredLevel",
    requiredlevel = "requiredLevel",
    sell = "sellValue",
    sellprice = "sellValue",
    sellvalue = "sellValue",
    bag = "location",
    slot = "location",
    bagslot = "location",
    exp = "expansion",
    rarity = "quality",
    prof = "professionQuality",
    profession = "professionQuality",
    professionquality = "professionQuality",
}

local GROUP_KEY_ALIASES = {
    off = NO_GROUP_KEY,
    disabled = NO_GROUP_KEY,
    category = "category",
    categories = "category",
    type = "type",
    itemtype = "type",
    slot = "inventorySlot",
    inventory = "inventorySlot",
    inventoryslot = "inventorySlot",
    quality = "quality",
    binding = "binding",
    bind = "binding",
    expansion = "expansion",
    exp = "expansion",
}

local function Lower(value)
    return strlower(tostring(value or ""))
end

local function NumberValue(value, fallback)
    if type(value) == "number" then
        return value
    end

    return fallback or 0
end

local function TextValue(value)
    return Lower(value or "")
end

local function GetQualityName(quality)
    if quality == nil then
        return UNKNOWN or "Unknown"
    end

    return _G["ITEM_QUALITY" .. tostring(quality) .. "_DESC"] or ("Quality " .. tostring(quality))
end

local function GetExpansionName(expansionID)
    if expansionID == nil then
        return UNKNOWN or "Unknown"
    end

    if GetExpansionDisplayInfo then
        local expansionInfo = GetExpansionDisplayInfo(expansionID)
        if type(expansionInfo) == "table" and expansionInfo.name then
            return expansionInfo.name
        elseif type(expansionInfo) == "string" then
            return expansionInfo
        end
    end

    return "Expansion " .. tostring(expansionID)
end

local function GetInventorySlotName(equipLoc)
    if not equipLoc or equipLoc == "" then
        return "Other"
    end

    return _G[equipLoc] or equipLoc
end

local function GetTypeText(item)
    if item.type and item.subtype and item.subtype ~= "" and item.subtype ~= item.type then
        return item.type .. " / " .. item.subtype
    end

    return item.type or item.subtype or ""
end

local function GetSortValue(item, sortKey)
    if sortKey == "name" then
        return TextValue(item.name)
    elseif sortKey == "quality" then
        return NumberValue(item.quality, -1)
    elseif sortKey == "itemLevel" then
        return NumberValue(item.itemLevel, -1)
    elseif sortKey == "requiredLevel" then
        return NumberValue(item.requiredLevel, -1)
    elseif sortKey == "quantity" then
        return NumberValue(item.count, 0)
    elseif sortKey == "type" then
        return TextValue(GetTypeText(item))
    elseif sortKey == "sellValue" then
        return NumberValue(item.totalSellValue or item.sellValue, 0)
    elseif sortKey == "expansion" then
        return NumberValue(item.expansionID, -1)
    elseif sortKey == "professionQuality" then
        return NumberValue(item.professionQuality, -1)
    elseif sortKey == "binding" then
        return TextValue(item.bindingText or item.bindingKey)
    elseif sortKey == "category" then
        return TextValue(item.categoryName or item.categoryKey)
    end

    return TextValue(item.name)
end

local function CompareLocation(left, right)
    local leftBag = NumberValue(left.bagID, 0)
    local rightBag = NumberValue(right.bagID, 0)
    if leftBag ~= rightBag then
        return leftBag < rightBag
    end

    return NumberValue(left.slotIndex, 0) < NumberValue(right.slotIndex, 0)
end

local function CompareSort(left, right, sortKey, sortAscending)
    if sortKey == "location" then
        if left.bagID ~= right.bagID or left.slotIndex ~= right.slotIndex then
            if sortAscending then
                return CompareLocation(left, right)
            end

            return CompareLocation(right, left)
        end

        return nil
    end

    local leftValue = GetSortValue(left, sortKey)
    local rightValue = GetSortValue(right, sortKey)

    if leftValue ~= rightValue then
        if sortAscending then
            return leftValue < rightValue
        end

        return leftValue > rightValue
    end

    return nil
end

local function SortItems(items, sortKey, sortAscending, secondarySortKey, secondarySortAscending)
    table.sort(items, function(left, right)
        local primaryResult = CompareSort(left, right, sortKey, sortAscending)
        if primaryResult ~= nil then
            return primaryResult
        end

        if secondarySortKey and secondarySortKey ~= NO_SECONDARY_SORT_KEY and secondarySortKey ~= sortKey then
            local secondaryResult = CompareSort(left, right, secondarySortKey, secondarySortAscending)
            if secondaryResult ~= nil then
                return secondaryResult
            end
        end

        return CompareLocation(left, right)
    end)
end

local function ItemMatchesSearch(item, searchText)
    if not searchText or searchText == "" then
        return true
    end

    local fields = {
        item.name,
        item.type,
        item.subtype,
        item.categoryName,
        item.bindingText,
        item.bagSlotText,
        item.itemID,
    }

    for _, field in ipairs(fields) do
        if field and string.find(Lower(field), searchText, 1, true) then
            return true
        end
    end

    return false
end

local function GetGroupInfo(item, groupKey)
    if groupKey == "category" then
        return item.categoryKey or "other", item.categoryName or Categories.GetCategoryName(item.categoryKey)
    elseif groupKey == "type" then
        local typeKey = item.type or item.subtype or "other"
        return typeKey, typeKey
    elseif groupKey == "inventorySlot" then
        local slotKey = item.equipLoc or "other"
        return slotKey, GetInventorySlotName(item.equipLoc)
    elseif groupKey == "quality" then
        local qualityKey = tostring(item.quality or "unknown")
        return qualityKey, GetQualityName(item.quality)
    elseif groupKey == "binding" then
        local bindingKey = item.bindingKey or "unknown"
        return bindingKey, item.bindingText or bindingKey
    elseif groupKey == "expansion" then
        local expansionKey = tostring(item.expansionID or "unknown")
        return expansionKey, GetExpansionName(item.expansionID)
    end

    return NO_GROUP_KEY, ""
end

local function NormalizeKey(key, aliases, validKeys, defaultKey)
    if validKeys[key] then
        return key
    end

    key = Lower(key)
    key = aliases[key] or key

    if validKeys[key] then
        return key
    end

    return defaultKey
end

function ListModel.GetRowTypeItem()
    return ROW_TYPE_ITEM
end

function ListModel.GetRowTypeGroup()
    return ROW_TYPE_GROUP
end

function ListModel.GetSortKeyList()
    return SORT_KEY_LIST
end

function ListModel.GetSecondarySortKeyList()
    return SECONDARY_SORT_KEY_LIST
end

function ListModel.GetNoSecondarySortKey()
    return NO_SECONDARY_SORT_KEY
end

function ListModel.GetGroupKeyList()
    return GROUP_KEY_LIST
end

function ListModel.GetGroupLabel(groupKey)
    groupKey = ListModel.NormalizeGroupKey(groupKey)
    return GROUP_KEY_LABELS[groupKey] or groupKey
end

function ListModel.NormalizeSortKey(sortKey)
    return NormalizeKey(sortKey, SORT_KEY_ALIASES, VALID_SORT_KEYS, DEFAULT_SORT_KEY)
end

function ListModel.NormalizeSecondarySortKey(sortKey)
    return NormalizeKey(sortKey, SORT_KEY_ALIASES, VALID_SECONDARY_SORT_KEYS, NO_SECONDARY_SORT_KEY)
end

function ListModel.NormalizeGroupKey(groupKey)
    return NormalizeKey(groupKey, GROUP_KEY_ALIASES, VALID_GROUP_KEYS, DEFAULT_GROUP_KEY)
end

function ListModel.IsValidSortKey(sortKey)
    return NormalizeKey(sortKey, SORT_KEY_ALIASES, VALID_SORT_KEYS) ~= nil
end

function ListModel.IsValidSecondarySortKey(sortKey)
    return NormalizeKey(sortKey, SORT_KEY_ALIASES, VALID_SECONDARY_SORT_KEYS) ~= nil
end

function ListModel.IsValidGroupKey(groupKey)
    return NormalizeKey(groupKey, GROUP_KEY_ALIASES, VALID_GROUP_KEYS) ~= nil
end

function ListModel.IsGrouped(groupKey)
    return groupKey and groupKey ~= NO_GROUP_KEY
end

function ListModel.IsSecondarySortEnabled(secondarySortKey, primarySortKey)
    secondarySortKey = ListModel.NormalizeSecondarySortKey(secondarySortKey)
    primarySortKey = ListModel.NormalizeSortKey(primarySortKey)
    return secondarySortKey ~= NO_SECONDARY_SORT_KEY and secondarySortKey ~= primarySortKey
end

function ListModel.BuildRows(items, state)
    local searchText = Lower(state and state.searchText)
    local sortKey = ListModel.NormalizeSortKey(state and state.sortKey)
    local sortAscending = not (state and state.sortAscending == false)
    local secondarySortKey = ListModel.NormalizeSecondarySortKey(state and state.secondarySortKey)
    local secondarySortAscending = not (state and state.secondarySortAscending == false)
    if not ListModel.IsSecondarySortEnabled(secondarySortKey, sortKey) then
        secondarySortKey = NO_SECONDARY_SORT_KEY
    end
    local groupKey = ListModel.NormalizeGroupKey(state and state.groupKey)
    local collapsedGroups = state and state.collapsedGroups or {}
    local filteredItems = {}

    if items then
        for _, item in ipairs(items) do
            if ItemMatchesSearch(item, searchText) then
                filteredItems[#filteredItems + 1] = item
            end
        end
    end

    SortItems(filteredItems, sortKey, sortAscending, secondarySortKey, secondarySortAscending)

    if not ListModel.IsGrouped(groupKey) then
        local rows = {}
        for _, item in ipairs(filteredItems) do
            rows[#rows + 1] = {
                rowType = ROW_TYPE_ITEM,
                item = item,
            }
        end

        return rows, #filteredItems
    end

    local groupMap = {}
    local groups = {}

    for _, item in ipairs(filteredItems) do
        local key, label = GetGroupInfo(item, groupKey)
        local id = groupKey .. ":" .. tostring(key)
        local group = groupMap[id]

        if not group then
            group = {
                id = id,
                key = key,
                label = label,
                items = {},
                sortText = TextValue(label),
            }
            groupMap[id] = group
            groups[#groups + 1] = group
        end

        group.items[#group.items + 1] = item
    end

    table.sort(groups, function(left, right)
        if left.sortText ~= right.sortText then
            return left.sortText < right.sortText
        end

        return tostring(left.id) < tostring(right.id)
    end)

    local rows = {}
    for _, group in ipairs(groups) do
        local collapsed = collapsedGroups[group.id] == true
        rows[#rows + 1] = {
            rowType = ROW_TYPE_GROUP,
            groupID = group.id,
            groupKey = group.key,
            label = group.label,
            count = #group.items,
            collapsed = collapsed,
        }

        if not collapsed then
            for _, item in ipairs(group.items) do
                rows[#rows + 1] = {
                    rowType = ROW_TYPE_ITEM,
                    item = item,
                }
            end
        end
    end

    return rows, #filteredItems
end

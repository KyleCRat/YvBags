local _, NS = ...

-- Search, grouping, sorting, and display-row construction contract.
local ListModel = {}
NS.ItemListModel = ListModel

local Categories = NS.Categories
local Columns = NS.ItemListColumns
local Pins = NS.ItemPins

local ROW_TYPE_ITEM = "item"
local ROW_TYPE_GROUP = "group"
local ROW_TYPE_DIVIDER = "divider"
local NO_GROUP_KEY = "none"
local MANUAL_SORT_KEY = "manual"
local NO_SECONDARY_SORT_KEY = "none"
local DEFAULT_SORT_KEY = "name"
local DEFAULT_GROUP_KEY = "category"
local PINNED_GROUP_KEY = "pinned"
local PINNED_GROUP_ID = "pins:pinned"
local PINNED_GROUP_LABEL = "Pinned"
local PINNED_GROUP_SORT_PRIORITY = -1

local SORT_KEY_LIST = {
    MANUAL_SORT_KEY,
    "name",
    "quality",
    "itemLevel",
    "requiredLevel",
    "quantity",
    "type",
    "subtype",
    "sellValue",
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
    "subtype",
    "sellValue",
    "expansion",
    "professionQuality",
    "binding",
    "category",
}

local GROUP_KEY_LIST = {
    NO_GROUP_KEY,
    "category",
    "type",
    "quality",
    "binding",
    "expansion",
}

local GROUP_KEY_LABELS = {
    none = "No Grouping",
    category = "Category",
    type = "Item Type",
    quality = "Rarity",
    binding = "Binding",
    expansion = "Expansion",
}

local VALID_SORT_KEYS = {
    manual = true,
    name = true,
    quality = true,
    itemLevel = true,
    requiredLevel = true,
    quantity = true,
    type = true,
    subtype = true,
    sellValue = true,
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
    subtype = true,
    sellValue = true,
    expansion = true,
    professionQuality = true,
    binding = true,
    category = true,
}

local VALID_GROUP_KEYS = {
    none = true,
    category = true,
    type = true,
    quality = true,
    binding = true,
    expansion = true,
}

local PRIMARY_SORT_KEY_ALIASES = {
    none = MANUAL_SORT_KEY,
    off = MANUAL_SORT_KEY,
    disabled = MANUAL_SORT_KEY,
    manual = MANUAL_SORT_KEY,
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
    exp = "expansion",
    rarity = "quality",
    sub = "subtype",
    itemsubtype = "subtype",
    prof = "professionQuality",
    profession = "professionQuality",
    professionquality = "professionQuality",
}

local SECONDARY_SORT_KEY_ALIASES = {
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
    exp = "expansion",
    rarity = "quality",
    sub = "subtype",
    itemsubtype = "subtype",
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
    quality = "quality",
    binding = "binding",
    bind = "binding",
    expansion = "expansion",
    exp = "expansion",
}

-- Sort value normalization and comparison
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
        return UNKNOWN
    end

    return _G["ITEM_QUALITY" .. tostring(quality) .. "_DESC"]
end

local function GetExpansionName(expansionID)
    if expansionID == nil then
        return UNKNOWN
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

local function GetTypeSortText(item)
    return (item.type or "") .. "\001" .. (item.subtype or "")
end

local function GetSubtypeSortText(item)
    return (item.subtype or "") .. "\001" .. (item.type or "")
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
        return TextValue(GetTypeSortText(item))
    elseif sortKey == "subtype" then
        return TextValue(GetSubtypeSortText(item))
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

local function BuildSortValueCache(items, sortKey)
    local values = {}
    for _, item in ipairs(items) do
        values[item] = GetSortValue(item, sortKey)
    end

    return values
end

local function BuildSortPriorityCache(items, sortKey)
    if sortKey ~= "category" then
        return nil
    end

    local priorities = {}
    for _, item in ipairs(items) do
        priorities[item] = Categories.GetSortPriority(item.categoryKey)
    end

    return priorities
end

local function BuildItemIdentityCache(items)
    local names = {}
    local itemIDs = {}
    for _, item in ipairs(items) do
        names[item] = TextValue(item.name)
        itemIDs[item] = NumberValue(item.itemID, -1)
    end

    return names, itemIDs
end

local function CompareItemIdentity(left, right, names, itemIDs)
    local leftName = names[left]
    local rightName = names[right]
    if leftName ~= rightName then
        return leftName < rightName
    end

    local leftItemID = itemIDs[left]
    local rightItemID = itemIDs[right]
    if leftItemID ~= rightItemID then
        return leftItemID < rightItemID
    end

    return nil
end

local function CompareSort(left, right, values, sortAscending, priorities)
    if priorities then
        local leftPriority = priorities[left]
        local rightPriority = priorities[right]
        if leftPriority ~= rightPriority then
            return leftPriority < rightPriority
        end
    end

    local leftValue = values[left]
    local rightValue = values[right]

    if leftValue ~= rightValue then
        if sortAscending then
            return leftValue < rightValue
        end

        return leftValue > rightValue
    end

    return nil
end

local function SortItems(items, sortKey, sortAscending, secondarySortKey, secondarySortAscending)
    local primaryValues
    local secondaryValues
    local primaryPriorities
    local secondaryPriorities
    local identityNames
    local identityItemIDs
    local defaultQuantityValues
    if sortKey ~= MANUAL_SORT_KEY then
        primaryValues = BuildSortValueCache(items, sortKey)
        primaryPriorities = BuildSortPriorityCache(items, sortKey)
        identityNames, identityItemIDs = BuildItemIdentityCache(items)
        if sortKey ~= "quantity" and secondarySortKey ~= "quantity" then
            defaultQuantityValues = BuildSortValueCache(items, "quantity")
        end
        if secondarySortKey and secondarySortKey ~= NO_SECONDARY_SORT_KEY and secondarySortKey ~= sortKey then
            secondaryValues = BuildSortValueCache(items, secondarySortKey)
            secondaryPriorities = BuildSortPriorityCache(items, secondarySortKey)
        end
    end

    table.sort(items, function(left, right)
        if primaryValues then
            local primaryResult = CompareSort(left, right, primaryValues, sortAscending, primaryPriorities)
            if primaryResult ~= nil then
                return primaryResult
            end

            if secondaryValues then
                local secondaryResult = CompareSort(left, right, secondaryValues, secondarySortAscending, secondaryPriorities)
                if secondaryResult ~= nil then
                    return secondaryResult
                end
            end

            local identityResult = CompareItemIdentity(left, right, identityNames, identityItemIDs)
            if identityResult ~= nil then
                return identityResult
            end

            if defaultQuantityValues then
                local quantityResult = CompareSort(left, right, defaultQuantityValues, false)
                if quantityResult ~= nil then
                    return quantityResult
                end
            end
        end

        return CompareLocation(left, right)
    end)
end

-- Search and grouping
local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function AppendSearchValue(values, value)
    if IsSecretValue(value) then
        return
    end

    if value == nil then
        return
    end

    local text = C_StringUtil.StripHyperlinks(tostring(value))
    if IsSecretValue(text) then
        return
    end

    if text ~= "" then
        values[#values + 1] = text
    end
end

local function AppendFormattedColumns(values, item)
    for _, column in ipairs(Columns.GetColumns()) do
        local formatted = Columns.FormatColumn(item, column.key)
        if not IsSecretValue(formatted) and formatted and formatted ~= "" and formatted ~= "-" then
            AppendSearchValue(values, formatted)

            local label = column.tooltipTitle or column.sortLabel or column.label
            if label and label ~= "" then
                AppendSearchValue(values, label .. " " .. formatted)
            end
        end
    end
end

local function GetMoneySearchText(copper)
    if IsSecretValue(copper) then
        return nil
    end

    if type(copper) ~= "number" or copper <= 0 then
        return nil
    end

    local copperPerGold = COPPER_PER_GOLD or 10000
    local copperPerSilver = COPPER_PER_SILVER or 100
    local gold = math.floor(copper / copperPerGold)
    local silver = math.floor((copper - (gold * copperPerGold)) / copperPerSilver)
    local copperOnly = copper - (gold * copperPerGold) - (silver * copperPerSilver)
    return ("%d gold %d silver %d copper %dg %ds %dc"):format(gold, silver, copperOnly, gold, silver, copperOnly)
end

local function BuildItemSearchDocument(item)
    local values = {}
    AppendFormattedColumns(values, item)
    AppendSearchValue(values, item.name)
    AppendSearchValue(values, item.itemID)
    AppendSearchValue(values, item.type)
    AppendSearchValue(values, item.subtype)
    AppendSearchValue(values, item.categoryName)
    AppendSearchValue(values, item.bindingText)
    AppendSearchValue(values, item.bindingKey)
    AppendSearchValue(values, GetQualityName(item.quality))
    AppendSearchValue(values, GetExpansionName(item.expansionID))
    AppendSearchValue(values, item.itemDescription)
    AppendSearchValue(values, item.keystoneMapName)
    AppendSearchValue(values, item.battlePetName)

    if item.isPinned then
        AppendSearchValue(values, "pin pinned")
    end

    local professionQuality = item.professionQuality
    if not IsSecretValue(professionQuality) and type(professionQuality) == "number" then
        AppendSearchValue(values, ("profession quality %d"):format(professionQuality))
    end

    AppendSearchValue(values, GetMoneySearchText(item.totalSellValue))
    AppendSearchValue(values, item.tooltipSearchText)
    item.searchDocument = Lower(table.concat(values, "\n"))
    return item.searchDocument
end

local function ItemMatchesSearch(item, searchText)
    if not searchText or searchText == "" then
        return true
    end

    local searchDocument = item.searchDocument or BuildItemSearchDocument(item)
    return string.find(searchDocument, searchText, 1, true) ~= nil
end

local function GetGroupInfo(item, groupKey)
    if groupKey == "category" then
        return item.categoryKey or "other", item.categoryName or Categories.GetCategoryName(item.categoryKey)
    elseif groupKey == "type" then
        local typeKey = item.type or item.subtype or "other"
        return typeKey, typeKey
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

-- Public model contract
function ListModel.GetRowTypeItem()
    return ROW_TYPE_ITEM
end

function ListModel.GetRowTypeGroup()
    return ROW_TYPE_GROUP
end

function ListModel.GetRowTypeDivider()
    return ROW_TYPE_DIVIDER
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

function ListModel.GetManualSortKey()
    return MANUAL_SORT_KEY
end

function ListModel.IsManualSortKey(sortKey)
    return ListModel.NormalizeSortKey(sortKey) == MANUAL_SORT_KEY
end

function ListModel.GetGroupKeyList()
    return GROUP_KEY_LIST
end

function ListModel.GetGroupLabel(groupKey)
    groupKey = ListModel.NormalizeGroupKey(groupKey)
    return GROUP_KEY_LABELS[groupKey] or groupKey
end

function ListModel.NormalizeSortKey(sortKey)
    return NormalizeKey(sortKey, PRIMARY_SORT_KEY_ALIASES, VALID_SORT_KEYS, DEFAULT_SORT_KEY)
end

function ListModel.NormalizeSecondarySortKey(sortKey)
    return NormalizeKey(sortKey, SECONDARY_SORT_KEY_ALIASES, VALID_SECONDARY_SORT_KEYS, NO_SECONDARY_SORT_KEY)
end

function ListModel.NormalizeGroupKey(groupKey)
    return NormalizeKey(groupKey, GROUP_KEY_ALIASES, VALID_GROUP_KEYS, DEFAULT_GROUP_KEY)
end

function ListModel.IsValidSortKey(sortKey)
    return NormalizeKey(sortKey, PRIMARY_SORT_KEY_ALIASES, VALID_SORT_KEYS) ~= nil
end

function ListModel.IsValidSecondarySortKey(sortKey)
    return NormalizeKey(sortKey, SECONDARY_SORT_KEY_ALIASES, VALID_SECONDARY_SORT_KEYS) ~= nil
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
    return primarySortKey ~= MANUAL_SORT_KEY and secondarySortKey ~= NO_SECONDARY_SORT_KEY and secondarySortKey ~= primarySortKey
end

local function AppendItemRows(rows, items)
    for _, item in ipairs(items) do
        rows[#rows + 1] = {
            rowType = ROW_TYPE_ITEM,
            item = item,
        }
    end
end

local function AppendTopRowsDivider(rows, newItems, pinnedItems, pinDisplayMode)
    if pinDisplayMode ~= Pins.DisplayModes.Top
        or #newItems == 0
        or #pinnedItems == 0 then
        return
    end

    rows[#rows + 1] = {
        rowType = ROW_TYPE_DIVIDER,
    }
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
    local pinDisplayMode = Pins.GetDisplayMode()
    local filteredItems = {}
    local newItems = {}
    local regularItems = {}

    if items then
        for _, item in ipairs(items) do
            if ItemMatchesSearch(item, searchText) then
                filteredItems[#filteredItems + 1] = item
            end
        end
    end

    SortItems(filteredItems, sortKey, sortAscending, secondarySortKey, secondarySortAscending)

    for _, item in ipairs(filteredItems) do
        local target = item.isNewThisSession and newItems or regularItems
        target[#target + 1] = item
    end

    if not ListModel.IsGrouped(groupKey) then
        local rows = {}
        local pinnedItems = {}
        local unpinnedItems = {}

        AppendItemRows(rows, newItems)

        if pinDisplayMode == Pins.DisplayModes.Normal then
            unpinnedItems = regularItems
        else
            for _, item in ipairs(regularItems) do
                local target = item.isPinned and pinnedItems or unpinnedItems
                target[#target + 1] = item
            end
        end

        if pinDisplayMode == Pins.DisplayModes.Group and #pinnedItems > 0 then
            local collapsed = collapsedGroups[PINNED_GROUP_ID] == true
            rows[#rows + 1] = {
                rowType = ROW_TYPE_GROUP,
                groupID = PINNED_GROUP_ID,
                groupKey = PINNED_GROUP_KEY,
                label = PINNED_GROUP_LABEL,
                count = #pinnedItems,
                collapsed = collapsed,
            }

            if not collapsed then
                for _, item in ipairs(pinnedItems) do
                    rows[#rows + 1] = {
                        rowType = ROW_TYPE_ITEM,
                        item = item,
                    }
                end
            end
        else
            AppendTopRowsDivider(rows, newItems, pinnedItems, pinDisplayMode)
            AppendItemRows(rows, pinnedItems)
        end

        AppendItemRows(rows, unpinnedItems)

        return rows, #filteredItems
    end

    local groupMap = {}
    local groups = {}
    local pinnedItems = {}

    for _, item in ipairs(regularItems) do
        if item.isPinned and pinDisplayMode == Pins.DisplayModes.Top then
            pinnedItems[#pinnedItems + 1] = item
        else
            local key
            local label
            local isPinnedGroup = item.isPinned and pinDisplayMode == Pins.DisplayModes.Group
            if isPinnedGroup then
                key = PINNED_GROUP_KEY
                label = PINNED_GROUP_LABEL
            else
                key, label = GetGroupInfo(item, groupKey)
            end

            local id = isPinnedGroup and PINNED_GROUP_ID or groupKey .. ":" .. tostring(key)
            local group = groupMap[id]

            if not group then
                local sortPriority = 0
                if isPinnedGroup then
                    sortPriority = PINNED_GROUP_SORT_PRIORITY
                elseif groupKey == "category" then
                    sortPriority = Categories.GetSortPriority(key)
                end

                group = {
                    id = id,
                    key = key,
                    label = label,
                    items = {},
                    sortPriority = sortPriority,
                    sortText = TextValue(label),
                }
                groupMap[id] = group
                groups[#groups + 1] = group
            end

            if item.isPinned and pinDisplayMode == Pins.DisplayModes.TopOfGroups then
                group.pinnedItems = group.pinnedItems or {}
                group.pinnedItems[#group.pinnedItems + 1] = item
            else
                group.items[#group.items + 1] = item
            end
        end
    end

    table.sort(groups, function(left, right)
        if left.sortPriority ~= right.sortPriority then
            return left.sortPriority < right.sortPriority
        end

        if left.sortText ~= right.sortText then
            return left.sortText < right.sortText
        end

        return tostring(left.id) < tostring(right.id)
    end)

    local rows = {}
    AppendItemRows(rows, newItems)
    AppendTopRowsDivider(rows, newItems, pinnedItems, pinDisplayMode)
    AppendItemRows(rows, pinnedItems)

    for _, group in ipairs(groups) do
        local collapsed = collapsedGroups[group.id] == true
        local pinnedCount = group.pinnedItems and #group.pinnedItems or 0
        rows[#rows + 1] = {
            rowType = ROW_TYPE_GROUP,
            groupID = group.id,
            groupKey = group.key,
            label = group.label,
            count = pinnedCount + #group.items,
            collapsed = collapsed,
        }

        if not collapsed then
            if group.pinnedItems then
                for _, item in ipairs(group.pinnedItems) do
                    rows[#rows + 1] = {
                        rowType = ROW_TYPE_ITEM,
                        item = item,
                    }
                end
            end

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

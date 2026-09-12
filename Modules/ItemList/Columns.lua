local _, NS = ...

-- Available-column definitions, formatting, and column-owned visual metadata.
local Columns = {}
NS.ItemListColumns = Columns

local Binding = NS.Binding
local Media = NS.Media

local COLUMN_GAP = 6
local MAX_COLUMN_WIDTH = 1024
local DEFAULT_TEXT_COLOR_R = 0.86
local DEFAULT_TEXT_COLOR_G = 0.86
local DEFAULT_TEXT_COLOR_B = 0.86
local DEFAULT_NAME_COLOR_R = 1
local DEFAULT_NAME_COLOR_G = 1
local DEFAULT_NAME_COLOR_B = 1
local WARBOUND_COLOR_R = 0
local WARBOUND_COLOR_G = 0.8352941176470589
local WARBOUND_COLOR_B = 1
local DEFAULT_BINDING_ICON_COLOR_R = 0.55
local DEFAULT_BINDING_ICON_COLOR_G = 0.55
local DEFAULT_BINDING_ICON_COLOR_B = 0.55
local WARBOUND_BINDING_ICON_SIZE = 32
local ITEM_ICON_COLUMN_WIDTH = 30
local COMPACT_ICON_COLUMN_WIDTH = 28
local HEADER_GOLD_ICON_SIZE = 12
local BINDING_HEADER_ICON_SIZE = 16
local RARITY_HEADER_ICON_SIZE = 12
local PROFESSION_QUALITY_HEADER_ATLAS = "Professions-ChatIcon-Quality-12-Tier2"
local PROFESSION_QUALITY_HEADER_ICON_SIZE = 16
local RARE_QUALITY = Enum and Enum.ItemQuality and Enum.ItemQuality.Rare or 3
local RARE_COLOR_R = 0
local RARE_COLOR_G = 0.4392156862745098
local RARE_COLOR_B = 0.8666666666666667
local SORT_LABELS = {
    category = "Category",
    manual = "Manual",
}
local EXPANSION_LABELS = {
    [0] = "WoW",
    [1] = "BC",
    [2] = "WLK",
    [3] = "CAT",
    [4] = "MoP",
    [5] = "WoD",
    [6] = "LEG",
    [7] = "BFA",
    [8] = "SL",
    [9] = "DF",
    [10] = "TWW",
    [11] = "MID",
}

local professionQualityAtlasCache = {}
local availableColumns
local columnsByKey

local function GetQualityColor(quality, fallbackR, fallbackG, fallbackB)
    local color = ColorManager and ColorManager.GetColorDataForItemQuality and ColorManager.GetColorDataForItemQuality(quality)
    color = color or (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality])
    return {
        r = color and color.r or fallbackR,
        g = color and color.g or fallbackG,
        b = color and color.b or fallbackB,
    }
end

local warboundColor = {
    r = WARBOUND_COLOR_R,
    g = WARBOUND_COLOR_G,
    b = WARBOUND_COLOR_B,
}
local defaultBindingIconColor = {
    r = DEFAULT_BINDING_ICON_COLOR_R,
    g = DEFAULT_BINDING_ICON_COLOR_G,
    b = DEFAULT_BINDING_ICON_COLOR_B,
}
local rarityIconColor = GetQualityColor(RARE_QUALITY, RARE_COLOR_R, RARE_COLOR_G, RARE_COLOR_B)
local defaultBindingIconInfo = {
    texture = Media.GetSoulboundBindingIconTexture(),
    desaturated = false,
    color = defaultBindingIconColor,
}
local warboundBindingIconInfo = {
    atlas = Media.GetWarboundBindingIconAtlas(),
    desaturated = false,
    color = warboundColor,
    size = WARBOUND_BINDING_ICON_SIZE,
}
local goldHeaderLabel = NS.Money.GetGoldIconMarkup(HEADER_GOLD_ICON_SIZE)

-- Canonical order and widths also define Reset Columns. Visibility is per list.
local COLUMNS = {
    {
        key = "count",
        label = "#",
        width = 40,
        minWidth = 32,
        justify = "RIGHT",
        sortKey = "quantity",
        sortLabel = "quantity",
        tooltipTitle = "Quantity",
        defaultAscending = false,
    },
    {
        key = "binding",
        label = "",
        headerTexture = Media.GetSoulboundBindingIconTexture(),
        headerIconSize = BINDING_HEADER_ICON_SIZE,
        headerIconColorToken = "accent",
        width = COMPACT_ICON_COLUMN_WIDTH,
        minWidth = COMPACT_ICON_COLUMN_WIDTH,
        justify = "CENTER",
        sortKey = "binding",
        sortLabel = "binding status",
        tooltipTitle = "Binding",
    },
    {
        key = "icon",
        label = "",
        headerTexture = Media.GetCircleTexture(),
        headerIconSize = RARITY_HEADER_ICON_SIZE,
        headerIconColor = rarityIconColor,
        width = ITEM_ICON_COLUMN_WIDTH,
        minWidth = ITEM_ICON_COLUMN_WIDTH,
        menuLabel = "Item Icon (Rarity)",
        sortKey = "quality",
        sortLabel = "rarity",
        tooltipTitle = "Rarity",
        defaultAscending = false,
    },
    {
        key = "professionQuality",
        label = "",
        headerAtlas = PROFESSION_QUALITY_HEADER_ATLAS,
        headerIconSize = PROFESSION_QUALITY_HEADER_ICON_SIZE,
        width = COMPACT_ICON_COLUMN_WIDTH,
        minWidth = COMPACT_ICON_COLUMN_WIDTH,
        justify = "CENTER",
        sortKey = "professionQuality",
        sortLabel = "profession quality",
        tooltipTitle = "Profession Quality",
        defaultAscending = false,
    },
    {
        key = "name",
        label = NAME or "Name",
        width = 220,
        minWidth = 60,
        sortKey = "name",
        sortLabel = "name",
        tooltipTitle = NAME or "Name",
    },
    {
        key = "expansion",
        label = "Xpac",
        width = 48,
        minWidth = 32,
        justify = "CENTER",
        sortKey = "expansion",
        sortLabel = "expansion",
        tooltipTitle = "Expansion",
        defaultAscending = false,
    },
    {
        key = "sellValue",
        label = goldHeaderLabel,
        width = 82,
        minWidth = 48,
        justify = "RIGHT",
        sortKey = "sellValue",
        sortLabel = "sell price",
        tooltipTitle = "Sell Price",
        defaultAscending = false,
    },
    {
        key = "itemLevel",
        label = "ilvl",
        width = 44,
        minWidth = 32,
        justify = "RIGHT",
        sortKey = "itemLevel",
        sortLabel = "item level",
        tooltipTitle = "Item Level",
        defaultAscending = false,
    },
    {
        key = "requiredLevel",
        label = "Req",
        width = 44,
        minWidth = 32,
        justify = "RIGHT",
        sortKey = "requiredLevel",
        sortLabel = "required level",
        tooltipTitle = "Required Level",
        defaultAscending = false,
    },
    {
        key = "type",
        label = TYPE or "Type",
        width = 78,
        minWidth = 48,
        sortKey = "type",
        sortLabel = "type",
        tooltipTitle = TYPE or "Type",
    },
    {
        key = "subtype",
        label = "Subtype",
        width = 100,
        minWidth = 48,
        sortKey = "subtype",
        sortLabel = "subtype",
        tooltipTitle = "Subtype",
    },
    -- Optional physical-location display; native routing always retains it.
    {
        key = "location",
        defaultHidden = true,
        label = "Bag/Slot",
        width = 68,
        minWidth = 68,
        tooltipTitle = "Bag/Slot",
        tooltipText = "Physical bag or bank-tab ID and slot number.",
    },
}

-- Column formatting
local function EmptyDash(value)
    if value == nil or value == "" then
        return "-"
    end

    return tostring(value)
end

local function FormatMoney(copper)
    return NS.Money.Format(copper)
end

local function FormatSubtype(item)
    if not item.subtype or item.subtype == "" or item.subtype == item.type then
        return "-"
    end

    return item.subtype
end

local function FormatExpansion(expansionID)
    if expansionID == nil then
        return "-"
    end

    return EXPANSION_LABELS[expansionID] or tostring(expansionID)
end

local function GetAvailableColumns()
    if availableColumns then
        return availableColumns
    end

    availableColumns = {}
    columnsByKey = {}
    for _, column in ipairs(COLUMNS) do
        availableColumns[#availableColumns + 1] = column
        columnsByKey[column.key] = column
    end

    return availableColumns
end

-- Column visual state
local function SetNameTextColor(fontString, item)
    local color = item and item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    else
        fontString:SetTextColor(DEFAULT_NAME_COLOR_R, DEFAULT_NAME_COLOR_G, DEFAULT_NAME_COLOR_B)
    end
end

local function SetSellValueTextColor(fontString, item)
    local display = item and NS.Money.GetDisplay(item.totalSellValue or item.sellValue)
    local color = display and display.color
    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    else
        Columns.SetDefaultTextColor(fontString)
    end
end

-- Public column contract
function Columns.GetAvailableColumns()
    return GetAvailableColumns()
end

function Columns.GetColumn(key)
    GetAvailableColumns()
    return columnsByKey[key]
end

function Columns.GetLabel(column)
    return column.menuLabel or column.tooltipTitle
end

function Columns.ClampWidth(column, width)
    if type(width) ~= "number" or width ~= width
        or width == math.huge or width == -math.huge then
        return column.width
    end

    return math.floor(math.max(column.minWidth, math.min(MAX_COLUMN_WIDTH, width)) + 0.5)
end

function Columns.GetColumnBySortKey(sortKey)
    for _, column in ipairs(GetAvailableColumns()) do
        if column.sortKey and column.sortKey == sortKey then
            return column
        end
    end

    return nil
end

function Columns.GetDefaultSortAscending(sortKey)
    local column = Columns.GetColumnBySortKey(sortKey)
    return not (column and column.defaultAscending == false)
end

function Columns.GetSortLabel(sortKey)
    if SORT_LABELS[sortKey] then
        return SORT_LABELS[sortKey]
    end

    local column = Columns.GetColumnBySortKey(sortKey)
    if column then
        return column.tooltipTitle or column.sortLabel or column.label or sortKey
    end

    return sortKey or ""
end

function Columns.GetColumnGap()
    return COLUMN_GAP
end

function Columns.GetContentWidth()
    local width = 0
    local columns = GetAvailableColumns()

    -- Default frame sizing excludes optional, initially hidden columns.
    for _, column in ipairs(columns) do
        if not column.defaultHidden then
            if width > 0 then
                width = width + COLUMN_GAP
            end
            width = width + column.width
        end
    end

    return width
end

function Columns.FormatColumn(item, columnKey)
    if columnKey == "name" then
        return item.name or UNKNOWN
    elseif columnKey == "count" then
        return item.count and item.count > 1 and tostring(item.count) or ""
    elseif columnKey == "itemLevel" then
        return EmptyDash(item.itemLevel)
    elseif columnKey == "requiredLevel" then
        return EmptyDash(item.requiredLevel)
    elseif columnKey == "type" then
        return EmptyDash(item.type)
    elseif columnKey == "subtype" then
        return FormatSubtype(item)
    elseif columnKey == "binding" then
        return ""
    elseif columnKey == "expansion" then
        return FormatExpansion(item.expansionID)
    elseif columnKey == "sellValue" then
        return FormatMoney(item.totalSellValue or item.sellValue)
    elseif columnKey == "location" then
        return item.bagSlotText or "-"
    elseif columnKey == "professionQuality" then
        return ""
    end

    return ""
end

function Columns.GetProfessionQualityAtlas(item)
    if not item.professionQuality or not C_TradeSkillUI then
        return nil
    end

    local itemInfo = item.link or item.staticLink or item.itemID
    if not itemInfo then
        return nil
    end

    local cacheKey = tostring(itemInfo)
    if professionQualityAtlasCache[cacheKey] ~= nil then
        return professionQualityAtlasCache[cacheKey]
    end

    local qualityInfo
    if C_TradeSkillUI.GetItemReagentQualityInfo then
        qualityInfo = C_TradeSkillUI.GetItemReagentQualityInfo(itemInfo)
    end

    if not qualityInfo and C_TradeSkillUI.GetItemCraftedQualityInfo then
        qualityInfo = C_TradeSkillUI.GetItemCraftedQualityInfo(itemInfo)
    end

    local atlas = qualityInfo and (qualityInfo.icon or qualityInfo.iconSmall or qualityInfo.iconChat or qualityInfo.iconInventory)
    professionQualityAtlasCache[cacheKey] = atlas or false
    return professionQualityAtlasCache[cacheKey]
end

function Columns.GetBindingIconInfo(item)
    if not item or not item.bindingKey then
        return nil
    end

    if not Binding.HasBindingIcon(item.bindingKey) then
        return nil
    elseif Binding.IsWarboundKey(item.bindingKey) then
        return warboundBindingIconInfo
    end

    return defaultBindingIconInfo
end

function Columns.GetItemIconBorderColor(item)
    if item and Binding.IsWarboundKey(item.bindingKey) then
        return warboundColor
    end

    return nil
end

function Columns.GetWarboundColor()
    return warboundColor
end

function Columns.SetDefaultTextColor(fontString)
    fontString:SetTextColor(DEFAULT_TEXT_COLOR_R, DEFAULT_TEXT_COLOR_G, DEFAULT_TEXT_COLOR_B)
end

function Columns.ApplyTextColor(fontString, columnKey, item)
    if columnKey == "name" then
        SetNameTextColor(fontString, item)
    elseif columnKey == "sellValue" then
        SetSellValueTextColor(fontString, item)
    else
        Columns.SetDefaultTextColor(fontString)
    end
end

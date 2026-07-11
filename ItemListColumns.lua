local _, NS = ...

local Columns = {}
NS.ItemListColumns = Columns

local Binding = NS.Binding
local Media = NS.Media
local ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B = Media.GetAccentColor()

local COLUMN_GAP = 6
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
local enabledColumns

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
local accentIconColor = {
    r = ACCENT_COLOR_R,
    g = ACCENT_COLOR_G,
    b = ACCENT_COLOR_B,
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
local goldHeaderLabel = NS.Money and NS.Money.GetGoldIconMarkup and NS.Money.GetGoldIconMarkup(HEADER_GOLD_ICON_SIZE) or "Gold"

-- Fixed v1 columns. Later column customization can replace this table without
-- changing row rendering or list controller code.
local COLUMNS = {
    {
        key = "count",
        label = "#",
        width = 40,
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
        headerIconColor = accentIconColor,
        width = COMPACT_ICON_COLUMN_WIDTH,
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
        sortKey = "name",
        sortLabel = "name",
        tooltipTitle = NAME or "Name",
    },
    {
        key = "expansion",
        label = "Xpac",
        width = 48,
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
        sortKey = "type",
        sortLabel = "type",
        tooltipTitle = TYPE or "Type",
    },
    {
        key = "subtype",
        label = "Subtype",
        width = 100,
        sortKey = "subtype",
        sortLabel = "subtype",
        tooltipTitle = "Subtype",
    },
    -- Disabled for v1; retained for future optional column visibility.
    {
        key = "location",
        enabled = false,
        label = "Bag/Slot",
        width = 68,
        tooltipTitle = "Bag/Slot",
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
    return NS.Money and NS.Money.Format and NS.Money.Format(copper) or "-"
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

local function IsColumnEnabled(column)
    return column.enabled ~= false
end

local function GetEnabledColumns()
    if enabledColumns then
        return enabledColumns
    end

    enabledColumns = {}
    for _, column in ipairs(COLUMNS) do
        if IsColumnEnabled(column) then
            enabledColumns[#enabledColumns + 1] = column
        end
    end

    return enabledColumns
end

local function SetNameTextColor(fontString, item)
    local color = item and item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    else
        fontString:SetTextColor(DEFAULT_NAME_COLOR_R, DEFAULT_NAME_COLOR_G, DEFAULT_NAME_COLOR_B)
    end
end

local function SetSellValueTextColor(fontString, item)
    local display = item and NS.Money and NS.Money.GetDisplay and NS.Money.GetDisplay(item.totalSellValue or item.sellValue)
    local color = display and display.color
    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    else
        Columns.SetDefaultTextColor(fontString)
    end
end

function Columns.GetColumns()
    return GetEnabledColumns()
end

function Columns.GetColumnBySortKey(sortKey)
    for _, column in ipairs(GetEnabledColumns()) do
        if column.sortKey == sortKey then
            return column
        end
    end

    return nil
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
    local columns = GetEnabledColumns()

    for index, column in ipairs(columns) do
        width = width + column.width
        if index < #columns then
            width = width + COLUMN_GAP
        end
    end

    return width
end

function Columns.FormatColumn(item, columnKey)
    if columnKey == "name" then
        return item.name or UNKNOWN or "Unknown"
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

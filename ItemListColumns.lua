local _, NS = ...

local Columns = {}
NS.ItemListColumns = Columns

local Binding = NS.Binding
local Media = NS.Media

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

local professionQualityAtlasCache = {}
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

-- Fixed v1 columns. Later column customization can replace this table without
-- changing row rendering or list controller code.
local COLUMNS = {
    { key = "count", label = "Qty", width = 40, justify = "RIGHT" },
    { key = "binding", label = "", width = COMPACT_ICON_COLUMN_WIDTH, justify = "CENTER" },
    { key = "icon", label = "", width = ITEM_ICON_COLUMN_WIDTH },
    { key = "professionQuality", label = "", width = COMPACT_ICON_COLUMN_WIDTH, justify = "CENTER" },
    { key = "name", label = NAME or "Name", width = 220 },
    { key = "expansion", label = "Exp", width = 48, justify = "RIGHT" },
    { key = "sellValue", label = SELL_PRICE or "Sell", width = 82, justify = "RIGHT" },
    { key = "itemLevel", label = "Ilvl", width = 44, justify = "RIGHT" },
    { key = "requiredLevel", label = "Req", width = 44, justify = "RIGHT" },
    { key = "type", label = TYPE or "Type", width = 138 },
    { key = "location", label = "Bag/Slot", width = 68 },
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

local function FormatType(item)
    if item.type and item.subtype and item.subtype ~= "" and item.subtype ~= item.type then
        return item.type .. " / " .. item.subtype
    end

    return item.type or item.subtype or "-"
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
    return COLUMNS
end

function Columns.GetColumnGap()
    return COLUMN_GAP
end

function Columns.GetContentWidth()
    local width = 0

    for index, column in ipairs(COLUMNS) do
        width = width + column.width
        if index < #COLUMNS then
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
        return FormatType(item)
    elseif columnKey == "binding" then
        return ""
    elseif columnKey == "expansion" then
        return EmptyDash(item.expansionID)
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

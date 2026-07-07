local _, NS = ...

local Columns = {}
NS.ItemListColumns = Columns

local COLUMN_GAP = 6
local DEFAULT_TEXT_COLOR_R = 0.86
local DEFAULT_TEXT_COLOR_G = 0.86
local DEFAULT_TEXT_COLOR_B = 0.86
local DEFAULT_NAME_COLOR_R = 1
local DEFAULT_NAME_COLOR_G = 1
local DEFAULT_NAME_COLOR_B = 1
local MONEY_DISPLAY_FORMAT = "%s |T%s:0|t"
local MONEY_GOLD_KEY = "gold"
local MONEY_SILVER_KEY = "silver"
local MONEY_COPPER_KEY = "copper"

local MONEY_DENOMINATIONS = {
    [MONEY_GOLD_KEY] = {
        icon = "Interface\\MoneyFrame\\UI-GoldIcon",
        color = { r = 1, g = 0.82, b = 0 },
    },
    [MONEY_SILVER_KEY] = {
        icon = "Interface\\MoneyFrame\\UI-SilverIcon",
        color = { r = 0.75, g = 0.75, b = 0.75 },
    },
    [MONEY_COPPER_KEY] = {
        icon = "Interface\\MoneyFrame\\UI-CopperIcon",
        color = { r = 0.78, g = 0.45, b = 0.25 },
    },
}

local moneyDisplayCache = {}
local professionQualityAtlasCache = {}

-- Fixed v1 columns. Later column customization can replace this table without
-- changing row rendering or list controller code.
local COLUMNS = {
    { key = "icon", label = "", width = 30 },
    { key = "name", label = NAME or "Name", width = 220 },
    { key = "count", label = "Qty", width = 40, justify = "RIGHT" },
    { key = "itemLevel", label = "Ilvl", width = 44, justify = "RIGHT" },
    { key = "requiredLevel", label = "Req", width = 44, justify = "RIGHT" },
    { key = "type", label = TYPE or "Type", width = 138 },
    { key = "binding", label = "Binding", width = 96 },
    { key = "expansion", label = "Exp", width = 48, justify = "RIGHT" },
    { key = "sellValue", label = SELL_PRICE or "Sell", width = 82, justify = "RIGHT" },
    { key = "location", label = "Bag/Slot", width = 68 },
    { key = "professionQuality", label = "Q", width = 28, justify = "CENTER" },
}

-- Column formatting
local function EmptyDash(value)
    if value == nil or value == "" then
        return "-"
    end

    return tostring(value)
end

local function FormatLargeMoneyAmount(amount)
    if AbbreviateNumbers then
        return AbbreviateNumbers(amount)
    elseif AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(amount)
    elseif BreakUpLargeNumbers then
        return BreakUpLargeNumbers(amount)
    end

    return tostring(amount)
end

local function GetMoneyDisplay(copper)
    if not copper or copper <= 0 then
        return nil
    end

    if moneyDisplayCache[copper] then
        return moneyDisplayCache[copper]
    end

    local copperPerGold = COPPER_PER_GOLD or 10000
    local copperPerSilver = COPPER_PER_SILVER or 100
    local gold = math.floor(copper / copperPerGold)
    local silver = math.floor((copper - (gold * copperPerGold)) / copperPerSilver)
    local copperOnly = copper - (gold * copperPerGold) - (silver * copperPerSilver)
    local key
    local amount

    if gold > 0 then
        key = MONEY_GOLD_KEY
        amount = gold
    elseif silver > 0 then
        key = MONEY_SILVER_KEY
        amount = silver
    else
        key = MONEY_COPPER_KEY
        amount = copperOnly
    end

    local denomination = MONEY_DENOMINATIONS[key]
    local display = {
        key = key,
        color = denomination.color,
        text = MONEY_DISPLAY_FORMAT:format(FormatLargeMoneyAmount(amount), denomination.icon),
    }

    moneyDisplayCache[copper] = display
    return display
end

local function FormatMoney(copper)
    local display = GetMoneyDisplay(copper)
    return display and display.text or "-"
end

local function FormatType(item)
    if item.type and item.subtype and item.subtype ~= "" and item.subtype ~= item.type then
        return item.type .. " / " .. item.subtype
    end

    return item.type or item.subtype or "-"
end

local function FormatBinding(item)
    if not item.bindingKey or item.bindingKey == "none" then
        return "-"
    end

    if item.bindingKey == "pickup" then
        return "BoP"
    elseif item.bindingKey == "equip" then
        return "BoE"
    elseif item.bindingKey == "use" then
        return "BoU"
    elseif item.bindingKey == "bound" then
        return ITEM_SOULBOUND or "Soulbound"
    elseif item.bindingKey == "account" then
        return ITEM_BIND_TO_ACCOUNT or "Warbound"
    elseif item.bindingKey == "accountUntilEquipped" then
        return "Warbound Eq"
    end

    return item.bindingText or item.bindingKey
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
    local display = item and GetMoneyDisplay(item.totalSellValue or item.sellValue)
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
        return FormatBinding(item)
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

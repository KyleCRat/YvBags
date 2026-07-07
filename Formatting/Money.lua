local _, NS = ...

local Money = {}
NS.Money = Money

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

function Money.GetDisplay(copper, includeZero)
    if not copper or copper < 0 or (copper == 0 and not includeZero) then
        return nil
    end

    local cacheKey = tostring(copper) .. ":" .. tostring(includeZero)
    if moneyDisplayCache[cacheKey] then
        return moneyDisplayCache[cacheKey]
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

    moneyDisplayCache[cacheKey] = display
    return display
end

function Money.Format(copper, includeZero)
    local display = Money.GetDisplay(copper, includeZero)
    return display and display.text or "-"
end

function Money.ApplyColor(fontString, copper, includeZero, fallbackColor)
    local display = Money.GetDisplay(copper, includeZero)
    local color = display and display.color or fallbackColor

    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    end
end

local _, NS = ...

local Categories = {}
NS.Categories = Categories

-- Category labels
local CATEGORY_LABELS = {
    junk = "Junk",
    keystone = "Mythic Keystone",
    quest = "Quest",
    consumable = "Consumable",
    container = "Container",
    weapon = "Weapon",
    gem = "Gem",
    armor = "Armor",
    reagent = "Reagent",
    tradegoods = "Trade Goods",
    enhancement = "Enhancement",
    recipe = "Recipe",
    miscellaneous = "Miscellaneous",
    glyph = "Glyph",
    battlepet = "Battle Pet",
    token = "Token",
    profession = "Profession",
    housing = "Housing",
    other = "Other",
    unknown = "Unknown",
}

Categories.labels = CATEGORY_LABELS

-- Blizzard enum compatibility
local function EnumValue(enumName, key, fallback)
    if Enum and Enum[enumName] and Enum[enumName][key] ~= nil then
        return Enum[enumName][key]
    end

    return fallback
end

-- Item class to default category mapping
local ITEM_CLASS_CATEGORIES = {}

local function SetItemClassCategory(enumKey, fallback, categoryKey)
    ITEM_CLASS_CATEGORIES[EnumValue("ItemClass", enumKey, fallback)] = categoryKey
end

SetItemClassCategory("Consumable", 0, "consumable")
SetItemClassCategory("Container", 1, "container")
SetItemClassCategory("Weapon", 2, "weapon")
SetItemClassCategory("Gem", 3, "gem")
SetItemClassCategory("Armor", 4, "armor")
SetItemClassCategory("Reagent", 5, "reagent")
SetItemClassCategory("Tradegoods", 7, "tradegoods")
SetItemClassCategory("ItemEnhancement", 8, "enhancement")
SetItemClassCategory("Recipe", 9, "recipe")
SetItemClassCategory("Questitem", 12, "quest")
SetItemClassCategory("Miscellaneous", 15, "miscellaneous")
SetItemClassCategory("Glyph", 16, "glyph")
SetItemClassCategory("Battlepet", 17, "battlepet")
SetItemClassCategory("WoWToken", 18, "token")
SetItemClassCategory("Profession", 19, "profession")
SetItemClassCategory("Housing", 20, "housing")

-- Public category helpers
function Categories.GetCategoryKey(item)
    if item.isKeystone then
        return "keystone"
    end

    if item.isBattlePet then
        return "battlepet"
    end

    if ITEM_CLASS_CATEGORIES[item.classID] == "quest" then
        return "quest"
    end

    if item.quality == EnumValue("ItemQuality", "Poor", 0) and (item.sellValue or 0) > 0 then
        return "junk"
    end

    if item.isCraftingReagent then
        return "reagent"
    end

    return ITEM_CLASS_CATEGORIES[item.classID] or "other"
end

function Categories.GetCategoryName(categoryKey)
    return CATEGORY_LABELS[categoryKey] or CATEGORY_LABELS.other
end

function Categories.GetLabels()
    return CATEGORY_LABELS
end

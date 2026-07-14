local _, NS = ...

-- Built-in v1 category assignment and labels.
local Categories = {}
NS.Categories = Categories

-- Built-in category order and labels
local CATEGORY_DEFINITIONS = {
    { key = "openable", label = "Openable" },
    { key = "cosmetic", label = "Cosmetic" },
    { key = "keystone", label = "Mythic Keystone" },
    { key = "consumable", label = "Consumable" },
    { key = "equipment", label = "Equipment" },
    { key = "quest", label = "Quest" },
    { key = "enhancement", label = "Enhancement" },
    { key = "gem", label = "Gem" },
    { key = "recipe", label = "Recipe" },
    { key = "reagent", label = "Reagent" },
    { key = "tradegoods", label = "Trade Goods" },
    { key = "profession", label = "Profession" },
    { key = "container", label = "Container" },
    { key = "glyph", label = "Glyph" },
    { key = "battlepet", label = "Battle Pet" },
    { key = "token", label = "Token" },
    { key = "housing", label = "Housing" },
    { key = "miscellaneous", label = "Miscellaneous" },
    { key = "other", label = "Other" },
    { key = "unknown", label = "Unknown" },
    { key = "junk", label = "Junk" },
}

local CATEGORY_LABELS = {}
local CATEGORY_SORT_PRIORITIES = {}

for sortPriority, definition in ipairs(CATEGORY_DEFINITIONS) do
    CATEGORY_LABELS[definition.key] = definition.label
    CATEGORY_SORT_PRIORITIES[definition.key] = sortPriority
end

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
SetItemClassCategory("Weapon", 2, "equipment")
SetItemClassCategory("Gem", 3, "gem")
SetItemClassCategory("Armor", 4, "equipment")
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

    if item.hasLoot then
        return "openable"
    end

    if item.isBattlePet then
        return "battlepet"
    end

    if item.isCosmetic then
        return "cosmetic"
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

function Categories.GetSortPriority(categoryKey)
    return CATEGORY_SORT_PRIORITIES[categoryKey] or CATEGORY_SORT_PRIORITIES.other
end

function Categories.GetLabels()
    return CATEGORY_LABELS
end

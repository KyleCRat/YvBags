local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.ACCOUNT_DB_NAME = ADDON_NAME .. "DB"
NS.CHARACTER_DB_NAME = ADDON_NAME .. "CharacterDB"
NS.ACCOUNT_STORAGE_METADATA_KEY = "__yvBags"
NS.ACCOUNT_STORAGE_SCHEMA_VERSION = 1
NS.FRAME_NAME = ADDON_NAME .. "Frame"
NS.ITEM_BUTTON_GLOBAL_NAME_PREFIX = ADDON_NAME .. "ItemListButton"
NS.ADDON_MEDIA_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local function CreateDefaultCategoryRuleSet(categoryID)
    return {
        mode = "all",
        nextRuleID = 2,
        entries = {
            {
                id = "rule:1",
                field = "defaultCategory",
                operator = "equals",
                value = categoryID,
            },
        },
    }
end

local function CreateDefaultCategoryDefinition(categoryID, name)
    return {
        name = name,
        rules = CreateDefaultCategoryRuleSet(categoryID),
    }
end

NS.defaults = {
    global = {
        debug = false,
        features = {
            replaceBlizzardBags = true,
            autosellGrayJunk = false,
        },
        pins = {
            items = {},
        },
    },
    profile = {
        list = {
            sortKey = "quality",
            sortAscending = false,
            secondarySortKey = "itemLevel",
            secondarySortAscending = false,
            groupKey = "category",
        },
        pins = {
            displayMode = "top",
        },
        display = {
            showCooldownsInName = true,
        },
        categories = {
            schemaVersion = 1,
            nextCustomID = 1,
            order = {
                "openable",
                "cosmetic",
                "collectables",
                "keystone",
                "consumable",
                "equipment",
                "quest",
                "enhancement",
                "gem",
                "recipe",
                "reagent",
                "tradegoods",
                "profession",
                "container",
                "glyph",
                "token",
                "housing",
                "miscellaneous",
                "other",
                "unknown",
                "junk",
            },
            definitions = {
                openable = CreateDefaultCategoryDefinition("openable", "Openable"),
                cosmetic = CreateDefaultCategoryDefinition("cosmetic", "Cosmetic"),
                collectables = CreateDefaultCategoryDefinition("collectables", "Collectables"),
                keystone = CreateDefaultCategoryDefinition("keystone", "Mythic Keystone"),
                consumable = CreateDefaultCategoryDefinition("consumable", "Consumable"),
                equipment = CreateDefaultCategoryDefinition("equipment", "Equipment"),
                quest = CreateDefaultCategoryDefinition("quest", "Quest"),
                enhancement = CreateDefaultCategoryDefinition("enhancement", "Enhancement"),
                gem = CreateDefaultCategoryDefinition("gem", "Gem"),
                recipe = CreateDefaultCategoryDefinition("recipe", "Recipe"),
                reagent = CreateDefaultCategoryDefinition("reagent", "Reagent"),
                tradegoods = CreateDefaultCategoryDefinition("tradegoods", "Trade Goods"),
                profession = CreateDefaultCategoryDefinition("profession", "Profession"),
                container = CreateDefaultCategoryDefinition("container", "Container"),
                glyph = CreateDefaultCategoryDefinition("glyph", "Glyph"),
                token = CreateDefaultCategoryDefinition("token", "Token"),
                housing = CreateDefaultCategoryDefinition("housing", "Housing"),
                miscellaneous = CreateDefaultCategoryDefinition("miscellaneous", "Miscellaneous"),
                other = { name = "Other" },
                unknown = CreateDefaultCategoryDefinition("unknown", "Unknown"),
                junk = CreateDefaultCategoryDefinition("junk", "Junk"),
            },
        },
    },
    character = {
        frame = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 1080,
            height = 560,
            scale = 1,
        },
    },
}

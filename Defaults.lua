local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.ACCOUNT_DB_NAME = ADDON_NAME .. "DB"
NS.CHARACTER_DB_NAME = ADDON_NAME .. "CharacterDB"
NS.ACCOUNT_STORAGE_METADATA_KEY = "__yvBags"
NS.ACCOUNT_STORAGE_SCHEMA_VERSION = 1
NS.FRAME_NAME = ADDON_NAME .. "Frame"
NS.ITEM_BUTTON_GLOBAL_NAME_PREFIX = ADDON_NAME .. "ItemListButton"
NS.ADDON_MEDIA_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

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
                openable = { name = "Openable" },
                cosmetic = { name = "Cosmetic" },
                collectables = { name = "Collectables" },
                keystone = { name = "Mythic Keystone" },
                consumable = { name = "Consumable" },
                equipment = { name = "Equipment" },
                quest = { name = "Quest" },
                enhancement = { name = "Enhancement" },
                gem = { name = "Gem" },
                recipe = { name = "Recipe" },
                reagent = { name = "Reagent" },
                tradegoods = { name = "Trade Goods" },
                profession = { name = "Profession" },
                container = { name = "Container" },
                glyph = { name = "Glyph" },
                token = { name = "Token" },
                housing = { name = "Housing" },
                miscellaneous = { name = "Miscellaneous" },
                other = { name = "Other" },
                unknown = { name = "Unknown" },
                junk = { name = "Junk" },
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

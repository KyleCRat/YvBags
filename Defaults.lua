local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.ACCOUNT_DB_NAME = ADDON_NAME .. "DB"
NS.CHARACTER_DB_NAME = ADDON_NAME .. "CharacterDB"
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
        list = {
            sortKey = "name",
            sortAscending = true,
            secondarySortKey = "none",
            secondarySortAscending = true,
            groupKey = "category",
        },
        pins = {
            displayMode = "top",
            items = {},
        },
        display = {
            showCooldownsInName = true,
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

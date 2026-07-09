local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME

NS.defaults = {
    global = {
        debug = false,
        features = {
            autosellGrayJunk = false,
        },
        list = {
            sortKey = "name",
            sortAscending = true,
            groupKey = "category",
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

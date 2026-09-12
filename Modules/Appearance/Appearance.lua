local ADDON_NAME, NS = ...

-- One native library context shared by both windows; no frame/region adapters.
local Skins = LibStub("LibYvSkins-1.0")
local r, g, b = NS.Media.GetAccentColor()
NS.Skins = Skins:CreateContext(ADDON_NAME, {
    tokens = { accent = { r = r, g = g, b = b } },
})

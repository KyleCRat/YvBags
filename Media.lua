local _, NS = ...

local Media = {}
NS.Media = Media

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local MEDIA_TYPE_BORDER = LSM and LSM.MediaType and LSM.MediaType.BORDER or "border"
local MEDIA_TYPE_FONT = LSM and LSM.MediaType and LSM.MediaType.FONT or "font"
local ADDON_NAME = NS.ADDON_NAME
local ADDON_MEDIA_PATH = NS.ADDON_MEDIA_PATH
local Skins = LibStub("LibYvSkins-1.0")

local Borders = {
    icon = {
        type = MEDIA_TYPE_BORDER,
        key = ADDON_NAME .. " Icon Border",
        path = ADDON_MEDIA_PATH .. "Textures\\Vertex-IconFrame-Border.tga",
    },
}

local Fonts = {
    primary = {
        type = MEDIA_TYPE_FONT,
        key = "PT Sans Narrow",
        path = ADDON_MEDIA_PATH .. "Fonts\\PTSansNarrow-Bold.ttf",
    },
}

local Textures = {
    insetBackground = "Interface\\FrameGeneral\\UIFrameMidnightBackground",
    sortArrowUp = Skins:GetIconTexture("arrowUp"),
    sortArrowDown = Skins:GetIconTexture("arrowDown"),
    circle = ADDON_MEDIA_PATH .. "Textures\\Vertex-Circle.tga",
    mover = ADDON_MEDIA_PATH .. "Textures\\Vertex-Mover.tga",
    settings = Skins:GetIconTexture("settings"),
    scale = Skins:GetIconTexture("scale"),
    add = Skins:GetIconTexture("plus"),
    remove = Skins:GetIconTexture("minus"),
    newItem = ADDON_MEDIA_PATH .. "Textures\\Vertex-New.tga",
    pinned = ADDON_MEDIA_PATH .. "Textures\\Vertex-Pinned.tga",
    soulboundBindingIcon = ADDON_MEDIA_PATH .. "Textures\\Vertex-Lock.tga",
}

local EXPANSION_TEXTURE_PATH = ADDON_MEDIA_PATH .. "Textures\\Expansions\\"
-- Expansion icons use the full exported image without added padding.
local ExpansionIcons = {
    [0] = { file = "Classic", width = 40, height = 20 },
    [1] = { file = "BurningCrusade", width = 40, height = 20 },
    [2] = { file = "WrathOfTheLichKing", width = 36, height = 20 },
    [3] = { file = "Cataclysm", width = 40, height = 16 },
    [4] = { file = "MistsOfPandaria", width = 37, height = 20 },
    [5] = { file = "WarlordsOfDraenor", width = 46, height = 14 },
    [6] = { file = "Legion", width = 40, height = 16 },
    [7] = { file = "BattleForAzeroth", width = 80, height = 30 },
    [8] = { file = "Shadowlands", width = 80, height = 30 },
    [9] = { file = "Dragonflight", width = 80, height = 38 },
    [10] = { file = "TheWarWithin", width = 100, height = 54 },
    [11] = { file = "Midnight", width = 100, height = 42 },
    [12] = { file = "TheLastTitan", width = 100, height = 54 },
}
for _, icon in pairs(ExpansionIcons) do
    icon.texture = EXPANSION_TEXTURE_PATH .. icon.file .. ".tga"
    icon.textureWidth = icon.textureWidth or icon.width
    icon.textureHeight = icon.textureHeight or icon.height
    icon.texCoord = { 0, icon.width / icon.textureWidth, 0, icon.height / icon.textureHeight }
end

local Atlases = {
    warboundBindingIcon = "GM-icon-assist-hover",
    warbandTransfer = "warbands-transferable-icon",
    add = "common-icon-plus",
    remove = "common-icon-minus",
    delete = "common-icon-redx",
    professionQuality = {
        "Professions-Icon-Quality-Tier1",
        "Professions-Icon-Quality-Tier2",
        "Professions-Icon-Quality-Tier3",
        "Professions-Icon-Quality-Tier4",
        "Professions-Icon-Quality-Tier5",
    },
    professionQualityTwoRank = {
        "Professions-Icon-Quality-12-Tier1",
        "Professions-Icon-Quality-12-Tier2",
    },
}

local Colors = {
    accent = { r = 0.15, g = 0.88, b = 1 },
}

local function RegisterMediaGroup(mediaGroup)
    if not LSM then
        return
    end

    for _, media in pairs(mediaGroup) do
        LSM:Register(media.type, media.key, media.path)
    end
end

function Media.Register()
    RegisterMediaGroup(Borders)
    RegisterMediaGroup(Fonts)
end

function Media.GetIconBorderTexture()
    if LSM then
        return LSM:Fetch(Borders.icon.type, Borders.icon.key, true) or Borders.icon.path
    end

    return Borders.icon.path
end

function Media.GetInsetBackgroundTexture()
    return Textures.insetBackground
end

function Media.GetSortArrowTexture(ascending)
    return ascending and Textures.sortArrowUp or Textures.sortArrowDown
end

function Media.GetCircleTexture()
    return Textures.circle
end

function Media.GetMoverTexture()
    return Textures.mover
end

function Media.GetMoverColor()
    return NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
end

function Media.GetSettingsTexture()
    return Textures.settings
end

function Media.GetScaleTexture()
    return Textures.scale
end

function Media.GetNewItemTexture()
    return Textures.newItem
end

function Media.GetPinnedTexture()
    return Textures.pinned
end

function Media.GetSoulboundBindingIconTexture()
    return Textures.soulboundBindingIcon
end

function Media.GetWarboundBindingIconAtlas()
    return Atlases.warboundBindingIcon
end

function Media.GetWarbandTransferAtlas()
    return Atlases.warbandTransfer
end

function Media.GetAddAtlas()
    return Atlases.add
end

function Media.GetAddTexture()
    return Textures.add
end

function Media.GetRemoveTexture()
    return Textures.remove
end

function Media.GetRemoveAtlas()
    return Atlases.remove
end

function Media.GetDeleteAtlas()
    return Atlases.delete
end

function Media.GetProfessionQualityAtlases(quality)
    return Atlases.professionQuality[quality],
        Atlases.professionQualityTwoRank[quality]
end

function Media.GetExpansionIconInfo(expansionID)
    return ExpansionIcons[expansionID]
end

function Media.GetExpansionIconMarkup(expansionID, maxWidth, maxHeight)
    local icon = ExpansionIcons[expansionID]
    if not icon then
        return nil
    end

    local scale = math.min(1, maxWidth / icon.width, maxHeight / icon.height)
    local width = math.max(1, math.floor(icon.width * scale + 0.5))
    local height = math.max(1, math.floor(icon.height * scale + 0.5))
    return CreateTextureMarkup(
        icon.texture,
        icon.textureWidth, icon.textureHeight,
        width, height,
        0, icon.width / icon.textureWidth,
        0, icon.height / icon.textureHeight
    )
end

function Media.GetAccentColor()
    local color = Colors.accent
    return color.r, color.g, color.b
end

function Media.GetPrimaryFont()
    if LSM then
        return LSM:Fetch(Fonts.primary.type, Fonts.primary.key, true) or Fonts.primary.path
    end

    return Fonts.primary.path
end

Media.Register()

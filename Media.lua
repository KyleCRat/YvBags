local _, NS = ...

local Media = {}
NS.Media = Media

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local MEDIA_TYPE_BORDER = LSM and LSM.MediaType and LSM.MediaType.BORDER or "border"
local MEDIA_TYPE_FONT = LSM and LSM.MediaType and LSM.MediaType.FONT or "font"
local ADDON_NAME = NS.ADDON_NAME
local ADDON_MEDIA_PATH = NS.ADDON_MEDIA_PATH

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
    sortArrow = ADDON_MEDIA_PATH .. "Textures\\Vertex-Arrow.tga",
    circle = ADDON_MEDIA_PATH .. "Textures\\Vertex-Circle.tga",
    mover = ADDON_MEDIA_PATH .. "Textures\\Vertex-Mover.tga",
    newItem = ADDON_MEDIA_PATH .. "Textures\\Vertex-New.tga",
    pinned = ADDON_MEDIA_PATH .. "Textures\\Vertex-Pinned.tga",
    soulboundBindingIcon = ADDON_MEDIA_PATH .. "Textures\\Vertex-Lock.tga",
    divider = "Interface\\Common\\UI-TooltipDivider",
}

local Atlases = {
    warboundBindingIcon = "GM-icon-assist-hover",
    warbandTransfer = "warbands-transferable-icon",
    checkmark = "common-icon-checkmark-yellow",
    add = "common-icon-plus",
    remove = "common-icon-minus",
    delete = "common-icon-redx",
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

function Media.GetSortArrowTexture()
    return Textures.sortArrow
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

function Media.GetCheckmarkAtlas()
    return Atlases.checkmark
end

function Media.GetAddAtlas()
    return Atlases.add
end

function Media.GetRemoveAtlas()
    return Atlases.remove
end

function Media.GetDeleteAtlas()
    return Atlases.delete
end

function Media.GetDividerTexture()
    return Textures.divider
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

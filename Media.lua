local _, NS = ...

local Media = {}
NS.Media = Media

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local MEDIA_TYPE_BORDER = LSM and LSM.MediaType and LSM.MediaType.BORDER or "border"
local MEDIA_TYPE_FONT = LSM and LSM.MediaType and LSM.MediaType.FONT or "font"

local ICON_BORDER_KEY = "YvBags Icon Border"
local ICON_BORDER_TEXTURE = "Interface\\AddOns\\YvBags\\Media\\Textures\\Vertex-IconFrame-Border.tga"
local SOULBOUND_BINDING_ICON_TEXTURE = "Interface\\AddOns\\YvBags\\Media\\Textures\\Vertex-Lock.tga"
local WARBOUND_BINDING_ICON_ATLAS = "GM-icon-assist-hover"
local PRIMARY_FONT_KEY = "YvBags PT Sans Narrow"
local PRIMARY_FONT_PATH = "Interface\\AddOns\\YvBags\\Media\\Fonts\\PTSansNarrow-Bold.ttf"

function Media.Register()
    if LSM then
        LSM:Register(MEDIA_TYPE_BORDER, ICON_BORDER_KEY, ICON_BORDER_TEXTURE)
        LSM:Register(MEDIA_TYPE_FONT, PRIMARY_FONT_KEY, PRIMARY_FONT_PATH)
    end
end

function Media.GetIconBorderTexture()
    if LSM then
        return LSM:Fetch(MEDIA_TYPE_BORDER, ICON_BORDER_KEY, true) or ICON_BORDER_TEXTURE
    end

    return ICON_BORDER_TEXTURE
end

function Media.GetSoulboundBindingIconTexture()
    return SOULBOUND_BINDING_ICON_TEXTURE
end

function Media.GetWarboundBindingIconAtlas()
    return WARBOUND_BINDING_ICON_ATLAS
end

function Media.GetPrimaryFont()
    if LSM then
        return LSM:Fetch(MEDIA_TYPE_FONT, PRIMARY_FONT_KEY, true) or PRIMARY_FONT_PATH
    end

    return PRIMARY_FONT_PATH
end

Media.Register()

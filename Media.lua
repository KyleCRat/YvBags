local _, NS = ...

local Media = {}
NS.Media = Media

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local MEDIA_TYPE_BORDER = LSM and LSM.MediaType and LSM.MediaType.BORDER or "border"

local ICON_BORDER_KEY = "YvBags Icon Border"
local ICON_BORDER_TEXTURE = "Interface\\AddOns\\YvBags\\Media\\Textures\\Vertex-IconFrame-Border.tga"

function Media.Register()
    if LSM then
        LSM:Register(MEDIA_TYPE_BORDER, ICON_BORDER_KEY, ICON_BORDER_TEXTURE)
    end
end

function Media.GetIconBorderTexture()
    if LSM then
        return LSM:Fetch(MEDIA_TYPE_BORDER, ICON_BORDER_KEY, true) or ICON_BORDER_TEXTURE
    end

    return ICON_BORDER_TEXTURE
end

Media.Register()

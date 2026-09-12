local ADDON_NAME, NS = ...

-- One native library context shared by both windows; no frame/region adapters.
local Skins = LibStub("LibYvSkins-1.0")
local r, g, b = NS.Media.GetAccentColor()
NS.Skins = Skins:CreateContext(ADDON_NAME, {
    font = NS.Media.GetPrimaryFont(),
    iconBorder = NS.Media.GetIconBorderTexture(),
    tokens = { accent = { r = r, g = g, b = b } },
})

local Appearance = { callbacks = {} }
NS.Appearance = Appearance

function Appearance.GetSkin()
    local skin = NS.globalDB:Get("appearance", "skin")
    return skin == "flat" and "flat" or "modern"
end

function Appearance.SetSkin(skin)
    NS.globalDB:Set("appearance", "skin", skin)
end

function Appearance.Reset()
    Appearance.SetSkin(NS.defaults.global.appearance.skin)
end

function Appearance.GetStatusText()
    local requested, applied, reason = NS.Skins:GetSkinStatus()
    if reason == "unavailable" then
        return "Flat unavailable: another addon loaded an older LibPopupSlider. WoW Modern remains active."
    elseif reason == "combat" then
        return "Skin change queued until combat ends."
    elseif reason == "interaction" then
        return "Skin change queued until moving, resizing, or scaling finishes."
    elseif requested ~= applied then
        return "Applying skin to bags and bank..."
    end
    return "Shared by bags and bank, independent of the active profile."
end

function Appearance.RegisterCallback(callback)
    Appearance.callbacks[#Appearance.callbacks + 1] = callback
end

NS.Skins:SetSkinCallbacks({
    beforeApply = function()
        if NS.frame then
            NS.ItemListHeader.CancelInteraction(NS.frame.itemList.header)
            NS.frame.itemList:PrewarmItemRows()
        end
        if NS.bankFrame then
            NS.ItemListHeader.CancelInteraction(NS.bankFrame.itemList.header)
            NS.bankFrame.itemList:PrewarmItemRows()
        end
    end,
    onApplied = function()
        if NS.frame then NS.MainFrameGeometry.RefreshResizeBounds(NS.frame) end
        if NS.bankFrame then NS.BankFrameGeometry.RefreshResizeBounds(NS.bankFrame) end
    end,
    onStatusChanged = function()
        for _, callback in ipairs(Appearance.callbacks) do callback() end
    end,
})

NS:RegisterInitCallback(function()
    local function Refresh()
        NS.Skins:RequestSkin(Appearance.GetSkin())
    end
    NS.globalDB:RegisterTreeCallback(Refresh, "appearance")
    NS.globalDB:RegisterLifecycleCallback("OnReset", Refresh)
    Refresh()
end)

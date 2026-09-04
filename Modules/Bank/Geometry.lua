local _, NS = ...

-- Custom-bank frame position, size, and scale persistence.
local Geometry = {}
NS.BankFrameGeometry = Geometry

local Layout = NS.BankFrameLayout
local DB_SECTION = "bankFrame"
local SCALE_MIN = 0.5
local SCALE_MAX = 1.5
local FIRST_POSITION_GAP = 12

local function ClampScale(scale)
    return math.max(SCALE_MIN, math.min(SCALE_MAX, tonumber(scale) or 1))
end

local function GetNearestPixelSize(frame, size)
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(size, frame:GetEffectiveScale())
    end

    return math.floor(size + 0.5)
end

local function SetPixelPerfectSize(frame, width, height)
    frame:SetSize(
        GetNearestPixelSize(frame, width),
        GetNearestPixelSize(frame, height)
    )
end

function Geometry.PreventClientSaving(frame)
    frame:SetDontSavePosition(true)
end

function Geometry.ClearClientPosition(frame)
    frame:SetUserPlaced(false)
end

function Geometry.GetSavedScale()
    return ClampScale(NS.charDB:Get(DB_SECTION, "scale"))
end

function Geometry.SetScale(scale)
    scale = ClampScale(scale)
    NS.charDB:Set(DB_SECTION, "scale", scale)

    if NS.bankFrame then
        NS.bankFrame:SetScale(scale)
        NS.MainFrameControls.RefreshScale(NS.bankFrame, scale)
    end

    NS.Settings.NotifyBankFrameScaleChanged()
end

function Geometry.GetMaxWidth()
    return math.max(
        Layout.MinWidth,
        NS.ItemList.GetPreferredWidth() + Layout.GetHorizontalChromeWidth()
    )
end

function Geometry.SnapSize(frame)
    SetPixelPerfectSize(frame, frame:GetWidth(), frame:GetHeight())
end

function Geometry.RestoreSize(frame)
    local maxWidth = Geometry.GetMaxWidth()
    local savedWidth = NS.charDB:Get(DB_SECTION, "width")
    local savedHeight = NS.charDB:Get(DB_SECTION, "height")
    local width = math.min(
        math.max(savedWidth or maxWidth, Layout.MinWidth),
        maxWidth
    )
    local height = math.max(savedHeight or Layout.MinHeight, Layout.MinHeight)
    SetPixelPerfectSize(frame, width, height)
end

function Geometry.Save(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    NS.charDB:Set(DB_SECTION, "point", point or "CENTER")
    NS.charDB:Set(
        DB_SECTION,
        "relativePoint",
        relativePoint or "CENTER"
    )
    NS.charDB:Set(DB_SECTION, "x", x or 0)
    NS.charDB:Set(DB_SECTION, "y", y or 0)
    NS.charDB:Set(DB_SECTION, "width", frame:GetWidth())
    NS.charDB:Set(DB_SECTION, "height", frame:GetHeight())
    NS.charDB:Set(DB_SECTION, "positionInitialized", true)
    Geometry.PreventClientSaving(frame)
    Geometry.ClearClientPosition(frame)
end

local function SetFirstPosition(frame)
    local bagFrame = NS.frame
    local screenWidth = UIParent:GetWidth()
    local frameWidth = frame:GetWidth() * frame:GetScale()
    local bagLeft = bagFrame and bagFrame:GetLeft()
    local bagRight = bagFrame and bagFrame:GetRight()
    local bagTop = bagFrame and bagFrame:GetTop()

    frame:ClearAllPoints()
    if bagRight and bagTop
        and bagRight + FIRST_POSITION_GAP + frameWidth <= screenWidth then
        frame:SetPoint(
            "TOPLEFT",
            UIParent,
            "BOTTOMLEFT",
            bagRight + FIRST_POSITION_GAP,
            bagTop
        )
    elseif bagLeft and bagTop
        and bagLeft - FIRST_POSITION_GAP - frameWidth >= 0 then
        frame:SetPoint(
            "TOPRIGHT",
            UIParent,
            "BOTTOMLEFT",
            bagLeft - FIRST_POSITION_GAP,
            bagTop
        )
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    Geometry.Save(frame)
end

function Geometry.RestorePosition(frame)
    if NS.charDB:Get(DB_SECTION, "positionInitialized") ~= true then
        SetFirstPosition(frame)
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        NS.charDB:Get(DB_SECTION, "point") or "CENTER",
        UIParent,
        NS.charDB:Get(DB_SECTION, "relativePoint") or "CENTER",
        NS.charDB:Get(DB_SECTION, "x") or 0,
        NS.charDB:Get(DB_SECTION, "y") or 0
    )
end

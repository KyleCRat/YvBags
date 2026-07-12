local _, NS = ...

-- Main-frame position, size, scale, and diagnostic persistence contract.
local Geometry = {}
NS.MainFrameGeometry = Geometry

local Layout = NS.MainFrameLayout

local SCALE_MIN = 0.5
local SCALE_MAX = 1.5
local DEFAULT_POINT = "CENTER"
local DEFAULT_RELATIVE_POINT = "CENTER"
local DEBUG_POSITION = false

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
    frame:SetSize(GetNearestPixelSize(frame, width), GetNearestPixelSize(frame, height))
end

local function FormatDebugNumber(value)
    if type(value) == "number" then
        return ("%.3f"):format(value)
    end

    return tostring(value)
end

local function GetRegionName(region)
    if not region then
        return "nil"
    end

    if region.GetName then
        return region:GetName() or tostring(region)
    end

    return tostring(region)
end

local function IsDebugEnabled()
    return DEBUG_POSITION or NS.db:Get("debug") == true
end

function Geometry.PreventClientSaving(frame)
    if frame.SetDontSavePosition then
        frame:SetDontSavePosition(true)
    end
end

function Geometry.ClearClientPosition(frame)
    if frame.SetUserPlaced then
        frame:SetUserPlaced(false)
    end
end

function Geometry.GetSavedScale()
    return ClampScale(NS.charDB:Get("frame", "scale"))
end

function Geometry.SetScale(scale)
    scale = ClampScale(scale)
    NS.charDB:Set("frame", "scale", scale)

    local frame = NS.frame
    if frame then
        frame:SetScale(scale)
        NS.MainFrameControls.RefreshScale(frame, scale)
    end

    NS.Settings.NotifyFrameScaleChanged()
end

function Geometry.GetMaxWidth()
    local listWidth = NS.ItemList.GetPreferredWidth()
    return math.max(Layout.MinWidth, listWidth + Layout.GetHorizontalChromeWidth())
end

function Geometry.SnapSize(frame)
    SetPixelPerfectSize(frame, frame:GetWidth(), frame:GetHeight())
end

function Geometry.RestoreSize(frame)
    local maxWidth = Geometry.GetMaxWidth()
    local savedWidth = NS.charDB:Get("frame", "width")
    local width = math.min(math.max(savedWidth or maxWidth, Layout.MinWidth), maxWidth)
    local height = math.max(NS.charDB:Get("frame", "height") or Layout.MinHeight, Layout.MinHeight)
    SetPixelPerfectSize(frame, width, height)
end

function Geometry.Save(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    NS.charDB:Set("frame", "point", point or DEFAULT_POINT)
    NS.charDB:Set("frame", "relativePoint", relativePoint or DEFAULT_RELATIVE_POINT)
    NS.charDB:Set("frame", "x", x or 0)
    NS.charDB:Set("frame", "y", y or 0)
    NS.charDB:Set("frame", "width", frame:GetWidth())
    NS.charDB:Set("frame", "height", frame:GetHeight())
    Geometry.PreventClientSaving(frame)
    Geometry.ClearClientPosition(frame)
end

function Geometry.RestorePosition(frame)
    frame:ClearAllPoints()
    frame:SetPoint(
        NS.charDB:Get("frame", "point") or DEFAULT_POINT,
        UIParent,
        NS.charDB:Get("frame", "relativePoint") or DEFAULT_RELATIVE_POINT,
        NS.charDB:Get("frame", "x") or 0,
        NS.charDB:Get("frame", "y") or 0
    )
end

function Geometry.PrintDebug(frame, reason)
    if not IsDebugEnabled() then
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    NS:Print(("Frame position [%s] frame point=%s relativeTo=%s relativePoint=%s x=%s y=%s width=%s height=%s left=%s top=%s right=%s bottom=%s scale=%s effectiveScale=%s"):format(
        tostring(reason),
        tostring(point),
        GetRegionName(relativeTo),
        tostring(relativePoint),
        FormatDebugNumber(x),
        FormatDebugNumber(y),
        FormatDebugNumber(frame:GetWidth()),
        FormatDebugNumber(frame:GetHeight()),
        FormatDebugNumber(frame:GetLeft()),
        FormatDebugNumber(frame:GetTop()),
        FormatDebugNumber(frame:GetRight()),
        FormatDebugNumber(frame:GetBottom()),
        FormatDebugNumber(frame:GetScale()),
        FormatDebugNumber(frame:GetEffectiveScale())
    ))
    NS:Print(("Frame DB [%s] point=%s relativePoint=%s x=%s y=%s width=%s height=%s scale=%s"):format(
        tostring(reason),
        tostring(NS.charDB:Get("frame", "point")),
        tostring(NS.charDB:Get("frame", "relativePoint")),
        FormatDebugNumber(NS.charDB:Get("frame", "x")),
        FormatDebugNumber(NS.charDB:Get("frame", "y")),
        FormatDebugNumber(NS.charDB:Get("frame", "width")),
        FormatDebugNumber(NS.charDB:Get("frame", "height")),
        FormatDebugNumber(NS.charDB:Get("frame", "scale"))
    ))
end

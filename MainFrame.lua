local ADDON_NAME, NS = ...

local FRAME_NAME = "YvBagsFrame"

local function SaveFramePosition(frame)
    if not NS.charDB then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    NS.charDB:Set("frame", "point", point or "CENTER")
    NS.charDB:Set("frame", "relativePoint", relativePoint or "CENTER")
    NS.charDB:Set("frame", "x", x or 0)
    NS.charDB:Set("frame", "y", y or 0)
end

local function RestoreFramePosition(frame)
    frame:ClearAllPoints()
    frame:SetPoint(
        NS.charDB:Get("frame", "point"),
        UIParent,
        NS.charDB:Get("frame", "relativePoint"),
        NS.charDB:Get("frame", "x"),
        NS.charDB:Get("frame", "y")
    )
end

function NS:CreateMainFrame()
    if NS.frame then
        return NS.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "ButtonFrameTemplate")
    frame:SetSize(NS.charDB:Get("frame", "width"), NS.charDB:Get("frame", "height"))
    frame:SetScale(NS.charDB:Get("frame", "scale"))
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    if frame.SetTitle then
        frame:SetTitle(ADDON_NAME)
    end

    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_08")
        frame:SetPortraitTexCoord(0, 1, 0, 1)
    end

    RestoreFramePosition(frame)

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -60)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 26)
    end

    local dragRegion = frame.TitleContainer or frame
    dragRegion:EnableMouse(true)
    dragRegion:RegisterForDrag("LeftButton")
    dragRegion:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)

    dragRegion:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveFramePosition(frame)
    end)

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("CENTER", frame.Inset or frame, "CENTER", 0, 0)
    body:SetText("YvBags chunk 1 placeholder")

    NS.frame = frame
    return frame
end

function NS:ShowFrame()
    local frame = NS.frame or NS:CreateMainFrame()
    frame:Show()
end

function NS:HideFrame()
    if NS.frame then
        NS.frame:Hide()
    end
end

function NS:ToggleFrame()
    local frame = NS.frame or NS:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

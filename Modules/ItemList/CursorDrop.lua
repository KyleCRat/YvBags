local _, NS = ...

-- Native empty-slot drop target for sorted insertion and Manual-mode placement.
local CursorDrop = {}
NS.ItemListCursorDrop = CursorDrop

local ItemButton = NS.ItemRowButton
local Layout = NS.ItemListLayout
local ListModel = NS.ItemListModel
local ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B = NS.Media.GetAccentColor()

local UPDATE_INTERVAL = 0.05
local OVERLAY_FRAME_LEVEL_OFFSET = 80
local MANUAL_OVERLAY_HEIGHT = 50
local TEXT_SIZE = 22
local TEXT_FLAGS = "OUTLINE, SLUG"
local TEXT_FORMAT = "Place %s into your bags"
local FALLBACK_ITEM_NAME = "item"
local TEXT_SIDE_PADDING = 24
local BACKGROUND_ALPHA = 0.72
local HOVER_BACKGROUND_ALPHA = 0.18
local HOVER_BACKGROUND_INSET = 9
local GLOW_CORNER_TEXTURE = "Interface\\Common\\GlowBorder-Corner"
local GLOW_TOP_TEXTURE = "Interface\\Common\\GlowBorder-Top"
local GLOW_LEFT_TEXTURE = "Interface\\Common\\GlowBorder-Left"
local GLOW_CORNER_SIZE = 16
local GLOW_MIN_ALPHA = 0.35
local GLOW_MAX_ALPHA = 0.85
local GLOW_PULSE_DURATION = 0.85
local MODE_FULL = "full"
local MODE_MANUAL = "manual"

local function GetDropText(itemID, itemLink)
    local itemName = itemLink
    if not itemName and itemID then
        if C_Item and C_Item.GetItemInfo then
            itemName = C_Item.GetItemInfo(itemID)
        elseif GetItemInfo then
            itemName = GetItemInfo(itemID)
        end
    end

    return TEXT_FORMAT:format(itemName or FALLBACK_ITEM_NAME)
end

local function GetCursorItemData()
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType ~= "item" then
        return nil
    end

    local sourceContainerID
    local sourceSlotIndex
    local cursorItemLocation = C_Cursor.GetCursorItem()
    if cursorItemLocation then
        sourceContainerID, sourceSlotIndex = cursorItemLocation:GetBagAndSlot()
    end

    return itemID, itemLink, sourceContainerID, sourceSlotIndex
end

local function SetHovered(overlay, hovered)
    if overlay.hovered == hovered then
        return
    end

    overlay.hovered = hovered
    overlay.hoverBackground:SetShown(hovered)
end

local function StartGlow(overlay)
    overlay.glow:SetAlpha(GLOW_MIN_ALPHA)
    overlay.glowPulse:Play()
end

local function StopGlow(overlay)
    if overlay.glowPulse:IsPlaying() then
        overlay.glowPulse:Stop()
    end

    overlay.glow:SetAlpha(GLOW_MIN_ALPHA)
end

local function RestartGlow(overlay)
    if overlay:IsShown() then
        StopGlow(overlay)
        StartGlow(overlay)
    end
end

local function CreateGlowTexture(parent, texture)
    local region = parent:CreateTexture(nil, "BORDER")
    region:SetTexture(texture)
    region:SetBlendMode("ADD")
    region:SetDesaturated(true)
    region:SetVertexColor(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, 1)
    return region
end

local function CreateGlow(parent)
    local glow = CreateFrame("Frame", nil, parent)
    glow:SetAllPoints(parent)
    glow:SetAlpha(GLOW_MIN_ALPHA)

    local topLeft = CreateGlowTexture(glow, GLOW_CORNER_TEXTURE)
    topLeft:SetSize(GLOW_CORNER_SIZE, GLOW_CORNER_SIZE)
    topLeft:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)

    local topRight = CreateGlowTexture(glow, GLOW_CORNER_TEXTURE)
    topRight:SetSize(GLOW_CORNER_SIZE, GLOW_CORNER_SIZE)
    topRight:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
    topRight:SetTexCoord(1, 0, 0, 1)

    local bottomLeft = CreateGlowTexture(glow, GLOW_CORNER_TEXTURE)
    bottomLeft:SetSize(GLOW_CORNER_SIZE, GLOW_CORNER_SIZE)
    bottomLeft:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
    bottomLeft:SetTexCoord(0, 1, 1, 0)

    local bottomRight = CreateGlowTexture(glow, GLOW_CORNER_TEXTURE)
    bottomRight:SetSize(GLOW_CORNER_SIZE, GLOW_CORNER_SIZE)
    bottomRight:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
    bottomRight:SetTexCoord(1, 0, 1, 0)

    local top = CreateGlowTexture(glow, GLOW_TOP_TEXTURE)
    top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
    top:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMLEFT", 0, 0)

    local bottom = CreateGlowTexture(glow, GLOW_TOP_TEXTURE)
    bottom:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", 0, 0)
    bottom:SetTexCoord(0, 1, 1, 0)

    local left = CreateGlowTexture(glow, GLOW_LEFT_TEXTURE)
    left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT", 0, 0)

    local right = CreateGlowTexture(glow, GLOW_LEFT_TEXTURE)
    right:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT", 0, 0)
    right:SetTexCoord(1, 0, 0, 1)

    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(GLOW_MIN_ALPHA)
    alpha:SetToAlpha(GLOW_MAX_ALPHA)
    alpha:SetDuration(GLOW_PULSE_DURATION)

    parent.glow = glow
    parent.glowPulse = pulse
end

local function CreateOverlay(parent)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetFrameLevel(parent:GetFrameLevel() + OVERLAY_FRAME_LEVEL_OFFSET)
    overlay:SetScript("OnShow", StartGlow)
    overlay:SetScript("OnHide", StopGlow)

    local background = overlay:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(overlay)
    background:SetColorTexture(0, 0, 0, BACKGROUND_ALPHA)
    overlay.background = background

    local hoverBackground = overlay:CreateTexture(nil, "BACKGROUND", nil, 1)
    hoverBackground:SetPoint("TOPLEFT", overlay, "TOPLEFT", HOVER_BACKGROUND_INSET, -HOVER_BACKGROUND_INSET)
    hoverBackground:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -HOVER_BACKGROUND_INSET, HOVER_BACKGROUND_INSET)
    hoverBackground:SetColorTexture(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, HOVER_BACKGROUND_ALPHA)
    hoverBackground:Hide()
    overlay.hoverBackground = hoverBackground

    CreateGlow(overlay)

    local text = overlay:CreateFontString(nil, "OVERLAY")
    text:SetFont(NS.Media.GetPrimaryFont(), TEXT_SIZE, TEXT_FLAGS)
    text:SetTextColor(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B)
    text:SetPoint("LEFT", overlay, "LEFT", TEXT_SIDE_PADDING, 0)
    text:SetPoint("RIGHT", overlay, "RIGHT", -TEXT_SIDE_PADDING, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    overlay.text = text

    overlay.emptySlotTarget = ItemButton.CreateEmptySlotTarget(overlay)
    overlay.dropTargetDirty = true

    overlay:Hide()
    return overlay
end

local function SetManualDropActive(list, active)
    if list.manualDropActive == active then
        return
    end

    list.manualDropActive = active
    list.scrollBox:ClearAllPoints()
    list.scrollBox:SetPoint("TOPLEFT", list.header, "BOTTOMLEFT", Layout.ScrollBoxLeftOffset, Layout.ScrollBoxTopGap)

    if active then
        list.scrollBox:SetPoint("BOTTOMRIGHT", list.cursorDropOverlay, "TOPRIGHT", Layout.ScrollBoxRightOffset, 0)
    else
        list.scrollBox:SetPoint("BOTTOMRIGHT", list.frame, "BOTTOMRIGHT", Layout.ScrollBoxRightOffset, Layout.ScrollBoxBottomOffset)
    end

    Layout.PositionScrollBar(list.scrollBar, list.scrollBox)
end

local function SetOverlayMode(list, mode)
    local overlay = list.cursorDropOverlay
    if overlay.mode == mode then
        return
    end

    overlay.mode = mode
    overlay:ClearAllPoints()

    if mode == MODE_MANUAL then
        overlay:SetPoint("BOTTOMLEFT", list.frame, "BOTTOMLEFT", Layout.ScrollBoxLeftOffset, Layout.ScrollBoxBottomOffset)
        overlay:SetPoint("BOTTOMRIGHT", list.frame, "BOTTOMRIGHT", Layout.ScrollBoxRightOffset, Layout.ScrollBoxBottomOffset)
        overlay:SetHeight(MANUAL_OVERLAY_HEIGHT)
    else
        overlay:SetPoint("TOPLEFT", list.scrollBox, "TOPLEFT", 0, 0)
        overlay:SetPoint("BOTTOMRIGHT", list.scrollBox, "BOTTOMRIGHT", 0, 0)
    end

    RestartGlow(overlay)
end

local function IsCursorOverDropArea(list)
    if list.cursorDropOverlay.emptySlotTarget:IsMouseOver() then
        return true
    end

    if not list.frame:IsMouseOver() then
        return false
    end

    return not list.header:IsMouseOver()
end

local function HasCursorItemChanged(overlay, itemID, itemLink, sourceContainerID, sourceSlotIndex)
    return overlay.cursorItemID ~= itemID
        or overlay.cursorItemLink ~= itemLink
        or overlay.sourceContainerID ~= sourceContainerID
        or overlay.sourceSlotIndex ~= sourceSlotIndex
end

local function SetCursorItem(overlay, itemID, itemLink, sourceContainerID, sourceSlotIndex)
    overlay.cursorItemID = itemID
    overlay.cursorItemLink = itemLink
    overlay.sourceContainerID = sourceContainerID
    overlay.sourceSlotIndex = sourceSlotIndex
    overlay.dropTargetDirty = true
end

local function ClearCursorItem(overlay)
    overlay.cursorItemID = nil
    overlay.cursorItemLink = nil
    overlay.sourceContainerID = nil
    overlay.sourceSlotIndex = nil
    overlay.targetBagID = nil
    overlay.targetSlotIndex = nil
    overlay.dropTargetDirty = true
end

local function RefreshEmptySlotTarget(overlay)
    if overlay.targetBagID
        and not NS.BagManagement.IsPlayerContainerSlotEmpty(
            overlay.targetBagID,
            overlay.targetSlotIndex
        ) then
        overlay.dropTargetDirty = true
    end

    if overlay.dropTargetDirty then
        local bagID, slotIndex = NS.BagManagement.FindCursorItemEmptySlot(
            overlay.cursorItemID,
            overlay.cursorItemLink,
            overlay.sourceContainerID,
            overlay.sourceSlotIndex
        )
        overlay.targetBagID = bagID
        overlay.targetSlotIndex = slotIndex
        overlay.dropTargetDirty = false

        if bagID then
            ItemButton.SetEmptySlotTarget(overlay.emptySlotTarget, bagID, slotIndex)
        end
    end

    return overlay.targetBagID ~= nil
end

local function HideOverlay(list)
    local overlay = list.cursorDropOverlay
    overlay.dropText = nil
    SetManualDropActive(list, false)
    SetHovered(overlay, false)
    overlay:Hide()
end

function CursorDrop.Update(list)
    local overlay = list.cursorDropOverlay
    local itemID, itemLink, sourceContainerID, sourceSlotIndex = GetCursorItemData()

    if not itemID and not itemLink then
        ClearCursorItem(overlay)
        HideOverlay(list)
        return
    end

    if HasCursorItemChanged(overlay, itemID, itemLink, sourceContainerID, sourceSlotIndex) then
        SetCursorItem(overlay, itemID, itemLink, sourceContainerID, sourceSlotIndex)
    end

    if not IsCursorOverDropArea(list) or not RefreshEmptySlotTarget(overlay) then
        HideOverlay(list)
        return
    end

    if ListModel.IsManualSortKey(list.sortKey) then
        SetOverlayMode(list, MODE_MANUAL)
        SetManualDropActive(list, true)
    else
        SetManualDropActive(list, false)
        SetOverlayMode(list, MODE_FULL)
    end

    local dropText = GetDropText(itemID, itemLink)
    if overlay.dropText ~= dropText then
        overlay.text:SetText(dropText)
        overlay.dropText = dropText
    end

    overlay:Show()
    SetHovered(overlay, overlay.emptySlotTarget:IsMouseOver())
end

function CursorDrop.Attach(list)
    list.cursorDropOverlay = CreateOverlay(list.frame)

    NS.Inventory:RegisterUpdateCallback(function()
        list.cursorDropOverlay.dropTargetDirty = true
    end)

    local elapsedSinceUpdate = 0
    list.frame:SetScript("OnUpdate", function(_, elapsed)
        elapsedSinceUpdate = elapsedSinceUpdate + elapsed
        if elapsedSinceUpdate < UPDATE_INTERVAL then
            return
        end

        elapsedSinceUpdate = 0
        CursorDrop.Update(list)
    end)
end

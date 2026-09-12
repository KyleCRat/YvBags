local _, NS = ...

-- Native physical-slot targets for sorted insertion and Manual-mode placement.
local CursorDrop = {}
NS.ItemListCursorDrop = CursorDrop

local Layout = NS.ItemListLayout
local ListModel = NS.ItemListModel
local CursorItem = NS.CursorItem

local UPDATE_INTERVAL = 0.05
local OVERLAY_FRAME_LEVEL_OFFSET = 80
local MANUAL_OVERLAY_HEIGHT = 50
local TEXT_SIZE = 22
local TEXT_FLAGS = "OUTLINE, SLUG"
local DEFAULT_TEXT_FORMAT = "Place %s"
local DEFAULT_MERGE_TEXT_FORMAT = "Merge %s into an existing stack"
local FALLBACK_ITEM_NAME = "item"
local TEXT_SIDE_PADDING = 24
local BACKGROUND_ALPHA = 0.72
local HOVER_BACKGROUND_ALPHA = 0.18
local HOVER_BACKGROUND_INSET = 9
local GLOW_MIN_ALPHA = 0.35
local GLOW_MAX_ALPHA = 0.85
local GLOW_PULSE_DURATION = 0.85
local MODE_FULL = "full"
local MODE_MANUAL = "manual"

local function GetDropText(itemID, itemLink, textFormat)
    local itemName = itemLink
    if not itemName and itemID then
        if C_Item and C_Item.GetItemInfo then
            itemName = C_Item.GetItemInfo(itemID)
        elseif GetItemInfo then
            itemName = GetItemInfo(itemID)
        end
    end

    return (textFormat or DEFAULT_TEXT_FORMAT):format(
        itemName or FALLBACK_ITEM_NAME
    )
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

local function CreateGlow(parent, window)
    local glow = NS.Skins:CreateGlowBorder(parent, { geometryRoot = window })
    glow:SetAlpha(GLOW_MIN_ALPHA)

    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(GLOW_MIN_ALPHA)
    alpha:SetToAlpha(GLOW_MAX_ALPHA)
    alpha:SetDuration(GLOW_PULSE_DURATION)

    parent.glow = glow
    parent.glowPulse = pulse
end

local function CreateOverlay(list)
    local parent = list.frame
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetFrameLevel(parent:GetFrameLevel() + OVERLAY_FRAME_LEVEL_OFFSET)
    overlay:SetScript("OnShow", StartGlow)
    overlay:SetScript("OnHide", StopGlow)

    local background = NS.Skins:CreateTexture(overlay, { geometryRoot = list.window, layer = "BACKGROUND" })
    background:SetAllPoints(overlay)
    background:SetColorTexture(0, 0, 0, BACKGROUND_ALPHA)
    overlay.background = background

    local hoverBackground = NS.Skins:CreateTexture(overlay, {
        geometryRoot = list.window, layer = "BACKGROUND", sublevel = 1,
        colorToken = "accent", alpha = HOVER_BACKGROUND_ALPHA,
    })
    hoverBackground:SetPoint("TOPLEFT", overlay, "TOPLEFT", HOVER_BACKGROUND_INSET, -HOVER_BACKGROUND_INSET)
    hoverBackground:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -HOVER_BACKGROUND_INSET, HOVER_BACKGROUND_INSET)
    hoverBackground:Hide()
    overlay.hoverBackground = hoverBackground

    CreateGlow(overlay, list.window)

    local text = NS.Skins:CreateText(overlay, {
        geometryRoot = list.window, fontSize = TEXT_SIZE, fontFlags = TEXT_FLAGS, colorToken = "accent",
    })
    text:SetPoint("LEFT", overlay, "LEFT", TEXT_SIDE_PADDING, 0)
    text:SetPoint("RIGHT", overlay, "RIGHT", -TEXT_SIDE_PADDING, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    overlay.text = text

    overlay.dropTarget =
        list.context.itemButtonAdapter.CreateDropTarget(overlay, list)
    overlay.targetLocation = ItemLocation:CreateEmpty()
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
    if list.cursorDropOverlay.dropTarget:IsMouseOver() then
        return true
    end

    if not list.frame:IsMouseOver() then
        return false
    end

    return not list.header:IsMouseOver()
end

local function InvalidateTarget(overlay)
    overlay.dropTargetDirty = true
    if overlay.isMergeTarget then
        -- Lock/cursor events may be inside native input. Disable a stale merge
        -- target now, but leave rebinding to the next update or mouse press.
        overlay.dropTarget:Disable()
    end
end

local function ClearCursorItem(overlay)
    overlay.cursorRevision = nil
    overlay.targetBagID = nil
    overlay.targetSlotIndex = nil
    overlay.targetLocation:Clear()
    overlay.allowMerge = nil
    overlay.isMergeTarget = false
    overlay.dropTargetDirty = true
end

local function RefreshDropTarget(overlay, cursor)
    local list = overlay.list
    local dropContext = list.context.cursorDrop
    local allowMerge = not InCombatLockdown()
        and not ListModel.IsManualSortKey(list.sortKey)
        and CursorItem.CanMerge(cursor)

    if overlay.allowMerge ~= allowMerge then
        overlay.allowMerge = allowMerge
        InvalidateTarget(overlay)
    end

    if overlay.targetBagID and not overlay.dropTargetDirty then
        local valid
        if overlay.isMergeTarget then
            valid = CursorItem.GetMergeSlotInfo(
                cursor, overlay.targetBagID, overlay.targetSlotIndex,
                overlay.targetLocation
            )
        else
            valid = dropContext.isSlotEmpty(
                overlay.targetBagID, overlay.targetSlotIndex
            )
        end
        if not valid then
            InvalidateTarget(overlay)
        end
    end

    if overlay.dropTargetDirty then
        local bagID, slotIndex, info
        if allowMerge then
            local items, excludedBagID = dropContext.getMergeItems(cursor.location)
            if items then
                bagID, slotIndex, info = CursorItem.FindMergeSlot(
                    cursor, items, overlay.targetLocation, excludedBagID
                )
            end
        end
        if not bagID then
            bagID, slotIndex = dropContext.findEmptySlot(
                cursor.itemID, cursor.link, cursor.bagID, cursor.slotIndex
            )
        end
        overlay.targetBagID = bagID
        overlay.targetSlotIndex = slotIndex
        overlay.isMergeTarget = info ~= nil
        overlay.dropTargetDirty = false

        if bagID then
            list.context.itemButtonAdapter.SetDropTarget(
                overlay.dropTarget,
                bagID,
                slotIndex,
                info
            )
            overlay.dropTarget:Enable()
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

-- Keep polling while an item is held, even outside the list, to detect reentry.
function CursorDrop.Update(list)
    local overlay = list.cursorDropOverlay
    local cursor, revision = CursorItem.Get()

    if not cursor then
        ClearCursorItem(overlay)
        HideOverlay(list)
        return false
    end

    if overlay.cursorRevision ~= revision then
        overlay.cursorRevision = revision
        InvalidateTarget(overlay)
    end

    if not IsCursorOverDropArea(list) or not RefreshDropTarget(overlay, cursor) then
        HideOverlay(list)
        return true
    end

    if ListModel.IsManualSortKey(list.sortKey) then
        SetOverlayMode(list, MODE_MANUAL)
        SetManualDropActive(list, true)
    else
        SetManualDropActive(list, false)
        SetOverlayMode(list, MODE_FULL)
    end

    local textFormat = list.context.cursorDrop.textFormat
    if overlay.isMergeTarget then
        textFormat = list.context.cursorDrop.mergeTextFormat or DEFAULT_MERGE_TEXT_FORMAT
    end
    local dropText = GetDropText(cursor.itemID, cursor.link, textFormat)
    if overlay.dropText ~= dropText then
        overlay.text:SetText(dropText)
        overlay.dropText = dropText
    end

    overlay:Show()
    SetHovered(overlay, overlay.dropTarget:IsMouseOver())
    return true
end

function CursorDrop.Invalidate(list)
    InvalidateTarget(list.cursorDropOverlay)
end

function CursorDrop.Attach(list)
    list.cursorDropOverlay = CreateOverlay(list)
    list.cursorDropOverlay.list = list

    local elapsedSinceUpdate = 0
    local function StopPolling()
        elapsedSinceUpdate = 0
        list.frame:SetScript("OnUpdate", nil)
    end

    local function OnUpdate(_, elapsed)
        elapsedSinceUpdate = elapsedSinceUpdate + elapsed
        if elapsedSinceUpdate < UPDATE_INTERVAL then
            return
        end

        elapsedSinceUpdate = 0
        if not CursorDrop.Update(list) then
            StopPolling()
        end
    end

    local function RefreshNow()
        elapsedSinceUpdate = 0
        if list.frame:IsVisible() and CursorDrop.Update(list) then
            list.frame:SetScript("OnUpdate", OnUpdate)
        else
            StopPolling()
        end
    end

    local function Invalidate()
        InvalidateTarget(list.cursorDropOverlay)
    end

    local function QueueCursorRefresh()
        Invalidate()
        if list.frame:IsVisible() then
            -- CURSOR_CHANGED can fire inside native item input. Let the
            -- action and its post-hooks finish before selecting a target.
            elapsedSinceUpdate = UPDATE_INTERVAL
            list.frame:SetScript("OnUpdate", OnUpdate)
        end
    end

    local function RefreshTarget()
        Invalidate()
        RefreshNow()
    end

    list.context.cursorDrop.registerUpdateCallback(Invalidate)
    NS:RegisterEventHandler("CURSOR_CHANGED", QueueCursorRefresh)
    NS:RegisterEventHandler("PLAYER_REGEN_DISABLED", RefreshTarget)
    NS:RegisterEventHandler("PLAYER_REGEN_ENABLED", RefreshTarget)

    list.frame:HookScript("OnShow", RefreshTarget)
    list.frame:HookScript("OnHide", StopPolling)
    list.cursorDropOverlay.dropTarget:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            list.cursorDropOverlay.dropTargetDirty = true
            RefreshNow()
        end
    end)

    RefreshNow()
end

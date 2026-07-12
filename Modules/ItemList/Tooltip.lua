local _, NS = ...

-- Debounced native item tooltips and immediate cursor-feedback contract.
local ItemTooltip = {}
NS.ItemTooltip = ItemTooltip

local USE_CURSOR_ANCHOR = false
local ESTIMATED_TOOLTIP_WIDTH = 360
local ESTIMATED_TOOLTIP_HEIGHT = 240
local SCREEN_PADDING = 16
local CURSOR_OFFSET_X = 12
local CURSOR_OFFSET_Y = -12
local ROW_SIDE_OFFSET_X = 0
local ROW_SIDE_OFFSET_Y = 0
local TOOLTIP_SHOW_DELAY = 0.05
local SIDE_LEFT = "LEFT"
local SIDE_RIGHT = "RIGHT"

local hooked = false
local schedulerFrame
local pendingButton
local pendingElapsed = 0

-- Tooltip positioning
local function GetScreenSize()
    local width = GetScreenWidth and GetScreenWidth() or nil
    local height = GetScreenHeight and GetScreenHeight() or nil

    if UIParent then
        width = width or UIParent:GetWidth()
        height = height or UIParent:GetHeight()
    end

    return width or 0, height or 0
end

local function GetCursorUiPosition()
    if not GetCursorPosition then
        return nil, nil
    end

    local x, y = GetCursorPosition()
    if not x or not y then
        return nil, nil
    end

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if scale and scale > 0 then
        x = x / scale
        y = y / scale
    end

    return x, y
end

local function GetPreferredSide(row)
    local frame = NS.frame or row
    local cursorX = GetCursorUiPosition()
    local frameLeft = frame and frame:GetLeft()
    local frameRight = frame and frame:GetRight()

    if cursorX and frameLeft and frameRight then
        if math.abs(cursorX - frameLeft) <= math.abs(frameRight - cursorX) then
            return SIDE_LEFT
        end

        return SIDE_RIGHT
    end

    local rowCenter = row:GetCenter()
    local screenWidth = GetScreenSize()
    if rowCenter and screenWidth > 0 and rowCenter < (screenWidth / 2) then
        return SIDE_LEFT
    end

    return SIDE_RIGHT
end

local function GetAvailableSide(row, preferredSide)
    local screenWidth = GetScreenSize()
    local rowLeft = row:GetLeft()
    local rowRight = row:GetRight()

    if not rowLeft or not rowRight or screenWidth <= 0 then
        return preferredSide
    end

    local leftRoom = rowLeft - SCREEN_PADDING
    local rightRoom = screenWidth - rowRight - SCREEN_PADDING
    local leftFits = leftRoom >= ESTIMATED_TOOLTIP_WIDTH
    local rightFits = rightRoom >= ESTIMATED_TOOLTIP_WIDTH

    if preferredSide == SIDE_LEFT then
        if leftFits or (not rightFits and leftRoom >= rightRoom) then
            return SIDE_LEFT
        end

        return SIDE_RIGHT
    end

    if rightFits or (not leftFits and rightRoom >= leftRoom) then
        return SIDE_RIGHT
    end

    return SIDE_LEFT
end

local function AnchorToCursor(tooltip)
    local cursorX, cursorY = GetCursorUiPosition()
    if not cursorX or not cursorY then
        return
    end

    local screenWidth, screenHeight = GetScreenSize()
    local x = cursorX + CURSOR_OFFSET_X
    local y = cursorY + CURSOR_OFFSET_Y

    if screenWidth > 0 then
        x = math.max(SCREEN_PADDING, math.min(x, screenWidth - ESTIMATED_TOOLTIP_WIDTH - SCREEN_PADDING))
    end
    if screenHeight > 0 then
        y = math.max(ESTIMATED_TOOLTIP_HEIGHT + SCREEN_PADDING, math.min(y, screenHeight - SCREEN_PADDING))
    end

    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function AnchorToRowEdge(tooltip, row)
    local side = GetAvailableSide(row, GetPreferredSide(row))

    tooltip:ClearAllPoints()
    if side == SIDE_LEFT then
        if tooltip.SetAnchorType then
            tooltip:SetAnchorType("ANCHOR_LEFT", 0, 0)
        end
        tooltip:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", -ROW_SIDE_OFFSET_X, ROW_SIDE_OFFSET_Y)
    else
        if tooltip.SetAnchorType then
            tooltip:SetAnchorType("ANCHOR_RIGHT", 0, 0)
        end
        tooltip:SetPoint("BOTTOMLEFT", row, "TOPRIGHT", ROW_SIDE_OFFSET_X, ROW_SIDE_OFFSET_Y)
    end
end

local function AnchorRowTooltip(row, tooltip)
    if not row or not tooltip then
        return
    end

    if USE_CURSOR_ANCHOR then
        AnchorToCursor(tooltip)
    else
        AnchorToRowEdge(tooltip, row)
    end
end

-- Immediate cursor feedback and cleanup
local function IsRegisteredRowButton(button)
    local row = button and button.row
    return row and row.itemButton == button and button.usesCustomTooltipAnchor
end

local function CancelPendingTooltip(button)
    if pendingButton == button then
        pendingButton = nil
        pendingElapsed = 0
        if schedulerFrame then
            schedulerFrame:Hide()
        end
    end
end

local function ClearCursorState()
    if ResetCursor and not (SpellIsTargeting and SpellIsTargeting()) then
        ResetCursor()
    end

    if ClearCursorHoveredItem then
        ClearCursorHoveredItem()
    end
end

local function UpdateCursorState(button)
    if not button or not button.GetBagID or not button.GetID then
        return
    end

    if not (SpellIsTargeting and SpellIsTargeting()) then
        if IsModifiedClick and IsModifiedClick("DRESSUP") and button.HasItem and button:HasItem() then
            if ShowInspectCursor then
                ShowInspectCursor()
            end
        elseif MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
            if C_Container and C_Container.ShowContainerSellCursor then
                C_Container.ShowContainerSellCursor(button:GetBagID(), button:GetID())
            end
        elseif button.IsReadable and button:IsReadable() then
            if ShowInspectCursor then
                ShowInspectCursor()
            end
        elseif ResetCursor then
            ResetCursor()
        end
    end

    if ItemLocation and SetCursorHoveredItem then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(button:GetBagID(), button:GetID())
        if itemLocation and itemLocation:IsValid() then
            SetCursorHoveredItem(itemLocation)
        end
    end
end

local function HideTooltip(button)
    CancelPendingTooltip(button)

    if button and button.tooltipShown and button.OnLeave then
        button:OnLeave()
    else
        if GameTooltip_Hide then
            GameTooltip_Hide()
        elseif GameTooltip then
            GameTooltip:Hide()
        end

        ClearCursorState()
    end

    if button then
        button.tooltipShown = false
    end
end

-- Delayed native tooltip rendering
local function ShouldShowTooltip(button)
    return IsRegisteredRowButton(button) and button.IsMouseOver and button:IsMouseOver() and button.HasItem and button:HasItem()
end

local function ShowTooltip(button)
    pendingButton = nil
    pendingElapsed = 0
    if schedulerFrame then
        schedulerFrame:Hide()
    end

    if not ShouldShowTooltip(button) then
        return
    end

    if ContainerFrameItemButton_OnEnter then
        ContainerFrameItemButton_OnEnter(button)
    elseif button.OnEnter then
        button:OnEnter()
    end

    button.tooltipShown = true
end

local function EnsureSchedulerFrame()
    if schedulerFrame then
        return schedulerFrame
    end

    schedulerFrame = CreateFrame("Frame")
    schedulerFrame:Hide()
    schedulerFrame:SetScript("OnUpdate", function(_, elapsed)
        if not pendingButton then
            schedulerFrame:Hide()
            return
        end

        pendingElapsed = pendingElapsed + elapsed
        if pendingElapsed < TOOLTIP_SHOW_DELAY then
            return
        end

        ShowTooltip(pendingButton)
    end)

    return schedulerFrame
end

local function ScheduleTooltip(button)
    pendingButton = button
    pendingElapsed = 0
    EnsureSchedulerFrame():Show()
end

local function OnRowButtonEnter(button)
    button.tooltipShown = false
    UpdateCursorState(button)
    ScheduleTooltip(button)
end

local function OnRowButtonLeave(button)
    HideTooltip(button)
end

-- Public tooltip contract
function ItemTooltip.Initialize()
    if hooked or not hooksecurefunc or not ContainerFrameItemButton_CalculateItemTooltipAnchors then
        return
    end

    hooksecurefunc("ContainerFrameItemButton_CalculateItemTooltipAnchors", function(button, tooltip)
        if IsRegisteredRowButton(button) then
            AnchorRowTooltip(button.row, tooltip)
        end
    end)

    hooked = true
end

function ItemTooltip.RegisterRowButton(button)
    if not button then
        return
    end

    button.usesCustomTooltipAnchor = true
    button:SetScript("OnEnter", OnRowButtonEnter)
    button:SetScript("OnLeave", OnRowButtonLeave)
    ItemTooltip.Initialize()
end

function ItemTooltip.ResetButton(button)
    if pendingButton == button or button.tooltipShown or (button.IsMouseOver and button:IsMouseOver()) then
        HideTooltip(button)
    end
end

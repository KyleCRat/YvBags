local _, NS = ...

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
local SIDE_LEFT = "LEFT"
local SIDE_RIGHT = "RIGHT"

local hooked = false

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

local function IsRegisteredRowButton(button)
    local row = button and button.row
    return row and row.itemButton == button and button.usesCustomTooltipAnchor
end

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
    ItemTooltip.Initialize()
end

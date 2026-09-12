local _, NS = ...

-- Pooled noninteractive divider between direct item-row partitions.
local DividerRow = {}
NS.ItemSectionDividerRow = DividerRow

local ROW_HEIGHT = 12
local DIVIDER_LEFT_OFFSET = 2
local DIVIDER_RIGHT_OFFSET = 2
local DIVIDER_ALPHA = 0.55
local DIVIDER_LAYER = "ARTWORK"
local DIVIDER_SUBLEVEL = 0

local function GetRightClipPadding(row)
    return row.rightClipPadding or 0
end

local function InitializeRow(row, owner)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(false)

    row.dividerTexture, row.divider = NS.Skins:CreateSeparator(row, {
        geometryRoot = owner.window,
        left = DIVIDER_LEFT_OFFSET,
        right = DIVIDER_RIGHT_OFFSET + GetRightClipPadding(row),
        alpha = DIVIDER_ALPHA,
        layer = DIVIDER_LAYER,
        sublevel = DIVIDER_SUBLEVEL,
        clip = owner.scrollBox,
    })

    row.sectionDividerInitialized = true
end

function DividerRow.GetRowHeight()
    return ROW_HEIGHT
end

function DividerRow.Render(row, owner)
    if not row.sectionDividerInitialized then
        InitializeRow(row, owner)
    end

    row.divider:SetShown(true)
end

function DividerRow.Reset(row)
    row.divider:SetShown(false)
end

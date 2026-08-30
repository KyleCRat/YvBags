local _, NS = ...

-- Pooled noninteractive divider between direct item-row partitions.
local DividerRow = {}
NS.ItemSectionDividerRow = DividerRow

local Media = NS.Media

local ROW_HEIGHT = 12
local DIVIDER_HEIGHT = 12
local DIVIDER_LEFT_OFFSET = 2
local DIVIDER_RIGHT_OFFSET = -2
local DIVIDER_ALPHA = 0.55
local DIVIDER_LAYER = "ARTWORK"
local DIVIDER_SUBLEVEL = 0

local function GetRightClipPadding(row)
    return row.rightClipPadding or 0
end

local function Layout(row)
    row.divider:ClearAllPoints()
    row.divider:SetPoint("LEFT", row, "LEFT", DIVIDER_LEFT_OFFSET, 0)
    row.divider:SetPoint(
        "RIGHT",
        row,
        "RIGHT",
        DIVIDER_RIGHT_OFFSET - GetRightClipPadding(row),
        0
    )
end

local function InitializeRow(row)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(false)

    row.divider = row:CreateTexture(nil, DIVIDER_LAYER)
    row.divider:SetDrawLayer(DIVIDER_LAYER, DIVIDER_SUBLEVEL)
    row.divider:SetTexture(Media.GetDividerTexture())
    row.divider:SetBlendMode("ADD")
    row.divider:SetHeight(DIVIDER_HEIGHT)
    Layout(row)

    row.sectionDividerInitialized = true
end

function DividerRow.GetRowHeight()
    return ROW_HEIGHT
end

function DividerRow.Render(row)
    if not row.sectionDividerInitialized then
        InitializeRow(row)
    end

    local r, g, b = Media.GetAccentColor()
    row.divider:SetVertexColor(r, g, b, DIVIDER_ALPHA)
    Layout(row)
    row.divider:Show()
end

function DividerRow.Reset(row)
    row.divider:Hide()
end

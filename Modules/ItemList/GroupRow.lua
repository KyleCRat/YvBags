local _, NS = ...

-- Pooled group-row visuals and collapse interaction contract.
local GroupRow = {}
NS.ItemGroupRow = GroupRow

local Pixel = LibStub("LibYvSkins-1.0").Pixel
local CONTENT_HEIGHT = 31
local TOP_MARGIN = 4
local BOTTOM_MARGIN = 2
local ROW_HEIGHT = CONTENT_HEIGHT + BOTTOM_MARGIN
local FLAT_LEFT_MARGIN = 4
local TEXT_SIZE = 16
local CONTENT_FRAME_LEVEL_OFFSET = 2

-- Row construction and visual state
local function GetTopMargin(groupData)
    return groupData.hasPreviousRow and TOP_MARGIN or 0
end

local function LayoutContent(row)
    row.contentClip:SetFrameLevel(row:GetFrameLevel() + CONTENT_FRAME_LEVEL_OFFSET)
    local flat = NS.Skins:GetAppliedSkin() == "flat"
    local left = flat and FLAT_LEFT_MARGIN or 0
    local top = GetTopMargin(row.groupData)
    if flat then
        -- Keep the thin border inside native clipping without adding the
        -- inter-group margin above the first row.
        top = top + Pixel.GetPhysicalSize(row, 1)
    end
    if row.contentLeft == left and row.contentTop == top
        and row.contentRight == row.rightClipPadding then
        return
    end
    row.contentLeft, row.contentTop, row.contentRight = left, top, row.rightClipPadding
    row.contentClip:ClearAllPoints()
    row.contentClip:SetPoint("TOPLEFT", row, "TOPLEFT", left, -top)
    row.contentClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -row.rightClipPadding, BOTTOM_MARGIN)
end

local function InitializeRow(row, owner)
    row:SetHeight(GroupRow.GetRowHeight(row.groupData))
    row:EnableMouse(false)

    row.contentClip = CreateFrame("Frame", nil, row)
    LayoutContent(row)
    row.contentClip:SetClipsChildren(true)

    row.header, row.headerAppearance = NS.Skins:CreateExpandableHeader(row.contentClip, {
        geometryRoot = owner.window,
        clip = owner.scrollBox,
        height = CONTENT_HEIGHT,
        font = NS.Media.GetPrimaryFont(),
        fontSize = TEXT_SIZE,
        onClick = function()
            if row.owner and row.groupID then
                row.owner:ToggleGroupCollapsed(row.groupID)
            end
        end,
    })
    row.header:SetAllPoints(row.contentClip)

    row.groupInitialized = true
end

-- Public row contract
function GroupRow.GetRowHeight(groupData)
    return ROW_HEIGHT + GetTopMargin(groupData)
end

function GroupRow.Render(row, groupData, owner)
    row.owner = owner
    row.groupID = groupData.groupID
    row.groupData = groupData

    if not row.groupInitialized then
        InitializeRow(row, owner)
    end

    LayoutContent(row)
    row.header:SetText(("%s (%d)"):format(groupData.label or "", groupData.count or 0))
    row.headerAppearance:SetExpanded(not groupData.collapsed)
    row.headerAppearance:SetShown(true)
end

function GroupRow.RefreshGeometry(row)
    LayoutContent(row)
    if NS.Skins:GetAppliedSkin() == "flat" then
        row.headerAppearance:RefreshGeometry()
    end
end

function GroupRow.Reset(row)
    row.headerAppearance:SetShown(false)
    row.headerAppearance:SetExpanded(true)
    row.header:SetText("")
    row.owner = nil
    row.groupID = nil
    row.groupData = nil
end

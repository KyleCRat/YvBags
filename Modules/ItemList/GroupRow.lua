local _, NS = ...

-- Pooled group-row visuals and collapse interaction contract.
local GroupRow = {}
NS.ItemGroupRow = GroupRow

local CONTENT_HEIGHT = 31
local BOTTOM_MARGIN = 2
local ROW_HEIGHT = CONTENT_HEIGHT + BOTTOM_MARGIN
local TEXT_SIZE = 16
local CONTENT_FRAME_LEVEL_OFFSET = 2

-- Row construction and visual state
local function LayoutContent(row)
    row.contentClip:SetFrameLevel(row:GetFrameLevel() + CONTENT_FRAME_LEVEL_OFFSET)
    row.contentClip:ClearAllPoints()
    row.contentClip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.contentClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -row.rightClipPadding, BOTTOM_MARGIN)
end

local function InitializeRow(row, owner)
    row:SetHeight(ROW_HEIGHT)
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
function GroupRow.GetRowHeight()
    return ROW_HEIGHT
end

function GroupRow.Render(row, groupData, owner)
    if not row.groupInitialized then
        InitializeRow(row, owner)
    end

    row.owner = owner
    row.groupID = groupData.groupID
    row.groupData = groupData

    LayoutContent(row)
    row.header:SetText(("%s (%d)"):format(groupData.label or "", groupData.count or 0))
    row.headerAppearance:SetExpanded(not groupData.collapsed)
    row.headerAppearance:SetShown(true)
end

function GroupRow.Reset(row)
    row.headerAppearance:SetShown(false)
    row.headerAppearance:SetExpanded(true)
    row.header:SetText("")
    row.owner = nil
    row.groupID = nil
    row.groupData = nil
end

local _, NS = ...

local GroupRow = {}
NS.ItemGroupRow = GroupRow

local Media = NS.Media

local CONTENT_HEIGHT = 31
local BOTTOM_MARGIN = 2
local ROW_HEIGHT = CONTENT_HEIGHT + BOTTOM_MARGIN
local TEXT_SIZE = 18
local TOGGLE_ICON_SIZE = 29
local TOGGLE_ICON_LEFT_OFFSET = 4
local TOGGLE_ICON_TEXT_GAP = 4
local TEXT_LEFT_OFFSET = TOGGLE_ICON_LEFT_OFFSET + TOGGLE_ICON_SIZE + TOGGLE_ICON_TEXT_GAP
local TEXT_RIGHT_OFFSET = -8
local FONT_STRING_LAYER = "OVERLAY"
local HIGHLIGHT_LAYER = "BACKGROUND"
local HIGHLIGHT_SUBLEVEL = -8
local BORDER_LAYER = "ARTWORK"
local BORDER_SUBLEVEL = 0
local TOGGLE_LAYER = "ARTWORK"
local TOGGLE_SUBLEVEL = 6
local CONTENT_FRAME_LEVEL_OFFSET = 2
local HIGHLIGHT_COLOR_R = 1
local HIGHLIGHT_COLOR_G = 0.82
local HIGHLIGHT_COLOR_B = 0
local HIGHLIGHT_ALPHA = 0.14
local DIVIDER_HEIGHT = 12
local DIVIDER_LEFT_OFFSET = 2
local DIVIDER_RIGHT_OFFSET = -2
local DIVIDER_BOTTOM_OFFSET = -5
local DIVIDER_COLOR_R = 1
local DIVIDER_COLOR_G = 0.82
local DIVIDER_COLOR_B = 0.34
local DIVIDER_ALPHA = 0.55
local TEXT_COLOR_R = 1
local TEXT_COLOR_G = 0.82
local TEXT_COLOR_B = 0
local TOGGLE_BUTTON_TEXTURE = "Interface\\Common\\CommonButtonAssets2x"
local TOGGLE_TEXCOORDS = {
    expanded = {
        normal = { 0.00390625, 0.23046875, 0.0078125, 0.4609375 },
        pressed = { 0.23828125, 0.46484375, 0.0078125, 0.4609375 },
        disabled = { 0.00390625, 0.23046875, 0.4765625, 0.9296875 },
    },
    collapsed = {
        normal = { 0.23828125, 0.46484375, 0.4765625, 0.9296875 },
        pressed = { 0.47265625, 0.69921875, 0.4765625, 0.9296875 },
        disabled = { 0.47265625, 0.69921875, 0.0078125, 0.4609375 },
    },
}

local function GetPrimaryFont()
    return NS.Media and NS.Media.GetPrimaryFont and NS.Media.GetPrimaryFont() or STANDARD_TEXT_FONT
end

local function GetRightClipPadding(row)
    return row.rightClipPadding or 0
end

local function UpdateContentFrameLevel(row)
    if row.contentClip and row.GetFrameLevel and row.contentClip.SetFrameLevel then
        row.contentClip:SetFrameLevel(row:GetFrameLevel() + CONTENT_FRAME_LEVEL_OFFSET)
    end
end

local function AnchorContentClip(row)
    row.contentClip:ClearAllPoints()
    row.contentClip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.contentClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -GetRightClipPadding(row), BOTTOM_MARGIN)
end

local function AnchorDivider(row)
    row.divider:ClearAllPoints()
    row.divider:SetPoint("BOTTOMLEFT", row.contentClip, "BOTTOMLEFT", DIVIDER_LEFT_OFFSET, DIVIDER_BOTTOM_OFFSET)
    row.divider:SetPoint("BOTTOMRIGHT", row.contentClip, "BOTTOMRIGHT", DIVIDER_RIGHT_OFFSET, DIVIDER_BOTTOM_OFFSET)
end

local function SetTextureCoords(texture, coords)
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

local function UpdateToggleIcon(row, pressed)
    if not row.toggleIcon then
        return
    end

    local state = row.groupData and row.groupData.collapsed and "collapsed" or "expanded"
    local textureState = pressed and "pressed" or "normal"
    SetTextureCoords(row.toggleIcon, TOGGLE_TEXCOORDS[state][textureState])
end

local function InitializeRow(row)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

    row.highlight = row:CreateTexture(nil, HIGHLIGHT_LAYER)
    row.highlight:SetDrawLayer(HIGHLIGHT_LAYER, HIGHLIGHT_SUBLEVEL)
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(HIGHLIGHT_COLOR_R, HIGHLIGHT_COLOR_G, HIGHLIGHT_COLOR_B, HIGHLIGHT_ALPHA)
    row.highlight:Hide()

    row.contentClip = CreateFrame("Frame", nil, row)
    UpdateContentFrameLevel(row)
    AnchorContentClip(row)
    if row.contentClip.SetClipsChildren then
        row.contentClip:SetClipsChildren(true)
    end

    row.divider = row:CreateTexture(nil, BORDER_LAYER)
    row.divider:SetDrawLayer(BORDER_LAYER, BORDER_SUBLEVEL)
    row.divider:SetTexture(Media.GetDividerTexture())
    row.divider:SetBlendMode("ADD")
    row.divider:SetHeight(DIVIDER_HEIGHT)
    AnchorDivider(row)
    row.divider:SetVertexColor(DIVIDER_COLOR_R, DIVIDER_COLOR_G, DIVIDER_COLOR_B, DIVIDER_ALPHA)

    row.toggleIcon = row.contentClip:CreateTexture(nil, TOGGLE_LAYER)
    row.toggleIcon:SetDrawLayer(TOGGLE_LAYER, TOGGLE_SUBLEVEL)
    row.toggleIcon:SetTexture(TOGGLE_BUTTON_TEXTURE)
    row.toggleIcon:SetSize(TOGGLE_ICON_SIZE, TOGGLE_ICON_SIZE)
    row.toggleIcon:SetPoint("LEFT", row.contentClip, "LEFT", TOGGLE_ICON_LEFT_OFFSET, 0)

    row.label = row.contentClip:CreateFontString(nil, FONT_STRING_LAYER)
    row.label:SetFont(GetPrimaryFont(), TEXT_SIZE)
    row.label:SetTextColor(TEXT_COLOR_R, TEXT_COLOR_G, TEXT_COLOR_B)
    row.label:SetJustifyH("LEFT")
    row.label:SetJustifyV("MIDDLE")
    row.label:SetPoint("LEFT", row.contentClip, "LEFT", TEXT_LEFT_OFFSET, 0)
    row.label:SetPoint("RIGHT", row.contentClip, "RIGHT", TEXT_RIGHT_OFFSET, 0)
    row.label:SetWordWrap(false)
    row.label:SetMaxLines(1)

    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
    end)

    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        UpdateToggleIcon(self, false)
    end)

    row:SetScript("OnMouseDown", function(self)
        UpdateToggleIcon(self, true)
    end)

    row:SetScript("OnMouseUp", function(self)
        UpdateToggleIcon(self, false)
    end)

    row:SetScript("OnClick", function(self)
        if self.owner and self.groupID then
            self.owner:ToggleGroupCollapsed(self.groupID)
        end
    end)

    row.groupInitialized = true
end

function GroupRow.GetRowHeight()
    return ROW_HEIGHT
end

function GroupRow.Render(row, groupData, owner)
    if not row.groupInitialized then
        InitializeRow(row)
    end

    row.owner = owner
    row.groupID = groupData.groupID
    row.groupData = groupData

    if row.contentClip then
        UpdateContentFrameLevel(row)
        AnchorContentClip(row)
    end

    if row.divider and row.contentClip then
        AnchorDivider(row)
    end

    UpdateToggleIcon(row, false)
    row.label:SetText(("%s (%d)"):format(groupData.label or "", groupData.count or 0))
end

function GroupRow.Reset(row)
    row.owner = nil
    row.groupID = nil
    row.groupData = nil

    if row.highlight then
        row.highlight:Hide()
    end

    if row.label then
        row.label:SetText("")
    end
end

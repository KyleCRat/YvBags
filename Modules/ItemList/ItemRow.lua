local _, NS = ...

-- Pooled item-row visual contract. Interaction and cooldowns live separately.
local ItemRow = {}
NS.ItemRow = ItemRow

local Columns = NS.ItemListColumns
local Cooldown = NS.ItemRowCooldown
local ItemButton = NS.ItemRowButton

-- Row geometry
local ROW_HEIGHT = 31
local ICON_SIZE = 23
local ICON_FRAME_SIZE = 29
local PROFESSION_QUALITY_ICON_SIZE = 22
local BINDING_ICON_SIZE = 22
local ICON_LEFT_OFFSET = 3
local PIN_MARKER_SIZE = 16
local ICON_TEX_COORD_LEFT = 0.08
local ICON_TEX_COORD_RIGHT = 0.92
local ICON_TEX_COORD_TOP = 0.08
local ICON_TEX_COORD_BOTTOM = 0.92
local ROW_TEXT_SIZE = 16

-- Visual state
local DEFAULT_HIGHLIGHT_COLOR_R = 1
local DEFAULT_HIGHLIGHT_COLOR_G = 1
local DEFAULT_HIGHLIGHT_COLOR_B = 1
local DEFAULT_ICON_BORDER_COLOR_R = 0.55
local DEFAULT_ICON_BORDER_COLOR_G = 0.55
local DEFAULT_ICON_BORDER_COLOR_B = 0.55
local RARITY_HIGHLIGHT_ALPHA = 0.16
local DEFAULT_HIGHLIGHT_ALPHA = 0.08
local CONTAINER_HIGHLIGHT_ALPHA = 0.14
local PIN_MARKER_ALPHA = 0.82
local FALLBACK_ITEM_ICON = 134400
local CONTAINER_HIGHLIGHT_COLOR_R, CONTAINER_HIGHLIGHT_COLOR_G, CONTAINER_HIGHLIGHT_COLOR_B = NS.Media.GetAccentColor()

-- Draw layers
local ROW_HIGHLIGHT_LAYER = "BACKGROUND"
local ROW_ICON_LAYER = "ARTWORK"
local ROW_ICON_SUBLEVEL = 5
local ICON_BORDER_LAYER = "ARTWORK"
local ICON_BORDER_SUBLEVEL = 7
local PROFESSION_QUALITY_LAYER = "ARTWORK"
local PROFESSION_QUALITY_SUBLEVEL = 7
local BINDING_ICON_LAYER = "ARTWORK"
local BINDING_ICON_SUBLEVEL = 7
local PIN_MARKER_LAYER = "OVERLAY"
local PIN_MARKER_SUBLEVEL = 2

local function IsTextColumn(column)
    return column.key ~= "icon" and column.key ~= "binding" and column.key ~= "professionQuality"
end

local function GetRightClipPadding(row)
    return row.rightClipPadding or 0
end

-- Highlight and border state
local function UpdateRowHighlightColor(row, item)
    local color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color then
        row.highlight:SetColorTexture(color.r, color.g, color.b, RARITY_HIGHLIGHT_ALPHA)
    else
        row.highlight:SetColorTexture(DEFAULT_HIGHLIGHT_COLOR_R, DEFAULT_HIGHLIGHT_COLOR_G, DEFAULT_HIGHLIGHT_COLOR_B, DEFAULT_HIGHLIGHT_ALPHA)
    end
end

local function UpdateIconBorderColor(row, item)
    local color = Columns.GetItemIconBorderColor(item)
    if not color then
        color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    end

    if color then
        row.iconBorder:SetVertexColor(color.r, color.g, color.b, 1)
    else
        row.iconBorder:SetVertexColor(DEFAULT_ICON_BORDER_COLOR_R, DEFAULT_ICON_BORDER_COLOR_G, DEFAULT_ICON_BORDER_COLOR_B, 1)
    end

    row.iconBorder:Show()
end

local function UpdateContainerHighlight(row)
    local highlighted = row.item ~= nil
        and row.highlightedBagID ~= nil
        and row.item.bagID == row.highlightedBagID
    row.containerHighlight:SetShown(highlighted)
end

local function UpdatePinMarker(row, item)
    if not item.isPinned then
        row.pinMarker:Hide()
        return
    end

    local r, g, b = NS.Media.GetAccentColor()
    row.pinMarker:SetVertexColor(r, g, b, PIN_MARKER_ALPHA)
    row.pinMarker:Show()
end

-- Row construction and layout
local function LayoutRow(row)
    local columns = Columns.GetColumns()
    local columnGap = Columns.GetColumnGap()
    local xOffset = 0

    row.contentClip:ClearAllPoints()
    row.contentClip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.contentClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -GetRightClipPadding(row), 0)
    Cooldown.LayoutShade(row)

    for _, column in ipairs(columns) do
        local columnCenterX = xOffset + (column.width / 2)

        if column.key == "icon" then
            local iconCenterX = xOffset + ICON_LEFT_OFFSET + (ICON_FRAME_SIZE / 2)
            row.iconBorder:ClearAllPoints()
            row.iconBorder:SetPoint("CENTER", row.contentClip, "LEFT", iconCenterX, 0)
            row.iconBorder:SetSize(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("CENTER", row.contentClip, "LEFT", iconCenterX, 0)
            row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        elseif column.key == "binding" then
            row.bindingIcon:ClearAllPoints()
            row.bindingIcon:SetPoint("CENTER", row.contentClip, "LEFT", columnCenterX, 0)
        elseif column.key == "professionQuality" then
            row.professionQualityIcon:ClearAllPoints()
            row.professionQualityIcon:SetPoint("CENTER", row.contentClip, "LEFT", columnCenterX, 0)
        end

        if IsTextColumn(column) then
            local text = row.text[column.key]
            text:ClearAllPoints()
            text:SetPoint("LEFT", row.contentClip, "LEFT", xOffset, 0)
            text:SetSize(column.width, ROW_HEIGHT)
            text:SetJustifyH(column.justify or "LEFT")
        end

        xOffset = xOffset + column.width + columnGap
    end
end

local function CreateTextColumns(row, columns)
    row.text = {}
    for _, column in ipairs(columns) do
        if IsTextColumn(column) then
            local text = row.contentClip:CreateFontString(nil, "OVERLAY")
            text:SetFont(NS.Media.GetPrimaryFont(), ROW_TEXT_SIZE)
            text:SetJustifyV("MIDDLE")
            text:SetWordWrap(false)
            text:SetMaxLines(1)
            if column.key ~= "name" then
                Columns.SetDefaultTextColor(text)
            end
            row.text[column.key] = text
        end
    end
end

local function InitializeRow(row)
    local columns = Columns.GetColumns()

    row:SetHeight(ROW_HEIGHT)
    row:SetClipsChildren(true)
    row:EnableMouse(false)
    row:SetID(0)

    row.containerHighlight = row:CreateTexture(nil, ROW_HIGHLIGHT_LAYER)
    row.containerHighlight:SetAllPoints(row)
    row.containerHighlight:SetColorTexture(CONTAINER_HIGHLIGHT_COLOR_R, CONTAINER_HIGHLIGHT_COLOR_G, CONTAINER_HIGHLIGHT_COLOR_B, CONTAINER_HIGHLIGHT_ALPHA)
    row.containerHighlight:Hide()

    row.highlight = row:CreateTexture(nil, ROW_HIGHLIGHT_LAYER)
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(DEFAULT_HIGHLIGHT_COLOR_R, DEFAULT_HIGHLIGHT_COLOR_G, DEFAULT_HIGHLIGHT_COLOR_B, DEFAULT_HIGHLIGHT_ALPHA)
    row.highlight:Hide()

    row.contentClip = CreateFrame("Frame", nil, row)
    row.contentClip:SetClipsChildren(true)

    row.pinMarker = row.contentClip:CreateTexture(nil, PIN_MARKER_LAYER)
    row.pinMarker:SetDrawLayer(PIN_MARKER_LAYER, PIN_MARKER_SUBLEVEL)
    row.pinMarker:SetTexture(NS.Media.GetPinnedTexture())
    row.pinMarker:SetSize(PIN_MARKER_SIZE, PIN_MARKER_SIZE)
    row.pinMarker:SetPoint("TOPLEFT", row.contentClip, "TOPLEFT", 0, 0)
    row.pinMarker:Hide()

    row.icon = row.contentClip:CreateTexture(nil, ROW_ICON_LAYER)
    row.icon:SetDrawLayer(ROW_ICON_LAYER, ROW_ICON_SUBLEVEL)
    row.icon:SetTexCoord(ICON_TEX_COORD_LEFT, ICON_TEX_COORD_RIGHT, ICON_TEX_COORD_TOP, ICON_TEX_COORD_BOTTOM)
    row.icon:Hide()

    row.iconBorder = row.contentClip:CreateTexture(nil, ICON_BORDER_LAYER)
    row.iconBorder:SetDrawLayer(ICON_BORDER_LAYER, ICON_BORDER_SUBLEVEL)
    row.iconBorder:SetTexture(NS.Media.GetIconBorderTexture())
    row.iconBorder:Hide()

    Cooldown.CreateShade(row)
    row.itemButton = ItemButton.Create(row)
    CreateTextColumns(row, columns)

    row.professionQualityIcon = row.contentClip:CreateTexture(nil, PROFESSION_QUALITY_LAYER)
    row.professionQualityIcon:SetSize(PROFESSION_QUALITY_ICON_SIZE, PROFESSION_QUALITY_ICON_SIZE)
    row.professionQualityIcon:SetDrawLayer(PROFESSION_QUALITY_LAYER, PROFESSION_QUALITY_SUBLEVEL)
    row.professionQualityIcon:Hide()

    row.bindingIcon = row.contentClip:CreateTexture(nil, BINDING_ICON_LAYER)
    row.bindingIcon:SetSize(BINDING_ICON_SIZE, BINDING_ICON_SIZE)
    row.bindingIcon:SetDrawLayer(BINDING_ICON_LAYER, BINDING_ICON_SUBLEVEL)
    row.bindingIcon:Hide()

    LayoutRow(row)
    row.rowInitialized = true
end

local function RenderProfessionQuality(row, item)
    local atlas = Columns.GetProfessionQualityAtlas(item)
    if atlas then
        row.professionQualityIcon:SetAtlas(atlas, false)
        row.professionQualityIcon:Show()
    else
        row.professionQualityIcon:Hide()
    end
end

local function RenderBinding(row, item)
    local iconInfo = Columns.GetBindingIconInfo(item)
    if not iconInfo then
        row.bindingIcon:Hide()
        return
    end

    row.bindingIcon:SetSize(iconInfo.size or BINDING_ICON_SIZE, iconInfo.size or BINDING_ICON_SIZE)
    if iconInfo.atlas then
        row.bindingIcon:SetAtlas(iconInfo.atlas, false)
    else
        row.bindingIcon:SetTexture(iconInfo.texture)
        row.bindingIcon:SetTexCoord(0, 1, 0, 1)
    end
    row.bindingIcon:SetDesaturated(iconInfo.desaturated)

    local color = iconInfo.color
    if color then
        row.bindingIcon:SetVertexColor(color.r, color.g, color.b, 1)
    else
        row.bindingIcon:SetVertexColor(1, 1, 1, 1)
    end
    row.bindingIcon:Show()
end

local function RenderText(row, item)
    for _, column in ipairs(Columns.GetColumns()) do
        if IsTextColumn(column) then
            local text = row.text[column.key]
            if column.key == "name" then
                Cooldown.SetName(row)
            else
                text:SetText(Columns.FormatColumn(item, column.key))
            end
            Columns.ApplyTextColor(text, column.key, item)
        end
    end
end

-- Public row contract
function ItemRow.GetRowHeight()
    return ROW_HEIGHT
end

function ItemRow.ClearCooldownCache()
    Cooldown.ClearCache()
end

function ItemRow.RefreshCooldown(row)
    Cooldown.Refresh(row)
end

function ItemRow.SetHighlightedBagID(row, highlightedBagID)
    row.highlightedBagID = highlightedBagID
    UpdateContainerHighlight(row)
end

function ItemRow.Render(row, item, list)
    if not row.rowInitialized then
        InitializeRow(row)
    end

    row.item = item
    if list then
        row.highlightedBagID = list.highlightedBagID
    end

    UpdateRowHighlightColor(row, item)
    UpdateContainerHighlight(row)
    UpdatePinMarker(row, item)
    UpdateIconBorderColor(row, item)
    ItemButton.Update(row.itemButton, item)

    row.icon:SetTexture(item.icon or FALLBACK_ITEM_ICON)
    row.icon:SetDesaturated(item.isLocked)
    row.icon:Show()

    RenderProfessionQuality(row, item)
    RenderBinding(row, item)
    RenderText(row, item)
    Cooldown.Update(row, item)
end

function ItemRow.Reset(row)
    row.item = nil
    row.highlightedBagID = nil
    row:SetID(0)
    row.highlight:Hide()
    row.containerHighlight:Hide()
    row.pinMarker:Hide()
    Cooldown.Clear(row)

    row.icon:SetTexture(nil)
    row.icon:SetDesaturated(false)
    row.icon:Hide()
    row.iconBorder:Hide()
    ItemButton.Reset(row.itemButton)
    row.professionQualityIcon:Hide()

    row.bindingIcon:SetSize(BINDING_ICON_SIZE, BINDING_ICON_SIZE)
    row.bindingIcon:SetTexture(nil)
    row.bindingIcon:SetTexCoord(0, 1, 0, 1)
    row.bindingIcon:SetDesaturated(false)
    row.bindingIcon:SetVertexColor(1, 1, 1, 1)
    row.bindingIcon:Hide()

    for _, text in pairs(row.text) do
        text:SetText("")
    end
end

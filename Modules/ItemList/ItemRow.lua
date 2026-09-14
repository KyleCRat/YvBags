local _, NS = ...

-- Pooled item-row visual contract. Interaction and cooldowns live separately.
local ItemRow = {}
NS.ItemRow = ItemRow

local Columns = NS.ItemListColumns
local Cooldown = NS.ItemRowCooldown

-- Row geometry
local ROW_HEIGHT = 31
local ICON_SIZE = 23
local ICON_FRAME_SIZE = 29
local PROFESSION_QUALITY_ICON_SIZE = 22
local BINDING_ICON_SIZE = 22
local ICON_LEFT_OFFSET = 3
local NEW_ITEM_MARKER_SIZE = NS.ItemListLayout.ItemMarkerWidth
local PIN_MARKER_SIZE = 16
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
local NEW_ITEM_HIGHLIGHT_MIN_ALPHA = 0.04
local NEW_ITEM_HIGHLIGHT_MAX_ALPHA = 0.12
local NEW_ITEM_HIGHLIGHT_HALF_DURATION = 1
local NEW_ITEM_MARKER_ALPHA = 0.9
local PIN_MARKER_ALPHA = 0.82
local FALLBACK_ITEM_ICON = 134400

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
local EXPANSION_ICON_LAYER = "ARTWORK"
local EXPANSION_ICON_SUBLEVEL = 7
local ITEM_MARKER_LAYER = "OVERLAY"
local ITEM_MARKER_SUBLEVEL = 2

local function IsTextColumn(column)
    return column.key ~= "icon" and column.key ~= "binding"
        and column.key ~= "professionQuality" and column.key ~= "expansion"
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
        row.iconAppearance:SetBorderColor(color.r, color.g, color.b, 1)
    else
        row.iconAppearance:SetBorderColor(DEFAULT_ICON_BORDER_COLOR_R, DEFAULT_ICON_BORDER_COLOR_G, DEFAULT_ICON_BORDER_COLOR_B, 1)
    end
end

local function UpdateContainerHighlight(row)
    local highlighted = row.item ~= nil
        and row.highlightedBagID ~= nil
        and row.item.bagID == row.highlightedBagID
    row.containerHighlight:SetShown(highlighted)
end

local function StopNewItemAnimation(row)
    row.newItemAnimation:Stop()
    row.newItemHighlight:SetAlpha(NEW_ITEM_HIGHLIGHT_MIN_ALPHA)
    row.newItemHighlight:Hide()
end

local function UpdateItemMarkers(row, item)
    row.newItemMarker:Hide()
    row.pinMarker:Hide()

    if item.isNewThisSession then
        row.newItemMarker:Show()
    elseif item.isPinned then
        row.pinMarker:Show()
    end
end

local function UpdateNewItemVisuals(row, item)
    UpdateItemMarkers(row, item)

    if not item.isNewUnseen then
        StopNewItemAnimation(row)
        return
    end

    if not row.newItemHighlight:IsShown() then
        row.newItemHighlight:SetAlpha(NEW_ITEM_HIGHLIGHT_MIN_ALPHA)
        row.newItemHighlight:Show()
    end
    if not row.newItemAnimation:IsPlaying() then
        row.newItemAnimation:Play()
    end
end

-- Row construction and layout
local function LayoutRow(row)
    local layout = row.list.columnLayout
    if row.columnLayout == layout and row.columnLayoutRevision == layout.revision then
        return
    end

    for _, column in ipairs(Columns.GetAvailableColumns()) do
        local key = column.key
        local entry = layout.byKey[key]
        local shown = entry ~= nil
        if row.columnVisibility[key] ~= shown then
            row.columnVisibility[key] = shown
            if key == "icon" then
                row.icon:SetShown(row.item ~= nil and shown)
                row.iconAppearance:SetBorderShown(row.item ~= nil and shown)
            elseif key == "binding" then
                row.bindingIcon:SetShown(row.hasBindingIcon == true and shown)
            elseif key == "professionQuality" then
                row.professionQualityIcon:SetShown(row.hasProfessionQualityIcon == true and shown)
            elseif key == "expansion" then
                row.expansionIcon:SetShown(row.hasExpansionIcon == true and shown)
            else
                row.text[key]:SetShown(shown)
            end
        end

        if entry then
            local region, point, x = row.text[key], "LEFT", entry.x
            if key == "icon" then
                region, point = row.icon, "CENTER"
                x = x + entry.width / 2 + ICON_LEFT_OFFSET + (ICON_FRAME_SIZE - column.width) / 2
            elseif key == "binding" then
                region, point, x = row.bindingIcon, "CENTER", x + entry.width / 2
            elseif key == "professionQuality" then
                region, point, x = row.professionQualityIcon, "CENTER", x + entry.width / 2
            elseif key == "expansion" then
                region, point, x = row.expansionIcon, "CENTER", x + entry.width / 2
            end
            if row.columnPositions[key] ~= x then
                region:ClearAllPoints()
                region:SetPoint(point, row.contentClip, "LEFT", x, 0)
                row.columnPositions[key] = x
                if key == "icon" and NS.Skins:GetAppliedSkin() == "flat" then
                    row.iconAppearance:RefreshGeometry()
                end
            end
            if IsTextColumn(column) and row.columnWidths[key] ~= entry.width then
                region:SetWidth(entry.width)
                row.columnWidths[key] = entry.width
            end
        end
    end
    row.columnLayout = layout
    row.columnLayoutRevision = layout.revision
end

local function CreateTextColumns(row, columns)
    row.text = {}
    for _, column in ipairs(columns) do
        if IsTextColumn(column) then
            local text = NS.Skins:CreateText(row.contentClip, {
                geometryRoot = row.list.window, fontSize = ROW_TEXT_SIZE,
            })
            text:SetHeight(ROW_HEIGHT)
            text:SetJustifyH(column.justify or "LEFT")
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

local function CreateNewItemAnimation(row)
    local animation = row.newItemHighlight:CreateAnimationGroup()
    animation:SetLooping("REPEAT")

    local fadeIn = animation:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(NEW_ITEM_HIGHLIGHT_MIN_ALPHA)
    fadeIn:SetToAlpha(NEW_ITEM_HIGHLIGHT_MAX_ALPHA)
    fadeIn:SetDuration(NEW_ITEM_HIGHLIGHT_HALF_DURATION)
    fadeIn:SetOrder(1)
    fadeIn:SetSmoothing("IN_OUT")

    local fadeOut = animation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(NEW_ITEM_HIGHLIGHT_MAX_ALPHA)
    fadeOut:SetToAlpha(NEW_ITEM_HIGHLIGHT_MIN_ALPHA)
    fadeOut:SetDuration(NEW_ITEM_HIGHLIGHT_HALF_DURATION)
    fadeOut:SetOrder(2)
    fadeOut:SetSmoothing("IN_OUT")

    row.newItemAnimation = animation
end

local function InitializeRow(row, list)
    row.list = list
    row.itemButtonAdapter = list.context.itemButtonAdapter
    local columns = Columns.GetAvailableColumns()
    -- Retain applied geometry through pool resets. These scalar snapshots also
    -- let rows catch up after several layout revisions while they were inactive.
    row.columnPositions = {}
    row.columnWidths = {}
    row.columnVisibility = {}

    row:SetHeight(ROW_HEIGHT)
    row:SetClipsChildren(true)
    row:EnableMouse(false)
    row:SetID(0)

    row.newItemHighlight = NS.Skins:CreateTexture(row, {
        geometryRoot = list.window, layer = ROW_HIGHLIGHT_LAYER, colorToken = "accent",
    })
    row.newItemHighlight:SetAllPoints(row)
    row.newItemHighlight:SetAlpha(NEW_ITEM_HIGHLIGHT_MIN_ALPHA)
    row.newItemHighlight:Hide()
    CreateNewItemAnimation(row)

    row.containerHighlight = NS.Skins:CreateTexture(row, {
        geometryRoot = list.window, layer = ROW_HIGHLIGHT_LAYER,
        colorToken = "accent", alpha = CONTAINER_HIGHLIGHT_ALPHA,
    })
    row.containerHighlight:SetAllPoints(row)
    row.containerHighlight:Hide()

    row.highlight = NS.Skins:CreateTexture(row, { geometryRoot = list.window, layer = ROW_HIGHLIGHT_LAYER })
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(DEFAULT_HIGHLIGHT_COLOR_R, DEFAULT_HIGHLIGHT_COLOR_G, DEFAULT_HIGHLIGHT_COLOR_B, DEFAULT_HIGHLIGHT_ALPHA)
    row.highlight:Hide()

    row.contentClip = CreateFrame("Frame", nil, row)
    row.contentClip:SetClipsChildren(true)
    row.contentClip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.contentClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -GetRightClipPadding(row), 0)

    row.newItemMarker = NS.Skins:CreateTexture(row.contentClip, {
        geometryRoot = list.window, layer = ITEM_MARKER_LAYER, sublevel = ITEM_MARKER_SUBLEVEL,
        texture = NS.Media.GetNewItemTexture(), colorToken = "accent", alpha = NEW_ITEM_MARKER_ALPHA,
    })
    row.newItemMarker:SetSize(NEW_ITEM_MARKER_SIZE, NEW_ITEM_MARKER_SIZE)
    row.newItemMarker:SetPoint("LEFT", row.contentClip, "LEFT", 0, 0)
    row.newItemMarker:Hide()

    row.pinMarker = NS.Skins:CreateTexture(row.contentClip, {
        geometryRoot = list.window, layer = ITEM_MARKER_LAYER, sublevel = ITEM_MARKER_SUBLEVEL,
        texture = NS.Media.GetPinnedTexture(), colorToken = "accent", alpha = PIN_MARKER_ALPHA,
    })
    row.pinMarker:SetSize(PIN_MARKER_SIZE, PIN_MARKER_SIZE)
    row.pinMarker:SetPoint("TOPLEFT", row.contentClip, "TOPLEFT", 0, 0)
    row.pinMarker:Hide()

    row.icon, row.iconAppearance = NS.Skins:CreateIcon(row.contentClip, {
        clip = list.scrollBox,
        geometryRoot = list.window, width = ICON_SIZE, layer = ROW_ICON_LAYER, sublevel = ROW_ICON_SUBLEVEL,
        borderLayer = ICON_BORDER_LAYER, borderSublevel = ICON_BORDER_SUBLEVEL, artworkOutset = 1,
    })
    row.icon:Hide()
    row.iconAppearance:SetBorderShown(false)

    Cooldown.CreateShade(row)
    Cooldown.LayoutShade(row)
    row.itemButton = row.itemButtonAdapter.Create(row, list)
    CreateTextColumns(row, columns)

    row.professionQualityIcon = NS.Skins:CreateTexture(row.contentClip, {
        geometryRoot = list.window, layer = PROFESSION_QUALITY_LAYER, sublevel = PROFESSION_QUALITY_SUBLEVEL,
    })
    row.professionQualityIcon:SetSize(PROFESSION_QUALITY_ICON_SIZE, PROFESSION_QUALITY_ICON_SIZE)
    row.professionQualityIcon:SetDrawLayer(PROFESSION_QUALITY_LAYER, PROFESSION_QUALITY_SUBLEVEL)
    row.professionQualityIcon:Hide()

    row.bindingIcon = NS.Skins:CreateTexture(row.contentClip, {
        geometryRoot = list.window, layer = BINDING_ICON_LAYER, sublevel = BINDING_ICON_SUBLEVEL,
    })
    row.bindingIcon:SetSize(BINDING_ICON_SIZE, BINDING_ICON_SIZE)
    row.bindingIcon:SetDrawLayer(BINDING_ICON_LAYER, BINDING_ICON_SUBLEVEL)
    row.bindingIcon:Hide()

    row.expansionIcon = NS.Skins:CreateTexture(row.contentClip, {
        geometryRoot = list.window, layer = EXPANSION_ICON_LAYER, sublevel = EXPANSION_ICON_SUBLEVEL,
    })
    row.expansionIcon:Hide()

    LayoutRow(row)
    row.rowInitialized = true
end

local function RenderProfessionQuality(row, item)
    local atlas = Columns.GetProfessionQualityAtlas(item)
    row.hasProfessionQualityIcon = atlas and true or false
    if atlas then
        row.professionQualityIcon:SetAtlas(atlas, false)
        row.professionQualityIcon:SetShown(row.list.columnLayout.byKey.professionQuality ~= nil)
    else
        row.professionQualityIcon:Hide()
    end
end

local function RenderBinding(row, item)
    local iconInfo = Columns.GetBindingIconInfo(item)
    row.hasBindingIcon = iconInfo ~= nil
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
    row.bindingIcon:SetShown(row.list.columnLayout.byKey.binding ~= nil)
end

local function RenderExpansion(row, item)
    local iconInfo = Columns.GetExpansionIconInfo(item.expansionID)
    row.hasExpansionIcon = iconInfo ~= nil
    if not iconInfo then
        row.expansionIcon:Hide()
        return
    end

    row.expansionIcon:SetTexture(iconInfo.texture)
    row.expansionIcon:SetTexCoord(unpack(iconInfo.texCoord))
    row.expansionIcon:SetSize(iconInfo.width, iconInfo.height)
    row.expansionIcon:SetShown(row.list.columnLayout.byKey.expansion ~= nil)
end

local function RenderText(row, item)
    for _, column in ipairs(Columns.GetAvailableColumns()) do
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

function ItemRow.Initialize(row, list)
    if not row.rowInitialized then
        InitializeRow(row, list)
    end
end

function ItemRow.ApplyColumnLayout(row)
    LayoutRow(row)
end

function ItemRow.ClearCooldownCache()
    Cooldown.ClearCache()
end

function ItemRow.RefreshCooldown(row)
    Cooldown.Refresh(row)
end

function ItemRow.RefreshLock(row, isLocked)
    if row.item then
        row.icon:SetDesaturated(isLocked == true)
    end
end

function ItemRow.RefreshNewItemState(row)
    if row.item then
        UpdateNewItemVisuals(row, row.item)
    end
end

function ItemRow.HandleItemEnter(row)
    if row.item and row.list.context.handleItemEnter(row.item) then
        UpdateNewItemVisuals(row, row.item)
    end
end

function ItemRow.StopNewItemAnimation(row)
    StopNewItemAnimation(row)
end

function ItemRow.SetHighlightedBagID(row, highlightedBagID)
    row.highlightedBagID = highlightedBagID
    UpdateContainerHighlight(row)
end

function ItemRow.Render(row, item, list)
    ItemRow.Initialize(row, list)

    row.item = item
    LayoutRow(row)
    if list then
        row.highlightedBagID = list.highlightedBagID
    end

    UpdateRowHighlightColor(row, item)
    UpdateContainerHighlight(row)
    UpdateNewItemVisuals(row, item)
    UpdateIconBorderColor(row, item)
    row.itemButtonAdapter.Update(row.itemButton, item)

    row.icon:SetTexture(item.icon or FALLBACK_ITEM_ICON)
    row.icon:SetDesaturated(item.isLocked)
    row.icon:SetShown(list.columnLayout.byKey.icon ~= nil)
    row.iconAppearance:SetBorderShown(list.columnLayout.byKey.icon ~= nil)

    RenderProfessionQuality(row, item)
    RenderBinding(row, item)
    RenderExpansion(row, item)
    RenderText(row, item)
    Cooldown.Update(row, item)
end

function ItemRow.Reset(row)
    row.item = nil
    row.hasBindingIcon = false
    row.hasProfessionQualityIcon = false
    row.hasExpansionIcon = false
    row.highlightedBagID = nil
    row:SetID(0)
    StopNewItemAnimation(row)
    row.highlight:Hide()
    row.containerHighlight:Hide()
    row.newItemMarker:Hide()
    row.pinMarker:Hide()
    Cooldown.Clear(row)

    row.icon:SetTexture(nil)
    row.icon:SetDesaturated(false)
    row.icon:Hide()
    row.iconAppearance:SetBorderShown(false)
    row.itemButtonAdapter.Reset(row.itemButton)
    row.professionQualityIcon:Hide()

    row.expansionIcon:SetTexture(nil)
    row.expansionIcon:Hide()

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

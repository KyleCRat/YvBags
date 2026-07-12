local _, NS = ...

-- Column-header contract: rendering, sorting controls, and list context menus.
local Header = {}
NS.ItemListHeader = Header

local Columns = NS.ItemListColumns
local ListModel = NS.ItemListModel
local Layout = NS.ItemListLayout
local Media = NS.Media
local ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B = Media.GetAccentColor()

-- Text, icons, and dividers
local HEADER_TEXT_SIZE = 16
local HEADER_SORT_ICON_SIZE = 13
local HEADER_SORT_ICON_GAP = 1
local HEADER_TOOLTIP_TEXT_COLOR_R = 0.86
local HEADER_TOOLTIP_TEXT_COLOR_G = 0.86
local HEADER_TOOLTIP_TEXT_COLOR_B = 0.86
local HEADER_BOTTOM_DIVIDER_LEFT_OFFSET = 2
local HEADER_BOTTOM_DIVIDER_RIGHT_OFFSET = -2
local HEADER_BOTTOM_DIVIDER_BOTTOM_OFFSET = -6
local HEADER_DIVIDER_HEIGHT = 14
local HEADER_DIVIDER_ALPHA = 0.68
local HEADER_SEPARATOR_HANDLE_WIDTH = 6
local HEADER_SEPARATOR_TOP_OFFSET = 1
local HEADER_SEPARATOR_BOTTOM_OFFSET = 1
local HEADER_SEPARATOR_TEXTURE_LENGTH = Layout.HeaderHeight - HEADER_SEPARATOR_TOP_OFFSET - HEADER_SEPARATOR_BOTTOM_OFFSET
local HEADER_SEPARATOR_TEXTURE_THICKNESS = 6
local HEADER_SEPARATOR_HOVER_ALPHA = 0.14
local HEADER_SEPARATOR_PRESSED_ALPHA = 0.28
local HEADER_SEPARATOR_LINE_HOVER_ALPHA = 0.86
local HEADER_SEPARATOR_LINE_PRESSED_ALPHA = 1
local HEADER_SEPARATOR_FRAME_LEVEL_OFFSET = 3
local HEADER_HOVER_ALPHA = 0.08
local HEADER_PRESSED_ALPHA = 0.16

-- Context menu labels
local GROUP_MENU_TITLE = "Group By"
local PRIMARY_SORT_MENU_TITLE = "Primary Sort"
local PRIMARY_SORT_DIRECTION_MENU_TITLE = "Sort Direction"
local SECONDARY_SORT_MENU_TITLE = "Secondary Sort"
local SECONDARY_SORT_DIRECTION_MENU_TITLE = "Secondary Direction"
local NO_SECONDARY_SORT_LABEL = "None"
local ASCENDING_LABEL = "Ascending"
local DESCENDING_LABEL = "Descending"

local function GetPrimaryFont()
    return Media.GetPrimaryFont()
end

local function GetHeaderText(column)
    return column.label or ""
end

local function GetHeaderIconSize(column)
    return column.headerIconSize or HEADER_TEXT_SIZE
end

local function HasHeaderIcon(column)
    return column.headerAtlas or column.headerTexture
end

local function ApplyHeaderIcon(button)
    local icon = button.headerIcon
    local column = button.column
    if not icon or not HasHeaderIcon(column) then
        return
    end

    if column.headerAtlas then
        icon:SetAtlas(column.headerAtlas, false)
    else
        icon:SetTexture(column.headerTexture)
        icon:SetTexCoord(0, 1, 0, 1)
    end

    local color = column.headerIconColor
    if color then
        icon:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    else
        icon:SetVertexColor(1, 1, 1, 1)
    end

    icon:SetSize(GetHeaderIconSize(column), GetHeaderIconSize(column))
    icon:Show()
end

local function GetHeaderTooltipTitle(column)
    local title = column.tooltipTitle or GetHeaderText(column)
    if title and title ~= "" then
        return title
    end

    return column.sortLabel or column.sortKey or ""
end

local function ShowHeaderTooltip(button)
    local column = button.column
    if not column or not column.sortKey or not GameTooltip then
        return
    end

    local title = GetHeaderTooltipTitle(column)
    local sortLabel = column.sortLabel or title or column.sortKey
    local tooltipText = column.tooltipText or ("Sort by " .. sortLabel)

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    GameTooltip:AddLine(tooltipText, HEADER_TOOLTIP_TEXT_COLOR_R, HEADER_TOOLTIP_TEXT_COLOR_G, HEADER_TOOLTIP_TEXT_COLOR_B, true)
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

-- Context menu construction
local function GetMenuSelectionLabel(title, value)
    return title .. ": " .. value
end

local function SetMenuText(fontString, text)
    if not fontString then
        return
    end

    if fontString.SetTextToFit then
        fontString:SetTextToFit(text)
    else
        fontString:SetText(text)
    end
end

local function AddDynamicMenuText(elementDescription, getText)
    elementDescription:AddInitializer(function(button, description)
        local text = getText()
        if MenuUtil and MenuUtil.SetElementText then
            MenuUtil.SetElementText(description, text)
        end

        SetMenuText(button.fontString, text)
        SetMenuText(button.Text, text)
    end)
end

local function GetPrimarySortLabel(sortKey)
    return Columns.GetSortLabel(ListModel.NormalizeSortKey(sortKey))
end

local function AddPrimarySortMenu(rootDescription, list)
    local menu = rootDescription:CreateButton(GetMenuSelectionLabel(PRIMARY_SORT_MENU_TITLE, GetPrimarySortLabel(list.sortKey)))
    AddDynamicMenuText(menu, function()
        return GetMenuSelectionLabel(PRIMARY_SORT_MENU_TITLE, GetPrimarySortLabel(list.sortKey))
    end)

    local function IsSelected(sortKey)
        return list.sortKey == ListModel.NormalizeSortKey(sortKey)
    end

    local function SetSort(sortKey)
        sortKey = ListModel.NormalizeSortKey(sortKey)
        local ascending = list.sortAscending
        if list.sortKey ~= sortKey then
            ascending = Columns.GetDefaultSortAscending(sortKey)
        end

        list:SetSort(sortKey, ascending)
        return MenuResponse.Refresh
    end

    for _, sortKey in ipairs(ListModel.GetSortKeyList()) do
        menu:CreateRadio(GetPrimarySortLabel(sortKey), IsSelected, SetSort, sortKey)
    end

    local function IsDirectionEnabled()
        return not ListModel.IsManualSortKey(list.sortKey)
    end

    menu:CreateDivider()
    menu:CreateTitle(PRIMARY_SORT_DIRECTION_MENU_TITLE)
    menu:CreateRadio(ASCENDING_LABEL, function()
        return list.sortAscending == true
    end, function()
        list:SetSort(list.sortKey, true)
        return MenuResponse.Refresh
    end):SetEnabled(IsDirectionEnabled)
    menu:CreateRadio(DESCENDING_LABEL, function()
        return list.sortAscending == false
    end, function()
        list:SetSort(list.sortKey, false)
        return MenuResponse.Refresh
    end):SetEnabled(IsDirectionEnabled)
end

local function GetSecondarySortLabel(sortKey)
    sortKey = ListModel.NormalizeSecondarySortKey(sortKey)
    if sortKey == ListModel.GetNoSecondarySortKey() then
        return NO_SECONDARY_SORT_LABEL
    end

    return Columns.GetSortLabel(sortKey)
end

local function AddSecondarySortMenu(rootDescription, list)
    local menu = rootDescription:CreateButton(GetMenuSelectionLabel(SECONDARY_SORT_MENU_TITLE, GetSecondarySortLabel(list.secondarySortKey)))
    menu:SetEnabled(function()
        return not ListModel.IsManualSortKey(list.sortKey)
    end)
    AddDynamicMenuText(menu, function()
        return GetMenuSelectionLabel(SECONDARY_SORT_MENU_TITLE, GetSecondarySortLabel(list.secondarySortKey))
    end)

    local function IsOptionEnabled(sortKey)
        sortKey = ListModel.NormalizeSecondarySortKey(sortKey)
        return sortKey == ListModel.GetNoSecondarySortKey() or ListModel.IsSecondarySortEnabled(sortKey, list.sortKey)
    end

    local function IsSelected(sortKey)
        return list.secondarySortKey == ListModel.NormalizeSecondarySortKey(sortKey)
    end

    local function SetSort(sortKey)
        list:SetSecondarySort(sortKey)
        return MenuResponse.Refresh
    end

    for _, sortKey in ipairs(ListModel.GetSecondarySortKeyList()) do
        local optionSortKey = ListModel.NormalizeSecondarySortKey(sortKey)
        menu:CreateRadio(GetSecondarySortLabel(optionSortKey), IsSelected, SetSort, optionSortKey):SetEnabled(function()
            return IsOptionEnabled(optionSortKey)
        end)
    end

    local function IsDirectionEnabled()
        return not ListModel.IsManualSortKey(list.sortKey) and list.secondarySortKey ~= ListModel.GetNoSecondarySortKey()
    end

    menu:CreateDivider()
    menu:CreateTitle(SECONDARY_SORT_DIRECTION_MENU_TITLE)
    menu:CreateRadio(ASCENDING_LABEL, function()
        return list.secondarySortAscending == true
    end, function()
        list:SetSecondarySortDirection(true)
        return MenuResponse.Refresh
    end):SetEnabled(IsDirectionEnabled)
    menu:CreateRadio(DESCENDING_LABEL, function()
        return list.secondarySortAscending == false
    end, function()
        list:SetSecondarySortDirection(false)
        return MenuResponse.Refresh
    end):SetEnabled(IsDirectionEnabled)
end

local function AddGroupMenu(rootDescription, list)
    local menu = rootDescription:CreateButton(GetMenuSelectionLabel(GROUP_MENU_TITLE, ListModel.GetGroupLabel(list.groupKey)))

    local function IsSelected(groupKey)
        return list.groupKey == ListModel.NormalizeGroupKey(groupKey)
    end

    local function SetSelected(groupKey)
        list:SetGroup(groupKey)
        return MenuResponse.Refresh
    end

    for _, groupKey in ipairs(ListModel.GetGroupKeyList()) do
        menu:CreateRadio(ListModel.GetGroupLabel(groupKey), IsSelected, SetSelected, groupKey)
    end
end

local function ShowContextMenu(owner, list)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return
    end

    HideTooltip()
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        AddGroupMenu(rootDescription, list)
        AddPrimarySortMenu(rootDescription, list)
        AddSecondarySortMenu(rootDescription, list)
    end)
end

-- Header visual state
local function AnchorSortIcon(button)
    button.sortIcon:ClearAllPoints()

    if button.headerIcon and button.headerIcon:IsShown() then
        button.sortIcon:SetPoint("LEFT", button, "CENTER", (button.headerIcon:GetWidth() / 2) + HEADER_SORT_ICON_GAP, 0)
        return
    end

    if GetHeaderText(button.column) == "" then
        button.sortIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
        return
    end

    button.sortIcon:SetPoint("LEFT", button, "CENTER", ((button.text:GetStringWidth() or 0) / 2) + HEADER_SORT_ICON_GAP, 0)
end

local function UpdateButtonVisualState(button)
    button.pressedTexture:SetShown(button.isPressed == true)
    button.hoverTexture:SetShown(button.isHovered == true and button.isPressed ~= true)
end

local function OnButtonEnter(button)
    if button:IsEnabled() then
        button.isHovered = true
        UpdateButtonVisualState(button)
        ShowHeaderTooltip(button)
    end
end

local function OnButtonLeave(button)
    button.isHovered = false
    button.isPressed = false
    UpdateButtonVisualState(button)
    HideTooltip()
end

local function OnButtonMouseDown(button, mouseButton)
    if mouseButton == "LeftButton" and button:IsEnabled() then
        button.isPressed = true
        UpdateButtonVisualState(button)
    end
end

local function OnButtonMouseUp(button)
    button.isPressed = false
    button.isHovered = button:IsMouseOver()
    UpdateButtonVisualState(button)
end

local function SetSeparatorLineAlpha(separator, alpha)
    separator.line:SetVertexColor(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, alpha)
end

local function UpdateSeparatorVisualState(separator)
    separator.pressedTexture:SetShown(separator.isPressed == true)
    separator.hoverTexture:SetShown(separator.isHovered == true and separator.isPressed ~= true)

    if separator.isPressed then
        SetSeparatorLineAlpha(separator, HEADER_SEPARATOR_LINE_PRESSED_ALPHA)
    elseif separator.isHovered then
        SetSeparatorLineAlpha(separator, HEADER_SEPARATOR_LINE_HOVER_ALPHA)
    else
        SetSeparatorLineAlpha(separator, HEADER_DIVIDER_ALPHA)
    end
end

local function CreateSeparator(parent, xOffset, list)
    local separator = CreateFrame("Button", nil, parent)
    separator:SetPoint("LEFT", parent, "LEFT", xOffset - (HEADER_SEPARATOR_HANDLE_WIDTH / 2), 0)
    separator:SetSize(HEADER_SEPARATOR_HANDLE_WIDTH, Layout.HeaderHeight)
    separator:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    separator:SetFrameLevel(parent:GetFrameLevel() + HEADER_SEPARATOR_FRAME_LEVEL_OFFSET)
    separator.list = list

    local hoverTexture = separator:CreateTexture(nil, "BACKGROUND")
    hoverTexture:SetAllPoints(separator)
    hoverTexture:SetColorTexture(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, HEADER_SEPARATOR_HOVER_ALPHA)
    hoverTexture:Hide()
    separator.hoverTexture = hoverTexture

    local pressedTexture = separator:CreateTexture(nil, "BACKGROUND")
    pressedTexture:SetAllPoints(separator)
    pressedTexture:SetColorTexture(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, HEADER_SEPARATOR_PRESSED_ALPHA)
    pressedTexture:Hide()
    separator.pressedTexture = pressedTexture

    local line = separator:CreateTexture(nil, "BORDER")
    line:SetTexture(Media.GetDividerTexture())
    line:SetBlendMode("ADD")
    line:SetPoint("CENTER", separator, "CENTER", 0, 0)
    line:SetSize(HEADER_SEPARATOR_TEXTURE_LENGTH, HEADER_SEPARATOR_TEXTURE_THICKNESS)
    if line.SetRotation then
        line:SetRotation(math.pi / 2)
    end
    separator.line = line

    separator:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateSeparatorVisualState(self)
    end)
    separator:SetScript("OnLeave", function(self)
        self.isHovered = false
        self.isPressed = false
        UpdateSeparatorVisualState(self)
    end)
    separator:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self.isPressed = true
            UpdateSeparatorVisualState(self)
        end
    end)
    separator:SetScript("OnMouseUp", function(self, mouseButton)
        self.isPressed = false
        self.isHovered = self:IsMouseOver()
        UpdateSeparatorVisualState(self)
        if mouseButton == "RightButton" then
            ShowContextMenu(self, self.list)
        end
    end)
    UpdateSeparatorVisualState(separator)

    return separator
end

-- Public contract
function Header.Refresh(header, list)
    if not header or not header.buttons then
        return
    end

    for _, button in ipairs(header.buttons) do
        button.text:SetText(GetHeaderText(button.column))
        if button.headerIcon then
            if HasHeaderIcon(button.column) then
                ApplyHeaderIcon(button)
            else
                button.headerIcon:Hide()
            end
        end

        if button.column.sortKey and button.column.sortKey == list.sortKey then
            button.sortIcon:Show()
            if list.sortAscending then
                button.sortIcon:SetTexCoord(0, 1, 0, 1)
            else
                button.sortIcon:SetTexCoord(0, 1, 1, 0)
            end
            AnchorSortIcon(button)
        else
            button.sortIcon:Hide()
        end
    end
end

function Header.Create(parent, list)
    local columns = Columns.GetColumns()
    local columnGap = Columns.GetColumnGap()
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(Layout.HeaderHeight)
    header:SetClipsChildren(true)

    local content = CreateFrame("Frame", nil, header)
    content:SetAllPoints(header)
    content:SetClipsChildren(true)

    local bottomDivider = header:CreateTexture(nil, "BORDER")
    bottomDivider:SetTexture(Media.GetDividerTexture())
    bottomDivider:SetBlendMode("ADD")
    bottomDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", HEADER_BOTTOM_DIVIDER_LEFT_OFFSET, HEADER_BOTTOM_DIVIDER_BOTTOM_OFFSET)
    bottomDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", HEADER_BOTTOM_DIVIDER_RIGHT_OFFSET, HEADER_BOTTOM_DIVIDER_BOTTOM_OFFSET)
    bottomDivider:SetHeight(HEADER_DIVIDER_HEIGHT)
    bottomDivider:SetVertexColor(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, HEADER_DIVIDER_ALPHA)
    header.bottomDivider = bottomDivider

    header.buttons = {}
    header.separators = {}

    local xOffset = 0
    for index, column in ipairs(columns) do
        local buttonWidth = column.width
        if index == #columns then
            buttonWidth = buttonWidth + Layout.ScrollBarContentPadding
        end

        local button = CreateFrame("Button", nil, content)
        button:SetPoint("LEFT", content, "LEFT", xOffset, 0)
        button:SetSize(buttonWidth, Layout.HeaderHeight)
        button.column = column
        button:SetEnabled(column.sortKey ~= nil)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local hoverTexture = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        hoverTexture:SetAllPoints(button)
        hoverTexture:SetColorTexture(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, HEADER_HOVER_ALPHA)
        hoverTexture:Hide()
        button.hoverTexture = hoverTexture

        local pressedTexture = button:CreateTexture(nil, "BACKGROUND", nil, -6)
        pressedTexture:SetAllPoints(button)
        pressedTexture:SetColorTexture(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B, HEADER_PRESSED_ALPHA)
        pressedTexture:Hide()
        button.pressedTexture = pressedTexture

        local text = button:CreateFontString(nil, "OVERLAY")
        text:SetFont(GetPrimaryFont(), HEADER_TEXT_SIZE)
        text:SetTextColor(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B)
        text:SetAllPoints(button)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetText(GetHeaderText(column))
        button.text = text

        if HasHeaderIcon(column) then
            button.headerIcon = button:CreateTexture(nil, "OVERLAY")
            button.headerIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
            ApplyHeaderIcon(button)
        end

        local sortIcon = button:CreateTexture(nil, "OVERLAY")
        sortIcon:SetTexture(Media.GetSortArrowTexture())
        sortIcon:SetSize(HEADER_SORT_ICON_SIZE, HEADER_SORT_ICON_SIZE)
        sortIcon:SetVertexColor(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B)
        sortIcon:Hide()
        button.sortIcon = sortIcon

        button:SetScript("OnEnter", OnButtonEnter)
        button:SetScript("OnLeave", OnButtonLeave)
        button:SetScript("OnMouseDown", OnButtonMouseDown)
        button:SetScript("OnMouseUp", OnButtonMouseUp)
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowContextMenu(self, list)
            elseif self.column.sortKey then
                list:SetSort(self.column.sortKey)
            end
        end)

        header.buttons[#header.buttons + 1] = button

        if index < #columns then
            local separator = CreateSeparator(content, xOffset + column.width + (columnGap / 2), list)
            separator.leftColumn = column
            separator.rightColumn = columns[index + 1]
            header.separators[#header.separators + 1] = separator
        end

        xOffset = xOffset + column.width + columnGap
    end

    Header.Refresh(header, list)
    return header
end

local _, NS = ...

-- Column-header contract: rendering, sorting controls, and list context menus.
local Header = {}
NS.ItemListHeader = Header

local Columns = NS.ItemListColumns
local ColumnMenu = NS.ItemListColumnMenu
local Interaction = NS.ItemListHeaderInteraction
local ListSettings = NS.ItemListSettings
local ListModel = NS.ItemListModel
local Layout = NS.ItemListLayout
local Media = NS.Media

-- Text, icons, and dividers
local HEADER_TEXT_SIZE = 16
local HEADER_SORT_ICON_SIZE = 13
local HEADER_SORT_ICON_GAP = 1
local HEADER_TOOLTIP_TEXT_COLOR_R = 0.86
local HEADER_TOOLTIP_TEXT_COLOR_G = 0.86
local HEADER_TOOLTIP_TEXT_COLOR_B = 0.86
local MODERN_HEADER_SIDE_INSET = 2
local MODERN_SEPARATOR_TOP_INSET = 1
local HEADER_DIVIDER_THICKNESS = 1
local HEADER_DIVIDER_ALPHA = 0.68
local HEADER_SEPARATOR_HANDLE_WIDTH = 6
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

local function GetHeaderText(column)
    return column.label or ""
end

local function GetHeaderIconSize(column)
    return column.headerIconSize or HEADER_TEXT_SIZE
end

local function HasHeaderIcon(column)
    return column.headerAtlas or column.headerTexture
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
    if not column or not GameTooltip then
        return
    end

    local title = GetHeaderTooltipTitle(column)
    local sortLabel = column.sortLabel or title or column.sortKey
    local tooltipText = column.tooltipText or (column.sortKey and ("Sort by " .. sortLabel))

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if tooltipText then
        GameTooltip:AddLine(tooltipText, HEADER_TOOLTIP_TEXT_COLOR_R, HEADER_TOOLTIP_TEXT_COLOR_G, HEADER_TOOLTIP_TEXT_COLOR_B, true)
    end
    if ListSettings.CanEditColumns() then
        GameTooltip:AddLine("Drag to reorder. Drag a divider to resize. Right-click for column options.", HEADER_TOOLTIP_TEXT_COLOR_R, HEADER_TOOLTIP_TEXT_COLOR_G, HEADER_TOOLTIP_TEXT_COLOR_B, true)
    else
        GameTooltip:AddLine("Column editing is unavailable during combat.", HEADER_TOOLTIP_TEXT_COLOR_R, HEADER_TOOLTIP_TEXT_COLOR_G, HEADER_TOOLTIP_TEXT_COLOR_B, true)
    end
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

local function ShowContextMenu(list, columnKey)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return
    end

    HideTooltip()
    -- Keep the owner visible even when this menu hides its originating column.
    MenuUtil.CreateContextMenu(list.header, function(_, rootDescription)
        if columnKey then
            ColumnMenu.PopulateColumnActions(rootDescription, list.settingsScope, columnKey)
            rootDescription:CreateDivider()
        end
        AddGroupMenu(rootDescription, list)
        AddPrimarySortMenu(rootDescription, list)
        AddSecondarySortMenu(rootDescription, list)
        rootDescription:CreateDivider()
        ColumnMenu.Populate(rootDescription:CreateButton("Columns"), list.settingsScope)
    end)
end

-- Header visual state
local function LayoutHeaderContent(button, sorted)
    local hasText = GetHeaderText(button.column) ~= ""
    local arrowSpace = sorted and (button.headerIcon or hasText)
        and (HEADER_SORT_ICON_SIZE + HEADER_SORT_ICON_GAP) or 0

    -- Center the label/icon and arrow as one block, reserving the arrow's
    -- width in the text bounds so narrow columns still truncate their label.
    button.text:ClearAllPoints()
    button.text:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -arrowSpace, 0)
    if button.headerIcon then
        button.headerIcon:ClearAllPoints()
        button.headerIcon:SetPoint("CENTER", button, "CENTER", -arrowSpace / 2, 0)
    end

    button.sortIcon:ClearAllPoints()
    if not sorted then
        return
    end

    if button.headerIcon then
        button.sortIcon:SetPoint("LEFT", button.headerIcon, "RIGHT", HEADER_SORT_ICON_GAP, 0)
        return
    end

    if not hasText then
        button.sortIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
        return
    end

    local textWidth = math.min(button.text:GetStringWidth(), math.max(0, button:GetWidth() - arrowSpace))
    button.sortIcon:SetPoint("LEFT", button, "CENTER", (textWidth - arrowSpace) / 2 + HEADER_SORT_ICON_GAP, 0)
end

local function RefreshButtonSortState(button, list, layoutChanged)
    local sorted = button.column.sortKey ~= nil and button.column.sortKey == list.sortKey
    local sortChanged = button.isSorted ~= sorted
    if sortChanged then
        button.sortIcon:SetShown(sorted)
        button.isSorted = sorted
    end
    if sorted and (sortChanged or button.sortAscending ~= list.sortAscending) then
        button.sortIcon:SetTexture(Media.GetSortArrowTexture(list.sortAscending))
        button.sortAscending = list.sortAscending
    end
    if layoutChanged or sortChanged then
        LayoutHeaderContent(button, sorted)
    end
end

local function UpdateButtonVisualState(button)
    button.pressedTexture:SetShown(button.isPressed == true)
    button.hoverTexture:SetShown(button.isHovered == true and button.isPressed ~= true)
end

local function OnButtonEnter(button)
    if button:IsEnabled() and not button.header.interaction then
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
    separator.line:SetAlpha(alpha)
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
    separator.UpdateVisualState = UpdateSeparatorVisualState

    local hoverTexture = NS.Skins:CreateTexture(separator, {
        geometryRoot = list.window, layer = "BACKGROUND", colorToken = "accent", alpha = HEADER_SEPARATOR_HOVER_ALPHA,
    })
    hoverTexture:SetAllPoints(separator)
    hoverTexture:Hide()
    separator.hoverTexture = hoverTexture

    local pressedTexture = NS.Skins:CreateTexture(separator, {
        geometryRoot = list.window, layer = "BACKGROUND", colorToken = "accent", alpha = HEADER_SEPARATOR_PRESSED_ALPHA,
    })
    pressedTexture:SetAllPoints(separator)
    pressedTexture:Hide()
    separator.pressedTexture = pressedTexture

    -- Only the line spans the inset's top margin; the resize hit area and
    -- column contents keep their original viewport geometry.
    local lineBounds = CreateFrame("Frame", nil, separator)
    local header = parent:GetParent()
    lineBounds:SetPoint("BOTTOMLEFT", separator, "BOTTOMLEFT", 0, 0)
    lineBounds:SetSize(HEADER_SEPARATOR_HANDLE_WIDTH, header:GetHeight())
    separator.lineBounds = lineBounds
    separator.lineTexture, separator.line = NS.Skins:CreateSeparator(header, {
        geometryRoot = list.window,
        bounds = lineBounds,
        orientation = "vertical",
        pixelInsets = { top = HEADER_DIVIDER_THICKNESS, bottom = HEADER_DIVIDER_THICKNESS },
        clip = header,
        alpha = HEADER_DIVIDER_ALPHA,
        modernLayout = {
            bounds = separator, orientation = "vertical", top = MODERN_SEPARATOR_TOP_INSET,
            pixelInsets = { bottom = HEADER_DIVIDER_THICKNESS }, clip = parent,
        },
    })

    separator:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateSeparatorVisualState(self)
        if not self.header.interaction then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Resize " .. Columns.GetLabel(self.column))
            GameTooltip:AddLine(ListSettings.CanEditColumns()
                and "Drag to resize. Right-click for column options."
                or "Column editing is unavailable during combat.", 0.86, 0.86, 0.86, true)
            GameTooltip:Show()
        end
    end)
    separator:SetScript("OnLeave", function(self)
        self.isHovered = false
        self.isPressed = false
        UpdateSeparatorVisualState(self)
        HideTooltip()
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
            ShowContextMenu(self.list, self.column.key)
        end
    end)
    UpdateSeparatorVisualState(separator)

    return separator
end

-- Public contract
function Header.CancelInteraction(header)
    Interaction.Cancel(header)
end

function Header.RefreshPixelGeometry(header)
    local height = header:GetHeight()
    local heightChanged = header.lineHeight ~= height
    header.lineHeight = height
    header.bottomDivider:RefreshGeometry()
    for _, separator in ipairs(header.separators) do
        if heightChanged then
            separator.lineBounds:SetHeight(height)
        end
        separator.line:RefreshGeometry()
    end
end

function Header.ApplyColumnLayout(header, list)
    local entries = list.columnLayout.entries
    local lastEntry = entries[#entries]
    for index, button in ipairs(header.buttons) do
        local entry = list.columnLayout.byKey[button.column.key]
        local separator = header.separators[index]
        local shown = entry ~= nil
        local visibilityChanged = button.columnShown ~= shown
        local widthChanged = entry ~= nil and button.columnWidth ~= entry.width
        local separatorChanged = visibilityChanged
        if visibilityChanged then
            button:SetShown(shown)
            separator:SetShown(shown)
            separator.line:SetShown(shown)
            button.columnShown = shown
        end
        if entry then
            if button.columnX ~= entry.x then
                button:ClearAllPoints()
                button:SetPoint("LEFT", header.content, "LEFT", entry.x, 0)
                button.columnX = entry.x
            end
            if widthChanged then
                button:SetWidth(entry.width)
                button.columnWidth = entry.width
            end
            local separatorX = entry.x + entry.width + Columns.GetColumnGap() / 2
            if entry == lastEntry then
                -- The trailing handle must remain inside the clipped content.
                separatorX = entry.x + entry.width - HEADER_SEPARATOR_HANDLE_WIDTH / 2
            end
            if separator.columnX ~= separatorX then
                separator:ClearAllPoints()
                separator:SetPoint("LEFT", header.content, "LEFT", separatorX - HEADER_SEPARATOR_HANDLE_WIDTH / 2, 0)
                separator.columnX = separatorX
                separatorChanged = true
            end
        end
        if separatorChanged then
            separator.line:RefreshGeometry()
        end
        RefreshButtonSortState(button, list, visibilityChanged or widthChanged)
    end
    header.bottomDivider:RefreshGeometry()
end

function Header.Refresh(header, list)
    if not header or not header.buttons then
        return
    end

    for _, button in ipairs(header.buttons) do
        RefreshButtonSortState(button, list, true)
    end
end

function Header.Create(parent, list)
    local columns = Columns.GetAvailableColumns()
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    header:SetPoint("BOTTOM", list.frame, "TOP", 0, -Layout.HeaderHeight)
    header:SetClipsChildren(true)
    header:EnableMouse(true)
    header:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ShowContextMenu(list)
        end
    end)

    local content = CreateFrame("Frame", nil, header)
    -- The header owns the space above the scrollbar; only rows reserve its gutter.
    content:SetPoint("TOPLEFT", list.frame, "TOPLEFT", Layout.HeaderLeftOffset, Layout.HeaderTopOffset)
    content:SetPoint("BOTTOMRIGHT", list.frame, "TOPRIGHT", Layout.HeaderRightOffset, -Layout.HeaderHeight)
    content:SetClipsChildren(true)
    header.content = content

    header.bottomDividerTexture, header.bottomDivider = NS.Skins:CreateSeparator(header, {
        geometryRoot = list.window,
        align = "end",
        thickness = HEADER_DIVIDER_THICKNESS,
        pixelInsets = { left = HEADER_DIVIDER_THICKNESS, right = HEADER_DIVIDER_THICKNESS },
        alpha = HEADER_DIVIDER_ALPHA,
        modernLayout = {
            bounds = content, align = "end", thickness = HEADER_DIVIDER_THICKNESS,
            left = MODERN_HEADER_SIDE_INSET, right = MODERN_HEADER_SIDE_INSET,
        },
    })

    header.buttons = {}
    header.separators = {}

    for _, column in ipairs(columns) do
        local button = CreateFrame("Button", nil, content)
        button:SetSize(column.width, Layout.HeaderHeight)
        button.column = column
        button.header = header
        button.UpdateVisualState = UpdateButtonVisualState
        -- Display-only headers still support dragging and context actions.
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local hoverTexture = NS.Skins:CreateTexture(button, {
            geometryRoot = list.window, layer = "BACKGROUND", sublevel = -7,
            colorToken = "accent", alpha = HEADER_HOVER_ALPHA,
        })
        hoverTexture:SetAllPoints(button)
        hoverTexture:Hide()
        button.hoverTexture = hoverTexture

        local pressedTexture = NS.Skins:CreateTexture(button, {
            geometryRoot = list.window, layer = "BACKGROUND", sublevel = -6,
            colorToken = "accent", alpha = HEADER_PRESSED_ALPHA,
        })
        pressedTexture:SetAllPoints(button)
        pressedTexture:Hide()
        button.pressedTexture = pressedTexture

        local text = NS.Skins:CreateText(button, {
            geometryRoot = list.window, fontSize = HEADER_TEXT_SIZE, colorToken = "accent",
        })
        text:SetAllPoints(button)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetWordWrap(false)
        text:SetMaxLines(1)
        text:SetText(GetHeaderText(column))
        button.text = text

        if HasHeaderIcon(column) then
            button.headerIcon = NS.Skins:CreateTexture(button, {
                geometryRoot = list.window, layer = "OVERLAY",
                width = GetHeaderIconSize(column), height = GetHeaderIconSize(column),
                atlas = column.headerAtlas, texture = column.headerTexture, colorToken = column.headerIconColorToken,
            })
            button.headerIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
            local color = column.headerIconColor
            if color then
                button.headerIcon:SetVertexColor(color.r, color.g, color.b, color.a or 1)
            end
        end

        local sortIcon = NS.Skins:CreateTexture(button, {
            geometryRoot = list.window, layer = "OVERLAY", texture = Media.GetSortArrowTexture(), colorToken = "accent",
        })
        sortIcon:SetSize(HEADER_SORT_ICON_SIZE, HEADER_SORT_ICON_SIZE)
        sortIcon:Hide()
        button.sortIcon = sortIcon

        button:SetScript("OnEnter", OnButtonEnter)
        button:SetScript("OnLeave", OnButtonLeave)
        button:SetScript("OnMouseDown", OnButtonMouseDown)
        button:SetScript("OnMouseUp", OnButtonMouseUp)
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowContextMenu(list, self.column.key)
            elseif not self.suppressClick and not header.interaction and self.column.sortKey then
                list:SetSort(self.column.sortKey)
            end
        end)

        header.buttons[#header.buttons + 1] = button

        local separator = CreateSeparator(content, 0, list)
        separator.column = column
        separator.header = header
        header.separators[#header.separators + 1] = separator
    end

    Header.ApplyColumnLayout(header, list)
    Interaction.Attach(header, list)
    header:SetScript("OnSizeChanged", Header.RefreshPixelGeometry)
    header:SetScript("OnShow", function(self)
        -- Custom font metrics may be unavailable while the window is built
        -- hidden. Remeasure once after it becomes visible, without polling.
        C_Timer.After(0, function()
            if self:IsVisible() then
                Header.RefreshPixelGeometry(self)
                Header.Refresh(self, list)
            end
        end)
    end)
    return header
end

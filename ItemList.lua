local _, NS = ...

local ItemList = {}
NS.ItemList = ItemList

local Columns = NS.ItemListColumns
local ItemRow = NS.ItemRow
local GroupRow = NS.ItemGroupRow
local ListModel = NS.ItemListModel
local Media = NS.Media
local ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B = Media.GetAccentColor()

local HEADER_HEIGHT = 24
local SCROLL_BAR_WIDTH = 14
local SCROLL_BAR_CONTENT_PADDING = 22
local SEARCH_BOX_WIDTH = 320
local SEARCH_BOX_HEIGHT = 20
local HEADER_TEXT_SIZE = 16
local EMPTY_TEXT_SIZE = 16
local HEADER_TEXT_COLOR_R = ACCENT_COLOR_R
local HEADER_TEXT_COLOR_G = ACCENT_COLOR_G
local HEADER_TEXT_COLOR_B = ACCENT_COLOR_B
local HEADER_DIVIDER_HEIGHT = 14
local HEADER_DIVIDER_COLOR_R = ACCENT_COLOR_R
local HEADER_DIVIDER_COLOR_G = ACCENT_COLOR_G
local HEADER_DIVIDER_COLOR_B = ACCENT_COLOR_B
local HEADER_DIVIDER_ALPHA = 0.68
local HEADER_BOTTOM_DIVIDER_LEFT_OFFSET = 2
local HEADER_BOTTOM_DIVIDER_RIGHT_OFFSET = -2
local HEADER_BOTTOM_DIVIDER_BOTTOM_OFFSET = -6
local HEADER_HOVER_COLOR_R = ACCENT_COLOR_R
local HEADER_HOVER_COLOR_G = ACCENT_COLOR_G
local HEADER_HOVER_COLOR_B = ACCENT_COLOR_B
local HEADER_HOVER_ALPHA = 0.08
local HEADER_PRESSED_COLOR_R = ACCENT_COLOR_R
local HEADER_PRESSED_COLOR_G = ACCENT_COLOR_G
local HEADER_PRESSED_COLOR_B = ACCENT_COLOR_B
local HEADER_PRESSED_ALPHA = 0.16
local HEADER_SORT_ICON_SIZE = 13
local HEADER_SORT_ICON_GAP = 3
local HEADER_SEPARATOR_HANDLE_WIDTH = 6
local HEADER_SEPARATOR_TOP_OFFSET = 1
local HEADER_SEPARATOR_BOTTOM_OFFSET = 1
local HEADER_SEPARATOR_TEXTURE_LENGTH = HEADER_HEIGHT - HEADER_SEPARATOR_TOP_OFFSET - HEADER_SEPARATOR_BOTTOM_OFFSET
local HEADER_SEPARATOR_TEXTURE_THICKNESS = 6
local HEADER_SEPARATOR_HOVER_ALPHA = 0.16
local HEADER_SEPARATOR_PRESSED_ALPHA = 0.28
local HEADER_SEPARATOR_LINE_HOVER_ALPHA = 0.86
local HEADER_SEPARATOR_LINE_PRESSED_ALPHA = 1
local HEADER_SEPARATOR_FRAME_LEVEL_OFFSET = 3
local HEADER_TOOLTIP_TEXT_COLOR_R = 0.86
local HEADER_TOOLTIP_TEXT_COLOR_G = 0.86
local HEADER_TOOLTIP_TEXT_COLOR_B = 0.86
local GROUP_MENU_TITLE = "Group By"
local EMPTY_TEXT_COLOR_R = 0.5
local EMPTY_TEXT_COLOR_G = 0.5
local EMPTY_TEXT_COLOR_B = 0.5
local FONT_STRING_LAYER = "OVERLAY"
local LIST_FRAME_TYPE = "Frame"
local BUTTON_FRAME_TYPE = "Button"
local EDIT_BOX_FRAME_TYPE = "EditBox"
local SEARCH_BOX_TEMPLATE = "SearchBoxTemplate"
local SCROLL_BOX_TEMPLATE = "WowScrollBoxList"
local SCROLL_BAR_FRAME_TYPE = "EventFrame"
local SCROLL_BAR_TEMPLATE = "MinimalScrollBar"
local HEADER_LEFT_OFFSET = 0
local HEADER_TOP_OFFSET = 0
local HEADER_RIGHT_OFFSET = 0
local SCROLL_BOX_LEFT_OFFSET = 0
local SCROLL_BOX_RIGHT_OFFSET = 0
local SCROLL_BOX_TOP_GAP = -2
local SCROLL_BOX_BOTTOM_OFFSET = 0
local SCROLL_BAR_RIGHT_OFFSET = -8
local SCROLL_BAR_TOP_OFFSET = -2
local SCROLL_BAR_BOTTOM_OFFSET = 2
local EMPTY_TEXT_X_OFFSET = 0
local EMPTY_TEXT_Y_OFFSET = 0
local EMPTY_LIST_TEXT = "No bag items"

local function GetPrimaryFont()
    return NS.Media and NS.Media.GetPrimaryFont and NS.Media.GetPrimaryFont() or STANDARD_TEXT_FONT
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

local function ShowGroupMenu(owner, list)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return
    end

    HideTooltip()
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(GROUP_MENU_TITLE)

        local function IsSelected(groupKey)
            return list.groupKey == ListModel.NormalizeGroupKey(groupKey)
        end

        local function SetSelected(groupKey)
            list:SetGroup(groupKey)
            return MenuResponse.Refresh
        end

        for _, groupKey in ipairs(ListModel.GetGroupKeyList()) do
            rootDescription:CreateRadio(ListModel.GetGroupLabel(groupKey), IsSelected, SetSelected, groupKey)
        end
    end)
end

local function AnchorHeaderSortIcon(button)
    button.sortIcon:ClearAllPoints()

    if button.headerIcon and button.headerIcon:IsShown() then
        local xOffset = (button.headerIcon:GetWidth() / 2) + HEADER_SORT_ICON_GAP
        button.sortIcon:SetPoint("LEFT", button, "CENTER", xOffset, 0)
        return
    end

    local label = GetHeaderText(button.column)
    if label == "" then
        button.sortIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
        return
    end

    local textWidth = button.text:GetStringWidth() or 0
    local xOffset = (textWidth / 2) + HEADER_SORT_ICON_GAP
    button.sortIcon:SetPoint("LEFT", button, "CENTER", xOffset, 0)
end

local function UpdateHeaderButtonVisualState(button)
    if button.pressedTexture and button.isPressed then
        button.pressedTexture:Show()
    elseif button.pressedTexture then
        button.pressedTexture:Hide()
    end

    if button.hoverTexture then
        if button.isHovered and not button.isPressed then
            button.hoverTexture:Show()
        else
            button.hoverTexture:Hide()
        end
    end
end

local function HeaderButton_OnEnter(button)
    if button:IsEnabled() then
        button.isHovered = true
        UpdateHeaderButtonVisualState(button)
        ShowHeaderTooltip(button)
    end
end

local function HeaderButton_OnLeave(button)
    button.isHovered = false
    button.isPressed = false
    UpdateHeaderButtonVisualState(button)
    HideTooltip()
end

local function HeaderButton_OnMouseDown(button, mouseButton)
    if mouseButton == "LeftButton" and button:IsEnabled() then
        button.isPressed = true
        UpdateHeaderButtonVisualState(button)
    end
end

local function HeaderButton_OnMouseUp(button)
    button.isPressed = false
    button.isHovered = button:IsMouseOver()
    UpdateHeaderButtonVisualState(button)
end

local function SetHeaderSeparatorLineAlpha(separator, alpha)
    if separator.line then
        separator.line:SetVertexColor(HEADER_DIVIDER_COLOR_R, HEADER_DIVIDER_COLOR_G, HEADER_DIVIDER_COLOR_B, alpha)
    end
end

local function UpdateHeaderSeparatorVisualState(separator)
    if separator.pressedTexture and separator.isPressed then
        separator.pressedTexture:Show()
    elseif separator.pressedTexture then
        separator.pressedTexture:Hide()
    end

    if separator.hoverTexture then
        if separator.isHovered and not separator.isPressed then
            separator.hoverTexture:Show()
        else
            separator.hoverTexture:Hide()
        end
    end

    if separator.isPressed then
        SetHeaderSeparatorLineAlpha(separator, HEADER_SEPARATOR_LINE_PRESSED_ALPHA)
    elseif separator.isHovered then
        SetHeaderSeparatorLineAlpha(separator, HEADER_SEPARATOR_LINE_HOVER_ALPHA)
    else
        SetHeaderSeparatorLineAlpha(separator, HEADER_DIVIDER_ALPHA)
    end
end

local function HeaderSeparator_OnEnter(separator)
    separator.isHovered = true
    UpdateHeaderSeparatorVisualState(separator)
end

local function HeaderSeparator_OnLeave(separator)
    separator.isHovered = false
    separator.isPressed = false
    UpdateHeaderSeparatorVisualState(separator)
end

local function HeaderSeparator_OnMouseDown(separator, mouseButton)
    if mouseButton == "LeftButton" then
        separator.isPressed = true
        UpdateHeaderSeparatorVisualState(separator)
    end
end

local function HeaderSeparator_OnMouseUp(separator, mouseButton)
    separator.isPressed = false
    separator.isHovered = separator:IsMouseOver()
    UpdateHeaderSeparatorVisualState(separator)

    if mouseButton == "RightButton" and separator.list then
        ShowGroupMenu(separator, separator.list)
    end
end

local function UpdateHeaderSortState(header, list)
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

        local sorted = button.column.sortKey and button.column.sortKey == list.sortKey
        if sorted then
            button.sortIcon:Show()
            if list.sortAscending then
                button.sortIcon:SetTexCoord(0, 1, 1, 0)
            else
                button.sortIcon:SetTexCoord(0, 1, 0, 1)
            end
            AnchorHeaderSortIcon(button)
        else
            button.sortIcon:Hide()
        end
    end
end

local function CreateSearchBox(parent, list)
    local searchBox = CreateFrame(EDIT_BOX_FRAME_TYPE, nil, parent, SEARCH_BOX_TEMPLATE)
    searchBox:SetSize(SEARCH_BOX_WIDTH, SEARCH_BOX_HEIGHT)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        if SearchBoxTemplate_OnTextChanged then
            SearchBoxTemplate_OnTextChanged(self)
        end

        if list.SetSearchText then
            list:SetSearchText(self:GetText())
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return searchBox
end

local function CreateHeaderSeparator(parent, xOffset)
    local separator = CreateFrame(BUTTON_FRAME_TYPE, nil, parent)
    separator:SetPoint("LEFT", parent, "LEFT", xOffset - (HEADER_SEPARATOR_HANDLE_WIDTH / 2), 0)
    separator:SetSize(HEADER_SEPARATOR_HANDLE_WIDTH, HEADER_HEIGHT)
    separator:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if separator.SetFrameLevel and parent.GetFrameLevel then
        separator:SetFrameLevel(parent:GetFrameLevel() + HEADER_SEPARATOR_FRAME_LEVEL_OFFSET)
    end

    local hoverTexture = separator:CreateTexture(nil, "BACKGROUND")
    hoverTexture:SetAllPoints(separator)
    hoverTexture:SetColorTexture(HEADER_HOVER_COLOR_R, HEADER_HOVER_COLOR_G, HEADER_HOVER_COLOR_B, HEADER_SEPARATOR_HOVER_ALPHA)
    hoverTexture:Hide()
    separator.hoverTexture = hoverTexture

    local pressedTexture = separator:CreateTexture(nil, "BACKGROUND")
    pressedTexture:SetAllPoints(separator)
    pressedTexture:SetColorTexture(HEADER_PRESSED_COLOR_R, HEADER_PRESSED_COLOR_G, HEADER_PRESSED_COLOR_B, HEADER_SEPARATOR_PRESSED_ALPHA)
    pressedTexture:Hide()
    separator.pressedTexture = pressedTexture

    local line = separator:CreateTexture(nil, "BORDER")
    line:SetTexture(Media.GetDividerTexture())
    line:SetBlendMode("ADD")
    line:SetPoint("CENTER", separator, "CENTER", 0, 0)
    -- UI-TooltipDivider is horizontal. Before rotation, width becomes visual length and height becomes visual thickness.
    line:SetSize(HEADER_SEPARATOR_TEXTURE_LENGTH, HEADER_SEPARATOR_TEXTURE_THICKNESS)
    if line.SetRotation then
        line:SetRotation(math.pi / 2)
    end
    separator.line = line

    separator:SetScript("OnEnter", HeaderSeparator_OnEnter)
    separator:SetScript("OnLeave", HeaderSeparator_OnLeave)
    separator:SetScript("OnMouseDown", HeaderSeparator_OnMouseDown)
    separator:SetScript("OnMouseUp", HeaderSeparator_OnMouseUp)
    UpdateHeaderSeparatorVisualState(separator)

    return separator
end

-- Header rendering
local function CreateHeader(parent, list)
    local columns = Columns.GetColumns()
    local columnGap = Columns.GetColumnGap()
    local header = CreateFrame(LIST_FRAME_TYPE, nil, parent)
    header:SetHeight(HEADER_HEIGHT)
    if header.SetClipsChildren then
        header:SetClipsChildren(true)
    end

    local content = CreateFrame(LIST_FRAME_TYPE, nil, header)
    content:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    if content.SetClipsChildren then
        content:SetClipsChildren(true)
    end

    local bottomDivider = header:CreateTexture(nil, "BORDER")
    bottomDivider:SetTexture(Media.GetDividerTexture())
    bottomDivider:SetBlendMode("ADD")
    bottomDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", HEADER_BOTTOM_DIVIDER_LEFT_OFFSET, HEADER_BOTTOM_DIVIDER_BOTTOM_OFFSET)
    bottomDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", HEADER_BOTTOM_DIVIDER_RIGHT_OFFSET, HEADER_BOTTOM_DIVIDER_BOTTOM_OFFSET)
    bottomDivider:SetHeight(HEADER_DIVIDER_HEIGHT)
    bottomDivider:SetVertexColor(HEADER_DIVIDER_COLOR_R, HEADER_DIVIDER_COLOR_G, HEADER_DIVIDER_COLOR_B, HEADER_DIVIDER_ALPHA)
    header.bottomDivider = bottomDivider

    header.buttons = {}
    header.separators = {}

    local xOffset = 0
    for index, column in ipairs(columns) do
        local buttonWidth = column.width
        if index == #columns then
            buttonWidth = buttonWidth + SCROLL_BAR_CONTENT_PADDING
        end

        local button = CreateFrame(BUTTON_FRAME_TYPE, nil, content)
        button:SetPoint("LEFT", content, "LEFT", xOffset, 0)
        button:SetSize(buttonWidth, HEADER_HEIGHT)
        button.column = column
        button.list = list
        button:SetEnabled(column.sortKey ~= nil)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local hoverTexture = button:CreateTexture(nil, "BACKGROUND")
        hoverTexture:SetDrawLayer("BACKGROUND", -7)
        hoverTexture:SetAllPoints(button)
        hoverTexture:SetColorTexture(HEADER_HOVER_COLOR_R, HEADER_HOVER_COLOR_G, HEADER_HOVER_COLOR_B, HEADER_HOVER_ALPHA)
        hoverTexture:Hide()
        button.hoverTexture = hoverTexture

        local pressedTexture = button:CreateTexture(nil, "BACKGROUND")
        pressedTexture:SetDrawLayer("BACKGROUND", -6)
        pressedTexture:SetAllPoints(button)
        pressedTexture:SetColorTexture(HEADER_PRESSED_COLOR_R, HEADER_PRESSED_COLOR_G, HEADER_PRESSED_COLOR_B, HEADER_PRESSED_ALPHA)
        pressedTexture:Hide()
        button.pressedTexture = pressedTexture

        local text = button:CreateFontString(nil, FONT_STRING_LAYER)
        text:SetFont(GetPrimaryFont(), HEADER_TEXT_SIZE)
        text:SetTextColor(HEADER_TEXT_COLOR_R, HEADER_TEXT_COLOR_G, HEADER_TEXT_COLOR_B)
        text:SetAllPoints(button)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetText(GetHeaderText(column))
        button.text = text

        if HasHeaderIcon(column) then
            local headerIcon = button:CreateTexture(nil, FONT_STRING_LAYER)
            headerIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.headerIcon = headerIcon
            ApplyHeaderIcon(button)
        end

        local sortIcon = button:CreateTexture(nil, FONT_STRING_LAYER)
        sortIcon:SetTexture(Media.GetSortArrowTexture())
        sortIcon:SetSize(HEADER_SORT_ICON_SIZE, HEADER_SORT_ICON_SIZE)
        sortIcon:SetVertexColor(ACCENT_COLOR_R, ACCENT_COLOR_G, ACCENT_COLOR_B)
        sortIcon:Hide()
        button.sortIcon = sortIcon

        button:SetScript("OnEnter", HeaderButton_OnEnter)
        button:SetScript("OnLeave", HeaderButton_OnLeave)
        button:SetScript("OnMouseDown", HeaderButton_OnMouseDown)
        button:SetScript("OnMouseUp", HeaderButton_OnMouseUp)

        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowGroupMenu(self, list)
            elseif self.column.sortKey then
                list:SetSort(self.column.sortKey)
            end
        end)

        header.buttons[#header.buttons + 1] = button

        if index < #columns then
            local separator = CreateHeaderSeparator(content, xOffset + column.width + (columnGap / 2))
            separator.leftColumn = column
            separator.rightColumn = columns[index + 1]
            separator.list = list
            header.separators[#header.separators + 1] = separator
        end

        xOffset = xOffset + column.width + columnGap
    end

    UpdateHeaderSortState(header, list)

    return header
end

function ItemList.GetPreferredWidth()
    return Columns.GetContentWidth() + SCROLL_BAR_CONTENT_PADDING
end

function ItemList.Create(parent)
    local list = {}
    list.items = {}
    list.searchText = ""
    list.sortKey = ListModel.NormalizeSortKey(NS.db:Get("list", "sortKey"))
    list.sortAscending = NS.db:Get("list", "sortAscending") ~= false
    list.groupKey = ListModel.NormalizeGroupKey(NS.db:Get("list", "groupKey"))
    list.collapsedGroups = {}

    local frame = CreateFrame(LIST_FRAME_TYPE, nil, parent)
    frame:SetAllPoints(parent)
    if frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
    list.frame = frame

    local header = CreateHeader(frame, list)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_LEFT_OFFSET, HEADER_TOP_OFFSET)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", HEADER_RIGHT_OFFSET)
    list.header = header

    local scrollBox = CreateFrame(LIST_FRAME_TYPE, nil, frame, SCROLL_BOX_TEMPLATE)
    scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", SCROLL_BOX_LEFT_OFFSET, SCROLL_BOX_TOP_GAP)
    scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", SCROLL_BOX_RIGHT_OFFSET, SCROLL_BOX_BOTTOM_OFFSET)
    if scrollBox.SetClipsChildren then
        scrollBox:SetClipsChildren(true)
    end
    list.scrollBox = scrollBox

    local scrollBar = CreateFrame(SCROLL_BAR_FRAME_TYPE, nil, frame, SCROLL_BAR_TEMPLATE)
    scrollBar:SetPoint("TOPRIGHT", scrollBox, "TOPRIGHT", SCROLL_BAR_RIGHT_OFFSET, SCROLL_BAR_TOP_OFFSET)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollBox, "BOTTOMRIGHT", SCROLL_BAR_RIGHT_OFFSET, SCROLL_BAR_BOTTOM_OFFSET)
    list.scrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(dataIndex, elementData)
        if elementData.rowType == ListModel.GetRowTypeGroup() then
            return GroupRow.GetRowHeight()
        end

        return ItemRow.GetRowHeight()
    end)
    view:SetElementFactory(function(factory, elementData)
        if elementData.rowType == ListModel.GetRowTypeGroup() then
            factory(BUTTON_FRAME_TYPE, function(row, rowData)
                row.rightClipPadding = SCROLL_BAR_CONTENT_PADDING
                GroupRow.Render(row, rowData, list)
            end)
        else
            factory(LIST_FRAME_TYPE, function(row, rowData)
                row.rightClipPadding = SCROLL_BAR_CONTENT_PADDING
                ItemRow.Render(row, rowData.item)
            end)
        end
    end)
    view:SetElementResetter(function(row)
        if row.groupInitialized then
            GroupRow.Reset(row)
        else
            ItemRow.Reset(row)
        end
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    list.view = view

    local emptyText = frame:CreateFontString(nil, FONT_STRING_LAYER)
    emptyText:SetFont(GetPrimaryFont(), EMPTY_TEXT_SIZE)
    emptyText:SetTextColor(EMPTY_TEXT_COLOR_R, EMPTY_TEXT_COLOR_G, EMPTY_TEXT_COLOR_B)
    emptyText:SetPoint("CENTER", scrollBox, "CENTER", EMPTY_TEXT_X_OFFSET, EMPTY_TEXT_Y_OFFSET)
    emptyText:SetText(EMPTY_LIST_TEXT)
    emptyText:Hide()
    list.emptyText = emptyText

    function list:RefreshHeaderSortState()
        UpdateHeaderSortState(self.header, self)
    end

    function list:RefreshDataProvider(retainScrollPosition)
        local rows, visibleItemCount = ListModel.BuildRows(self.items, self)
        local dataProvider = CreateDataProvider(rows)

        ItemRow.ClearCooldownCache()
        self.scrollBox:SetDataProvider(dataProvider, retainScrollPosition and ScrollBoxConstants.RetainScrollPosition or nil)
        self.emptyText:SetShown(visibleItemCount == 0)
        self.dataProvider = dataProvider
        self.displayRows = rows
        self.visibleItemCount = visibleItemCount
        self:RefreshHeaderSortState()
    end

    function list:SetItems(items)
        self.items = items or {}
        self:RefreshDataProvider(true)
    end

    function list:SetSearchText(searchText)
        searchText = searchText or ""
        if self.searchText == searchText then
            return
        end

        self.searchText = searchText
        self:RefreshDataProvider(false)
    end

    function list:CreateSearchBox(parent)
        if self.searchBox then
            self.searchBox:SetParent(parent)
            self.searchBox:ClearAllPoints()
            return self.searchBox
        end

        self.searchBox = CreateSearchBox(parent, self)
        return self.searchBox
    end

    function list:SetSort(sortKey, sortAscending)
        sortKey = ListModel.NormalizeSortKey(sortKey)

        if sortAscending == nil then
            if self.sortKey == sortKey then
                sortAscending = not self.sortAscending
            else
                local column = Columns.GetColumnBySortKey(sortKey)
                sortAscending = not (column and column.defaultAscending == false)
            end
        end

        self.sortKey = sortKey
        self.sortAscending = sortAscending == true

        NS.db:Set("list", "sortKey", self.sortKey)
        NS.db:Set("list", "sortAscending", self.sortAscending)

        self:RefreshDataProvider(true)
    end

    function list:SetGroup(groupKey)
        groupKey = ListModel.NormalizeGroupKey(groupKey)
        if self.groupKey == groupKey then
            return
        end

        self.groupKey = groupKey
        self.collapsedGroups = {}
        NS.db:Set("list", "groupKey", self.groupKey)
        self:RefreshDataProvider(true)
    end

    function list:ToggleGroupCollapsed(groupID)
        self.collapsedGroups[groupID] = not self.collapsedGroups[groupID]
        self:RefreshDataProvider(true)
    end

    function list:RefreshVisibleRows()
        for _, row in ipairs(self.view:GetFrames()) do
            if row.item then
                ItemRow.Render(row, row.item)
            elseif row.groupData then
                GroupRow.Render(row, row.groupData, self)
            end
        end
    end

    function list:RefreshVisibleCooldowns()
        ItemRow.ClearCooldownCache()
        for _, row in ipairs(self.view:GetFrames()) do
            ItemRow.RefreshCooldown(row)
        end
    end

    return list
end

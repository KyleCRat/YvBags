local _, NS = ...

local ItemList = {}
NS.ItemList = ItemList

local Columns = NS.ItemListColumns
local ItemRow = NS.ItemRow
local GroupRow = NS.ItemGroupRow
local ListModel = NS.ItemListModel

local HEADER_HEIGHT = 24
local SCROLL_BAR_WIDTH = 14
local SCROLL_BAR_CONTENT_PADDING = 22
local SEARCH_BOX_WIDTH = 320
local SEARCH_BOX_HEIGHT = 20
local HEADER_TEXT_SIZE = 16
local EMPTY_TEXT_SIZE = 16
local HEADER_TEXT_COLOR_R = 1
local HEADER_TEXT_COLOR_G = 0.82
local HEADER_TEXT_COLOR_B = 0
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

local function GetHeaderText(column, list)
    local label = column.label or ""

    if column.sortKey and column.sortKey == list.sortKey then
        local indicator = list.sortAscending and "^" or "v"
        if label == "" then
            return indicator
        end

        return label .. " " .. indicator
    end

    return label
end

local function UpdateHeaderSortState(header, list)
    if not header or not header.buttons then
        return
    end

    for _, button in ipairs(header.buttons) do
        button.text:SetText(GetHeaderText(button.column, list))
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
    content:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -SCROLL_BAR_CONTENT_PADDING, 0)
    if content.SetClipsChildren then
        content:SetClipsChildren(true)
    end

    header.buttons = {}

    local xOffset = 0
    for _, column in ipairs(columns) do
        local button = CreateFrame(BUTTON_FRAME_TYPE, nil, content)
        button:SetPoint("LEFT", content, "LEFT", xOffset, 0)
        button:SetSize(column.width, HEADER_HEIGHT)
        button.column = column
        button:SetEnabled(column.sortKey ~= nil)

        local text = button:CreateFontString(nil, FONT_STRING_LAYER)
        text:SetFont(GetPrimaryFont(), HEADER_TEXT_SIZE)
        text:SetTextColor(HEADER_TEXT_COLOR_R, HEADER_TEXT_COLOR_G, HEADER_TEXT_COLOR_B)
        text:SetAllPoints(button)
        text:SetJustifyH(column.justify or "LEFT")
        text:SetJustifyV("MIDDLE")
        text:SetText(GetHeaderText(column, list))
        button.text = text

        if column.sortKey then
            button:SetScript("OnClick", function(self)
                list:SetSort(self.column.sortKey)
            end)
        end

        header.buttons[#header.buttons + 1] = button

        xOffset = xOffset + column.width + columnGap
    end

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

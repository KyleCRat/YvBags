local _, NS = ...

-- Virtualized item-list controller and ScrollBox composition contract.
local ItemList = {}
NS.ItemList = ItemList

local Columns = NS.ItemListColumns
local CursorDrop = NS.ItemListCursorDrop
local GroupRow = NS.ItemGroupRow
local Header = NS.ItemListHeader
local ItemRow = NS.ItemRow
local Layout = NS.ItemListLayout
local ListModel = NS.ItemListModel
local SearchBox = NS.ItemListSearchBox

local SCROLL_BOX_TEMPLATE = "WowScrollBoxList"
local SCROLL_BAR_TEMPLATE = "MinimalScrollBar"
local ITEM_ROW_FRAME_TYPE = "Frame"
local ITEM_ROW_PREWARM_BUFFER = 2
local MIN_PREWARMED_ITEM_ROWS = 12
local EMPTY_TEXT_SIZE = 16
local EMPTY_TEXT_COLOR_R = 0.5
local EMPTY_TEXT_COLOR_G = 0.5
local EMPTY_TEXT_COLOR_B = 0.5
local EMPTY_LIST_TEXT = "No bag items"

local ListController = {}
ListController.__index = ListController

local function ApplyStoredProfileSettings(list)
    list.sortKey = ListModel.NormalizeSortKey(NS.db:Get("list", "sortKey"))
    list.sortAscending = NS.db:Get("list", "sortAscending") ~= false
    list.secondarySortKey = ListModel.NormalizeSecondarySortKey(NS.db:Get("list", "secondarySortKey"))
    list.secondarySortAscending = NS.db:Get("list", "secondarySortAscending") ~= false
    list.groupKey = ListModel.NormalizeGroupKey(NS.db:Get("list", "groupKey"))

    if not ListModel.IsSecondarySortEnabled(list.secondarySortKey, list.sortKey) then
        list.secondarySortKey = ListModel.GetNoSecondarySortKey()
        list.secondarySortAscending = true
    end
end

local function CreateListState()
    local list = setmetatable({}, ListController)
    list.items = {}
    list.searchText = ""
    list.collapsedGroups = {}
    ApplyStoredProfileSettings(list)

    return list
end

function ListController:RefreshHeaderSortState()
    Header.Refresh(self.header, self)
end

function ListController:RefreshDataProvider(retainScrollPosition)
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

function ListController:SetItems(items)
    self.items = items or {}
    self:RefreshDataProvider(true)
end

function ListController:SetHighlightedBagID(bagID)
    if self.highlightedBagID == bagID then
        return
    end

    self.highlightedBagID = bagID
    if self.scrollBox and self.scrollBox.ForEachFrame then
        self.scrollBox:ForEachFrame(function(row)
            if row.rowInitialized then
                ItemRow.SetHighlightedBagID(row, self.highlightedBagID)
            end
        end)
    end
end

function ListController:SetSearchText(searchText)
    searchText = searchText or ""
    if self.searchText == searchText then
        return
    end

    self.searchText = searchText
    self:RefreshDataProvider(false)
end

function ListController:CreateSearchBox(parent)
    if self.searchBox then
        self.searchBox:SetParent(parent)
        self.searchBox:ClearAllPoints()
        return self.searchBox
    end

    self.searchBox = SearchBox.Create(parent, self)
    return self.searchBox
end

function ListController:SetSort(sortKey, sortAscending)
    sortKey = ListModel.NormalizeSortKey(sortKey)

    if ListModel.IsManualSortKey(sortKey) then
        sortAscending = true
    elseif sortAscending == nil then
        if self.sortKey == sortKey then
            sortAscending = not self.sortAscending
        else
            sortAscending = Columns.GetDefaultSortAscending(sortKey)
        end
    end

    self.sortKey = sortKey
    self.sortAscending = sortAscending == true

    if not ListModel.IsSecondarySortEnabled(self.secondarySortKey, self.sortKey) then
        self.secondarySortKey = ListModel.GetNoSecondarySortKey()
        self.secondarySortAscending = true
        NS.db:Set("list", "secondarySortKey", self.secondarySortKey)
        NS.db:Set("list", "secondarySortAscending", self.secondarySortAscending)
    end

    NS.db:Set("list", "sortKey", self.sortKey)
    NS.db:Set("list", "sortAscending", self.sortAscending)
    self:RefreshDataProvider(true)
end

function ListController:SetSecondarySort(sortKey, sortAscending)
    sortKey = ListModel.NormalizeSecondarySortKey(sortKey)
    if not ListModel.IsSecondarySortEnabled(sortKey, self.sortKey) then
        sortKey = ListModel.GetNoSecondarySortKey()
    end

    if sortKey == ListModel.GetNoSecondarySortKey() then
        sortAscending = true
    elseif sortAscending == nil then
        if sortKey == self.secondarySortKey then
            sortAscending = self.secondarySortAscending
        else
            sortAscending = Columns.GetDefaultSortAscending(sortKey)
        end
    end

    if self.secondarySortKey == sortKey and self.secondarySortAscending == (sortAscending == true) then
        return
    end

    self.secondarySortKey = sortKey
    self.secondarySortAscending = sortAscending == true
    NS.db:Set("list", "secondarySortKey", self.secondarySortKey)
    NS.db:Set("list", "secondarySortAscending", self.secondarySortAscending)
    self:RefreshDataProvider(true)
end

function ListController:SetSecondarySortDirection(sortAscending)
    sortAscending = sortAscending == true
    if self.secondarySortAscending == sortAscending then
        return
    end

    self.secondarySortAscending = sortAscending
    NS.db:Set("list", "secondarySortAscending", self.secondarySortAscending)
    self:RefreshDataProvider(true)
end

function ListController:SetGroup(groupKey)
    groupKey = ListModel.NormalizeGroupKey(groupKey)
    if self.groupKey == groupKey then
        return
    end

    self.groupKey = groupKey
    self.collapsedGroups = {}
    NS.db:Set("list", "groupKey", self.groupKey)
    self:RefreshDataProvider(true)
end

function ListController:ToggleGroupCollapsed(groupID)
    self.collapsedGroups[groupID] = not self.collapsedGroups[groupID]
    self:RefreshDataProvider(true)
end

function ListController:RefreshVisibleRows()
    for _, row in ipairs(self.view:GetFrames()) do
        if row.item then
            ItemRow.Render(row, row.item, self)
        elseif row.groupData then
            GroupRow.Render(row, row.groupData, self)
        end
    end
end

function ListController:RefreshVisibleCooldowns()
    ItemRow.ClearCooldownCache()
    for _, row in ipairs(self.view:GetFrames()) do
        ItemRow.RefreshCooldown(row)
    end
end

function ListController:RefreshProfileSettings()
    ApplyStoredProfileSettings(self)
    self.collapsedGroups = {}
    self:RefreshDataProvider(true)
end

local function CreateScrollView(list)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, elementData)
        if elementData.rowType == ListModel.GetRowTypeGroup() then
            return GroupRow.GetRowHeight()
        end

        return ItemRow.GetRowHeight()
    end)
    view:SetElementFactory(function(factory, elementData)
        if elementData.rowType == ListModel.GetRowTypeGroup() then
            factory("Button", function(row, rowData)
                row.rightClipPadding = Layout.ScrollBarContentPadding
                CursorDrop.HookTarget(row)
                GroupRow.Render(row, rowData, list)
            end)
        else
            factory(ITEM_ROW_FRAME_TYPE, function(row, rowData)
                row.rightClipPadding = Layout.ScrollBarContentPadding
                ItemRow.Render(row, rowData.item, list)
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

    return view
end

local function PrewarmItemRows(list)
    local visibleExtent = math.max(list.scrollBox:GetVisibleExtent(), list.frame:GetHeight())
    local rowCount = math.max(
        MIN_PREWARMED_ITEM_ROWS,
        math.ceil(visibleExtent / ItemRow.GetRowHeight()) + ITEM_ROW_PREWARM_BUFFER
    )
    local rows = {}

    for index = 1, rowCount do
        local row = list.view.frameFactory:Create(
            list.view:GetScrollTarget(),
            ITEM_ROW_FRAME_TYPE,
            list.view.frameFactoryResetter
        )
        row.rightClipPadding = Layout.ScrollBarContentPadding
        ItemRow.Initialize(row)
        ItemRow.Reset(row)
        rows[index] = row
    end

    for index = 1, rowCount do
        list.view.frameFactory:Release(rows[index])
    end
end

local function CreateEmptyText(list)
    local emptyText = list.frame:CreateFontString(nil, "OVERLAY")
    emptyText:SetFont(NS.Media.GetPrimaryFont(), EMPTY_TEXT_SIZE)
    emptyText:SetTextColor(EMPTY_TEXT_COLOR_R, EMPTY_TEXT_COLOR_G, EMPTY_TEXT_COLOR_B)
    emptyText:SetPoint("CENTER", list.scrollBox, "CENTER", 0, 0)
    emptyText:SetText(EMPTY_LIST_TEXT)
    emptyText:Hide()
    return emptyText
end

-- Public module contract
function ItemList.GetPreferredWidth()
    return Columns.GetContentWidth() + Layout.ScrollBarContentPadding
end

function ItemList.Create(parent)
    local list = CreateListState()

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:SetClipsChildren(true)
    list.frame = frame

    local header = Header.Create(frame, list)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", Layout.HeaderLeftOffset, Layout.HeaderTopOffset)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", Layout.HeaderRightOffset, 0)
    list.header = header

    local scrollBox = CreateFrame("Frame", nil, frame, SCROLL_BOX_TEMPLATE)
    scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", Layout.ScrollBoxLeftOffset, Layout.ScrollBoxTopGap)
    scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Layout.ScrollBoxRightOffset, Layout.ScrollBoxBottomOffset)
    scrollBox:SetClipsChildren(true)
    list.scrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, frame, SCROLL_BAR_TEMPLATE)
    Layout.PositionScrollBar(scrollBar, scrollBox)
    list.scrollBar = scrollBar

    local view = CreateScrollView(list)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    list.view = view
    PrewarmItemRows(list)

    CursorDrop.Attach(list)
    list.emptyText = CreateEmptyText(list)

    local function OnProfileDataChanged()
        list:RefreshProfileSettings()
    end

    NS.db:RegisterLifecycleCallback("OnDataChanged", OnProfileDataChanged)
    NS.db:RegisterLifecycleCallback("OnReset", OnProfileDataChanged)
    return list
end

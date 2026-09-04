local _, NS = ...

-- Virtualized item-list controller and ScrollBox composition contract.
local ItemList = {}
NS.ItemList = ItemList

local Columns = NS.ItemListColumns
local CursorDrop = NS.ItemListCursorDrop
local DividerRow = NS.ItemSectionDividerRow
local GroupRow = NS.ItemGroupRow
local Header = NS.ItemListHeader
local ItemRow = NS.ItemRow
local Layout = NS.ItemListLayout
local ListModel = NS.ItemListModel
local ListSettings = NS.ItemListSettings
local SearchBox = NS.ItemListSearchBox

local SCROLL_BOX_TEMPLATE = "WowScrollBoxList"
local SCROLL_BAR_TEMPLATE = "MinimalScrollBar"
local ITEM_ROW_FRAME_TYPE = "Frame"
-- A distinct native type keeps dividers out of the protected item-row pool.
local DIVIDER_ROW_FRAME_TYPE = "EventFrame"
local ITEM_ROW_PREWARM_BUFFER = 2
local MIN_PREWARMED_ITEM_ROWS = 12
local EMPTY_TEXT_SIZE = 16
local EMPTY_TEXT_COLOR_R = 0.5
local EMPTY_TEXT_COLOR_G = 0.5
local EMPTY_TEXT_COLOR_B = 0.5
local DEFAULT_EMPTY_LIST_TEXT = "No items"

local ListController = {}
ListController.__index = ListController

local function ApplyStoredProfileSettings(list)
    local scope = list.settingsScope
    local previousSortKey = list.sortKey
    local previousSortAscending = list.sortAscending
    local previousSecondarySortKey = list.secondarySortKey
    local previousSecondarySortAscending = list.secondarySortAscending
    local previousGroupKey = list.groupKey
    local previousPinDisplayMode = list.pinDisplayMode

    list.sortKey = ListModel.NormalizeSortKey(
        ListSettings.GetListValue(scope, "sortKey")
    )
    list.sortAscending =
        ListSettings.GetListValue(scope, "sortAscending") ~= false
    list.secondarySortKey = ListModel.NormalizeSecondarySortKey(
        ListSettings.GetListValue(scope, "secondarySortKey")
    )
    list.secondarySortAscending =
        ListSettings.GetListValue(scope, "secondarySortAscending") ~= false
    list.groupKey = ListModel.NormalizeGroupKey(
        ListSettings.GetListValue(scope, "groupKey")
    )
    list.pinDisplayMode = NS.ItemPins.NormalizeDisplayMode(
        ListSettings.GetPinDisplayMode(scope)
    )

    if not ListModel.IsSecondarySortEnabled(list.secondarySortKey, list.sortKey) then
        list.secondarySortKey = ListModel.GetNoSecondarySortKey()
        list.secondarySortAscending = true
    end

    return previousSortKey ~= list.sortKey
        or previousSortAscending ~= list.sortAscending
        or previousSecondarySortKey ~= list.secondarySortKey
        or previousSecondarySortAscending ~= list.secondarySortAscending
        or previousGroupKey ~= list.groupKey
        or previousPinDisplayMode ~= list.pinDisplayMode
end

local function CreateListState(context)
    local list = setmetatable({}, ListController)
    list.context = context
    list.settingsScope = context.settingsScope
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

function ListController:SetEmptyText(text)
    self.emptyText:SetText(text or self.context.emptyText or DEFAULT_EMPTY_LIST_TEXT)
end

function ListController:InvalidateCursorDropTarget()
    if self.cursorDropOverlay then
        self.cursorDropOverlay.dropTargetDirty = true
    end
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
        ListSettings.SetListValue(
            self.settingsScope,
            "secondarySortKey",
            self.secondarySortKey
        )
        ListSettings.SetListValue(
            self.settingsScope,
            "secondarySortAscending",
            self.secondarySortAscending
        )
    end

    ListSettings.SetListValue(self.settingsScope, "sortKey", self.sortKey)
    ListSettings.SetListValue(
        self.settingsScope,
        "sortAscending",
        self.sortAscending
    )
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
    ListSettings.SetListValue(
        self.settingsScope,
        "secondarySortKey",
        self.secondarySortKey
    )
    ListSettings.SetListValue(
        self.settingsScope,
        "secondarySortAscending",
        self.secondarySortAscending
    )
    self:RefreshDataProvider(true)
end

function ListController:SetSecondarySortDirection(sortAscending)
    sortAscending = sortAscending == true
    if self.secondarySortAscending == sortAscending then
        return
    end

    self.secondarySortAscending = sortAscending
    ListSettings.SetListValue(
        self.settingsScope,
        "secondarySortAscending",
        self.secondarySortAscending
    )
    self:RefreshDataProvider(true)
end

function ListController:SetGroup(groupKey)
    groupKey = ListModel.NormalizeGroupKey(groupKey)
    if self.groupKey == groupKey then
        return
    end

    self.groupKey = groupKey
    self.collapsedGroups = {}
    ListSettings.SetListValue(self.settingsScope, "groupKey", self.groupKey)
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

function ListController:RefreshVisibleNewItemStates()
    for _, row in ipairs(self.view:GetFrames()) do
        if row.item then
            ItemRow.RefreshNewItemState(row)
        end
    end
end

function ListController:StopNewItemAnimations()
    for _, row in ipairs(self.view:GetFrames()) do
        if row.rowInitialized then
            ItemRow.StopNewItemAnimation(row)
        end
    end
end

function ListController:RefreshItemLock(bagID, slotIndex, isLocked)
    for _, row in ipairs(self.view:GetFrames()) do
        local item = row.item
        if item and item.bagID == bagID and item.slotIndex == slotIndex then
            ItemRow.RefreshLock(row, isLocked)
            return
        end
    end
end

function ListController:RefreshProfileSettings(forceRefresh)
    local settingsChanged = ApplyStoredProfileSettings(self)
    if not forceRefresh and not settingsChanged then
        return
    end

    self.collapsedGroups = {}
    self:RefreshDataProvider(true)
end

function ListController:ScheduleProfileSettingsRefresh(forceRefresh)
    self.profileSettingsRefreshForced =
        self.profileSettingsRefreshForced or forceRefresh == true
    if self.profileSettingsRefreshScheduled then
        return
    end

    self.profileSettingsRefreshScheduled = true
    C_Timer.After(0, function()
        if not self.profileSettingsRefreshScheduled then
            return
        end

        self.profileSettingsRefreshScheduled = false
        local forced = self.profileSettingsRefreshForced
        self.profileSettingsRefreshForced = false
        self:RefreshProfileSettings(forced)
    end)
end

local function CreateScrollView(list)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, elementData)
        if elementData.rowType == ListModel.GetRowTypeDivider() then
            return DividerRow.GetRowHeight()
        elseif elementData.rowType == ListModel.GetRowTypeGroup() then
            return GroupRow.GetRowHeight()
        end

        return ItemRow.GetRowHeight()
    end)
    view:SetElementFactory(function(factory, elementData)
        if elementData.rowType == ListModel.GetRowTypeDivider() then
            factory(DIVIDER_ROW_FRAME_TYPE, function(row)
                row.rightClipPadding = Layout.ScrollBarContentPadding
                DividerRow.Render(row)
            end)
        elseif elementData.rowType == ListModel.GetRowTypeGroup() then
            factory("Button", function(row, rowData)
                row.rightClipPadding = Layout.ScrollBarContentPadding
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
        if row.sectionDividerInitialized then
            DividerRow.Reset(row)
        elseif row.groupInitialized then
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
        ItemRow.Initialize(row, list)
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
    emptyText:SetText(list.context.emptyText or DEFAULT_EMPTY_LIST_TEXT)
    emptyText:Hide()
    return emptyText
end

-- Public module contract
function ItemList.GetPreferredWidth()
    return Columns.GetContentWidth() + Layout.ScrollBarContentPadding
end

function ItemList.Create(parent, context)
    context = context or {}
    context.settingsScope = context.settingsScope
        or ListSettings.Scopes.Bags
    context.itemButtonAdapter = context.itemButtonAdapter or NS.ItemRowButton
    context.emptyText = context.emptyText or "No bag items"
    context.handleItemEnter = context.handleItemEnter or function()
        return false
    end

    local list = CreateListState(context)

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

    if context.cursorDrop then
        CursorDrop.Attach(list)
    end
    list.emptyText = CreateEmptyText(list)

    local function OnProfileLifecycleChanged()
        -- Coalesce lifecycle callbacks after every profile-backed module has
        -- rebuilt its caches; LibSimpleDB does not promise callback-map order.
        list:ScheduleProfileSettingsRefresh(true)
    end

    local function OnProfileSettingChanged()
        list:ScheduleProfileSettingsRefresh(false)
    end

    NS.db:RegisterLifecycleCallback("OnDataChanged", OnProfileLifecycleChanged)
    NS.db:RegisterLifecycleCallback("OnReset", OnProfileLifecycleChanged)
    NS.db:RegisterTreeCallback(OnProfileSettingChanged, "list")
    NS.db:RegisterTreeCallback(OnProfileSettingChanged, "pins")
    if list.settingsScope == ListSettings.Scopes.Bank then
        NS.db:RegisterTreeCallback(OnProfileSettingChanged, "bank")
    end
    return list
end

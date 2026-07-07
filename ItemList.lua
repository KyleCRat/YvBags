local _, NS = ...

local ItemList = {}
NS.ItemList = ItemList

local Columns = NS.ItemListColumns
local ItemRow = NS.ItemRow

local HEADER_HEIGHT = 24
local SCROLL_BAR_WIDTH = 14
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
local SCROLL_BAR_X_OFFSET = 4
local SCROLL_BAR_TOP_OFFSET = -2
local SCROLL_BAR_BOTTOM_OFFSET = 2
local EMPTY_TEXT_X_OFFSET = 0
local EMPTY_TEXT_Y_OFFSET = 0
local EMPTY_LIST_TEXT = "No bag items"

local function GetPrimaryFont()
    return NS.Media and NS.Media.GetPrimaryFont and NS.Media.GetPrimaryFont() or STANDARD_TEXT_FONT
end

-- Header rendering
local function CreateHeader(parent)
    local columns = Columns.GetColumns()
    local columnGap = Columns.GetColumnGap()
    local header = CreateFrame(LIST_FRAME_TYPE, nil, parent)
    header:SetHeight(HEADER_HEIGHT)
    if header.SetClipsChildren then
        header:SetClipsChildren(true)
    end

    local xOffset = 0
    for _, column in ipairs(columns) do
        local text = header:CreateFontString(nil, FONT_STRING_LAYER)
        text:SetFont(GetPrimaryFont(), HEADER_TEXT_SIZE)
        text:SetTextColor(HEADER_TEXT_COLOR_R, HEADER_TEXT_COLOR_G, HEADER_TEXT_COLOR_B)
        text:SetPoint("LEFT", header, "LEFT", xOffset, 0)
        text:SetSize(column.width, HEADER_HEIGHT)
        text:SetJustifyH(column.justify or "LEFT")
        text:SetJustifyV("MIDDLE")
        text:SetText(column.label)

        xOffset = xOffset + column.width + columnGap
    end

    return header
end

function ItemList.GetPreferredWidth()
    return Columns.GetContentWidth() + SCROLL_BAR_WIDTH
end

function ItemList.Create(parent)
    local list = {}

    local frame = CreateFrame(LIST_FRAME_TYPE, nil, parent)
    frame:SetAllPoints(parent)
    if frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
    list.frame = frame

    local header = CreateHeader(frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_LEFT_OFFSET, HEADER_TOP_OFFSET)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SCROLL_BAR_WIDTH, HEADER_RIGHT_OFFSET)
    list.header = header

    local scrollBox = CreateFrame(LIST_FRAME_TYPE, nil, frame, SCROLL_BOX_TEMPLATE)
    scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", SCROLL_BOX_LEFT_OFFSET, SCROLL_BOX_TOP_GAP)
    scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLL_BAR_WIDTH + SCROLL_BOX_RIGHT_OFFSET, SCROLL_BOX_BOTTOM_OFFSET)
    if scrollBox.SetClipsChildren then
        scrollBox:SetClipsChildren(true)
    end
    list.scrollBox = scrollBox

    local scrollBar = CreateFrame(SCROLL_BAR_FRAME_TYPE, nil, frame, SCROLL_BAR_TEMPLATE)
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", SCROLL_BAR_X_OFFSET, SCROLL_BAR_TOP_OFFSET)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", SCROLL_BAR_X_OFFSET, SCROLL_BAR_BOTTOM_OFFSET)
    list.scrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ItemRow.GetRowHeight())
    view:SetElementInitializer("Frame", ItemRow.Render)
    view:SetElementResetter(ItemRow.Reset)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    list.view = view

    local emptyText = frame:CreateFontString(nil, FONT_STRING_LAYER)
    emptyText:SetFont(GetPrimaryFont(), EMPTY_TEXT_SIZE)
    emptyText:SetTextColor(EMPTY_TEXT_COLOR_R, EMPTY_TEXT_COLOR_G, EMPTY_TEXT_COLOR_B)
    emptyText:SetPoint("CENTER", scrollBox, "CENTER", EMPTY_TEXT_X_OFFSET, EMPTY_TEXT_Y_OFFSET)
    emptyText:SetText(EMPTY_LIST_TEXT)
    emptyText:Hide()
    list.emptyText = emptyText

    function list:SetItems(items)
        local rows = {}

        if items then
            for _, item in ipairs(items) do
                rows[#rows + 1] = item
            end
        end

        local dataProvider = CreateDataProvider(rows)
        ItemRow.ClearCooldownCache()
        self.scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
        self.emptyText:SetShown(#rows == 0)
        self.dataProvider = dataProvider
    end

    function list:RefreshVisibleRows()
        for _, row in ipairs(self.view:GetFrames()) do
            if row.item then
                ItemRow.Render(row, row.item)
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

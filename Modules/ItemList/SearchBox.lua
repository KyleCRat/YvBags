local _, NS = ...

-- Search-box construction contract for the item-list controller.
local SearchBox = {}
NS.ItemListSearchBox = SearchBox

local SEARCH_BOX_TEMPLATE = "SearchBoxNineSliceTemplate"
local SEARCH_BOX_WIDTH = 320
local SEARCH_BOX_TEXT_SIZE = 13
local SEARCH_BOX_FONT_FLAGS = ""
local SEARCH_ICON_LEFT_OFFSET = 7
local SEARCH_ICON_Y_OFFSET = 1
local CLEAR_BUTTON_RIGHT_OFFSET = -4
local CLEAR_BUTTON_Y_OFFSET = 1
local SEARCH_TEXT_LEFT_INSET = 25
local SEARCH_TEXT_RIGHT_INSET = 23

function SearchBox.Create(parent, list)
    local searchBox = CreateFrame("EditBox", nil, parent, SEARCH_BOX_TEMPLATE)
    searchBox:SetWidth(SEARCH_BOX_WIDTH)
    searchBox.Background:SetAtlas(NS.Media.GetTextInputBackgroundAtlas(), false)
    searchBox:SetFont(NS.Media.GetPrimaryFont(), SEARCH_BOX_TEXT_SIZE, SEARCH_BOX_FONT_FLAGS)
    searchBox:SetJustifyV("MIDDLE")
    searchBox:SetTextInsets(SEARCH_TEXT_LEFT_INSET, SEARCH_TEXT_RIGHT_INSET, 0, 0)
    searchBox.searchIcon:ClearAllPoints()
    searchBox.searchIcon:SetPoint(
        "LEFT",
        searchBox,
        "LEFT",
        SEARCH_ICON_LEFT_OFFSET,
        SEARCH_ICON_Y_OFFSET
    )
    searchBox.clearButton:ClearAllPoints()
    searchBox.clearButton:SetPoint(
        "RIGHT",
        searchBox,
        "RIGHT",
        CLEAR_BUTTON_RIGHT_OFFSET,
        CLEAR_BUTTON_Y_OFFSET
    )
    searchBox.Instructions:SetFont(NS.Media.GetPrimaryFont(), SEARCH_BOX_TEXT_SIZE, SEARCH_BOX_FONT_FLAGS)
    searchBox.Instructions:ClearAllPoints()
    searchBox.Instructions:SetPoint("TOPLEFT", searchBox, "TOPLEFT", SEARCH_TEXT_LEFT_INSET, 0)
    searchBox.Instructions:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", -SEARCH_TEXT_RIGHT_INSET, 0)
    searchBox:SetAutoFocus(false)
    searchBox:HookScript("OnTextChanged", function(self)
        list:SetSearchText(self:GetText())
    end)

    return searchBox
end

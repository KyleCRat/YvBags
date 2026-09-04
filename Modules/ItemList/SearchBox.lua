local _, NS = ...

-- Search-box construction contract for the item-list controller.
local SearchBox = {}
NS.ItemListSearchBox = SearchBox

local SEARCH_BOX_TEMPLATE = "SearchBoxNineSliceTemplate"
local SEARCH_BOX_WIDTH = 320
local SEARCH_BOX_HEIGHT = 28
local SEARCH_BOX_TEXT_SIZE = 18
local SEARCH_BOX_FONT_FLAGS = ""
local SEARCH_ICON_LEFT_OFFSET = 4
local SEARCH_ICON_Y_OFFSET = 0

local function GetPrimaryFont()
    return NS.Media.GetPrimaryFont()
end

function SearchBox.Create(parent, list)
    local searchBox = CreateFrame("EditBox", nil, parent, SEARCH_BOX_TEMPLATE)
    searchBox:SetSize(SEARCH_BOX_WIDTH, SEARCH_BOX_HEIGHT)
    searchBox:SetFont(GetPrimaryFont(), SEARCH_BOX_TEXT_SIZE, SEARCH_BOX_FONT_FLAGS)
    searchBox.searchIcon:ClearAllPoints()
    searchBox.searchIcon:SetPoint(
        "LEFT",
        searchBox,
        "LEFT",
        SEARCH_ICON_LEFT_OFFSET,
        SEARCH_ICON_Y_OFFSET
    )
    if searchBox.Instructions then
        searchBox.Instructions:SetFont(GetPrimaryFont(), SEARCH_BOX_TEXT_SIZE, SEARCH_BOX_FONT_FLAGS)
    end
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        if SearchBoxTemplate_OnTextChanged then
            SearchBoxTemplate_OnTextChanged(self)
        end

        list:SetSearchText(self:GetText())
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return searchBox
end

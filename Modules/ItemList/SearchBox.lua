local _, NS = ...

-- Search-box construction contract for the item-list controller.
local SearchBox = {}
NS.ItemListSearchBox = SearchBox

local SEARCH_BOX_WIDTH = 320
local SEARCH_BOX_TEXT_SIZE = 13

function SearchBox.Create(parent, list)
    local searchBox = NS.Skins:CreateSearchBox(parent, {
        geometryRoot = list.window, width = SEARCH_BOX_WIDTH,
        fontSize = SEARCH_BOX_TEXT_SIZE, focusGlow = false,
    })
    searchBox:HookScript("OnTextChanged", function(self)
        list:SetSearchText(self:GetText())
    end)

    return searchBox
end

local _, NS = ...

-- Shared geometry contract for list components.
local Layout = {
    HeaderHeight = 24,
    HeaderLeftOffset = 0,
    HeaderTopOffset = 0,
    HeaderRightOffset = 0,
    ScrollBarContentPadding = 22,
    ScrollBoxLeftOffset = 0,
    ScrollBoxRightOffset = 0,
    ScrollBoxTopGap = -2,
    ScrollBoxBottomOffset = 0,
    ScrollBarRightOffset = -8,
    ScrollBarTopOffset = -2,
    ScrollBarBottomOffset = 2,
}
NS.ItemListLayout = Layout

local function SetPixelPoint(region, point, relativeTo, relativePoint, offsetX, offsetY)
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY)
    else
        region:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    end
end

function Layout.PositionScrollBar(scrollBar, scrollBox)
    scrollBar:ClearAllPoints()
    SetPixelPoint(scrollBar, "TOPRIGHT", scrollBox, "TOPRIGHT", Layout.ScrollBarRightOffset, Layout.ScrollBarTopOffset)
    SetPixelPoint(scrollBar, "BOTTOMRIGHT", scrollBox, "BOTTOMRIGHT", Layout.ScrollBarRightOffset, Layout.ScrollBarBottomOffset)
end

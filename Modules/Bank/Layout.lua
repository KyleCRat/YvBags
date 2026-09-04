local _, NS = ...

-- Shared custom-bank frame geometry.
local Layout = {
    MinWidth = 520,
    MinHeight = 420,
    FrameInsetLeft = 4,
    FrameInsetRight = -6,
    FrameInsetTop = -60,
    FrameInsetBottom = 34,
    ContentInsetLeft = 3,
    ContentInsetRight = -3,
    ContentInsetTop = -3,
    ContentInsetBottom = 2,
    ResizeButtonRightOffset = -2,
    ResizeButtonBottomOffset = 3,
}
NS.BankFrameLayout = Layout

function Layout.GetHorizontalChromeWidth()
    return (Layout.FrameInsetLeft - Layout.FrameInsetRight)
        + (Layout.ContentInsetLeft - Layout.ContentInsetRight)
end

local _, NS = ...

-- Shared main-frame geometry used by construction and persistence modules.
local Layout = {
    MinWidth = 420,
    MinHeight = 360,
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
NS.MainFrameLayout = Layout

function Layout.GetHorizontalChromeWidth()
    return (Layout.FrameInsetLeft - Layout.FrameInsetRight) + (Layout.ContentInsetLeft - Layout.ContentInsetRight)
end

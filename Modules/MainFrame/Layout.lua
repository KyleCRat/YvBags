local _, NS = ...

-- Bag-specific bounds; LibYvSkins owns window chrome geometry.
local Layout = {
    MinWidth = 420,
    MinHeight = 360,
}
NS.MainFrameLayout = Layout

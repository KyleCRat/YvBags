local _, NS = ...

-- YvBags chooses its sections and toolbar composition. LYS owns the shell,
-- remaining Body space, native window controls, and reusable row arrangement.
local WindowLayout = {}
NS.WindowLayout = WindowLayout

local TOOLBAR_HEIGHT = 28
WindowLayout.ToolbarHeight = TOOLBAR_HEIGHT

WindowLayout.Layouts = {
    modern = {
        padding = { left = 4, right = 6, top = 0, bottom = 4 },
        header = { height = 28 + TOOLBAR_HEIGHT, gap = 4 },
        titleBar = { height = 24, margin = { left = -4, right = -6 } },
        footer = { height = 28, gap = 2, margin = { left = -1, right = 9 } },
        portrait = true,
        closeButton = "titleBar",
    },
    flat = {
        padding = 8,
        header = { height = TOOLBAR_HEIGHT, gap = 4 },
        titleBar = false,
        footer = { height = 24, gap = 4, margin = { right = 16 } },
        closeButton = "manual",
    },
}

local TOOLBAR_LAYOUTS = {
    modern = { left = 54, top = 28, gap = 2 },
    flat = { left = 0, top = 0, gap = 4, includeClose = true },
}

function WindowLayout.OnLayout(frame)
    local toolbar = frame.toolbar
    if not toolbar then return end -- Window construction precedes its contents.
    local layout = TOOLBAR_LAYOUTS[NS.Skins:GetAppliedSkin()]
    toolbar:ClearAllPoints()
    toolbar:SetPoint("TOPLEFT", frame.header, "TOPLEFT", layout.left, -layout.top)
    toolbar:SetPoint("TOPRIGHT", frame.header, "TOPRIGHT", 0, -layout.top)
    if frame.toolbarItems then
        local items = {}
        for index, item in ipairs(frame.toolbarItems) do items[index] = item end
        if layout.includeClose then
            frame.CloseButton:SetSize(TOOLBAR_HEIGHT, TOOLBAR_HEIGHT)
            items[#items + 1] = frame.CloseButton
        end
        NS.Skins:SetToolbarItems(toolbar, items, layout.gap)
    end
end

function WindowLayout.CreateToolbar(frame)
    frame.toolbar = NS.Skins:CreateToolbar(frame.header, { height = TOOLBAR_HEIGHT })
    NS.Skins:RegisterWindowDragRegion(frame, frame.toolbar)
    WindowLayout.OnLayout(frame)
end

function WindowLayout.GetMinimumWidth(frame)
    if not frame.toolbar then return 0 end
    return NS.Skins:GetToolbarMinimumWidth(frame.toolbar)
        + frame:GetWidth() - frame.toolbar:GetWidth()
end

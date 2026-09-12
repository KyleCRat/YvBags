local _, NS = ...

-- Header gestures change custom geometry, never the native item-button pool.
local Interaction = {}
NS.ItemListHeaderInteraction = Interaction

local Columns = NS.ItemListColumns
local ListSettings = NS.ItemListSettings
local Media = NS.Media
local INSERTION_WIDTH = 2
local DRAG_ALPHA = 0.45
local DRIVER_LEVEL_OFFSET = 10

local function GetCursorPositionInHeader(header)
    local x, y = GetCursorPosition()
    local content = header.content
    local scale = content:GetEffectiveScale()
    return x / scale - content:GetLeft(), y / scale - content:GetBottom()
end

function Interaction.Cancel(header)
    local state = header.interaction
    if not state then
        return
    end
    header.interaction = nil
    state.source:SetAlpha(1)
    state.source.isPressed = false
    state.source.isHovered = state.source:IsMouseOver()
    state.source:UpdateVisualState()
    header.interactionDriver:SetScript("OnUpdate", nil)
    header.interactionDriver:Hide()
    header.list:ClearColumnPreview()
end

local function Finish(header)
    local state = header.interaction
    if not state then
        return
    end
    Interaction.Cancel(header)
    if not ListSettings.CanEditColumns() or not header:IsShown() then
        return
    end
    if state.kind == "resize" then
        if state.valid and state.width ~= state.initialWidth then
            ListSettings.SetColumnWidth(header.list.settingsScope, state.key, state.width)
        end
    elseif state.targetKey then
        ListSettings.MoveColumn(header.list.settingsScope, state.key, state.targetKey, state.after)
    end
    header.list:RefreshColumnSettings()
end

local function UpdateInteraction(header)
    local state = header.interaction
    if not state then
        return
    end
    if InCombatLockdown() or not header:IsShown()
        or header.content:GetEffectiveScale() ~= state.scale then
        Interaction.Cancel(header)
        return
    end

    local x, y = GetCursorPositionInHeader(header)
    state.valid = y >= 0 and y <= header.content:GetHeight()
    local indicator = header.interactionDriver.indicator
    indicator:Hide()

    if state.kind == "resize" then
        local width = Columns.ClampWidth(state.column, state.initialWidth + x - state.startX)
        width = math.min(width, state.maxWidth)
        if width ~= state.width then
            state.width = width
            header.list:PreviewColumnWidth(state.key, width)
        end
    else
        state.targetKey = nil
        local viewportWidth = header.content:GetWidth()
        if state.valid and x >= 0 and x <= viewportWidth then
            local markerX
            for _, entry in ipairs(header.list.columnLayout.entries) do
                if entry.x >= viewportWidth then
                    break
                end
                if entry.column.key ~= state.key then
                    state.targetKey = entry.column.key
                    state.after = x >= entry.x + entry.width / 2
                    markerX = state.after and entry.x + entry.width + Columns.GetColumnGap() / 2
                        or entry.x - Columns.GetColumnGap() / 2
                    if not state.after then
                        break
                    end
                end
            end
            if markerX then
                indicator:ClearAllPoints()
                indicator:SetPoint("TOPLEFT", header.content, "TOPLEFT", math.max(0, math.min(viewportWidth - INSERTION_WIDTH, markerX)), 0)
                indicator:SetSize(INSERTION_WIDTH, header.content:GetHeight())
                indicator:Show()
            end
        end
    end

    -- Also catches releases outside the source button, without idle polling.
    if not IsMouseButtonDown("LeftButton") then
        Finish(header)
    end
end

local function Begin(header, source, kind)
    if not ListSettings.CanEditColumns() or GetCursorInfo() ~= nil then
        return
    end
    Interaction.Cancel(header)
    GameTooltip:Hide()
    local key = source.column.key
    local entry = header.list.columnLayout.byKey[key]
    if not entry or not source:IsShown() then
        return
    end
    local x = GetCursorPositionInHeader(header)
    header.interaction = {
        source = source,
        kind = kind,
        key = key,
        column = source.column,
        startX = x,
        initialWidth = entry.width,
        width = entry.width,
        scale = header.content:GetEffectiveScale(),
        valid = true,
    }
    if kind == "resize" then
        -- The header spans the inner frame, including above the scrollbar.
        -- Keep the entire handle reachable at that edge, at every scale.
        header.interaction.maxWidth = math.max(source.column.minWidth,
            math.floor(entry.width + header.content:GetRight() - source:GetRight()))
    end
    source.suppressClick = true
    if kind == "reorder" then
        source:SetAlpha(DRAG_ALPHA)
    end
    local driver = header.interactionDriver
    driver:SetPropagateKeyboardInput(true)
    driver:Show()
    driver:SetScript("OnUpdate", function()
        UpdateInteraction(header)
    end)
    UpdateInteraction(header)
end

function Interaction.Attach(header, list)
    header.list = list
    local driver = CreateFrame("Frame", nil, header)
    driver:SetAllPoints(header)
    driver:SetFrameLevel(header:GetFrameLevel() + DRIVER_LEVEL_OFFSET)
    driver:EnableKeyboard(true)
    driver:SetPropagateKeyboardInput(true)
    driver:Hide()
    local indicator = driver:CreateTexture(nil, "OVERLAY")
    local r, g, b = Media.GetAccentColor()
    indicator:SetColorTexture(r, g, b, 1)
    indicator:Hide()
    driver.indicator = indicator
    header.interactionDriver = driver
    driver:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then
            Interaction.Cancel(header)
            return
        end
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then
            Interaction.Cancel(header)
        end
    end)

    for _, button in ipairs(header.buttons) do
        button:RegisterForDrag("LeftButton")
        button:HookScript("OnMouseDown", function(self)
            self.suppressClick = false
        end)
        -- Blizzard's drag threshold preserves ordinary sorting clicks.
        button:SetScript("OnDragStart", function(self)
            Begin(header, self, "reorder")
        end)
        button:SetScript("OnDragStop", function()
            UpdateInteraction(header)
            Finish(header)
        end)
    end
    for _, separator in ipairs(header.separators) do
        separator:HookScript("OnMouseDown", function(self, mouseButton)
            if mouseButton == "LeftButton" then
                Begin(header, self, "resize")
            end
        end)
        separator:HookScript("OnMouseUp", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                UpdateInteraction(header)
                Finish(header)
            end
        end)
    end
    header:HookScript("OnHide", function()
        Interaction.Cancel(header)
    end)
    header:HookScript("OnSizeChanged", function()
        Interaction.Cancel(header)
    end)
end

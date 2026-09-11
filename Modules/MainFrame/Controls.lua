local _, NS = ...

-- Shared bag/bank subheader control construction contract.
local Controls = {
    SubheaderControlGap = 2,
}
NS.MainFrameControls = Controls

local Geometry = NS.MainFrameGeometry
local ADDON_NAME = NS.ADDON_NAME

-- Shared square header buttons
local SQUARE_BUTTON_SIZE = 28
local SQUARE_BUTTON_ICON_SIZE = 18
local SQUARE_BUTTON_DISABLED_ICON_ALPHA = 0.5
local SQUARE_BUTTON_NORMAL_ATLAS = "common-button-tertiary-square-normal"
local SQUARE_BUTTON_HOVER_ATLAS = "common-button-tertiary-square-hover"
local SQUARE_BUTTON_PRESSED_ATLAS = "common-button-tertiary-square-pressed"
local SQUARE_BUTTON_DISABLED_ATLAS = "common-button-tertiary-square-disabled"
local SUBHEADER_FRAME_LEVEL_OFFSET = 8

-- Scale control
local SCALE_MIN_PERCENT = 50
local SCALE_MAX_PERCENT = 150
local SCALE_STEP_PERCENT = 5
local SCALE_POPUP_WIDTH = 48
local SCALE_POPUP_HEIGHT = 180
local SCALE_POPUP_FONT_SIZE = 12
local SCALE_POPUP_FONT_FLAGS = "OUTLINE"

-- Settings and search controls
local SETTINGS_BUTTON_LEFT_OFFSET = 58
local SEARCH_BOX_RIGHT_OFFSET = -6
local SEARCH_BOX_TOP_OFFSET = -28
local SEARCH_FOCUS_KEY = "F"
local SEARCH_SHORTCUT_LISTENER_TEMPLATE = "InsecureKeyboardInputPropagatorTemplate"

local function FormatScalePercent(value)
    return ("%d%%"):format(math.floor((tonumber(value) or 0) + 0.5))
end

local function ShowTooltip(button, title, description)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(title, 1, 1, 1)
    if description then
        GameTooltip:AddLine(description, 0.86, 0.86, 0.86, true)
    end
    GameTooltip:Show()
end

local function CreateSquareButtonTexture(button, layer, atlas)
    local texture = button:CreateTexture(nil, layer)
    texture:SetAllPoints(button)
    texture:SetAtlas(atlas, false)
    return texture
end

local function UpdateSquareButtonVisualState(button)
    local enabled = button:IsEnabled()
    button.disabledTexture:SetShown(not enabled)
    button.pressedTexture:SetShown(enabled and button.isPressed == true)
    button.hoverTexture:SetShown(enabled and button.isHovered == true and button.isPressed ~= true)
    button.icon:SetAlpha(enabled and 1 or SQUARE_BUTTON_DISABLED_ICON_ALPHA)
end

local function CreateSquareIconButton(frame, iconTexture)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(SQUARE_BUTTON_SIZE, SQUARE_BUTTON_SIZE)
    button:SetFrameLevel(frame:GetFrameLevel() + SUBHEADER_FRAME_LEVEL_OFFSET)
    button:EnableMouse(true)
    button:SetHitRectInsets(0, 0, 0, 0)

    button.normalTexture = CreateSquareButtonTexture(button, "BACKGROUND", SQUARE_BUTTON_NORMAL_ATLAS)
    button.hoverTexture = CreateSquareButtonTexture(button, "BORDER", SQUARE_BUTTON_HOVER_ATLAS)
    button.pressedTexture = CreateSquareButtonTexture(button, "BORDER", SQUARE_BUTTON_PRESSED_ATLAS)
    button.disabledTexture = CreateSquareButtonTexture(button, "BORDER", SQUARE_BUTTON_DISABLED_ATLAS)
    button.hoverTexture:Hide()
    button.pressedTexture:Hide()
    button.disabledTexture:Hide()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(SQUARE_BUTTON_ICON_SIZE, SQUARE_BUTTON_ICON_SIZE)
    icon:SetTexture(iconTexture)
    button.icon = icon

    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateSquareButtonVisualState(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        self.isPressed = false
        UpdateSquareButtonVisualState(self)
        GameTooltip:Hide()
    end)
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self.isPressed = true
            UpdateSquareButtonVisualState(self)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        self.isPressed = false
        self.isHovered = self:IsMouseOver()
        UpdateSquareButtonVisualState(self)
    end)
    button:SetScript("OnEnable", UpdateSquareButtonVisualState)
    button:SetScript("OnDisable", UpdateSquareButtonVisualState)
    return button
end

function Controls.RefreshScale(frame, scale)
    if frame.scalePopup then
        frame.scalePopup:SetValue(scale * 100, true)
    end
end

function Controls.CreateScaleButton(frame, options)
    options = options or {}
    local geometry = options.geometry or Geometry
    local frameLabel = options.frameLabel or ADDON_NAME
    local button = CreateSquareIconButton(frame, NS.Media.GetScaleTexture())
    button:SetPoint("LEFT", frame.settingsButton, "RIGHT", Controls.SubheaderControlGap, 0)
    frame.scaleButton = button

    button:HookScript("OnEnter", function(self)
        ShowTooltip(
            self,
            ("Scale: %s"):format(FormatScalePercent(geometry.GetSavedScale() * 100)),
            ("Click and drag to resize the %s frame."):format(frameLabel)
        )
    end)

    local LibPopupSlider = LibStub("LibPopupSlider-1.0", true)
    if LibPopupSlider then
        local popup = LibPopupSlider:Create(button, {
            minValue = SCALE_MIN_PERCENT,
            maxValue = SCALE_MAX_PERCENT,
            step = SCALE_STEP_PERCENT,
            label = "Scale",
            formatValue = FormatScalePercent,
            onValueChanged = function(value)
                geometry.SetScale(value / 100)
            end,
            sliderHeight = SCALE_POPUP_HEIGHT,
            popupWidth = SCALE_POPUP_WIDTH,
            font = NS.Media.GetPrimaryFont(),
            fontFlags = SCALE_POPUP_FONT_FLAGS,
            fontSize = SCALE_POPUP_FONT_SIZE,
        })
        popup:SetValue(geometry.GetSavedScale() * 100, true)
        frame.scalePopup = popup
    else
        button:Disable()
    end
end

function Controls.CreateSettingsButton(frame, options)
    options = options or {}
    local button = CreateSquareIconButton(frame, NS.Media.GetSettingsTexture())
    button:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        options.leftOffset or SETTINGS_BUTTON_LEFT_OFFSET,
        options.topOffset or SEARCH_BOX_TOP_OFFSET
    )
    button:RegisterForClicks("LeftButtonUp")

    button:HookScript("OnEnter", function(self)
        ShowTooltip(
            self,
            "Settings",
            options.tooltip
                or ("Open %s settings."):format(ADDON_NAME)
        )
    end)
    button:SetScript("OnClick", function()
        if options.onClick then
            options.onClick()
        else
            NS.Settings.Open()
        end
    end)

    frame.settingsButton = button
    return button
end

local function ResetSearchShortcutListener(listener)
    if InCombatLockdown() then
        listener.resetAfterCombat = true
        return
    end

    listener.resetAfterCombat = nil
    listener:SetPropagateKeyboardInput(true)
    listener:EnableKeyboard(true)
end

function Controls.RegisterSearchShortcut(frame)
    local listener = CreateFrame("Frame", nil, frame, SEARCH_SHORTCUT_LISTENER_TEMPLATE)
    listener:SetAllPoints(frame)
    listener:EnableKeyboard(true)
    listener:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then
            return
        end

        local keyboardFocus = GetCurrentKeyBoardFocus()
        local canFocusSearch = not keyboardFocus or keyboardFocus == frame.searchBox
        local isSearchShortcut = key == SEARCH_FOCUS_KEY
            and IsControlKeyDown()
            and not IsAltKeyDown()
            and not IsShiftKeyDown()
        if canFocusSearch and isSearchShortcut then
            self:SetPropagateKeyboardInput(false)
            self:EnableKeyboard(false)
            frame.searchBox:SetFocus()
            C_Timer.After(0, function()
                ResetSearchShortcutListener(self)
            end)
        end
    end)
    listener:RegisterEvent("PLAYER_REGEN_DISABLED")
    listener:RegisterEvent("PLAYER_REGEN_ENABLED")
    listener:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            frame.searchBox:ClearFocus()
        elseif self.resetAfterCombat then
            ResetSearchShortcutListener(self)
        end
    end)
    frame.searchShortcutListener = listener
end

function Controls.LayoutSearch(frame, options)
    options = options or {}
    local searchBox = frame.searchBox
    local leftAnchor = options.leftAnchor or frame.scaleButton
    local gap = Controls.SubheaderControlGap
    searchBox:ClearAllPoints()
    searchBox:SetPoint(
        "TOPLEFT",
        leftAnchor,
        "TOPRIGHT",
        gap,
        0
    )
    searchBox:SetPoint(
        "BOTTOMLEFT",
        leftAnchor,
        "BOTTOMRIGHT",
        gap,
        0
    )
    searchBox:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        options.rightOffset or SEARCH_BOX_RIGHT_OFFSET,
        options.topOffset or SEARCH_BOX_TOP_OFFSET
    )
end

function Controls.CreateSearch(frame, options)
    local searchBox = frame.itemList:CreateSearchBox(frame)
    searchBox:SetFrameLevel(frame:GetFrameLevel() + SUBHEADER_FRAME_LEVEL_OFFSET)
    frame.searchBox = searchBox
    Controls.LayoutSearch(frame, options)
end

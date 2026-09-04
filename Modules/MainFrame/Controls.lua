local _, NS = ...

-- Main-frame title and subheader control construction contract.
local Controls = {}
NS.MainFrameControls = Controls

local Geometry = NS.MainFrameGeometry
local ADDON_NAME = NS.ADDON_NAME

-- Scale control
local TITLE_BUTTON_GAP = 4
local TITLE_BUTTON_FRAME_LEVEL_OFFSET = 20
local SCALE_BUTTON_WIDTH = 92
local SCALE_BUTTON_HEIGHT = 25
local SCALE_BUTTON_FONT_SIZE = 12
local SCALE_BUTTON_FONT_FLAGS = "OUTLINE"
local SCALE_BUTTON_TEXT_Y_OFFSET = 1
local SCALE_BUTTON_NORMAL_ATLAS = "common-button-tertiary-normal-small"
local SCALE_BUTTON_HOVER_ATLAS = "common-button-tertiary-hover-small"
local SCALE_BUTTON_PRESSED_ATLAS = "common-button-tertiary-pressed-small"
local SCALE_BUTTON_DISABLED_ATLAS = "common-button-tertiary-disabled-small"
local SCALE_MIN_PERCENT = 50
local SCALE_MAX_PERCENT = 150
local SCALE_STEP_PERCENT = 5
local SCALE_POPUP_WIDTH = 48
local SCALE_POPUP_HEIGHT = 180
local SCALE_POPUP_FONT_SIZE = 12

-- Settings and search controls
local SETTINGS_BUTTON_ICON = "Interface\\WorldMap\\GEAR_64GREY"
local SETTINGS_BUTTON_SIZE = 28
local SETTINGS_BUTTON_ICON_SIZE = 22
local SETTINGS_BUTTON_NORMAL_ALPHA = 0.72
local SETTINGS_BUTTON_HOVER_ALPHA = 1
local SETTINGS_BUTTON_PUSHED_OFFSET = -1
local SETTINGS_BUTTON_LEFT_OFFSET = 58
local SETTINGS_BUTTON_SEARCH_GAP = 6
local SEARCH_BOX_RIGHT_OFFSET = -6
local SEARCH_BOX_TOP_OFFSET = -28
local SEARCH_BOX_FRAME_LEVEL_OFFSET = 8
local SEARCH_FOCUS_KEY = "F"
local SEARCH_SHORTCUT_LISTENER_TEMPLATE = "InsecureKeyboardInputPropagatorTemplate"

local function FormatScalePercent(value)
    return ("%d%%"):format(math.floor((tonumber(value) or 0) + 0.5))
end

local function FormatScaleButtonText(scale)
    return ("Scale: %s"):format(FormatScalePercent((tonumber(scale) or 1) * 100))
end

local function ShowTooltip(button, title, description)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(title, 1, 1, 1)
    if description then
        GameTooltip:AddLine(description, 0.86, 0.86, 0.86, true)
    end
    GameTooltip:Show()
end

local function SetTitleButtonFrameLevel(frame, button)
    local frameLevel = math.max(
        frame:GetFrameLevel(),
        frame.TitleContainer:GetFrameLevel(),
        frame.CloseButton:GetFrameLevel()
    )
    button:SetFrameLevel(frameLevel + TITLE_BUTTON_FRAME_LEVEL_OFFSET)
end

local function CreateScaleButtonTexture(button, layer, atlas)
    local texture = button:CreateTexture(nil, layer)
    texture:SetAllPoints(button)
    texture:SetAtlas(atlas, false)
    return texture
end

local function UpdateScaleButtonVisualState(button)
    button.disabledTexture:SetShown(not button:IsEnabled())
    button.pressedTexture:SetShown(button:IsEnabled() and button.isPressed == true)
    button.hoverTexture:SetShown(button:IsEnabled() and button.isHovered == true and button.isPressed ~= true)
end

function Controls.RefreshScale(frame, scale)
    if not frame.scaleButton then
        return
    end

    frame.scaleButton.text:SetText(FormatScaleButtonText(scale))
    if frame.scalePopup then
        frame.scalePopup:SetValue(scale * 100, true)
    end
end

function Controls.CreateTitle(frame, options)
    options = options or {}
    local geometry = options.geometry or Geometry
    local frameLabel = options.frameLabel or ADDON_NAME
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(SCALE_BUTTON_WIDTH, SCALE_BUTTON_HEIGHT)
    button:SetPoint("RIGHT", frame.CloseButton, "LEFT", -TITLE_BUTTON_GAP, 0)
    SetTitleButtonFrameLevel(frame, button)
    button:EnableMouse(true)
    button:SetHitRectInsets(0, 0, 0, 0)

    button.normalTexture = CreateScaleButtonTexture(button, "BACKGROUND", SCALE_BUTTON_NORMAL_ATLAS)
    button.hoverTexture = CreateScaleButtonTexture(button, "BORDER", SCALE_BUTTON_HOVER_ATLAS)
    button.pressedTexture = CreateScaleButtonTexture(button, "BORDER", SCALE_BUTTON_PRESSED_ATLAS)
    button.disabledTexture = CreateScaleButtonTexture(button, "BORDER", SCALE_BUTTON_DISABLED_ATLAS)
    button.hoverTexture:Hide()
    button.pressedTexture:Hide()
    button.disabledTexture:Hide()

    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", button, "CENTER", 0, SCALE_BUTTON_TEXT_Y_OFFSET)
    text:SetFont(NS.Media.GetPrimaryFont(), SCALE_BUTTON_FONT_SIZE, SCALE_BUTTON_FONT_FLAGS)
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 0.9)
    text:SetShadowOffset(1, -1)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    button.text = text

    frame.scaleButton = button
    Controls.RefreshScale(frame, geometry.GetSavedScale())
    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateScaleButtonVisualState(self)
        ShowTooltip(
            self,
            "Scale",
            ("Click and drag to resize the %s frame."):format(frameLabel)
        )
    end)
    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        self.isPressed = false
        UpdateScaleButtonVisualState(self)
        GameTooltip:Hide()
    end)
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self.isPressed = true
            UpdateScaleButtonVisualState(self)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        self.isPressed = false
        self.isHovered = self:IsMouseOver()
        UpdateScaleButtonVisualState(self)
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
            fontFlags = SCALE_BUTTON_FONT_FLAGS,
            fontSize = SCALE_POPUP_FONT_SIZE,
        })
        popup:SetValue(geometry.GetSavedScale() * 100, true)
        frame.scalePopup = popup
    else
        button:Disable()
        UpdateScaleButtonVisualState(button)
    end
end

function Controls.CreateSettingsButton(frame, options)
    options = options or {}
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(SETTINGS_BUTTON_SIZE, SETTINGS_BUTTON_SIZE)
    button:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        options.leftOffset or SETTINGS_BUTTON_LEFT_OFFSET,
        options.topOffset or SEARCH_BOX_TOP_OFFSET
    )
    button:SetFrameLevel(frame:GetFrameLevel() + SEARCH_BOX_FRAME_LEVEL_OFFSET)
    button:RegisterForClicks("LeftButtonUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(SETTINGS_BUTTON_ICON_SIZE, SETTINGS_BUTTON_ICON_SIZE)
    icon:SetTexture(SETTINGS_BUTTON_ICON)
    icon:SetAlpha(SETTINGS_BUTTON_NORMAL_ALPHA)
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.12)
    highlight:SetBlendMode("ADD")

    button:SetScript("OnMouseDown", function(self)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER", self, "CENTER", 0, SETTINGS_BUTTON_PUSHED_OFFSET)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER", self, "CENTER", 0, 0)
    end)
    button:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(SETTINGS_BUTTON_HOVER_ALPHA)
        ShowTooltip(
            self,
            "Settings",
            options.tooltip
                or ("Open %s settings."):format(ADDON_NAME)
        )
    end)
    button:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(SETTINGS_BUTTON_NORMAL_ALPHA)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER", self, "CENTER", 0, 0)
        GameTooltip:Hide()
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

function Controls.CreateSearch(frame, options)
    local options = options or {}
    local settingsButton = options.settingsButton
        or Controls.CreateSettingsButton(frame, options.settingsButtonOptions)
    local searchBox = frame.itemList:CreateSearchBox(frame)
    searchBox:ClearAllPoints()
    searchBox:SetPoint(
        "TOPLEFT",
        options.leftAnchor or settingsButton,
        "TOPRIGHT",
        options.leftGap or SETTINGS_BUTTON_SEARCH_GAP,
        0
    )
    searchBox:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        options.rightOffset or SEARCH_BOX_RIGHT_OFFSET,
        options.topOffset or SEARCH_BOX_TOP_OFFSET
    )
    searchBox:SetFrameLevel(frame:GetFrameLevel() + SEARCH_BOX_FRAME_LEVEL_OFFSET)
    frame.searchBox = searchBox
end

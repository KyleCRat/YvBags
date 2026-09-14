local _, NS = ...

-- Shared bag/bank toolbar control construction contract.
local Controls = {}
NS.MainFrameControls = Controls

local Geometry = NS.MainFrameGeometry
local ADDON_NAME = NS.ADDON_NAME

-- Shared square header buttons
local SQUARE_BUTTON_SIZE = NS.WindowLayout.ToolbarHeight
local SQUARE_BUTTON_ICON_SIZE = 18
local TOOLBAR_FRAME_LEVEL_OFFSET = 8

-- Scale control
local SCALE_MIN_PERCENT = 50
local SCALE_MAX_PERCENT = 150
local SCALE_STEP_PERCENT = 5
local SCALE_POPUP_WIDTH = 48
local SCALE_POPUP_HEIGHT = 180
local SCALE_POPUP_FONT_SIZE = 12
local SCALE_POPUP_FONT_FLAGS = "OUTLINE"

-- Settings and search controls
local SEARCH_MIN_WIDTH = 96
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

function Controls.RefreshScale(frame, scale)
    if frame.scalePopup then
        frame.scalePopup:SetValue(scale * 100, true)
    end
end

function Controls.CreateScaleButton(frame, options)
    options = options or {}
    local geometry = options.geometry or Geometry
    local frameLabel = options.frameLabel or ADDON_NAME
    local button = NS.Skins:CreateButton(frame.toolbar, {
        geometryRoot = frame, variant = "square",
        width = SQUARE_BUTTON_SIZE, height = SQUARE_BUTTON_SIZE,
        icon = NS.Media.GetScaleTexture(), iconWidth = SQUARE_BUTTON_ICON_SIZE,
    })
    button:SetFrameLevel(frame:GetFrameLevel() + TOOLBAR_FRAME_LEVEL_OFFSET)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.scaleButton = button

    button:HookScript("OnEnter", function(self)
        ShowTooltip(
            self,
            ("Scale: %s"):format(FormatScalePercent(geometry.GetSavedScale() * 100)),
            ("Click and drag to resize the %s frame."):format(frameLabel)
        )
    end)

    local popup = NS.Skins:CreatePopupSlider(button, {
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
    if popup then
        popup:SetValue(geometry.GetSavedScale() * 100, true)
        frame.scalePopup = popup
    else
        button:Disable()
    end
end

function Controls.CreateSettingsButton(frame, options)
    options = options or {}
    local button = NS.Skins:CreateButton(frame.toolbar, {
        geometryRoot = frame, variant = "square",
        width = SQUARE_BUTTON_SIZE, height = SQUARE_BUTTON_SIZE,
        icon = NS.Media.GetSettingsTexture(), iconWidth = SQUARE_BUTTON_ICON_SIZE,
    })
    button:SetFrameLevel(frame:GetFrameLevel() + TOOLBAR_FRAME_LEVEL_OFFSET)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
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

function Controls.CreateSearch(frame)
    local searchBox = frame.itemList:CreateSearchBox(frame.toolbar)
    searchBox:SetHeight(SQUARE_BUTTON_SIZE)
    searchBox:SetFrameLevel(frame:GetFrameLevel() + TOOLBAR_FRAME_LEVEL_OFFSET)
    frame.searchBox = searchBox
    local toolbar = { frame.settingsButton, frame.scaleButton }
    if frame.characterBankButton then
        toolbar[#toolbar + 1] = frame.characterBankButton
        toolbar[#toolbar + 1] = frame.accountBankButton
    end
    toolbar[#toolbar + 1] = { control = searchBox, stretch = true, minWidth = SEARCH_MIN_WIDTH }
    frame.toolbarItems = toolbar
    NS.WindowLayout.OnLayout(frame)
end

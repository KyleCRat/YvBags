local ADDON_NAME, NS = ...

-- Main frame
local FRAME_NAME = NS.FRAME_NAME
local MIN_FRAME_WIDTH = 420
local MIN_FRAME_HEIGHT = 360
local MAIN_FRAME_TEMPLATE = "ButtonFrameTemplate"
local MAIN_FRAME_STRATA = "HIGH"
local MAIN_FRAME_PORTRAIT = "Interface\\Icons\\INV_Misc_Bag_08"
local FRAME_TYPE = "Frame"
local BUTTON_TYPE = "Button"

-- Title bar controls
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

-- Subheader controls
local SETTINGS_BUTTON_ICON = "Interface\\WorldMap\\GEAR_64GREY"
local SETTINGS_BUTTON_SIZE = 28
local SETTINGS_BUTTON_ICON_SIZE = 22
local SETTINGS_BUTTON_NORMAL_ALPHA = 0.72
local SETTINGS_BUTTON_HOVER_ALPHA = 1
local SETTINGS_BUTTON_PUSHED_OFFSET = -1
local SETTINGS_BUTTON_LEFT_OFFSET = 58
local SETTINGS_BUTTON_SEARCH_GAP = 6

-- Content and chrome
local CONTENT_INSET_LEFT = 3
local CONTENT_INSET_RIGHT = -3
local CONTENT_INSET_TOP = -3
local CONTENT_INSET_BOTTOM = 2
local FRAME_INSET_LEFT = 4
local FRAME_INSET_RIGHT = -6
local FRAME_INSET_TOP = -60
local FRAME_INSET_BOTTOM = 34
local SEARCH_BOX_RIGHT_OFFSET = -6
local SEARCH_BOX_TOP_OFFSET = -28
local SEARCH_BOX_FRAME_LEVEL_OFFSET = 8

-- Resize handle
local RESIZE_BUTTON_TEMPLATE = "PanelResizeButtonTemplate"
local RESIZE_BUTTON_RIGHT_OFFSET = -2
local RESIZE_BUTTON_BOTTOM_OFFSET = 3

-- Portrait
local PORTRAIT_TEX_COORD_LEFT = 0
local PORTRAIT_TEX_COORD_RIGHT = 1
local PORTRAIT_TEX_COORD_TOP = 0
local PORTRAIT_TEX_COORD_BOTTOM = 1

-- Positioning and diagnostics
local DEFAULT_FRAME_POINT = "CENTER"
local DEFAULT_FRAME_RELATIVE_POINT = "CENTER"
local DEBUG_FRAME_POSITION = false

-- Base WoW frame theme
local function ApplyBaseFrameTheme(frame)
    if frame.TopTileStreaks then
        frame.TopTileStreaks:Hide()
        frame.TopTileStreaks:SetAlpha(0)
    end
end

-- Title bar controls
local function GetPrimaryFont()
    return NS.Media and NS.Media.GetPrimaryFont and NS.Media.GetPrimaryFont() or STANDARD_TEXT_FONT
end

local function FormatScalePercent(value)
    return ("%d%%"):format(math.floor((tonumber(value) or 0) + 0.5))
end

local function FormatScaleButtonText(scale)
    return ("Scale: %s"):format(FormatScalePercent((tonumber(scale) or 1) * 100))
end

local function ClampScale(scale)
    scale = tonumber(scale) or 1
    return math.max(SCALE_MIN_PERCENT / 100, math.min(SCALE_MAX_PERCENT / 100, scale))
end

local function GetSavedFrameScale()
    return ClampScale(NS.charDB:Get("frame", "scale"))
end

local function ShowControlTooltip(button, title, description)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(title, 1, 1, 1)
    if description then
        GameTooltip:AddLine(description, 0.86, 0.86, 0.86, true)
    end
    GameTooltip:Show()
end

local function HideControlTooltip()
    GameTooltip:Hide()
end

local function SetTitleButtonFrameLevel(frame, button)
    local frameLevel = frame:GetFrameLevel() or 0

    if frame.TitleContainer and frame.TitleContainer.GetFrameLevel then
        frameLevel = math.max(frameLevel, frame.TitleContainer:GetFrameLevel() or frameLevel)
    end

    if frame.CloseButton and frame.CloseButton.GetFrameLevel then
        frameLevel = math.max(frameLevel, frame.CloseButton:GetFrameLevel() or frameLevel)
    end

    button:SetFrameLevel(frameLevel + TITLE_BUTTON_FRAME_LEVEL_OFFSET)
end

local function SetScaleButtonText(button, scale)
    if not button or not button.text then
        return
    end

    button.text:SetText(FormatScaleButtonText(scale))
end

local function ApplyScaleButtonFont(button)
    button.text:SetFont(GetPrimaryFont(), SCALE_BUTTON_FONT_SIZE, SCALE_BUTTON_FONT_FLAGS)
    button.text:SetTextColor(1, 1, 1)
    button.text:SetShadowColor(0, 0, 0, 0.9)
    button.text:SetShadowOffset(1, -1)
end

local function CreateScaleButtonTexture(button, layer, atlas)
    local texture = button:CreateTexture(nil, layer)
    texture:SetAllPoints(button)
    texture:SetAtlas(atlas, false)
    return texture
end

local function UpdateScaleButtonVisualState(button)
    if button.disabledTexture then
        button.disabledTexture:SetShown(not button:IsEnabled())
    end

    if button.pressedTexture then
        button.pressedTexture:SetShown(button:IsEnabled() and button.isPressed == true)
    end

    if button.hoverTexture then
        button.hoverTexture:SetShown(button:IsEnabled() and button.isHovered == true and button.isPressed ~= true)
    end
end

function NS:SetFrameScale(scale)
    if not NS.charDB then
        return
    end

    scale = ClampScale(scale)
    NS.charDB:Set("frame", "scale", scale)

    local frame = NS.frame
    if frame then
        frame:SetScale(scale)
        SetScaleButtonText(frame.scaleButton, scale)

        if frame.scalePopup then
            frame.scalePopup:SetValue(scale * 100, true)
        end
    end

    if NS.Settings and NS.Settings.NotifyFrameScaleChanged then
        NS.Settings.NotifyFrameScaleChanged()
    end
end

local function CreateScaleButton(frame)
    if not frame.CloseButton then
        return nil
    end

    local button = CreateFrame(BUTTON_TYPE, nil, frame)
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
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    button.text = text

    ApplyScaleButtonFont(button)
    SetScaleButtonText(button, GetSavedFrameScale())
    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateScaleButtonVisualState(self)
        ShowControlTooltip(self, "Scale", ("Click and drag to resize the %s frame."):format(ADDON_NAME))
    end)
    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        self.isPressed = false
        UpdateScaleButtonVisualState(self)
        HideControlTooltip()
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

    local LibPopupSlider = LibStub and LibStub("LibPopupSlider-1.0", true)
    if LibPopupSlider then
        local popup = LibPopupSlider:Create(button, {
            minValue = SCALE_MIN_PERCENT,
            maxValue = SCALE_MAX_PERCENT,
            step = SCALE_STEP_PERCENT,
            label = "Scale",
            formatValue = FormatScalePercent,
            onValueChanged = function(value)
                NS:SetFrameScale(value / 100)
            end,
            sliderHeight = SCALE_POPUP_HEIGHT,
            popupWidth = SCALE_POPUP_WIDTH,
            font = GetPrimaryFont(),
            fontFlags = "OUTLINE",
            fontSize = SCALE_POPUP_FONT_SIZE,
        })
        popup:SetValue(GetSavedFrameScale() * 100, true)
        frame.scalePopup = popup
    else
        button:Disable()
        UpdateScaleButtonVisualState(button)
    end

    frame.scaleButton = button
    return button
end

local function CreateSettingsButton(frame)
    local button = CreateFrame(BUTTON_TYPE, nil, frame)
    button:SetSize(SETTINGS_BUTTON_SIZE, SETTINGS_BUTTON_SIZE)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", SETTINGS_BUTTON_LEFT_OFFSET, SEARCH_BOX_TOP_OFFSET)
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
        ShowControlTooltip(self, "Settings", ("Open %s settings."):format(ADDON_NAME))
    end)
    button:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(SETTINGS_BUTTON_NORMAL_ALPHA)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER", self, "CENTER", 0, 0)
        HideControlTooltip()
    end)
    button:SetScript("OnClick", function()
        if NS.Settings and NS.Settings.Open then
            NS.Settings.Open()
        end
    end)

    frame.settingsButton = button
    return button
end

local function CreateTitleBarControls(frame)
    CreateScaleButton(frame)
end

-- Persistence helpers
local function PreventClientPositionSaving(frame)
    if frame.SetDontSavePosition then
        frame:SetDontSavePosition(true)
    end
end

local function ClearClientPosition(frame)
    if frame.SetUserPlaced then
        frame:SetUserPlaced(false)
    end
end

local function GetNearestPixelSize(frame, size)
    if PixelUtil and PixelUtil.GetNearestPixelSize and frame.GetEffectiveScale then
        return PixelUtil.GetNearestPixelSize(size, frame:GetEffectiveScale())
    end

    return math.floor(size + 0.5)
end

local function SetPixelPerfectFrameSize(frame, width, height)
    frame:SetSize(GetNearestPixelSize(frame, width), GetNearestPixelSize(frame, height))
end

local function SnapFrameSize(frame)
    SetPixelPerfectFrameSize(frame, frame:GetWidth(), frame:GetHeight())
end

local function FormatDebugNumber(value)
    if type(value) == "number" then
        return ("%.3f"):format(value)
    end

    return tostring(value)
end

local function GetDebugRegionName(region)
    if not region then
        return "nil"
    end

    if region.GetName then
        return region:GetName() or tostring(region)
    end

    return tostring(region)
end

local function IsFramePositionDebugEnabled()
    return DEBUG_FRAME_POSITION or (NS.db and NS.db:Get("debug") == true)
end

local function PrintFramePositionDebug(frame, reason)
    if not IsFramePositionDebugEnabled() or not NS.charDB or not NS.Print then
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    NS:Print(("Frame position [%s] frame point=%s relativeTo=%s relativePoint=%s x=%s y=%s width=%s height=%s left=%s top=%s right=%s bottom=%s scale=%s effectiveScale=%s"):format(
        tostring(reason),
        tostring(point),
        GetDebugRegionName(relativeTo),
        tostring(relativePoint),
        FormatDebugNumber(x),
        FormatDebugNumber(y),
        FormatDebugNumber(frame:GetWidth()),
        FormatDebugNumber(frame:GetHeight()),
        FormatDebugNumber(frame:GetLeft()),
        FormatDebugNumber(frame:GetTop()),
        FormatDebugNumber(frame:GetRight()),
        FormatDebugNumber(frame:GetBottom()),
        FormatDebugNumber(frame:GetScale()),
        FormatDebugNumber(frame:GetEffectiveScale())
    ))
    NS:Print(("Frame DB [%s] point=%s relativePoint=%s x=%s y=%s width=%s height=%s scale=%s"):format(
        tostring(reason),
        tostring(NS.charDB:Get("frame", "point")),
        tostring(NS.charDB:Get("frame", "relativePoint")),
        FormatDebugNumber(NS.charDB:Get("frame", "x")),
        FormatDebugNumber(NS.charDB:Get("frame", "y")),
        FormatDebugNumber(NS.charDB:Get("frame", "width")),
        FormatDebugNumber(NS.charDB:Get("frame", "height")),
        FormatDebugNumber(NS.charDB:Get("frame", "scale"))
    ))
end

local function SaveFrameGeometry(frame)
    if not NS.charDB then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    point = point or DEFAULT_FRAME_POINT
    relativePoint = relativePoint or DEFAULT_FRAME_RELATIVE_POINT

    NS.charDB:Set("frame", "point", point)
    NS.charDB:Set("frame", "relativePoint", relativePoint)
    NS.charDB:Set("frame", "x", x or 0)
    NS.charDB:Set("frame", "y", y or 0)
    NS.charDB:Set("frame", "width", frame:GetWidth())
    NS.charDB:Set("frame", "height", frame:GetHeight())
    PreventClientPositionSaving(frame)
    ClearClientPosition(frame)
end

local function RestoreFramePosition(frame)
    frame:ClearAllPoints()
    frame:SetPoint(
        NS.charDB:Get("frame", "point") or DEFAULT_FRAME_POINT,
        UIParent,
        NS.charDB:Get("frame", "relativePoint") or DEFAULT_FRAME_RELATIVE_POINT,
        NS.charDB:Get("frame", "x") or 0,
        NS.charDB:Get("frame", "y") or 0
    )
end

local function GetFrameHorizontalChromeWidth()
    return (FRAME_INSET_LEFT - FRAME_INSET_RIGHT) + (CONTENT_INSET_LEFT - CONTENT_INSET_RIGHT)
end

local function GetMaxFrameWidth()
    local listWidth = NS.ItemList and NS.ItemList.GetPreferredWidth and NS.ItemList.GetPreferredWidth() or MIN_FRAME_WIDTH
    return math.max(MIN_FRAME_WIDTH, listWidth + GetFrameHorizontalChromeWidth())
end

local function RestoreFrameSize(frame)
    local maxWidth = GetMaxFrameWidth()
    local savedWidth = NS.charDB:Get("frame", "width")
    local width = math.min(math.max(savedWidth or maxWidth, MIN_FRAME_WIDTH), maxWidth)
    local height = math.max(NS.charDB:Get("frame", "height") or MIN_FRAME_HEIGHT, MIN_FRAME_HEIGHT)
    SetPixelPerfectFrameSize(frame, width, height)
end

local function RefreshFrame(frame)
    if NS.Inventory and frame.itemList then
        frame.itemList:SetItems(NS.Inventory:GetItems())
    end

    NS.Footer.Refresh(frame)
end

-- Frame construction
local function CreateContentFrame(frame)
    local content = CreateFrame(FRAME_TYPE, nil, frame)
    content:SetPoint("TOPLEFT", frame.Inset or frame, "TOPLEFT", CONTENT_INSET_LEFT, CONTENT_INSET_TOP)
    content:SetPoint("BOTTOMRIGHT", frame.Inset or frame, "BOTTOMRIGHT", CONTENT_INSET_RIGHT, CONTENT_INSET_BOTTOM)
    frame.content = content

    if NS.ItemList then
        frame.itemList = NS.ItemList.Create(content)
    end
end

local function CreateSearchControls(frame)
    local settingsButton = CreateSettingsButton(frame)

    if not frame.itemList or not frame.itemList.CreateSearchBox then
        return
    end

    local searchBox = frame.itemList:CreateSearchBox(frame)
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", settingsButton, "TOPRIGHT", SETTINGS_BUTTON_SEARCH_GAP, 0)
    searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", SEARCH_BOX_RIGHT_OFFSET, SEARCH_BOX_TOP_OFFSET)
    searchBox:SetFrameLevel(frame:GetFrameLevel() + SEARCH_BOX_FRAME_LEVEL_OFFSET)
    frame.searchBox = searchBox
end

local function CreateResizeButton(frame)
    frame:SetResizable(true)

    local maxWidth = GetMaxFrameWidth()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT, maxWidth, nil)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT)
    end

    local resizeButton = CreateFrame(BUTTON_TYPE, nil, frame, RESIZE_BUTTON_TEMPLATE)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", RESIZE_BUTTON_RIGHT_OFFSET, RESIZE_BUTTON_BOTTOM_OFFSET)
    resizeButton:Init(frame, MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT, maxWidth, nil)
    resizeButton:SetOnResizeStoppedCallback(function(target)
        SnapFrameSize(target)
        SaveFrameGeometry(target)
        PrintFramePositionDebug(target, "resize-stop")
    end)
    frame.resizeButton = resizeButton
end

local function RegisterFrameCallbacks(frame)
    if frame.callbacksRegistered then
        return
    end

    if NS.Inventory then
        NS.Inventory:RegisterUpdateCallback(function()
            if NS.frame then
                RefreshFrame(NS.frame)
            end
        end)
    end

    NS:RegisterEventHandler("PLAYER_MONEY", function()
        if NS.frame then
            NS.Footer.UpdateMoney(NS.frame)
        end
    end)

    NS:RegisterEventHandler("BAG_UPDATE_COOLDOWN", function()
        if NS.frame and NS.frame.itemList then
            NS.frame.itemList:RefreshVisibleCooldowns()
        end
    end)

    NS:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", function()
        if NS.frame then
            NS.Footer.UpdateBagButtons(NS.frame)

            if NS.Inventory then
                NS.Inventory:ScheduleScan("PLAYER_EQUIPMENT_CHANGED")
            end
        end
    end)

    frame.callbacksRegistered = true
end

function NS:CreateMainFrame()
    if NS.frame then
        return NS.frame
    end

    local frame = CreateFrame(FRAME_TYPE, FRAME_NAME, UIParent, MAIN_FRAME_TEMPLATE)
    ApplyBaseFrameTheme(frame)
    PreventClientPositionSaving(frame)
    frame:SetScale(GetSavedFrameScale())
    RestoreFrameSize(frame)
    frame:SetFrameStrata(MAIN_FRAME_STRATA)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    ClearClientPosition(frame)
    frame:EnableMouse(true)
    frame:Hide()

    if frame.SetTitle then
        frame:SetTitle(ADDON_NAME)
    end

    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset(MAIN_FRAME_PORTRAIT)
        frame:SetPortraitTexCoord(PORTRAIT_TEX_COORD_LEFT, PORTRAIT_TEX_COORD_RIGHT, PORTRAIT_TEX_COORD_TOP, PORTRAIT_TEX_COORD_BOTTOM)
    end

    RestoreFramePosition(frame)
    CreateTitleBarControls(frame)

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_INSET_LEFT, FRAME_INSET_TOP)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FRAME_INSET_RIGHT, FRAME_INSET_BOTTOM)
    end

    local dragRegion = frame.TitleContainer or frame
    dragRegion:EnableMouse(true)
    dragRegion:RegisterForDrag("LeftButton")
    dragRegion:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)

    dragRegion:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveFrameGeometry(frame)
        PrintFramePositionDebug(frame, "move-stop")
    end)

    CreateContentFrame(frame)
    CreateSearchControls(frame)
    NS.Footer.Create(frame)
    CreateResizeButton(frame)
    RegisterFrameCallbacks(frame)

    frame:SetScript("OnShow", function(self)
        ClearClientPosition(self)
        if NS.BlizzardBags then
            NS.BlizzardBags.HideBlizzardBags()
        end
        PrintFramePositionDebug(self, "show")

        if NS.Inventory and not NS.Inventory.initialScanComplete then
            NS.Inventory:ScanNow("frame-show")
        end

        RefreshFrame(self)
    end)

    NS.frame = frame
    RefreshFrame(frame)
    PrintFramePositionDebug(frame, "addon-load")
    return frame
end

function NS:ShowFrame()
    local frame = NS.frame or NS:CreateMainFrame()
    frame:Show()
end

function NS:HideFrame()
    if NS.frame then
        NS.frame:Hide()
    end
end

function NS:ToggleFrame()
    local frame = NS.frame or NS:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

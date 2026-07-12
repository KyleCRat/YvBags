local _, NS = ...

local FooterCurrencies = {}
NS.FooterCurrencies = FooterCurrencies

-- Layout
local CURRENCY_CONTAINER_LEFT_PADDING = 12
local CURRENCY_CONTAINER_RIGHT_PADDING = 10
local CURRENCY_BUTTON_POOL_SIZE = 12
local CURRENCY_BUTTON_HEIGHT = 24
local CURRENCY_BUTTON_MIN_WIDTH = 48
local CURRENCY_BUTTON_TEXT_ICON_GAP = 4
local CURRENCY_BUTTON_GAP = 8

-- Icon visuals
local CURRENCY_ICON_SIZE = 18
local CURRENCY_ICON_BORDER_SIZE = 24
local CURRENCY_ICON_TEX_COORD_LEFT = 0.08
local CURRENCY_ICON_TEX_COORD_RIGHT = 0.92
local CURRENCY_ICON_TEX_COORD_TOP = 0.08
local CURRENCY_ICON_TEX_COORD_BOTTOM = 0.92
local CURRENCY_ICON_BORDER_ALPHA = 0.95

-- Text
local CURRENCY_TEXT_SIZE = 18
local CURRENCY_TEXT_COLOR_R = 1
local CURRENCY_TEXT_COLOR_G = 1
local CURRENCY_TEXT_COLOR_B = 1
local CURRENCY_TEXT_Y_OFFSET = -1
local CURRENCY_FONT_LAYER = "OVERLAY"

-- Data
local MAX_TRACKED_CURRENCY_SCAN = 32
local TOOLTIP_CURRENCY_ICON_SIZE = 16

-- Frame construction
local FRAME_TYPE = "Frame"
local BUTTON_TYPE = "Button"
local TEXTURE_LAYER_ARTWORK = "ARTWORK"
local TEXTURE_LAYER_OVERLAY = "OVERLAY"

local function GetPrimaryFont()
    return NS.Media.GetPrimaryFont()
end

local function FormatLargeAmount(amount)
    if AbbreviateNumbers then
        return AbbreviateNumbers(amount or 0)
    elseif AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(amount or 0)
    elseif BreakUpLargeNumbers then
        return BreakUpLargeNumbers(amount or 0)
    end

    return tostring(amount or 0)
end

local function FormatExactAmount(amount)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(amount or 0)
    end

    return tostring(amount or 0)
end

local function FormatAmountWithMax(currency)
    local quantity = currency.quantity or 0
    local maxQuantity = currency.maxQuantity or 0

    if maxQuantity > 0 then
        return ("%s / %s"):format(FormatExactAmount(quantity), FormatExactAmount(maxQuantity))
    end

    return FormatExactAmount(quantity)
end

local function GetCurrencyDetails(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and currencyID then
        return C_CurrencyInfo.GetCurrencyInfo(currencyID)
    end

    return nil
end

local function GetCurrencyQualityColor(currency)
    local quality = currency and currency.quality
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end

    return NS.Media.GetAccentColor()
end

local function BuildCurrencyData(backpackInfo)
    local currencyID = backpackInfo.currencyTypesID
    local details = GetCurrencyDetails(currencyID)
    local currency = {
        currencyID = currencyID,
        name = backpackInfo.name,
        quantity = backpackInfo.quantity or 0,
        iconFileID = backpackInfo.iconFileID,
        maxQuantity = 0,
        quality = nil,
    }

    if details then
        currency.name = details.name or currency.name
        currency.quantity = details.quantity or currency.quantity
        currency.iconFileID = details.iconFileID or currency.iconFileID
        currency.maxQuantity = details.maxQuantity or 0
        currency.quality = details.quality
    end

    return currency
end

local function GetTrackedCurrencies()
    local currencies = {}

    if not C_CurrencyInfo or not C_CurrencyInfo.GetBackpackCurrencyInfo then
        return currencies
    end

    for index = 1, MAX_TRACKED_CURRENCY_SCAN do
        local backpackInfo = C_CurrencyInfo.GetBackpackCurrencyInfo(index)
        if not backpackInfo then
            break
        end

        currencies[#currencies + 1] = BuildCurrencyData(backpackInfo)
    end

    return currencies
end

local function AddTooltipDivider(tooltip)
    if GameTooltip_AddBlankLineToTooltip then
        GameTooltip_AddBlankLineToTooltip(tooltip)
    else
        tooltip:AddLine(" ")
    end
end

local function AddTooltipActionLine(tooltip, text)
    local r, g, b = NS.Media.GetAccentColor()
    tooltip:AddLine(text, r, g, b)
end

local function GetTooltipAnchor(frame)
    local center = frame:GetCenter()
    local screenCenter = UIParent and UIParent:GetWidth() and UIParent:GetWidth() / 2

    if center and screenCenter and center > screenCenter then
        return "ANCHOR_LEFT"
    end

    return "ANCHOR_RIGHT"
end

local function GetCurrencyTooltipLabel(currency)
    local name = currency.name or ""
    if currency.iconFileID then
        return ("|T%d:%d|t %s"):format(currency.iconFileID, TOOLTIP_CURRENCY_ICON_SIZE, name)
    end

    return name
end

local function AddCurrencyTooltipLine(currency)
    local r, g, b = GetCurrencyQualityColor(currency)
    GameTooltip:AddDoubleLine(
        GetCurrencyTooltipLabel(currency),
        FormatAmountWithMax(currency),
        r, g, b,
        1, 1, 1
    )
end

local function ShowCurrencyTooltip(button)
    local hoveredCurrency = button.currency
    if not hoveredCurrency then
        return
    end

    local currencies = GetTrackedCurrencies()
    GameTooltip:SetOwner(button, GetTooltipAnchor(button))
    GameTooltip:ClearLines()

    for _, currency in ipairs(currencies) do
        AddCurrencyTooltipLine(currency)
    end

    AddTooltipDivider(GameTooltip)
    local r, g, b = GetCurrencyQualityColor(hoveredCurrency)
    GameTooltip:AddLine(GetCurrencyTooltipLabel(hoveredCurrency), r, g, b)
    GameTooltip:AddLine(FormatAmountWithMax(hoveredCurrency), 1, 1, 1)
    AddTooltipDivider(GameTooltip)
    AddTooltipActionLine(GameTooltip, "Middle-click to stop tracking")
    GameTooltip:Show()
end

local function HideCurrencyTooltip()
    GameTooltip:Hide()
end

local function RefreshTokenFrame()
    if BackpackTokenFrame and BackpackTokenFrame.Update then
        BackpackTokenFrame:Update()
    end

    if TokenFrame and TokenFrame:IsShown() and TokenFrame.Update then
        TokenFrame:Update()
    end
end

local function StopTrackingCurrency(button)
    if not button.currency or not button.currency.currencyID then
        return
    end

    if C_CurrencyInfo and C_CurrencyInfo.SetCurrencyBackpackByID then
        C_CurrencyInfo.SetCurrencyBackpackByID(button.currency.currencyID, false)
        RefreshTokenFrame()
        FooterCurrencies.Refresh(NS.frame)
        HideCurrencyTooltip()
    end
end

local function OnCurrencyClick(button, mouseButton)
    if not button.currency then
        return
    end

    if IsModifiedClick and IsModifiedClick("CHATLINK") and HandleModifiedItemClick and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
        local linkedToChat = HandleModifiedItemClick(C_CurrencyInfo.GetCurrencyLink(button.currency.currencyID))
        if linkedToChat then
            return
        end
    end

    if mouseButton == "MiddleButton" then
        StopTrackingCurrency(button)
    elseif mouseButton == "LeftButton" and CharacterFrame and CharacterFrame.ToggleTokenFrame then
        CharacterFrame:ToggleTokenFrame()
    end
end

local function OnCurrencyEnter(button)
    ShowCurrencyTooltip(button)
end

local function OnCurrencyLeave(button)
    HideCurrencyTooltip()
end

local function MeasureCurrencyButton(button, currency)
    button.countText:SetText(FormatLargeAmount(currency.quantity))
    return math.max(
        CURRENCY_BUTTON_MIN_WIDTH,
        button.countText:GetStringWidth() + CURRENCY_BUTTON_TEXT_ICON_GAP + CURRENCY_ICON_BORDER_SIZE
    )
end

local function UpdateCurrencyButton(button, currency, width)
    local r, g, b = GetCurrencyQualityColor(currency)

    button.currency = currency
    button:SetWidth(width)
    button.countText:SetText(FormatLargeAmount(currency.quantity))
    button.icon:SetTexture(currency.iconFileID)
    button.border:SetVertexColor(r, g, b, CURRENCY_ICON_BORDER_ALPHA)
    button:Show()
end

local function HideCurrencyButton(button)
    button.currency = nil
    button:Hide()
end

local function CreateCurrencyButton(parent)
    local button = CreateFrame(BUTTON_TYPE, nil, parent)
    button:SetSize(CURRENCY_BUTTON_MIN_WIDTH, CURRENCY_BUTTON_HEIGHT)
    button:RegisterForClicks("LeftButtonUp", "MiddleButtonUp")

    button.countText = button:CreateFontString(nil, CURRENCY_FONT_LAYER)
    button.countText:SetFont(GetPrimaryFont(), CURRENCY_TEXT_SIZE)
    button.countText:SetTextColor(CURRENCY_TEXT_COLOR_R, CURRENCY_TEXT_COLOR_G, CURRENCY_TEXT_COLOR_B)
    button.countText:SetPoint("TOPLEFT", button, "TOPLEFT", 0, CURRENCY_TEXT_Y_OFFSET)
    button.countText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -(CURRENCY_ICON_BORDER_SIZE + CURRENCY_BUTTON_TEXT_ICON_GAP), CURRENCY_TEXT_Y_OFFSET)
    button.countText:SetJustifyH("RIGHT")
    button.countText:SetJustifyV("MIDDLE")

    button.icon = button:CreateTexture(nil, TEXTURE_LAYER_ARTWORK)
    button.icon:SetPoint("RIGHT", button, "RIGHT", -3, 0)
    button.icon:SetSize(CURRENCY_ICON_SIZE, CURRENCY_ICON_SIZE)
    button.icon:SetTexCoord(CURRENCY_ICON_TEX_COORD_LEFT, CURRENCY_ICON_TEX_COORD_RIGHT, CURRENCY_ICON_TEX_COORD_TOP, CURRENCY_ICON_TEX_COORD_BOTTOM)

    button.border = button:CreateTexture(nil, TEXTURE_LAYER_OVERLAY)
    button.border:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
    button.border:SetSize(CURRENCY_ICON_BORDER_SIZE, CURRENCY_ICON_BORDER_SIZE)
    button.border:SetTexture(NS.Media.GetIconBorderTexture())

    button:SetScript("OnEnter", OnCurrencyEnter)
    button:SetScript("OnLeave", OnCurrencyLeave)
    button:SetScript("OnClick", OnCurrencyClick)
    button:Hide()
    return button
end

function FooterCurrencies.Refresh(frame)
    if not frame or not frame.currencyContainer or not frame.currencyButtons then
        return
    end

    local currencies = GetTrackedCurrencies()
    local availableWidth = frame.currencyContainer:GetWidth() or 0
    local previousButton
    local usedWidth = 0
    local visibleIndex = 0

    for _, button in ipairs(frame.currencyButtons) do
        HideCurrencyButton(button)
        button:ClearAllPoints()
    end

    if availableWidth <= CURRENCY_BUTTON_MIN_WIDTH or #currencies == 0 then
        return
    end

    for _, currency in ipairs(currencies) do
        local button = frame.currencyButtons[visibleIndex + 1]
        if not button then
            break
        end

        local buttonWidth = MeasureCurrencyButton(button, currency)
        local nextWidth = usedWidth + buttonWidth
        if visibleIndex > 0 then
            nextWidth = nextWidth + CURRENCY_BUTTON_GAP
        end

        if nextWidth > availableWidth then
            break
        end

        visibleIndex = visibleIndex + 1
        usedWidth = nextWidth

        if previousButton then
            button:SetPoint("RIGHT", previousButton, "LEFT", -CURRENCY_BUTTON_GAP, 0)
        else
            button:SetPoint("RIGHT", frame.currencyContainer, "RIGHT", 0, 0)
        end

        UpdateCurrencyButton(button, currency, buttonWidth)
        previousButton = button
    end
end

function FooterCurrencies.Create(frame, footer, leftAnchor, rightAnchor)
    local container = CreateFrame(FRAME_TYPE, nil, footer)
    container:SetPoint("LEFT", leftAnchor, "RIGHT", CURRENCY_CONTAINER_LEFT_PADDING, 0)
    container:SetPoint("RIGHT", rightAnchor, "LEFT", -CURRENCY_CONTAINER_RIGHT_PADDING, 0)
    container:SetHeight(CURRENCY_BUTTON_HEIGHT)
    frame.currencyContainer = container

    frame.currencyButtons = {}
    for index = 1, CURRENCY_BUTTON_POOL_SIZE do
        frame.currencyButtons[index] = CreateCurrencyButton(container)
    end

    container:SetScript("OnSizeChanged", function()
        FooterCurrencies.Refresh(frame)
    end)
end

NS:RegisterEventHandler("CURRENCY_DISPLAY_UPDATE", function()
    if NS.frame then
        FooterCurrencies.Refresh(NS.frame)
    end
end)

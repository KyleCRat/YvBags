local _, NS = ...

-- Bank-tab controls, totals, native banking actions, and money footer.
local Footer = {}
NS.BankFooter = Footer

local CHARACTER_BANK = Enum.BankType.Character
local ACCOUNT_BANK = Enum.BankType.Account
local PRECREATED_TAB_BUTTONS = 6
local FOOTER_LEFT_OFFSET = 3
local FOOTER_RIGHT_OFFSET = -15
local FOOTER_BOTTOM_OFFSET = 4
local FOOTER_HEIGHT = 28
local TAB_BUTTONS_X_OFFSET = 2
local TAB_BUTTON_SIZE = 24
local TAB_ICON_SIZE = 18
local TAB_BUTTON_GAP = 4
local TAB_ICON_LOAD_TIMEOUT_SECONDS = 0.5
local STATS_GAP = 8
local STATS_MIN_WIDTH = 62
local TEXT_SIZE = 18
local TEXT_Y_OFFSET = -1
local CONTROL_GAP = 4
local AUTO_DEPOSIT_MONEY_GAP = 12
local AUTO_DEPOSIT_MIN_WIDTH = 120
local AUTO_DEPOSIT_TEXT_PADDING = 18
local WARBAND_DEPOSIT_ICON_WIDTH = 18
local WARBAND_DEPOSIT_ICON_HEIGHT = 24
local SQUARE_BUTTON_SIZE = 28
local MONEY_ACTION_ICON_SIZE = 14
local CHECKMARK_SCALE = 1
local CHECKMARK_OFFSET_X = 2
local CHECKMARK_OFFSET_Y = 2
local MONEY_FRAME_RIGHT_OFFSET = 2
local MONEY_DISPLAY_MIN_WIDTH = 50
local MONEY_DISPLAY_PADDING = 8
local ICON_BROWSER_TOP_X_OFFSET = 8
local ICON_BROWSER_TOP_Y_OFFSET = -5
local ICON_BROWSER_RIGHT_OFFSET = -5
local ICON_BROWSER_BOTTOM_OFFSET = 40
local ICON_BROWSER_LABEL_Y_OFFSET = -10
local HIGHLIGHT_ALPHA = 0.18
local BORDER_ALPHA = 0.95
local PURCHASE_DISABLED_ALPHA = 0.4
local PURCHASE_ATLAS = "Garr_Building-AddFollowerPlus"
local TAB_SETTINGS_LOADING_TOOLTIP = "Bank tab settings are still loading."
local TAB_SETTINGS_UNAVAILABLE_TOOLTIP = "Bank tab settings are unavailable."
local INCLUDE_REAGENTS_TOOLTIP = "Include tradeable reagents when depositing all into the Warband bank."
local MONEY_WITHDRAW_TOOLTIP = "Withdraw money from the Warband bank."
local MONEY_DEPOSIT_TOOLTIP = "Deposit money into the Warband bank."

local MODERN_BUTTON_STYLES = {
    command = {
        height = SQUARE_BUTTON_SIZE,
        normal = "common-button-tertiary-normal",
        hover = "common-button-tertiary-hover",
        pressed = "common-button-tertiary-pressed",
        disabled = "common-button-tertiary-disabled",
        normalFont = GameFontNormal,
        highlightFont = GameFontHighlight,
        disabledFont = GameFontDisable,
    },
    square = {
        width = SQUARE_BUTTON_SIZE,
        height = SQUARE_BUTTON_SIZE,
        normal = "common-button-tertiary-square-normal",
        hover = "common-button-tertiary-square-hover",
        pressed = "common-button-tertiary-square-pressed",
        disabled = "common-button-tertiary-square-disabled",
        normalFont = GameFontNormalSmall,
        highlightFont = GameFontHighlightSmall,
        disabledFont = GameFontDisableSmall,
    },
}

local function AddTooltipDivider(tooltip)
    GameTooltip_AddBlankLineToTooltip(tooltip)
end

local function AddActionLine(tooltip, text)
    local r, g, b = NS.Media.GetAccentColor()
    tooltip:AddLine(text, r, g, b)
end

local function CreateButtonStateTexture(button, atlas, layer)
    local texture = button:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints(button)
    texture:SetAtlas(atlas, false)
    return texture
end

local function ApplyModernButtonStyle(button, style)
    button.modernButtonStyle = style
    button:SetHeight(style.height)
    if style.width then
        button:SetWidth(style.width)
    end

    button:SetNormalFontObject(style.normalFont)
    button:SetHighlightFontObject(style.highlightFont)
    button:SetDisabledFontObject(style.disabledFont)

    button.modernNormalTexture:SetAtlas(
        button:IsMouseOver() and style.hover or style.normal,
        false
    )
    button.modernPushedTexture:SetAtlas(style.pressed, false)
    button.modernDisabledTexture:SetAtlas(style.disabled, false)
end

local function SkinModernButton(button, style)
    button.Left:Hide()
    button.Middle:Hide()
    button.Right:Hide()
    button:GetHighlightTexture():SetTexture(nil)

    button.modernNormalTexture = CreateButtonStateTexture(
        button,
        style.normal
    )
    button.modernPushedTexture = CreateButtonStateTexture(
        button,
        style.pressed
    )
    button.modernDisabledTexture = CreateButtonStateTexture(
        button,
        style.disabled
    )
    button:SetNormalTexture(button.modernNormalTexture)
    button:SetPushedTexture(button.modernPushedTexture)
    button:SetDisabledTexture(button.modernDisabledTexture)
    ApplyModernButtonStyle(button, style)

    button:HookScript("OnEnter", function(self)
        self.modernNormalTexture:SetAtlas(
            self.modernButtonStyle.hover,
            false
        )
    end)
    button:HookScript("OnLeave", function(self)
        self.modernNormalTexture:SetAtlas(
            self.modernButtonStyle.normal,
            false
        )
    end)
end

local function CreateButtonIcon(button, atlas, width, height)
    local icon = button:CreateTexture(nil, "OVERLAY", nil, 1)
    icon:SetAtlas(atlas, true)
    icon:SetSize(width, height)
    icon:SetPoint("CENTER")
    return icon
end

local function SetButtonIconPressed(button, icon, pressed)
    icon:ClearAllPoints()
    icon:SetPoint(
        "CENTER",
        button,
        "CENTER",
        pressed and 1 or 0,
        pressed and -1 or 0
    )
end

local function CreateCheckmark(checkbox, disabled)
    local checkmark = checkbox:CreateTexture(nil, "ARTWORK")
    checkmark:SetPoint(
        "CENTER",
        checkbox,
        "CENTER",
        CHECKMARK_OFFSET_X,
        CHECKMARK_OFFSET_Y
    )
    checkmark:SetAtlas(NS.Media.GetCheckmarkAtlas(), true)
    checkmark:SetScale(CHECKMARK_SCALE)

    if disabled then
        checkmark:SetDesaturated(true)
        checkmark:SetVertexColor(
            GRAY_FONT_COLOR.r,
            GRAY_FONT_COLOR.g,
            GRAY_FONT_COLOR.b
        )
    end

    return checkmark
end

local function SkinModernCheckbox(checkbox)
    local style = MODERN_BUTTON_STYLES.square
    checkbox:SetSize(SQUARE_BUTTON_SIZE, SQUARE_BUTTON_SIZE)
    checkbox:SetNormalTexture(CreateButtonStateTexture(
        checkbox,
        style.normal
    ))
    checkbox:SetPushedTexture(CreateButtonStateTexture(
        checkbox,
        style.pressed
    ))
    checkbox:SetHighlightTexture(CreateButtonStateTexture(
        checkbox,
        style.hover,
        "HIGHLIGHT"
    ))
    checkbox:SetDisabledTexture(CreateButtonStateTexture(
        checkbox,
        style.disabled
    ))
    checkbox:SetCheckedTexture(CreateCheckmark(checkbox, false))
    checkbox:SetDisabledCheckedTexture(CreateCheckmark(checkbox, true))
    checkbox.Text:Hide()
end

local function AddDepositFlags(tooltip, depositFlags)
    if FlagsUtil.IsSet(
        depositFlags,
        Enum.BagSlotFlags.ExpansionCurrent
    ) then
        GameTooltip_AddNormalLine(
            tooltip,
            BANK_TAB_EXPANSION_ASSIGNMENT:format(
                BANK_TAB_EXPANSION_FILTER_CURRENT
            )
        )
    elseif FlagsUtil.IsSet(
        depositFlags,
        Enum.BagSlotFlags.ExpansionLegacy
    ) then
        GameTooltip_AddNormalLine(
            tooltip,
            BANK_TAB_EXPANSION_ASSIGNMENT:format(
                BANK_TAB_EXPANSION_FILTER_LEGACY
            )
        )
    end

    local filterList = ContainerFrameUtil_ConvertFilterFlagsToList(
        depositFlags
    )
    if filterList then
        GameTooltip_AddNormalLine(
            tooltip,
            BANK_TAB_DEPOSIT_ASSIGNMENTS:format(filterList),
            true
        )
    end
end

local function ShowTabTooltip(button)
    local container = button.container
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:SetText(container.name, 1, 1, 1)

    if not button:IsEnabled() then
        GameTooltip:AddLine(
            button.disabledTooltip,
            GRAY_FONT_COLOR.r,
            GRAY_FONT_COLOR.g,
            GRAY_FONT_COLOR.b,
            true
        )
        GameTooltip:Show()
        return
    end

    GameTooltip:AddDoubleLine(
        "Used / Total",
        ("%d / %d"):format(
            container.usedSlots,
            container.numSlots
        ),
        0.86,
        0.86,
        0.86,
        1,
        1,
        1
    )
    AddDepositFlags(GameTooltip, container.depositFlags)
    AddTooltipDivider(GameTooltip)
    AddActionLine(GameTooltip, "Left-click to configure this bank tab")
    GameTooltip:Show()
end

local function OnTabEnter(button)
    if button:IsEnabled() then
        button.highlight:Show()
        button.owner.itemList:SetHighlightedBagID(button.container.id)
    end
    ShowTabTooltip(button)
end

local function OnTabLeave(button)
    button.highlight:Hide()
    local container = button.container
    if container
        and button.owner.itemList.highlightedBagID == container.id then
        button.owner.itemList:SetHighlightedBagID(nil)
    end
    GameTooltip:Hide()
end

local function GetTabSettingsAvailability(bankType, tabID)
    if not NS.BankInventory:IsLoaded(bankType)
        or NS.BankInventory:IsLoading(bankType)
        or BankPanel:GetActiveBankType() ~= bankType
        or not BankPanel:GetTabData(tabID) then
        return false, TAB_SETTINGS_LOADING_TOOLTIP
    end

    if not C_Bank.CanUseBank(bankType) then
        return false, TAB_SETTINGS_UNAVAILABLE_TOOLTIP
    end

    return true
end

local function SetTabButtonEnabled(button, enabled, disabledTooltip)
    button:SetEnabled(enabled)
    button.disabledTooltip = disabledTooltip
    button.icon:SetDesaturated(not enabled)
    button.icon:SetAlpha(enabled and 1 or PURCHASE_DISABLED_ALPHA)
    button.border:SetAlpha(enabled and 1 or PURCHASE_DISABLED_ALPHA)

    if not enabled then
        button.highlight:Hide()
        if button.owner.itemList.highlightedBagID == button.container.id then
            button.owner.itemList:SetHighlightedBagID(nil)
        end
    end
end

local function CreateTabButton(frame, footer, index)
    local button = CreateFrame("Button", nil, footer)
    button:SetSize(TAB_BUTTON_SIZE, TAB_BUTTON_SIZE)
    button:SetPoint(
        "LEFT",
        footer,
        "LEFT",
        TAB_BUTTONS_X_OFFSET
            + (index - 1) * (TAB_BUTTON_SIZE + TAB_BUTTON_GAP),
        0
    )
    button:RegisterForClicks("LeftButtonUp")
    button.owner = frame

    local highlight = button:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(button)
    local r, g, b = NS.Media.GetAccentColor()
    highlight:SetColorTexture(r, g, b, HIGHLIGHT_ALPHA)
    highlight:Hide()
    button.highlight = highlight

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(TAB_ICON_SIZE, TAB_ICON_SIZE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER")
    border:SetSize(TAB_BUTTON_SIZE, TAB_BUTTON_SIZE)
    border:SetTexture(NS.Media.GetIconBorderTexture())
    border:SetVertexColor(0.86, 0.86, 0.86, BORDER_ALPHA)
    button.border = border

    button:SetScript("OnClick", function(self)
        local canConfigure = GetTabSettingsAvailability(
            self.container.bankType,
            self.container.id
        )
        if canConfigure then
            self.owner:OpenTabSettings(self.container.id)
        end
    end)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", OnTabEnter)
    button:SetScript("OnLeave", OnTabLeave)
    button:Hide()
    return button
end

local function ShowPurchaseTooltip(button)
    local bankType = button:GetAttribute("overrideBankType")
    local tabData = C_Bank.FetchNextPurchasableBankTabData(bankType)
    if not tabData then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:SetText(tabData.purchasePromptTitle, 1, 1, 1)
    GameTooltip:AddLine(tabData.purchasePromptBody, 0.86, 0.86, 0.86, true)
    GameTooltip_AddMoneyLine(GameTooltip, tabData.tabCost)
    if button:IsEnabled() then
        AddTooltipDivider(GameTooltip)
        AddActionLine(GameTooltip, "Left-click to purchase this bank tab")
    end
    GameTooltip:Show()
end

local function SetPurchaseButtonEnabled(button, enabled)
    button:SetEnabled(enabled)
    button.icon:SetDesaturated(not enabled)
    button.icon:SetAlpha(enabled and 1 or PURCHASE_DISABLED_ALPHA)
    button.border:SetAlpha(enabled and 1 or PURCHASE_DISABLED_ALPHA)
end

local function CreatePurchaseButton(frame, footer, bankType)
    local button = CreateFrame(
        "Button",
        nil,
        footer,
        "BankPanelPurchaseButtonScriptTemplate"
    )
    button:SetSize(TAB_BUTTON_SIZE, TAB_BUTTON_SIZE)
    button:SetAttribute("overrideBankType", bankType)
    button.owner = frame

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(TAB_ICON_SIZE, TAB_ICON_SIZE)
    icon:SetAtlas(PURCHASE_ATLAS, false)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER")
    border:SetSize(TAB_BUTTON_SIZE, TAB_BUTTON_SIZE)
    border:SetTexture(NS.Media.GetIconBorderTexture())
    border:SetVertexColor(0.86, 0.86, 0.86, BORDER_ALPHA)
    button.border = border

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    local r, g, b = NS.Media.GetAccentColor()
    highlight:SetColorTexture(r, g, b, HIGHLIGHT_ALPHA)

    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", ShowPurchaseTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:Hide()
    return button
end

local function GetButtonGroupWidth(visibleButtonCount)
    if visibleButtonCount == 0 then
        return 0
    end

    return TAB_BUTTONS_X_OFFSET
        + visibleButtonCount * TAB_BUTTON_SIZE
        + (visibleButtonCount - 1) * TAB_BUTTON_GAP
end

local function CancelPendingTabGroupReveal(frame)
    if frame.bankTabRevealTimer then
        frame.bankTabRevealTimer:Cancel()
        frame.bankTabRevealTimer = nil
    end
end

local function AreTabIconsLoaded(frame, visibleTabCount)
    for index = 1, visibleTabCount do
        if not frame.bankTabButtons[index].icon:IsObjectLoaded() then
            return false
        end
    end

    return true
end

local function RevealTabGroupWhenReady(
    frame,
    bankType,
    visibleTabCount,
    deadline
)
    if bankType ~= NS.BankInventory:GetActiveBankType() then
        return
    end

    if AreTabIconsLoaded(frame, visibleTabCount)
        or GetTime() >= deadline then
        frame.bankTabGroup:Show()
        return
    end

    local timer
    timer = C_Timer.NewTimer(0, function()
        if frame.bankTabRevealTimer ~= timer then
            return
        end

        frame.bankTabRevealTimer = nil
        RevealTabGroupWhenReady(
            frame,
            bankType,
            visibleTabCount,
            deadline
        )
    end)
    frame.bankTabRevealTimer = timer
end

local function ShowStatsTooltip(statsButton)
    local bankType = NS.BankInventory:GetActiveBankType()
    local stats = NS.BankInventory:GetStats(bankType)
    local containers = NS.BankInventory:GetContainers(bankType)

    GameTooltip:SetOwner(statsButton, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine(
        "Used / Total",
        ("%d / %d"):format(
            stats.usedSlots or 0,
            stats.totalSlots or 0
        ),
        1,
        1,
        1,
        1,
        1,
        1
    )

    for index = 1, #containers do
        local container = containers[index]
        GameTooltip:AddDoubleLine(
            container.name,
            ("%d / %d"):format(
                container.usedSlots,
                container.numSlots
            ),
            0.86,
            0.86,
            0.86,
            1,
            1,
            1
        )
    end

    if statsButton.canSort then
        AddTooltipDivider(GameTooltip)
        AddActionLine(
            GameTooltip,
            bankType == ACCOUNT_BANK
                and "Left-click to sort the Warband bank"
                or "Left-click to sort the Character bank"
        )
    end
    GameTooltip:Show()
end

local function GetDisplayedMoney(bankType)
    if bankType == ACCOUNT_BANK then
        return C_Bank.FetchDepositedMoney(bankType)
    end

    return GetMoney()
end

local function ShowMoneyTooltip(moneyDisplay)
    GameTooltip:SetOwner(moneyDisplay, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(
        NS.Money.FormatExact(moneyDisplay.copper, true),
        1,
        1,
        1
    )
    GameTooltip:Show()
end

local function HideMoneyTooltip()
    GameTooltip:Hide()
end

local function ShowMoneyActionTooltip(button)
    local disabledTooltip = button:GetDisabledTooltip()
    if not button:IsEnabled() and disabledTooltip then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.moneyActionTooltip, 1, 1, 1)
    GameTooltip:Show()
end

local function RefreshMoneyActionIcon(button)
    local enabled = button:IsEnabled()
    button.moneyActionIcon:SetDesaturated(not enabled)
    button.moneyActionIcon:SetAlpha(enabled and 1 or 0.5)
end

local function SkinMoneyActionButton(button, iconAtlas, tooltip)
    SkinModernButton(button, MODERN_BUTTON_STYLES.square)
    button.Text:Hide()
    button.moneyActionTooltip = tooltip
    button.moneyActionIcon = CreateButtonIcon(
        button,
        iconAtlas,
        MONEY_ACTION_ICON_SIZE,
        MONEY_ACTION_ICON_SIZE
    )
    SetButtonIconPressed(button, button.moneyActionIcon, false)
    RefreshMoneyActionIcon(button)

    button:HookScript("OnEnter", ShowMoneyActionTooltip)
    button:HookScript("OnLeave", function(self)
        SetButtonIconPressed(self, self.moneyActionIcon, false)
        GameTooltip:Hide()
    end)
    button:HookScript("OnMouseDown", function(self, mouseButton)
        if self:IsEnabled() and mouseButton == "LeftButton" then
            SetButtonIconPressed(self, self.moneyActionIcon, true)
        end
    end)
    button:HookScript("OnMouseUp", function(self)
        SetButtonIconPressed(self, self.moneyActionIcon, false)
    end)
    button:HookScript("OnEnable", RefreshMoneyActionIcon)
    button:HookScript("OnDisable", RefreshMoneyActionIcon)
end

local function LayoutMoneyFrame(moneyFrame)
    local displayWidth = math.max(
        MONEY_DISPLAY_MIN_WIDTH,
        moneyFrame.customMoneyText:GetStringWidth() + MONEY_DISPLAY_PADDING
    )
    moneyFrame.customMoneyDisplay:SetWidth(displayWidth)

    local width = 0
    local previous
    local buttons = moneyFrame.actionButtons
    for index = 1, #buttons do
        local button = buttons[index]
        if button:IsShown() then
            button:ClearAllPoints()
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", CONTROL_GAP, 0)
                width = width + CONTROL_GAP
            else
                button:SetPoint("LEFT", moneyFrame, "LEFT", 0, 0)
            end
            width = width + button:GetWidth()
            previous = button
        end
    end

    moneyFrame.customMoneyDisplay:ClearAllPoints()
    if previous then
        moneyFrame.customMoneyDisplay:SetPoint(
            "LEFT",
            previous,
            "RIGHT",
            CONTROL_GAP,
            0
        )
        width = width + CONTROL_GAP
    else
        moneyFrame.customMoneyDisplay:SetPoint(
            "LEFT",
            moneyFrame,
            "LEFT",
            0,
            0
        )
    end

    width = width + displayWidth
    moneyFrame:SetWidth(width)
end

local function RefreshMoneyDisplay(frame, bankType)
    local copper = GetDisplayedMoney(bankType)
    local display = NS.Money.GetDisplay(copper, true)
    local color = display.color

    frame.bankMoneyText:SetText(display.text)
    frame.bankMoneyText:SetTextColor(color.r, color.g, color.b)
    frame.bankMoneyDisplay.copper = copper
    LayoutMoneyFrame(frame.bankMoneyFrame)
end

local function RefreshWarbandDepositIcon(button)
    if not button.usesWarbandDepositIcon then
        return
    end

    local enabled = button:IsEnabled()
    button.warbandDepositIcon:SetDesaturated(not enabled)
    button.warbandDepositIcon:SetAlpha(
        enabled and (button:IsMouseOver() and 1 or 0.82) or 0.4
    )
end

local function SetWarbandDepositIconPressed(button, pressed)
    SetButtonIconPressed(button, button.warbandDepositIcon, pressed)
end

local function ShowAutoDepositTooltip(button)
    if not button.usesWarbandDepositIcon then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button:GetBestTextForBankType(), 1, 1, 1)
    GameTooltip:Show()
end

local function ShowIncludeReagentsTooltip(checkbox)
    GameTooltip:SetOwner(checkbox, "ANCHOR_RIGHT")
    GameTooltip:SetText(INCLUDE_REAGENTS_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
end

local function RefreshAutoDepositLayout(frame, bankType)
    local autoDepositFrame = frame.autoDepositFrame
    local depositButton = autoDepositFrame.DepositButton
    local checkbox = autoDepositFrame.IncludeReagentsCheckbox
    local usesWarbandIcon = bankType == ACCOUNT_BANK

    depositButton.usesWarbandDepositIcon = usesWarbandIcon
    ApplyModernButtonStyle(
        depositButton,
        usesWarbandIcon
            and MODERN_BUTTON_STYLES.square
            or MODERN_BUTTON_STYLES.command
    )
    depositButton.Text:SetShown(not usesWarbandIcon)
    depositButton.warbandDepositIcon:SetShown(usesWarbandIcon)
    depositButton:ClearAllPoints()
    depositButton:SetPoint("LEFT", autoDepositFrame, "LEFT", 0, 0)

    local width
    if usesWarbandIcon then
        SetWarbandDepositIconPressed(depositButton, false)
        checkbox:ClearAllPoints()
        checkbox:SetPoint("LEFT", depositButton, "RIGHT", CONTROL_GAP, 0)
        width = SQUARE_BUTTON_SIZE
            + CONTROL_GAP
            + SQUARE_BUTTON_SIZE
        RefreshWarbandDepositIcon(depositButton)
    else
        width = math.max(
            AUTO_DEPOSIT_MIN_WIDTH,
            depositButton.Text:GetStringWidth() + AUTO_DEPOSIT_TEXT_PADDING
        )
        depositButton:SetWidth(width)
    end

    autoDepositFrame:SetSize(width, FOOTER_HEIGHT)
    autoDepositFrame:ClearAllPoints()
    autoDepositFrame:SetPoint(
        "RIGHT",
        frame.bankMoneyFrame,
        "LEFT",
        -AUTO_DEPOSIT_MONEY_GAP,
        0
    )
end

local function RefreshTabButtons(frame)
    local bankType = NS.BankInventory:GetActiveBankType()
    local containers = NS.BankInventory:GetDisplayContainers(bankType)
    local loading = NS.BankInventory:IsLoading(bankType)

    CancelPendingTabGroupReveal(frame)
    frame.bankTabGroup:Hide()

    while #frame.bankTabButtons < #containers do
        local index = #frame.bankTabButtons + 1
        frame.bankTabButtons[index] = CreateTabButton(
            frame,
            frame.bankTabGroup,
            index
        )
    end

    for index = 1, #frame.bankTabButtons do
        local button = frame.bankTabButtons[index]
        local container = containers[index]
        if container then
            button.container = container
            button.icon:SetTexture(container.icon)
            SetTabButtonEnabled(
                button,
                GetTabSettingsAvailability(bankType, container.id)
            )
            button:Show()
        else
            button:Hide()
            button.container = nil
        end
    end

    frame.characterPurchaseButton:Hide()
    frame.accountPurchaseButton:Hide()

    local purchaseButton = bankType == ACCOUNT_BANK
        and frame.accountPurchaseButton
        or frame.characterPurchaseButton
    local purchaseData = C_Bank.FetchBankLockedReason(bankType) == nil
        and C_Bank.FetchNextPurchasableBankTabData(bankType)
    local visibleButtonCount = #containers
    if purchaseData
        and (not loading or NS.BankInventory:IsLoaded(bankType)) then
        purchaseButton:ClearAllPoints()
        purchaseButton:SetPoint(
            "LEFT",
            frame.bankTabGroup,
            "LEFT",
            TAB_BUTTONS_X_OFFSET
                + visibleButtonCount * (TAB_BUTTON_SIZE + TAB_BUTTON_GAP),
            0
        )
        SetPurchaseButtonEnabled(
            purchaseButton,
            not loading and C_Bank.CanPurchaseBankTab(bankType)
        )
        purchaseButton:Show()
        visibleButtonCount = visibleButtonCount + 1
    end

    frame.bankStatsButton:ClearAllPoints()
    frame.bankStatsButton:SetPoint(
        "LEFT",
        frame.bankTabGroup,
        "LEFT",
        GetButtonGroupWidth(visibleButtonCount) + STATS_GAP,
        0
    )

    RevealTabGroupWhenReady(
        frame,
        bankType,
        #containers,
        GetTime() + TAB_ICON_LOAD_TIMEOUT_SECONDS
    )
end

local function HideDefaultIconSelector(settingsMenu)
    settingsMenu.IconSelector:Hide()
    settingsMenu.IconSelector:SetAlpha(0)
    settingsMenu.BorderBox.IconTypeDropdown:Hide()
    settingsMenu.BorderBox.IconTypeDropdown:SetAlpha(0)
end

local function AttachOptionalIconBrowser(settingsMenu)
    local iconBrowserAPI = _G.LRPMediaIconBrowserAPI
    if not iconBrowserAPI or not iconBrowserAPI.CreateBrowser then
        return
    end

    local browser = iconBrowserAPI.CreateBrowser(
        settingsMenu.BorderBox
    )
    browser:ClearAllPoints()
    browser:SetPoint(
        "TOPLEFT",
        settingsMenu.DepositSettingsMenu,
        "BOTTOMLEFT",
        ICON_BROWSER_TOP_X_OFFSET,
        ICON_BROWSER_TOP_Y_OFFSET
    )
    browser:SetPoint(
        "BOTTOMRIGHT",
        settingsMenu.BorderBox,
        "BOTTOMRIGHT",
        ICON_BROWSER_RIGHT_OFFSET,
        ICON_BROWSER_BOTTOM_OFFSET
    )
    settingsMenu.LRPMIB_Browser = browser

    local selectionText = settingsMenu.BorderBox.IconSelectionText
    local point, relativeTo, relativePoint, xOffset, yOffset =
        selectionText:GetPoint(1)
    selectionText:ClearAllPoints()
    selectionText:SetPoint(
        point,
        relativeTo,
        relativePoint,
        xOffset,
        yOffset + ICON_BROWSER_LABEL_Y_OFFSET
    )

    settingsMenu:HookScript("OnShow", function(self)
        HideDefaultIconSelector(self)
        browser:Show()
    end)
end

function Footer.PreloadTabIcons(frame)
    local preloadTextures = frame.bankTabIconPreloadTextures
    local preloadIndex = 0
    local bankTypes = C_Bank.FetchViewableBankTypes()

    for bankTypeIndex = 1, #bankTypes do
        local bankType = bankTypes[bankTypeIndex]
        if bankType == CHARACTER_BANK or bankType == ACCOUNT_BANK then
            local tabData = C_Bank.FetchPurchasedBankTabData(bankType)
            for tabIndex = 1, #tabData do
                preloadIndex = preloadIndex + 1
                local texture = preloadTextures[preloadIndex]
                if not texture then
                    texture = frame.footer:CreateTexture(nil, "BACKGROUND")
                    texture:SetPoint("BOTTOMLEFT")
                    texture:SetSize(1, 1)
                    texture:SetAlpha(0)
                    preloadTextures[preloadIndex] = texture
                end

                texture:SetTexture(tabData[tabIndex].icon)
            end
        end
    end
end

function Footer.Refresh(frame)
    local bankType = NS.BankInventory:GetActiveBankType()
    if not bankType then
        return
    end

    RefreshTabButtons(frame)

    local stats = NS.BankInventory:GetStats(bankType)
    frame.bankStatsText:SetText(("%d/%d"):format(
        stats.usedSlots or 0,
        stats.totalSlots or 0
    ))
    frame.bankStatsButton:SetWidth(math.max(
        STATS_MIN_WIDTH,
        frame.bankStatsText:GetStringWidth() + 8
    ))

    local canUse = C_Bank.CanUseBank(bankType)
    local supportsDeposit = C_Bank.DoesBankTypeSupportAutoDeposit(bankType)
    frame.bankStatsButton.canSort = canUse
        and not NS.BankInventory:IsLoading(bankType)
        and (stats.containerCount or 0) > 0
    frame.autoDepositFrame:SetShown(supportsDeposit and canUse)
    if supportsDeposit then
        frame.autoDepositFrame:SetEnabled(canUse)
        RefreshAutoDepositLayout(frame, bankType)
    end
    frame.bankMoneyFrame:SetEnabled(canUse)
    if canUse then
        RefreshMoneyDisplay(frame, bankType)
    end
end

function Footer.HideTransientUI(frame)
    frame.tabSettingsMenu:Hide()
    frame.itemList:SetHighlightedBagID(nil)

    for index = 1, #frame.bankTabButtons do
        frame.bankTabButtons[index].highlight:Hide()
    end

    GameTooltip:Hide()
end

function Footer.Create(frame)
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint(
        "BOTTOMLEFT",
        frame,
        "BOTTOMLEFT",
        FOOTER_LEFT_OFFSET,
        FOOTER_BOTTOM_OFFSET
    )
    footer:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        FOOTER_RIGHT_OFFSET,
        FOOTER_BOTTOM_OFFSET
    )
    footer:SetHeight(FOOTER_HEIGHT)
    frame.footer = footer

    local tabGroup = CreateFrame("Frame", nil, footer)
    tabGroup:SetAllPoints(footer)
    tabGroup:Hide()
    frame.bankTabGroup = tabGroup
    frame.bankTabIconPreloadTextures = {}

    frame.bankTabButtons = {}
    for index = 1, PRECREATED_TAB_BUTTONS do
        frame.bankTabButtons[index] = CreateTabButton(
            frame,
            tabGroup,
            index
        )
    end

    frame.characterPurchaseButton = CreatePurchaseButton(
        frame,
        tabGroup,
        CHARACTER_BANK
    )
    frame.accountPurchaseButton = CreatePurchaseButton(
        frame,
        tabGroup,
        ACCOUNT_BANK
    )

    local statsButton = CreateFrame("Button", nil, tabGroup)
    statsButton:SetSize(STATS_MIN_WIDTH, TAB_BUTTON_SIZE)
    statsButton:RegisterForClicks("LeftButtonUp")
    statsButton.owner = frame
    statsButton:SetScript("OnEnter", ShowStatsTooltip)
    statsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.bankStatsButton = statsButton

    local statsText = statsButton:CreateFontString(nil, "OVERLAY")
    statsText:SetFont(NS.Media.GetPrimaryFont(), TEXT_SIZE)
    statsText:SetTextColor(1, 1, 1)
    statsText:SetJustifyH("LEFT")
    statsText:SetJustifyV("MIDDLE")
    statsText:SetPoint("TOPLEFT", statsButton, "TOPLEFT", 0, TEXT_Y_OFFSET)
    statsText:SetPoint(
        "BOTTOMRIGHT",
        statsButton,
        "BOTTOMRIGHT",
        0,
        TEXT_Y_OFFSET
    )
    frame.bankStatsText = statsText

    local autoSortButton = CreateFrame(
        "Button",
        nil,
        footer,
        "BankAutoSortButtonTemplate"
    )
    autoSortButton:Hide()
    frame.bankAutoSortButton = autoSortButton
    statsButton:SetScript("OnClick", function(self)
        if self.canSort then
            BankAutoSortButtonMixin.OnClick(autoSortButton)
        end
    end)

    local autoDepositFrame = CreateFrame(
        "Frame",
        nil,
        footer,
        "BankPanelAutoDepositFrameTemplate"
    )
    autoDepositFrame:ClearAllPoints()
    autoDepositFrame:SetHeight(FOOTER_HEIGHT)
    frame.autoDepositFrame = autoDepositFrame

    local autoDepositButton = autoDepositFrame.DepositButton
    SkinModernButton(
        autoDepositButton,
        MODERN_BUTTON_STYLES.command
    )
    local warbandDepositIcon = CreateButtonIcon(
        autoDepositButton,
        NS.Media.GetWarbandTransferAtlas(),
        WARBAND_DEPOSIT_ICON_WIDTH,
        WARBAND_DEPOSIT_ICON_HEIGHT
    )
    warbandDepositIcon:Hide()
    autoDepositButton.warbandDepositIcon = warbandDepositIcon
    SetWarbandDepositIconPressed(autoDepositButton, false)
    autoDepositButton:HookScript("OnEnter", function(self)
        RefreshWarbandDepositIcon(self)
        ShowAutoDepositTooltip(self)
    end)
    autoDepositButton:HookScript("OnLeave", function(self)
        SetWarbandDepositIconPressed(self, false)
        RefreshWarbandDepositIcon(self)
        if self.usesWarbandDepositIcon then
            GameTooltip:Hide()
        end
    end)
    autoDepositButton:HookScript("OnMouseDown", function(self, mouseButton)
        if self.usesWarbandDepositIcon and mouseButton == "LeftButton" then
            SetWarbandDepositIconPressed(self, true)
        end
    end)
    autoDepositButton:HookScript("OnMouseUp", function(self)
        if self.usesWarbandDepositIcon then
            SetWarbandDepositIconPressed(self, false)
            RefreshWarbandDepositIcon(self)
        end
    end)
    autoDepositButton:HookScript("OnEnable", RefreshWarbandDepositIcon)
    autoDepositButton:HookScript("OnDisable", RefreshWarbandDepositIcon)

    local includeReagentsCheckbox = autoDepositFrame.IncludeReagentsCheckbox
    SkinModernCheckbox(includeReagentsCheckbox)
    includeReagentsCheckbox:SetScript(
        "OnEnter",
        ShowIncludeReagentsTooltip
    )
    includeReagentsCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local moneyFrame = CreateFrame(
        "Frame",
        nil,
        footer,
        "BankPanelMoneyFrameTemplate"
    )
    moneyFrame:ClearAllPoints()
    moneyFrame:SetPoint(
        "RIGHT",
        footer,
        "RIGHT",
        MONEY_FRAME_RIGHT_OFFSET,
        0
    )
    moneyFrame:SetHeight(FOOTER_HEIGHT)
    moneyFrame.Border:Hide()
    moneyFrame.MoneyDisplay:Hide()
    SkinMoneyActionButton(
        moneyFrame.WithdrawButton,
        NS.Media.GetRemoveAtlas(),
        MONEY_WITHDRAW_TOOLTIP
    )
    SkinMoneyActionButton(
        moneyFrame.DepositButton,
        NS.Media.GetAddAtlas(),
        MONEY_DEPOSIT_TOOLTIP
    )
    moneyFrame.actionButtons = {
        moneyFrame.WithdrawButton,
        moneyFrame.DepositButton,
    }
    frame.bankMoneyFrame = moneyFrame

    local moneyDisplay = CreateFrame("Frame", nil, moneyFrame)
    moneyDisplay:SetPoint("LEFT", moneyFrame, "LEFT", 0, 0)
    moneyDisplay:SetSize(MONEY_DISPLAY_MIN_WIDTH, FOOTER_HEIGHT)
    moneyDisplay:EnableMouse(true)
    moneyDisplay:SetScript("OnEnter", ShowMoneyTooltip)
    moneyDisplay:SetScript("OnLeave", HideMoneyTooltip)
    moneyFrame.customMoneyDisplay = moneyDisplay
    frame.bankMoneyDisplay = moneyDisplay

    local moneyText = moneyDisplay:CreateFontString(nil, "OVERLAY")
    moneyText:SetFont(NS.Media.GetPrimaryFont(), TEXT_SIZE)
    moneyText:SetPoint("TOPLEFT", moneyDisplay, "TOPLEFT", 0, TEXT_Y_OFFSET)
    moneyText:SetPoint(
        "BOTTOMRIGHT",
        moneyDisplay,
        "BOTTOMRIGHT",
        0,
        TEXT_Y_OFFSET
    )
    moneyText:SetJustifyH("RIGHT")
    moneyText:SetJustifyV("MIDDLE")
    moneyFrame.customMoneyText = moneyText
    frame.bankMoneyText = moneyText
    moneyFrame.UpdateMoneyDisplayAnchoring = LayoutMoneyFrame
    LayoutMoneyFrame(moneyFrame)

    local settingsMenu = CreateFrame(
        "Frame",
        nil,
        frame,
        "BankPanelTabSettingsMenuTemplate"
    )
    settingsMenu:ClearAllPoints()
    settingsMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    settingsMenu:SetFrameStrata("DIALOG")
    settingsMenu:Hide()
    AttachOptionalIconBrowser(settingsMenu)
    frame.tabSettingsMenu = settingsMenu

    function frame:OpenTabSettings(tabID)
        local bankType = NS.BankInventory:GetActiveBankType()
        if not bankType
            or not GetTabSettingsAvailability(bankType, tabID) then
            return
        end

        if self.tabSettingsMenu:IsShown()
            and self.tabSettingsMenu:GetSelectedTabID() ~= tabID then
            self.tabSettingsMenu:SetSelectedTab(tabID)
        else
            self.tabSettingsMenu:OnOpenTabSettingsRequested(tabID)
        end
    end
end

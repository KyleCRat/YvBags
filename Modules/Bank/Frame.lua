local _, NS = ...

-- Top-level custom Character and Warband bank frame.
local BankFrameController = {}
NS.BankFrame = BankFrameController

local Controls = NS.MainFrameControls
local Geometry = NS.BankFrameGeometry
local Inventory = NS.BankInventory
local Layout = NS.BankFrameLayout
local ListSettings = NS.ItemListSettings

local CHARACTER_BANK = Enum.BankType.Character
local ACCOUNT_BANK = Enum.BankType.Account
local FRAME_TEMPLATE = "ButtonFrameTemplate"
local FRAME_PORTRAIT = "Interface\\Icons\\INV_Misc_Bag_10_Blue"
local FRAME_STRATA = "HIGH"
local RESIZE_BUTTON_TEMPLATE = "PanelResizeButtonTemplate"
local TYPE_BUTTON_HEIGHT = 28
local TYPE_BUTTON_GAP = 5
local TYPE_BUTTON_TEXT_SIZE = 13
local TYPE_BUTTON_NORMAL_ATLAS = "common-button-tertiary-normal"
local TYPE_BUTTON_HOVER_ATLAS = "common-button-tertiary-hover"
local TYPE_BUTTON_PRESSED_ATLAS = "common-button-tertiary-pressed"
local TYPE_BUTTON_SELECTED_ATLAS = "common-button-tertiary-selected"
local TYPE_BUTTON_SELECTED_OUTSET = 3
local SEARCH_GAP = 6
local SEARCH_RIGHT_OFFSET = -6
local SEARCH_TOP_OFFSET = -28
local EMPTY_ITEMS = {}

local LOCKED_MESSAGES = {
    [Enum.BankLockedReason.BankConversionFailed] =
        BANK_LOCKED_REASON_BANK_CONVERSION_FAILED,
    [Enum.BankLockedReason.BankDisabled] =
        BANK_LOCKED_REASON_BANK_DISABLED,
    [Enum.BankLockedReason.NoAccountInventoryLock] =
        BANK_LOCKED_REASON_NO_ACCOUNT_INVENTORY_LOCK,
}

local function GetBankTypeToken(bankType)
    return bankType == ACCOUNT_BANK and "account" or "character"
end

local function GetBankTypeFromToken(token)
    return token == "account" and ACCOUNT_BANK or CHARACTER_BANK
end

local function ApplyBaseFrameTheme(frame)
    local insetBackground = frame.Inset.Bg
    insetBackground:SetTexture(
        NS.Media.GetInsetBackgroundTexture(),
        "REPEAT",
        "REPEAT"
    )
    insetBackground:SetHorizTile(true)
    insetBackground:SetVertTile(true)
    frame.TopTileStreaks:Hide()
    frame.TopTileStreaks:SetAlpha(0)
end

local function GetEmptyText(bankType)
    local lockedReason = C_Bank.FetchBankLockedReason(bankType)
    if lockedReason then
        return LOCKED_MESSAGES[lockedReason] or "This bank is unavailable."
    end

    if Inventory:IsLoading(bankType) then
        return "Loading bank items..."
    end

    if #Inventory:GetContainers(bankType) == 0
        and C_Bank.FetchNextPurchasableBankTabData(bankType) then
        return "Purchase a bank tab to begin."
    end

    return bankType == ACCOUNT_BANK
        and "No Warband bank items"
        or "No Character bank items"
end

local function ApplyInventoryRefresh(frame, refreshFooter)
    local bankType = Inventory:GetActiveBankType()
    if not bankType then
        return
    end

    local containers = Inventory:GetContainers(bankType)
    local expectedTab = not Inventory:IsLoading(bankType) and containers[1]
    NS.BlizzardBank.SyncNativeBankType(
        bankType,
        expectedTab and expectedTab.id
    )
    frame.itemList:SetEmptyText(GetEmptyText(bankType))
    frame.itemList:SetItems(
        C_Bank.FetchBankLockedReason(bankType) == nil
            and Inventory:GetItems(bankType)
            or EMPTY_ITEMS
    )
    frame.content:Show()
    if refreshFooter ~= false then
        NS.BankFooter.Refresh(frame)
    end
end

local function CancelScheduledInventoryRefresh(frame)
    if frame.inventoryRefreshTimer then
        frame.inventoryRefreshTimer:Cancel()
        frame.inventoryRefreshTimer = nil
    end

    frame.inventoryRefreshPending = false
    frame.inventoryRefreshNeedsFooter = false
end

local function QueueInventoryRefreshAttempt(frame)
    if frame.inventoryRefreshTimer or not frame.inventoryRefreshPending then
        return
    end

    local timer
    timer = C_Timer.NewTimer(0, function()
        if frame.inventoryRefreshTimer ~= timer then
            return
        end

        frame.inventoryRefreshTimer = nil
        if NS.bankFrame ~= frame then
            frame.inventoryRefreshPending = false
            frame.inventoryRefreshNeedsFooter = false
            return
        end

        local bankType = Inventory:GetActiveBankType()
        if not frame.inventoryRefreshPending
            or not frame:IsShown()
            or Inventory:HasLockedItems(bankType) then
            return
        end

        local refreshFooter = frame.inventoryRefreshNeedsFooter
        frame.inventoryRefreshPending = false
        frame.inventoryRefreshNeedsFooter = false
        ApplyInventoryRefresh(frame, refreshFooter)
    end)
    frame.inventoryRefreshTimer = timer
end

local function RequestInventoryRefresh(frame, refreshFooter)
    frame.inventoryRefreshPending = true
    frame.inventoryRefreshNeedsFooter =
        frame.inventoryRefreshNeedsFooter or refreshFooter ~= false
    QueueInventoryRefreshAttempt(frame)
end

local function CreateContent(frame)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint(
        "TOPLEFT",
        frame.Inset,
        "TOPLEFT",
        Layout.ContentInsetLeft,
        Layout.ContentInsetTop
    )
    content:SetPoint(
        "BOTTOMRIGHT",
        frame.Inset,
        "BOTTOMRIGHT",
        Layout.ContentInsetRight,
        Layout.ContentInsetBottom
    )
    frame.content = content
    frame.itemList = NS.ItemList.Create(content, {
        settingsScope = ListSettings.Scopes.Bank,
        itemButtonAdapter = NS.BankItemRowButton,
        inventory = Inventory,
        tooltipFrame = frame,
        emptyText = "No bank items",
        handleItemEnter = function()
            return false
        end,
        cursorDrop = {
            textFormat = "Place %s into this bank",
            isSlotEmpty = function(tabID, slotIndex)
                return Inventory:IsSlotEmpty(tabID, slotIndex)
            end,
            findEmptySlot = function(...)
                return Inventory:FindCursorItemEmptySlot(...)
            end,
            registerUpdateCallback = function(callback)
                Inventory:RegisterUpdateCallback(callback)
            end,
        },
    })
end

local function CreateResizeButton(frame)
    local maxWidth = Geometry.GetMaxWidth()
    frame:SetResizable(true)
    frame:SetResizeBounds(Layout.MinWidth, Layout.MinHeight, maxWidth, nil)

    local resizeButton = CreateFrame(
        "Button",
        nil,
        frame,
        RESIZE_BUTTON_TEMPLATE
    )
    resizeButton:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        Layout.ResizeButtonRightOffset,
        Layout.ResizeButtonBottomOffset
    )
    resizeButton:Init(frame, Layout.MinWidth, Layout.MinHeight, maxWidth, nil)
    resizeButton:SetOnResizeStoppedCallback(function(target)
        Geometry.SnapSize(target)
        Geometry.Save(target)
    end)
    frame.resizeButton = resizeButton
end

local function CreateTypeButtonTexture(button, layer, atlas, outset)
    local texture = button:CreateTexture(nil, layer)
    if outset then
        texture:SetPoint(
            "TOPLEFT",
            button,
            "TOPLEFT",
            -outset,
            outset
        )
        texture:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            outset,
            -outset
        )
    else
        texture:SetAllPoints(button)
    end
    texture:SetAtlas(atlas, false)
    return texture
end

local function RefreshTypeButtonInteraction(button)
    local canActivate = not button.isSelected
    button.hoverTexture:SetShown(
        canActivate
            and button.isHovered == true
            and button.isPressed ~= true
    )
    button.pressedTexture:SetShown(
        canActivate and button.isPressed == true
    )
end

local function RefreshTypeButton(button, activeBankType)
    local selected = button.bankType == activeBankType
    button.isSelected = selected
    button.selectedTexture:SetShown(selected)
    button.normalTexture:SetShown(not selected)
    button.text:SetTextColor(
        selected and 1 or 0.92,
        selected and 0.82 or 0.92,
        selected and 0 or 0.92
    )
    RefreshTypeButtonInteraction(button)
end

local function CreateTypeButton(frame, text, bankType, width)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(width, TYPE_BUTTON_HEIGHT)
    button:RegisterForClicks("LeftButtonUp")
    button.bankType = bankType

    button.normalTexture = CreateTypeButtonTexture(
        button,
        "BACKGROUND",
        TYPE_BUTTON_NORMAL_ATLAS
    )
    button.selectedTexture = CreateTypeButtonTexture(
        button,
        "BACKGROUND",
        TYPE_BUTTON_SELECTED_ATLAS,
        TYPE_BUTTON_SELECTED_OUTSET
    )
    button.hoverTexture = CreateTypeButtonTexture(
        button,
        "BORDER",
        TYPE_BUTTON_HOVER_ATLAS
    )
    button.pressedTexture = CreateTypeButtonTexture(
        button,
        "BORDER",
        TYPE_BUTTON_PRESSED_ATLAS
    )
    button.selectedTexture:Hide()
    button.hoverTexture:Hide()
    button.pressedTexture:Hide()

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER", 0, 1)
    label:SetFont(NS.Media.GetPrimaryFont(), TYPE_BUTTON_TEXT_SIZE, "OUTLINE")
    label:SetText(text)
    button.text = label

    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        RefreshTypeButtonInteraction(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        self.isPressed = false
        RefreshTypeButtonInteraction(self)
    end)
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self.isPressed = true
            RefreshTypeButtonInteraction(self)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        self.isPressed = false
        self.isHovered = self:IsMouseOver()
        RefreshTypeButtonInteraction(self)
    end)
    button:SetScript("OnClick", function(self)
        frame:SetBankType(self.bankType)
    end)
    return button
end

local function RefreshTypeButtons(frame)
    local activeBankType = Inventory:GetActiveBankType()
    local previous = frame.settingsButton
    local buttons = {
        frame.characterBankButton,
        frame.accountBankButton,
    }

    for index = 1, #buttons do
        local button = buttons[index]
        local shown = Inventory:IsBankTypeViewable(button.bankType)
        button:SetShown(shown)
        if shown then
            button:ClearAllPoints()
            button:SetPoint(
                "LEFT",
                previous,
                "RIGHT",
                TYPE_BUTTON_GAP,
                0
            )
            previous = button
            RefreshTypeButton(button, activeBankType)
        end
    end

    frame.searchBox:ClearAllPoints()
    frame.searchBox:SetPoint("TOPLEFT", previous, "TOPRIGHT", SEARCH_GAP, 0)
    frame.searchBox:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        SEARCH_RIGHT_OFFSET,
        SEARCH_TOP_OFFSET
    )
end

local function CreateSubheaderControls(frame)
    local settingsButton = Controls.CreateSettingsButton(frame, {
        tooltip = "Open YvBags bank settings.",
        onClick = function()
            NS.Settings.OpenBank()
        end,
    })

    frame.characterBankButton = CreateTypeButton(
        frame,
        "Character",
        CHARACTER_BANK,
        108
    )
    frame.accountBankButton = CreateTypeButton(
        frame,
        "Warband",
        ACCOUNT_BANK,
        96
    )

    Controls.CreateSearch(frame, {
        settingsButton = settingsButton,
        leftAnchor = frame.accountBankButton,
    })
end

local function RegisterCallbacks(frame)
    Inventory:RegisterUpdateCallback(function(_, reason, bankType, ...)
        if NS.bankFrame ~= frame
            or bankType ~= Inventory:GetActiveBankType() then
            return
        end

        if reason == Inventory.UpdateReasons.Locks then
            local tabID, slotIndex, isLocked = ...
            frame.itemList:RefreshItemLock(tabID, slotIndex, isLocked)
            if frame.inventoryRefreshPending
                and not Inventory:HasLockedItems(bankType) then
                QueueInventoryRefreshAttempt(frame)
            end
        elseif reason == Inventory.UpdateReasons.Loading then
            NS.BlizzardBank.SyncNativeBankType(bankType)
            frame.itemList:SetEmptyText(GetEmptyText(bankType))
            NS.BankFooter.Refresh(frame)
        elseif reason == Inventory.UpdateReasons.Tabs then
            NS.BlizzardBank.SyncNativeBankType(bankType)
            NS.BankFooter.HideTransientUI(frame)
            RefreshTypeButtons(frame)
            NS.BankFooter.Refresh(frame)
        else
            RequestInventoryRefresh(frame, true)
        end
    end)

    NS:RegisterEventHandler("ACCOUNT_MONEY", function()
        if frame:IsShown() then
            NS.BankFooter.Refresh(frame)
        end
    end)
    NS:RegisterEventHandler("PLAYER_MONEY", function()
        if frame:IsShown() then
            NS.BankFooter.Refresh(frame)
        end
    end)
    NS:RegisterEventHandler("BAG_UPDATE_COOLDOWN", function()
        if frame:IsShown() then
            frame.itemList:RefreshVisibleCooldowns()
        end
    end)
end

function BankFrameController.Create()
    if NS.bankFrame then
        return NS.bankFrame
    end

    local frame = CreateFrame(
        "Frame",
        NS.BANK_FRAME_NAME,
        UIParent,
        FRAME_TEMPLATE
    )
    ApplyBaseFrameTheme(frame)
    Geometry.PreventClientSaving(frame)
    frame:SetScale(Geometry.GetSavedScale())
    Geometry.RestoreSize(frame)
    frame:SetFrameStrata(FRAME_STRATA)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    Geometry.ClearClientPosition(frame)
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetTitle("Bank")
    frame:SetPortraitToAsset(FRAME_PORTRAIT)
    frame:SetPortraitTexCoord(0, 1, 0, 1)

    Geometry.RestorePosition(frame)
    Controls.CreateTitle(frame, {
        geometry = Geometry,
        frameLabel = "bank",
    })

    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        Layout.FrameInsetLeft,
        Layout.FrameInsetTop
    )
    frame.Inset:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        Layout.FrameInsetRight,
        Layout.FrameInsetBottom
    )

    frame.TitleContainer:EnableMouse(true)
    frame.TitleContainer:RegisterForDrag("LeftButton")
    frame.TitleContainer:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame.TitleContainer:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        Geometry.Save(frame)
    end)

    CreateContent(frame)
    CreateSubheaderControls(frame)
    NS.BankFooter.Create(frame)
    CreateResizeButton(frame)
    RegisterCallbacks(frame)
    Controls.RegisterSearchShortcut(frame)

    function frame:SetBankType(bankType)
        if bankType == Inventory:GetActiveBankType()
            or not Inventory:IsBankTypeViewable(bankType) then
            return
        end

        NS.BlizzardBank.SyncNativeBankType(bankType)
        Inventory:SetActiveBankType(bankType)
        NS.charDB:Set(
            "bankFrame",
            "lastBankType",
            GetBankTypeToken(bankType)
        )
        NS.BankFooter.HideTransientUI(self)
        self.itemList:InvalidateCursorDropTarget()
        RefreshTypeButtons(self)
        self.content:Hide()
        RequestInventoryRefresh(self, true)
    end

    frame.CloseButton:SetScript("OnClick", function()
        C_Bank.CloseBankFrame()
    end)
    frame:SetScript("OnHide", function(self)
        NS.BankFooter.HideTransientUI(self)
        if Inventory.isOpen then
            C_Bank.CloseBankFrame()
        end
    end)

    NS.bankFrame = frame
    table.insert(UISpecialFrames, frame:GetName())
    return frame
end

function BankFrameController.Open()
    local frame = NS.bankFrame or BankFrameController.Create()
    local preferredBankType = GetBankTypeFromToken(
        NS.charDB:Get("bankFrame", "lastBankType")
    )
    local bankType = Inventory:Open(preferredBankType)
    if not bankType then
        C_Bank.CloseBankFrame()
        return
    end

    NS.BankFooter.PreloadTabIcons(frame)

    NS.charDB:Set(
        "bankFrame",
        "lastBankType",
        GetBankTypeToken(bankType)
    )
    NS.BlizzardBank.SyncNativeBankType(bankType)
    RefreshTypeButtons(frame)
    OpenAllBags(frame)
    frame:Show()
    ApplyInventoryRefresh(frame, true)
end

function BankFrameController.CloseFromBankEvent()
    local frame = NS.bankFrame
    Inventory:Close()
    if frame then
        CancelScheduledInventoryRefresh(frame)
        NS.BankFooter.HideTransientUI(frame)
        frame:Hide()

        -- Release data-provider references and reset pooled native bank
        -- buttons after the bank-close event stack has unwound.
        C_Timer.After(0, function()
            if NS.bankFrame == frame and not Inventory.isOpen then
                frame.itemList:SetEmptyText("No bank items")
                frame.itemList:SetItems(EMPTY_ITEMS)
            end
        end)
    end
    CloseAllBags(frame)
end

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
local FRAME_PORTRAIT =
    "Interface\\Icons\\INV_12_Profession_Tailoring_ReagentBag_Violet"
local TYPE_BUTTON_HEIGHT = 28
local TYPE_BUTTON_TEXT_SIZE = 13
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
    frame.body:Show()
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
    frame.itemList = NS.ItemList.Create(frame.body, {
        window = frame,
        settingsScope = ListSettings.Scopes.Bank,
        onColumnLayoutChanged = function()
            Geometry.RefreshResizeBounds(frame)
        end,
        itemButtonAdapter = NS.BankItemRowButton,
        inventory = Inventory,
        tooltipFrame = frame,
        emptyText = "No bank items",
        handleItemEnter = function()
            return false
        end,
        cursorDrop = {
            textFormat = "Place %s into this bank",
            mergeTextFormat = "Merge %s into a bank stack",
            getMergeItems = function(cursorItemLocation)
                if Inventory:CanAcceptCursorItem(cursorItemLocation) then
                    return Inventory:GetItems()
                end
            end,
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

local function RefreshTypeButton(button, activeBankType)
    button.appearance:SetSelected(button.bankType == activeBankType)
end

local function CreateTypeButton(frame, text, bankType, width)
    local button, appearance = NS.Skins:CreateTab(frame.toolbar, {
        geometryRoot = frame, width = width, height = TYPE_BUTTON_HEIGHT,
        text = text, fontSize = TYPE_BUTTON_TEXT_SIZE, fontFlags = "OUTLINE",
    })
    button.appearance = appearance
    button:SetWidth(math.max(width, math.ceil(button:GetFontString():GetStringWidth()) + 24))
    button.bankType = bankType
    button:SetScript("OnClick", function(self)
        frame:SetBankType(self.bankType)
    end)
    return button
end

local function RefreshTypeButtons(frame)
    local activeBankType = Inventory:GetActiveBankType()
    local buttons = {
        frame.characterBankButton,
        frame.accountBankButton,
    }

    for index = 1, #buttons do
        local button = buttons[index]
        local shown = Inventory:IsBankTypeViewable(button.bankType)
        button:SetShown(shown)
        if shown then
            RefreshTypeButton(button, activeBankType)
        end
    end

    NS.Skins:LayoutToolbar(frame.toolbar)
    Geometry.RefreshResizeBounds(frame)
end

local function CreateToolbarControls(frame)
    Controls.CreateSettingsButton(frame, {
        tooltip = "Open YvBags bank settings.",
        onClick = function()
            NS.Settings.OpenInventory()
        end,
    })
    Controls.CreateScaleButton(frame, {
        geometry = Geometry,
        frameLabel = "bank",
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

    Controls.CreateSearch(frame)
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
        elseif reason == Inventory.UpdateReasons.TooltipData then
            RequestInventoryRefresh(frame, false)
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

    local frame = NS.Skins:CreateWindow(UIParent, {
        name = NS.BANK_FRAME_NAME,
        title = "Bank",
        portrait = FRAME_PORTRAIT,
        insetBackground = NS.Media.GetInsetBackgroundTexture(),
        layouts = NS.WindowLayout.Layouts,
        onLayout = NS.WindowLayout.OnLayout,
        getMinimumWidth = NS.WindowLayout.GetMinimumWidth,
        minWidth = Layout.MinWidth,
        minHeight = Layout.MinHeight,
        maxWidth = Geometry.GetMaxWidth(),
        onMoveStopped = function(target)
            Geometry.Save(target)
        end,
        onResizeStopped = function(target)
            Geometry.SnapSize(target)
            Geometry.Save(target)
        end,
    })
    NS.WindowLayout.CreateToolbar(frame)
    Geometry.PreventClientSaving(frame)
    frame:SetScale(Geometry.GetSavedScale())
    Geometry.RestoreSize(frame)
    Geometry.ClearClientPosition(frame)
    Geometry.RestorePosition(frame)

    CreateContent(frame)
    CreateToolbarControls(frame)
    NS.BankFooter.Create(frame)
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
        self.body:Hide()
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

local _, NS = ...

-- Native bank-frame replacement ownership and bank-session routing.
local BlizzardBank = {}
NS.BlizzardBank = BlizzardBank

local function IsReplacementEnabled()
    return NS.globalDB:Get("features", "replaceBlizzardBank") ~= false
end

local function ApplyNativeFrameOwnership()
    if InCombatLockdown() then
        BlizzardBank.applyAfterCombat = true
        return
    end

    BlizzardBank.applyAfterCombat = nil
    if IsReplacementEnabled() then
        BankFrame:SetParent(BlizzardBank.hiddenParent)
    else
        BankFrame:SetParent(BlizzardBank.originalParent)
    end
end

local function OnPlayerRegenEnabled()
    if BlizzardBank.applyAfterCombat then
        ApplyNativeFrameOwnership()
    end
end

local function OnBankFrameOpened()
    if IsReplacementEnabled() then
        NS.BankFrame.Open()
    end
end

local function HideNativeBankPanel()
    BankPanel:CloseAllBankPopups()
    BankPanel:Hide()
end

local function OnBankFrameClosed()
    if IsReplacementEnabled() then
        HideNativeBankPanel()
        NS.BankFrame.CloseFromBankEvent()
    end
end

local function OnReplacementChanged(_db, enabled)
    if C_Bank.AreAnyBankTypesViewable() then
        C_Bank.CloseBankFrame()
    end

    if enabled == false
        and NS.bankFrame
        and (NS.bankFrame:IsShown() or NS.BankInventory.isOpen) then
        NS.BankFrame.CloseFromBankEvent()
    end

    if enabled == false then
        HideNativeBankPanel()
    end

    C_Timer.After(0, ApplyNativeFrameOwnership)
end

function BlizzardBank.IsReplacementEnabled()
    return IsReplacementEnabled()
end

function BlizzardBank.SyncNativeBankType(bankType, expectedTabID)
    -- Native refundable-item confirmations ask BankFrame for its active type,
    -- which only succeeds while the internal BankPanel is explicitly shown.
    -- Set the type before the first Show so BankPanel's OnShow refresh never
    -- reaches C_Bank with a nil bank type. Its hidden replacement parent still
    -- keeps every native pixel invisible.
    if BankPanel:GetActiveBankType() ~= bankType then
        BankPanel:SetBankType(bankType)
    end

    if not BankPanel:IsShown() then
        BankPanel:Show()
    end

    -- On a cold open BankPanel can already be shown with the requested type
    -- while its purchased-tab cache is still empty. Refresh it once YvBags
    -- has committed a tab that the native configurator must be able to find.
    if expectedTabID and not BankPanel:GetTabData(expectedTabID) then
        BankPanel:Reset()
    end
end

function BlizzardBank.Initialize()
    if BlizzardBank.initialized then
        return
    end

    BlizzardBank.initialized = true
    BlizzardBank.originalParent = BankFrame:GetParent()
    BlizzardBank.hiddenParent = CreateFrame("Frame", nil, UIParent)
    BlizzardBank.hiddenParent:Hide()

    ApplyNativeFrameOwnership()
    NS:RegisterEventHandler("BANKFRAME_OPENED", OnBankFrameOpened)
    NS:RegisterEventHandler("BANKFRAME_CLOSED", OnBankFrameClosed)
    NS:RegisterEventHandler("PLAYER_REGEN_ENABLED", OnPlayerRegenEnabled)
    NS.globalDB:RegisterCallback(
        OnReplacementChanged,
        "features",
        "replaceBlizzardBank"
    )
end

NS:RegisterInitCallback(BlizzardBank.Initialize)

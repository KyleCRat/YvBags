local ADDON_NAME, NS = ...

-- Top-level bag-frame lifecycle and composition contract.
local MainFrame = {}
NS.MainFrame = MainFrame

local Controls = NS.MainFrameControls
local Geometry = NS.MainFrameGeometry
local Layout = NS.MainFrameLayout

local FRAME_NAME = NS.FRAME_NAME
local FRAME_TEMPLATE = "ButtonFrameTemplate"
local FRAME_STRATA = "HIGH"
local FRAME_PORTRAIT = "Interface\\Icons\\INV_Misc_Bag_08"
local RESIZE_BUTTON_TEMPLATE = "PanelResizeButtonTemplate"

local function ApplyBaseFrameTheme(frame)
    if frame.TopTileStreaks then
        frame.TopTileStreaks:Hide()
        frame.TopTileStreaks:SetAlpha(0)
    end
end

local function ApplyInventoryRefresh(frame, refreshFooter)
    frame.itemList:SetItems(NS.Inventory:GetItems())

    if refreshFooter ~= false then
        NS.Footer.Refresh(frame)
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

local function RefreshImmediately(frame, refreshFooter)
    CancelScheduledInventoryRefresh(frame)
    ApplyInventoryRefresh(frame, refreshFooter)
end

local function IsPresentationOnlyUpdate(reason)
    return reason == NS.Inventory.UpdateReasons.Categories
        or reason == NS.Inventory.UpdateReasons.Pins
end

-- Provider replacement trails native input and remains parked through item locks.
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
        if NS.frame ~= frame then
            frame.inventoryRefreshPending = false
            frame.inventoryRefreshNeedsFooter = false
            return
        end

        if not frame.inventoryRefreshPending
            or not frame:IsShown()
            or NS.Inventory:HasLockedItems() then
            return
        end

        local refreshFooter = frame.inventoryRefreshNeedsFooter == true
        frame.inventoryRefreshPending = false
        frame.inventoryRefreshNeedsFooter = false
        ApplyInventoryRefresh(frame, refreshFooter)
    end)
    frame.inventoryRefreshTimer = timer
end

local function RequestInventoryRefresh(frame, reason)
    frame.inventoryRefreshPending = true
    frame.inventoryRefreshNeedsFooter =
        frame.inventoryRefreshNeedsFooter
        or not IsPresentationOnlyUpdate(reason)

    QueueInventoryRefreshAttempt(frame)
end

local function RefreshItemLock(frame, bagID, slotIndex, isLocked)
    -- This synchronous event may update custom art, but must not recycle rows.
    frame.itemList:RefreshItemLock(bagID, slotIndex, isLocked)

    if frame.inventoryRefreshPending and not NS.Inventory:HasLockedItems() then
        QueueInventoryRefreshAttempt(frame)
    end
end

local function CreateContent(frame)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", Layout.ContentInsetLeft, Layout.ContentInsetTop)
    content:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", Layout.ContentInsetRight, Layout.ContentInsetBottom)
    frame.content = content
    frame.itemList = NS.ItemList.Create(content)
end

local function CreateResizeButton(frame)
    local maxWidth = Geometry.GetMaxWidth()
    frame:SetResizable(true)
    frame:SetResizeBounds(Layout.MinWidth, Layout.MinHeight, maxWidth, nil)

    local resizeButton = CreateFrame("Button", nil, frame, RESIZE_BUTTON_TEMPLATE)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Layout.ResizeButtonRightOffset, Layout.ResizeButtonBottomOffset)
    resizeButton:Init(frame, Layout.MinWidth, Layout.MinHeight, maxWidth, nil)
    resizeButton:SetOnResizeStoppedCallback(function(target)
        Geometry.SnapSize(target)
        Geometry.Save(target)
        Geometry.PrintDebug(target, "resize-stop")
    end)
    frame.resizeButton = resizeButton
end

local function RegisterCallbacks(frame)
    NS.Inventory:RegisterUpdateCallback(function(_, reason, bagID, slotIndex, isLocked)
        if NS.frame ~= frame then
            return
        end

        if reason == NS.Inventory.UpdateReasons.Locks then
            RefreshItemLock(frame, bagID, slotIndex, isLocked)
        else
            RequestInventoryRefresh(frame, reason)
        end
    end)

    NS:RegisterEventHandler("PLAYER_MONEY", function()
        if NS.frame then
            NS.Footer.UpdateMoney(NS.frame)
        end
    end)

    NS:RegisterEventHandler("BAG_UPDATE_COOLDOWN", function()
        if NS.frame then
            NS.frame.itemList:RefreshVisibleCooldowns()
        end
    end)

    NS:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", function()
        if NS.frame then
            NS.Footer.UpdateBagButtons(NS.frame)
            NS.Inventory:ScheduleScan("PLAYER_EQUIPMENT_CHANGED")
        end
    end)
end

function MainFrame.Create()
    if NS.frame then
        return NS.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, FRAME_TEMPLATE)
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
    frame:SetTitle(ADDON_NAME)
    frame:SetPortraitToAsset(FRAME_PORTRAIT)
    frame:SetPortraitTexCoord(0, 1, 0, 1)

    Geometry.RestorePosition(frame)
    Controls.CreateTitle(frame)

    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", Layout.FrameInsetLeft, Layout.FrameInsetTop)
    frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Layout.FrameInsetRight, Layout.FrameInsetBottom)

    local dragRegion = frame.TitleContainer
    dragRegion:EnableMouse(true)
    dragRegion:RegisterForDrag("LeftButton")
    dragRegion:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    dragRegion:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        Geometry.Save(frame)
        Geometry.PrintDebug(frame, "move-stop")
    end)

    CreateContent(frame)
    Controls.CreateSearch(frame)
    NS.Footer.Create(frame)
    CreateResizeButton(frame)
    RegisterCallbacks(frame)

    frame:SetScript("OnShow", function(self)
        Geometry.ClearClientPosition(self)
        NS.BlizzardBags.HideBlizzardBags()
        Geometry.PrintDebug(self, "show")

        if not NS.Inventory.initialScanComplete then
            NS.Inventory:ScanNow("frame-show")
        end

        RequestInventoryRefresh(self)
    end)
    Controls.RegisterSearchShortcut(frame)

    NS.frame = frame
    RefreshImmediately(frame)
    Geometry.PrintDebug(frame, "addon-load")
    return frame
end

function MainFrame.Show()
    local frame = NS.frame or MainFrame.Create()
    frame:Show()
end

function MainFrame.Hide()
    if NS.frame then
        NS.frame:Hide()
    end
end

function MainFrame.Toggle()
    local frame = NS.frame or MainFrame.Create()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

local ADDON_NAME, NS = ...

-- Top-level bag-frame lifecycle and composition contract.
local MainFrame = {}
NS.MainFrame = MainFrame

local Controls = NS.MainFrameControls
local Geometry = NS.MainFrameGeometry
local Layout = NS.MainFrameLayout
local ListSettings = NS.ItemListSettings

local FRAME_NAME = NS.FRAME_NAME
local FRAME_PORTRAIT =
    "Interface\\Icons\\INV_Tailoring_Reagent_Bag_Violet_Reagent_Bag"

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
        or reason == NS.Inventory.UpdateReasons.NewItemPlacement
        or reason == NS.Inventory.UpdateReasons.Pins
        or reason == NS.Inventory.UpdateReasons.TooltipData
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
    frame.itemList = NS.ItemList.Create(frame.content, {
        window = frame,
        settingsScope = ListSettings.Scopes.Bags,
        onColumnLayoutChanged = function()
            Geometry.RefreshResizeBounds(frame)
        end,
        itemButtonAdapter = NS.ItemRowButton,
        tooltipFrame = frame,
        emptyText = "No bag items",
        handleItemEnter = function(item)
            return NS.NewItems.MarkSeen(item)
        end,
        cursorDrop = {
            textFormat = "Place %s into your bags",
            mergeTextFormat = "Merge %s into a bag stack",
            getMergeItems = function()
                return NS.Inventory:GetItems(), NS.BagManagement.cursorSourceContainerID
            end,
            isSlotEmpty = function(bagID, slotIndex)
                return NS.BagManagement.IsPlayerContainerSlotEmpty(
                    bagID,
                    slotIndex
                )
            end,
            findEmptySlot = function(
                itemID,
                itemLink,
                sourceContainerID,
                sourceSlotIndex
            )
                return NS.BagManagement.FindCursorItemEmptySlot(
                    itemID,
                    itemLink,
                    sourceContainerID,
                    sourceSlotIndex
                )
            end,
            registerUpdateCallback = function(callback)
                NS.Inventory:RegisterUpdateCallback(callback)
            end,
        },
    })
end

local function RegisterCallbacks(frame)
    NS.Inventory:RegisterUpdateCallback(function(_, reason, bagID, slotIndex, isLocked)
        if NS.frame ~= frame then
            return
        end

        if reason == NS.Inventory.UpdateReasons.Locks then
            RefreshItemLock(frame, bagID, slotIndex, isLocked)
        elseif reason == NS.Inventory.UpdateReasons.NewItemVisuals then
            frame.itemList:RefreshVisibleNewItemStates()
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

    local frame = NS.Skins:CreateWindow(UIParent, {
        name = FRAME_NAME,
        title = ADDON_NAME,
        portrait = FRAME_PORTRAIT,
        insetBackground = NS.Media.GetInsetBackgroundTexture(),
        minWidth = Layout.MinWidth,
        minHeight = Layout.MinHeight,
        maxWidth = Geometry.GetMaxWidth(),
        onMoveStopped = function(target)
            Geometry.Save(target)
            Geometry.PrintDebug(target, "move-stop")
        end,
        onResizeStopped = function(target)
            Geometry.SnapSize(target)
            Geometry.Save(target)
            Geometry.PrintDebug(target, "resize-stop")
        end,
    })
    Geometry.PreventClientSaving(frame)
    frame:SetScale(Geometry.GetSavedScale())
    Geometry.RestoreSize(frame)
    Geometry.ClearClientPosition(frame)
    Geometry.RestorePosition(frame)

    CreateContent(frame)
    Controls.CreateSettingsButton(frame)
    Controls.CreateScaleButton(frame)
    Controls.CreateSearch(frame)
    NS.Footer.Create(frame)
    RegisterCallbacks(frame)

    frame:SetScript("OnShow", function(self)
        Geometry.ClearClientPosition(self)
        NS.BlizzardBags.HideBlizzardBags()
        Geometry.PrintDebug(self, "show")

        if not NS.Inventory.initialScanComplete then
            NS.Inventory:ScanNow("frame-show")
        end

        NS.Inventory:BeginNewItemSession()
        RequestInventoryRefresh(self)
    end)
    frame:SetScript("OnHide", function(self)
        NS.Inventory:EndNewItemSession()
        self.itemList:StopNewItemAnimations()
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

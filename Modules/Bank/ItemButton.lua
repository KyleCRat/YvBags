local _, NS = ...

-- Native Blizzard bank-item bridge for full-row interaction.
local BankItemButton = {}
NS.BankItemRowButton = BankItemButton

local BUTTON_TEMPLATE = "BankItemButtonTemplate"
local FRAME_LEVEL_OFFSET = 10
local GLOBAL_NAME_PREFIX = NS.BANK_ITEM_BUTTON_GLOBAL_NAME_PREFIX

local buttonCount = 0
local buttonRows = setmetatable({}, { __mode = "k" })
local buttonLists = setmetatable({}, { __mode = "k" })

local function ClearNativeRegion(region)
    if not region then
        return
    end

    if region.SetTexture then
        region:SetTexture("")
    end
    if region.SetAlpha then
        region:SetAlpha(0)
    end
    if region.Hide then
        region:Hide()
    end
end

local function SuppressNativeVisuals(button)
    for _, region in pairs(button) do
        if region ~= button:GetParent()
            and type(region) == "table"
            and region.Hide then
            ClearNativeRegion(region)
        end
    end

    ClearNativeRegion(button:GetNormalTexture())
    ClearNativeRegion(button:GetHighlightTexture())
    ClearNativeRegion(button:GetPushedTexture())
    ClearNativeRegion(button:GetDisabledTexture())
    button:SetNormalTexture("")
    button:SetHighlightTexture("")
    button:SetPushedTexture("")
    button:SetDisabledTexture("")
end

local function Configure(button, parent)
    button:ClearAllPoints()
    button:SetAllPoints(parent)
    button:SetFrameLevel(parent:GetFrameLevel() + FRAME_LEVEL_OFFSET)
    button:SetAlpha(1)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    SuppressNativeVisuals(button)
end

local function CreateNativeButton(parent, list)
    buttonCount = buttonCount + 1
    local button = CreateFrame(
        "ItemButton",
        GLOBAL_NAME_PREFIX .. buttonCount,
        parent,
        BUTTON_TEMPLATE
    )
    buttonLists[button] = list
    Configure(button, parent)
    button:Show()
    return button
end

local function UpdateCursor(button)
    if not (SpellIsTargeting and SpellIsTargeting()) then
        if IsModifiedClick("DRESSUP") and button.itemInfo then
            ShowInspectCursor()
        else
            ResetCursor()
        end
    end

    local itemLocation = button:GetItemLocation()
    if itemLocation and itemLocation:IsValid() then
        SetCursorHoveredItem(itemLocation)
    end
end

local function RegisterTooltip(button, row)
    NS.ItemTooltip.RegisterRowButton(button, row, {
        nativeOnEnter = function(target)
            BankPanelItemButtonMixin.OnEnter(target)
        end,
        nativeOnLeave = function(target)
            BankPanelItemButtonMixin.OnLeave(target)
            ClearCursorHoveredItem()
        end,
        updateCursor = UpdateCursor,
    })
end

function BankItemButton.Create(row, list)
    local button = CreateNativeButton(row, list)
    buttonRows[button] = row
    RegisterTooltip(button, row)

    button:HookScript("OnEnter", function(self)
        local buttonRow = buttonRows[self]
        NS.ItemRow.HandleItemEnter(buttonRow)
        buttonRow.highlight:Show()
    end)
    button:HookScript("OnLeave", function(self)
        buttonRows[self].highlight:Hide()
    end)
    button:HookScript("OnMouseUp", function(self, mouseButton, upInside)
        if mouseButton ~= "MiddleButton" or upInside == false then
            return
        end

        local item = buttonRows[self].item
        if item then
            NS.ItemPins.Toggle(item)
        end
    end)
    return button
end

function BankItemButton.CreateEmptySlotTarget(parent, list)
    local button = CreateNativeButton(parent, list)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    return button
end

function BankItemButton.SetEmptySlotTarget(button, tabID, slotIndex)
    local list = buttonLists[button]
    local bankType = list.context.inventory:GetActiveBankType()
    button:Init(bankType, tabID, slotIndex)
    SuppressNativeVisuals(button)
    return true
end

function BankItemButton.Update(button, item)
    button:Init(item.bankType, item.bagID, item.slotIndex)
    SuppressNativeVisuals(button)
end

function BankItemButton.Reset(button)
    NS.ItemTooltip.ResetButton(button)
    button.isInitialized = false
    button.itemInfo = nil
    button.questItemInfo = nil
    SetItemButtonCount(button, 0)
    SuppressNativeVisuals(button)
end

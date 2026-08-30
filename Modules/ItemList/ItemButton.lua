local _, NS = ...

-- Native Blizzard item-button bridge contract for full-row interaction.
local ItemButton = {}
NS.ItemRowButton = ItemButton

local BUTTON_TEMPLATE = "ContainerFrameItemButtonTemplate"
local FRAME_LEVEL_OFFSET = 10
local GLOBAL_NAME_PREFIX = NS.ITEM_BUTTON_GLOBAL_NAME_PREFIX

local buttonCount = 0
local buttonRows = setmetatable({}, { __mode = "k" })
local emptySlotTargets = setmetatable({}, { __mode = "k" })

local function ClearNativeTexture(texture)
    if not texture then
        return
    end

    if texture.SetTexture then
        texture:SetTexture("")
    end
    if texture.SetAlpha then
        texture:SetAlpha(0)
    end
    if texture.ClearAllPoints then
        texture:ClearAllPoints()
    end
    if texture.Hide then
        texture:Hide()
    end
end

local function SuppressNativeVisuals(button)
    for _, region in pairs(button) do
        if region ~= button:GetParent() and type(region) == "table" and region.Hide then
            ClearNativeTexture(region)
        end
    end

    local name = button:GetName()
    ClearNativeTexture(button:GetNormalTexture())
    ClearNativeTexture(button:GetHighlightTexture())
    ClearNativeTexture(button:GetPushedTexture())
    ClearNativeTexture(button:GetDisabledTexture())

    if name then
        ClearNativeTexture(_G[name .. "IconTexture"])
        ClearNativeTexture(_G[name .. "Icon"])
        ClearNativeTexture(_G[name .. "NormalTexture"])
        ClearNativeTexture(_G[name .. "Count"])
    end

    button:SetNormalTexture("")
    button:SetHighlightTexture("")
    button:SetPushedTexture("")
    button:SetDisabledTexture("")

    button.flashAnim:Stop()
    button.newitemglowAnim:Stop()
    button.AugmentBorderAnim:Stop()
end

local function Configure(button, row)
    button:ClearAllPoints()
    button:SetAllPoints(row)
    button:SetFrameLevel(row:GetFrameLevel() + FRAME_LEVEL_OFFSET)
    button:SetAlpha(1)
    button:EnableMouse(true)
    SuppressNativeVisuals(button)
end

local function CreateNativeButton(parent)
    buttonCount = buttonCount + 1
    local button = CreateFrame("ItemButton", GLOBAL_NAME_PREFIX .. buttonCount, parent, BUTTON_TEMPLATE)
    Configure(button, parent)
    button:Show()
    SuppressNativeVisuals(button)
    return button
end

function ItemButton.Create(row)
    local button = CreateNativeButton(row)
    buttonRows[button] = row
    NS.ItemTooltip.RegisterRowButton(button, row)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:HookScript("OnEnter", function(self)
        local buttonRow = buttonRows[self]
        if buttonRow then
            NS.ItemRow.HandleItemEnter(buttonRow)
            buttonRow.highlight:Show()
        end
    end)
    button:HookScript("OnLeave", function(self)
        local buttonRow = buttonRows[self]
        if buttonRow then
            buttonRow.highlight:Hide()
        end
    end)
    button:HookScript("OnMouseUp", function(self, mouseButton, upInside)
        if mouseButton ~= "MiddleButton" or upInside == false then
            return
        end

        local buttonRow = buttonRows[self]
        local item = buttonRow and buttonRow.item
        if item then
            NS.Inventory:ToggleItemPin(item)
        end
    end)
    return button
end

function ItemButton.CreateEmptySlotTarget(parent)
    local button = CreateNativeButton(parent)
    emptySlotTargets[button] = {}
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    SetItemButtonCount(button, 0)
    button:SetHasItem(false)
    button:SetReadable(nil)
    button.Cooldown:Hide()
    return button
end

function ItemButton.SetEmptySlotTarget(button, bagID, slotIndex)
    local target = emptySlotTargets[button]
    if target.bagID == bagID and target.slotIndex == slotIndex then
        return false
    end

    button:SetBagID(bagID)
    button:SetID(slotIndex)
    SetItemButtonCount(button, 0)
    button:SetHasItem(false)
    button:SetReadable(nil)
    button.Cooldown:Hide()
    target.bagID = bagID
    target.slotIndex = slotIndex
    return true
end

function ItemButton.Update(button, item)
    button:SetBagID(item.bagID)
    button:SetID(item.slotIndex)
    SetItemButtonCount(button, item.count)
    button:SetHasItem(true)
    button:SetReadable(item.isReadable)
end

function ItemButton.Reset(button)
    NS.ItemTooltip.ResetButton(button)
    button:SetBagID(0)
    button:SetID(0)
    SetItemButtonCount(button, 0)
    button:SetHasItem(false)
    button:SetReadable(nil)
    button.Cooldown:Hide()
end

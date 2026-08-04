local _, NS = ...

-- Native Blizzard item-button bridge contract for full-row interaction.
local ItemButton = {}
NS.ItemRowButton = ItemButton

local BUTTON_TEMPLATE = "ContainerFrameItemButtonTemplate"
local FRAME_LEVEL_OFFSET = 10
local GLOBAL_NAME_PREFIX = NS.ITEM_BUTTON_GLOBAL_NAME_PREFIX

local buttonCount = 0

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
        if region ~= button.row and region ~= button:GetParent() and type(region) == "table" and region.Hide then
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

function ItemButton.Create(row)
    buttonCount = buttonCount + 1
    local button = CreateFrame("ItemButton", GLOBAL_NAME_PREFIX .. buttonCount, row, BUTTON_TEMPLATE)
    button.row = row
    NS.ItemTooltip.RegisterRowButton(button)
    Configure(button, row)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:Show()
    SuppressNativeVisuals(button)
    button:HookScript("OnEnter", function(self)
        self.row.highlight:Show()
    end)
    button:HookScript("OnLeave", function(self)
        self.row.highlight:Hide()
    end)
    button:HookScript("OnMouseUp", function(self, mouseButton, upInside)
        if mouseButton ~= "MiddleButton" or upInside == false then
            return
        end

        local item = self.row and self.row.item
        if item then
            NS.Inventory:ToggleItemPin(item)
        end
    end)
    return button
end

function ItemButton.Update(button, item)
    button:SetBagID(item.bagID)
    button:SetID(item.slotIndex)
    button.bag = item.bagID
    button.slot = item.slotIndex
    button.count = item.count
    button:SetHasItem(true)
    button:SetReadable(item.isReadable)
end

function ItemButton.Reset(button)
    NS.ItemTooltip.ResetButton(button)
    button:SetBagID(0)
    button:SetID(0)
    button.bag = nil
    button.slot = nil
    button.count = nil
    button.tooltipShown = false
    button:SetHasItem(false)
    button:SetReadable(nil)
    button.Cooldown:Hide()
end

local _, NS = ...

-- Footer layout, bag controls, inventory totals, money, and tooltips.
local Footer = {}
NS.Footer = Footer

-- Layout
local FOOTER_LEFT_OFFSET = 3
local FOOTER_RIGHT_OFFSET = -15
local FOOTER_BOTTOM_OFFSET = 4
local FOOTER_HEIGHT = 28

-- Text
local FOOTER_TEXT_SIZE = 18
local FOOTER_TEXT_COLOR_R = 1
local FOOTER_TEXT_COLOR_G = 1
local FOOTER_TEXT_COLOR_B = 1
local FOOTER_TEXT_Y_OFFSET = -1
local FOOTER_FONT_LAYER = "OVERLAY"

-- Left footer group
local FOOTER_STATS_Y_OFFSET = 0
local FOOTER_BAG_BUTTONS_X_OFFSET = 2
local FOOTER_STATS_TO_BAG_BUTTON_PADDING = 8
local FOOTER_STATS_HOVER_MIN_WIDTH = 64
local FOOTER_STATS_HOVER_PADDING = 8

-- Inventory stats
local FOOTER_FREE_SPACE_LOW_RATIO = 0.05
local FOOTER_FREE_SPACE_LOW_COLOR_R = 1
local FOOTER_FREE_SPACE_LOW_COLOR_G = 0.82
local FOOTER_FREE_SPACE_LOW_COLOR_B = 0.15
local FOOTER_FREE_SPACE_ZERO_COLOR_R = 1
local FOOTER_FREE_SPACE_ZERO_COLOR_G = 0.2
local FOOTER_FREE_SPACE_ZERO_COLOR_B = 0.15

-- Money
local FOOTER_MONEY_X_OFFSET = 2
local FOOTER_MONEY_Y_OFFSET = 0
local FOOTER_MONEY_HOVER_MIN_WIDTH = 50
local FOOTER_MONEY_HOVER_PADDING = 8

-- Bag buttons
local FOOTER_BAG_BUTTON_SIZE = 24
local FOOTER_BAG_BUTTON_ICON_SIZE = 18
local FOOTER_BAG_BUTTON_BORDER_SIZE = 24
local FOOTER_BAG_BUTTON_GAP = 4
local FOOTER_BAG_BUTTON_EMPTY_ALPHA = 0.35
local FOOTER_BAG_BUTTON_FILLED_ALPHA = 1
local FOOTER_BAG_BUTTON_HIGHLIGHT_ALPHA = 0.18
local FOOTER_BAG_BUTTON_BORDER_ALPHA = 0.95
local FOOTER_BAG_BUTTON_EMPTY_BORDER_ALPHA = 0.45
local FOOTER_BAG_BUTTON_REAGENT_BORDER_R = 0.15
local FOOTER_BAG_BUTTON_REAGENT_BORDER_G = 0.88
local FOOTER_BAG_BUTTON_REAGENT_BORDER_B = 1
local FOOTER_BAG_BUTTON_BORDER_R = 0.86
local FOOTER_BAG_BUTTON_BORDER_G = 0.86
local FOOTER_BAG_BUTTON_BORDER_B = 0.86
local FOOTER_BAG_BUTTON_EMPTY_BORDER_R = 0.45
local FOOTER_BAG_BUTTON_EMPTY_BORDER_G = 0.45
local FOOTER_BAG_BUTTON_EMPTY_BORDER_B = 0.45

-- Frame construction
local FRAME_TYPE = "Frame"
local BUTTON_TYPE = "Button"
local TEXTURE_LAYER_BACKGROUND = "BACKGROUND"
local TEXTURE_LAYER_ARTWORK = "ARTWORK"
local TEXTURE_LAYER_OVERLAY = "OVERLAY"

local function GetPrimaryFont()
    return NS.Media.GetPrimaryFont()
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

-- Money display
function Footer.UpdateMoney(frame)
    if not frame.moneyText then
        return
    end

    local copper = GetMoney and GetMoney() or 0
    local display = NS.Money.GetDisplay(copper, true)
    local color = display.color

    frame.moneyText:SetText(display.text)
    if frame.moneyHoverFrame then
        frame.moneyHoverFrame.copper = copper
        frame.moneyHoverFrame:SetWidth(math.max(FOOTER_MONEY_HOVER_MIN_WIDTH, frame.moneyText:GetStringWidth() + FOOTER_MONEY_HOVER_PADDING))
    end

    if color then
        frame.moneyText:SetTextColor(color.r, color.g, color.b)
    else
        frame.moneyText:SetTextColor(FOOTER_TEXT_COLOR_R, FOOTER_TEXT_COLOR_G, FOOTER_TEXT_COLOR_B)
    end

    NS.FooterCurrencies.Refresh(frame)
end

local function GetMoneyTooltipAnchor(frame)
    local center = frame:GetCenter()
    local screenCenter = UIParent and UIParent:GetWidth() and UIParent:GetWidth() / 2

    if center and screenCenter and center > screenCenter then
        return "ANCHOR_LEFT"
    end

    return "ANCHOR_RIGHT"
end

local function ShowMoneyTooltip(frame)
    local copper = frame.copper or (GetMoney and GetMoney() or 0)

    if GameTooltip_ClearMoney then
        GameTooltip_ClearMoney(GameTooltip)
    end

    GameTooltip:SetOwner(frame, GetMoneyTooltipAnchor(frame))
    GameTooltip:ClearLines()

    GameTooltip:AddLine(NS.Money.FormatExact(copper, true), 1, 1, 1)

    GameTooltip:Show()
end

local function HideMoneyTooltip()
    if GameTooltip_ClearMoney then
        GameTooltip_ClearMoney(GameTooltip)
    end

    GameTooltip:Hide()
end

-- Inventory stats display
local function GetInventoryStatsTextColor(stats)
    local freeSlots = stats and stats.freeSlots or 0
    local totalSlots = stats and stats.totalSlots or 0

    if freeSlots <= 0 then
        return FOOTER_FREE_SPACE_ZERO_COLOR_R, FOOTER_FREE_SPACE_ZERO_COLOR_G, FOOTER_FREE_SPACE_ZERO_COLOR_B
    elseif totalSlots > 0 and freeSlots <= totalSlots * FOOTER_FREE_SPACE_LOW_RATIO then
        return FOOTER_FREE_SPACE_LOW_COLOR_R, FOOTER_FREE_SPACE_LOW_COLOR_G, FOOTER_FREE_SPACE_LOW_COLOR_B
    end

    return FOOTER_TEXT_COLOR_R, FOOTER_TEXT_COLOR_G, FOOTER_TEXT_COLOR_B
end

local function ShowInventoryStatsTooltip(frame)
    if not NS.Inventory then
        return
    end

    local stats = NS.Inventory:GetStats()
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine("Used / Total", ("%d / %d"):format(stats.usedSlots or 0, stats.totalSlots or 0), 1, 1, 1, 1, 1, 1)
    AddTooltipDivider(GameTooltip)

    for _, container in ipairs(NS.Inventory:GetContainers()) do
        local name = container.name or ("Bag %d"):format(container.id or 0)
        GameTooltip:AddDoubleLine(name, ("%d / %d"):format(container.usedSlots or 0, container.numSlots or 0), 0.86, 0.86, 0.86, 1, 1, 1)
    end

    AddTooltipDivider(GameTooltip)
    AddTooltipActionLine(GameTooltip, "Left-click to sort bags")
    GameTooltip:Show()
end

local function HideInventoryStatsTooltip()
    GameTooltip:Hide()
end

local function SortBagsFromStatsDisplay()
    NS.BagManagement.CleanupBags()
end

local function UpdateInventoryStats(frame)
    if not frame.statsText then
        return
    end

    local stats = NS.Inventory:GetStats()
    frame.statsText:SetText(("%d/%d"):format(
        stats.usedSlots or 0,
        stats.totalSlots or 0
    ))

    frame.statsText:SetTextColor(GetInventoryStatsTextColor(stats))

    frame.statsHoverFrame:SetWidth(math.max(FOOTER_STATS_HOVER_MIN_WIDTH, frame.statsText:GetStringWidth() + FOOTER_STATS_HOVER_PADDING))
end

-- Bag button tooltips
local function GetBagUsageCounts(button)
    if button.containerID then
        local container = NS.Inventory:GetContainer(button.containerID)
        if container then
            return container.usedSlots or 0, container.numSlots or button.numSlots or 0
        end
    end

    local totalSlots = button.numSlots or 0
    if button.containerID then
        if C_Container and C_Container.GetContainerNumSlots then
            totalSlots = C_Container.GetContainerNumSlots(button.containerID) or totalSlots
        elseif GetContainerNumSlots then
            totalSlots = GetContainerNumSlots(button.containerID) or totalSlots
        end
    end

    local freeSlots = 0
    if button.containerID then
        if C_Container and C_Container.GetContainerNumFreeSlots then
            freeSlots = C_Container.GetContainerNumFreeSlots(button.containerID) or 0
        elseif GetContainerNumFreeSlots then
            freeSlots = GetContainerNumFreeSlots(button.containerID) or 0
        end
    end

    return math.max(totalSlots - freeSlots, 0), totalSlots
end

local function AddBagUsageTooltipLine(button)
    if not button.containerID then
        return false
    end

    local usedSlots, totalSlots = GetBagUsageCounts(button)
    if totalSlots <= 0 then
        return false
    end

    GameTooltip:AddDoubleLine(
        "Used / Total",
        ("%d / %d"):format(usedSlots, totalSlots),
        0.86, 0.86, 0.86,
        1, 1, 1
    )
    return true
end

local function ShowBagButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local hasInventoryItem
    if button.inventoryID and GetInventoryItemLink("player", button.inventoryID) then
        hasInventoryItem = GameTooltip:SetInventoryItem("player", button.inventoryID)
    end

    if not hasInventoryItem then
        local title
        if button.isBackpack then
            title = BACKPACK_TOOLTIP or "Backpack"
        else
            title = button.isReagentBag and (EQUIP_CONTAINER_REAGENT or "Equip Reagent Bag") or (EQUIP_CONTAINER or "Equip Bag")
        end

        GameTooltip:SetText(title, 1, 1, 1)
    end

    AddTooltipDivider(GameTooltip)
    if AddBagUsageTooltipLine(button) then
        AddTooltipDivider(GameTooltip)
    end
    if button.isBackpack then
        AddTooltipActionLine(GameTooltip, "Left-click to show Blizzard bags")
    else
        AddTooltipActionLine(GameTooltip, "Left-click or drag to pick up this bag")
    end
    AddTooltipActionLine(GameTooltip, "Right-click to empty this bag")
    if not button.isBackpack and not button.isEquipped then
        AddTooltipActionLine(GameTooltip, "Drop a bag here to equip it")
    end
    GameTooltip:Show()
end

local function HideBagButtonTooltip()
    GameTooltip:Hide()
end

-- Bag button interactions
local function OnBagButtonEnter(button)
    if button.highlight then
        button.highlight:Show()
    end

    NS.frame.itemList:SetHighlightedBagID(button.containerID)

    ShowBagButtonTooltip(button)
end

local function OnBagButtonLeave(button)
    if button.highlight then
        button.highlight:Hide()
    end

    if NS.frame.itemList.highlightedBagID == button.containerID then
        NS.frame.itemList:SetHighlightedBagID(nil)
    end

    HideBagButtonTooltip()
end

local function OnBagButtonClick(button, mouseButton)
    if mouseButton == "RightButton" then
        NS.BagManagement.EmptyBag(button.containerID)
    elseif button.isBackpack then
        NS.BlizzardBags.ShowBlizzardBags()
    else
        NS.BagManagement.HandleBagButtonClick(button.containerID)
    end
end

local function OnBagButtonDragStart(button)
    if not button.isBackpack then
        NS.BagManagement.PickupBag(button.containerID)
    end
end

local function OnBagButtonReceiveDrag(button)
    if not button.isBackpack then
        NS.BagManagement.PutCursorInBagSlot(button.containerID)
    end
end

-- Bag button rendering
local function UpdateBagButton(button, slot)
    button.containerID = slot.containerID
    button.inventoryID = slot.inventoryID
    button.isBackpack = slot.isBackpack
    button.isEquipped = slot.isEquipped
    button.isReagentBag = slot.isReagentBag
    button.numSlots = slot.numSlots

    button.icon:SetTexture(slot.icon)
    button.icon:SetDesaturated(not slot.isEquipped)
    button.icon:SetAlpha(slot.isEquipped and FOOTER_BAG_BUTTON_FILLED_ALPHA or FOOTER_BAG_BUTTON_EMPTY_ALPHA)

    if slot.isReagentBag and slot.isEquipped then
        button.border:SetVertexColor(FOOTER_BAG_BUTTON_REAGENT_BORDER_R, FOOTER_BAG_BUTTON_REAGENT_BORDER_G, FOOTER_BAG_BUTTON_REAGENT_BORDER_B, FOOTER_BAG_BUTTON_BORDER_ALPHA)
    elseif slot.isEquipped then
        button.border:SetVertexColor(FOOTER_BAG_BUTTON_BORDER_R, FOOTER_BAG_BUTTON_BORDER_G, FOOTER_BAG_BUTTON_BORDER_B, FOOTER_BAG_BUTTON_BORDER_ALPHA)
    else
        button.border:SetVertexColor(FOOTER_BAG_BUTTON_EMPTY_BORDER_R, FOOTER_BAG_BUTTON_EMPTY_BORDER_G, FOOTER_BAG_BUTTON_EMPTY_BORDER_B, FOOTER_BAG_BUTTON_EMPTY_BORDER_ALPHA)
    end

    button:Show()
end

function Footer.UpdateBagButtons(frame)
    if not frame.bagButtons then
        return
    end

    local slots = NS.BagManagement.GetBagSlots()
    for index, button in ipairs(frame.bagButtons) do
        local slot = slots[index]
        if slot then
            UpdateBagButton(button, slot)
        else
            button:Hide()
        end
    end
end

local function CreateBagButton(parent, index)
    local button = CreateFrame(BUTTON_TYPE, nil, parent)
    button:SetSize(FOOTER_BAG_BUTTON_SIZE, FOOTER_BAG_BUTTON_SIZE)
    button:SetPoint("LEFT", parent, "LEFT", FOOTER_BAG_BUTTONS_X_OFFSET + ((index - 1) * (FOOTER_BAG_BUTTON_SIZE + FOOTER_BAG_BUTTON_GAP)), 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.highlight = button:CreateTexture(nil, TEXTURE_LAYER_BACKGROUND)
    button.highlight:SetAllPoints(button)
    button.highlight:SetColorTexture(FOOTER_BAG_BUTTON_REAGENT_BORDER_R, FOOTER_BAG_BUTTON_REAGENT_BORDER_G, FOOTER_BAG_BUTTON_REAGENT_BORDER_B, FOOTER_BAG_BUTTON_HIGHLIGHT_ALPHA)
    button.highlight:Hide()

    button.icon = button:CreateTexture(nil, TEXTURE_LAYER_ARTWORK)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetSize(FOOTER_BAG_BUTTON_ICON_SIZE, FOOTER_BAG_BUTTON_ICON_SIZE)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.border = button:CreateTexture(nil, TEXTURE_LAYER_OVERLAY)
    button.border:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.border:SetSize(FOOTER_BAG_BUTTON_BORDER_SIZE, FOOTER_BAG_BUTTON_BORDER_SIZE)
    button.border:SetTexture(NS.Media.GetIconBorderTexture())

    button:SetScript("OnClick", OnBagButtonClick)
    button:SetScript("OnDragStart", OnBagButtonDragStart)
    button:SetScript("OnReceiveDrag", OnBagButtonReceiveDrag)
    button:SetScript("OnEnter", OnBagButtonEnter)
    button:SetScript("OnLeave", OnBagButtonLeave)
    return button
end

local function GetBagButtonGroupWidth(buttonCount)
    if buttonCount <= 0 then
        return 0
    end

    return FOOTER_BAG_BUTTONS_X_OFFSET + (buttonCount * FOOTER_BAG_BUTTON_SIZE) + ((buttonCount - 1) * FOOTER_BAG_BUTTON_GAP)
end

local function CreateBagButtons(frame, footer)
    frame.bagButtons = {}

    local maxButtons = 1 + (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0)
    for index = 1, maxButtons do
        frame.bagButtons[index] = CreateBagButton(footer, index)
    end

    function frame:UpdateBagButtons()
        Footer.UpdateBagButtons(self)
    end

    return GetBagButtonGroupWidth(maxButtons)
end

-- Footer lifecycle
function Footer.Refresh(frame)
    UpdateInventoryStats(frame)
    Footer.UpdateBagButtons(frame)
    Footer.UpdateMoney(frame)
end

function Footer.Create(frame)
    local footer = CreateFrame(FRAME_TYPE, nil, frame)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FOOTER_LEFT_OFFSET, FOOTER_BOTTOM_OFFSET)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FOOTER_RIGHT_OFFSET, FOOTER_BOTTOM_OFFSET)
    footer:SetHeight(FOOTER_HEIGHT)
    frame.footer = footer

    local bagButtonGroupWidth = CreateBagButtons(frame, footer)

    local statsHoverFrame = CreateFrame(BUTTON_TYPE, nil, footer)
    statsHoverFrame:SetPoint("LEFT", footer, "LEFT", bagButtonGroupWidth + FOOTER_STATS_TO_BAG_BUTTON_PADDING, FOOTER_STATS_Y_OFFSET)
    statsHoverFrame:SetSize(FOOTER_STATS_HOVER_MIN_WIDTH, FOOTER_HEIGHT)
    statsHoverFrame:RegisterForClicks("LeftButtonUp")
    statsHoverFrame:SetScript("OnEnter", ShowInventoryStatsTooltip)
    statsHoverFrame:SetScript("OnLeave", HideInventoryStatsTooltip)
    statsHoverFrame:SetScript("OnClick", SortBagsFromStatsDisplay)
    frame.statsHoverFrame = statsHoverFrame

    local statsText = statsHoverFrame:CreateFontString(nil, FOOTER_FONT_LAYER)
    statsText:SetFont(GetPrimaryFont(), FOOTER_TEXT_SIZE)
    statsText:SetTextColor(FOOTER_TEXT_COLOR_R, FOOTER_TEXT_COLOR_G, FOOTER_TEXT_COLOR_B)
    statsText:SetPoint("TOPLEFT", statsHoverFrame, "TOPLEFT", 0, FOOTER_TEXT_Y_OFFSET)
    statsText:SetPoint("BOTTOMRIGHT", statsHoverFrame, "BOTTOMRIGHT", 0, FOOTER_TEXT_Y_OFFSET)
    statsText:SetJustifyH("LEFT")
    statsText:SetJustifyV("MIDDLE")
    statsText:SetText("")
    frame.statsText = statsText

    local moneyHoverFrame = CreateFrame(FRAME_TYPE, nil, footer)
    moneyHoverFrame:SetPoint("RIGHT", footer, "RIGHT", FOOTER_MONEY_X_OFFSET, FOOTER_MONEY_Y_OFFSET)
    moneyHoverFrame:SetSize(FOOTER_MONEY_HOVER_MIN_WIDTH, FOOTER_HEIGHT)
    moneyHoverFrame:EnableMouse(true)
    moneyHoverFrame:SetScript("OnEnter", ShowMoneyTooltip)
    moneyHoverFrame:SetScript("OnLeave", HideMoneyTooltip)
    frame.moneyHoverFrame = moneyHoverFrame

    local moneyText = moneyHoverFrame:CreateFontString(nil, FOOTER_FONT_LAYER)
    moneyText:SetFont(GetPrimaryFont(), FOOTER_TEXT_SIZE)
    moneyText:SetTextColor(FOOTER_TEXT_COLOR_R, FOOTER_TEXT_COLOR_G, FOOTER_TEXT_COLOR_B)
    moneyText:SetPoint("TOPLEFT", moneyHoverFrame, "TOPLEFT", 0, FOOTER_TEXT_Y_OFFSET)
    moneyText:SetPoint("BOTTOMRIGHT", moneyHoverFrame, "BOTTOMRIGHT", 0, FOOTER_TEXT_Y_OFFSET)
    moneyText:SetJustifyH("RIGHT")
    moneyText:SetJustifyV("MIDDLE")
    moneyText:SetText("")
    frame.moneyText = moneyText

    NS.FooterCurrencies.Create(frame, footer, statsHoverFrame, moneyHoverFrame)
end

local ADDON_NAME, NS = ...

local FRAME_NAME = "YvBagsFrame"
local MIN_FRAME_WIDTH = 420
local MIN_FRAME_HEIGHT = 360
local MAIN_FRAME_TEMPLATE = "ButtonFrameTemplate"
local MAIN_FRAME_STRATA = "HIGH"
local MAIN_FRAME_PORTRAIT = "Interface\\Icons\\INV_Misc_Bag_08"

local CONTENT_INSET_LEFT = 3
local CONTENT_INSET_RIGHT = -3
local CONTENT_INSET_TOP = -3
local CONTENT_INSET_BOTTOM = 3

local FRAME_INSET_LEFT = 4
local FRAME_INSET_RIGHT = -6
local FRAME_INSET_TOP = -60
local FRAME_INSET_BOTTOM = 34
local FOOTER_LEFT_OFFSET = 14
local FOOTER_RIGHT_OFFSET = -34
local FOOTER_BOTTOM_OFFSET = 6
local FOOTER_HEIGHT = 24
local FOOTER_TEXT_SIZE = 18
local FOOTER_TEXT_COLOR_R = 1
local FOOTER_TEXT_COLOR_G = 1
local FOOTER_TEXT_COLOR_B = 1
local FOOTER_FONT_LAYER = "OVERLAY"
local FOOTER_STATS_X_OFFSET = 0
local FOOTER_STATS_Y_OFFSET = 0
local FOOTER_STATS_HOVER_MIN_WIDTH = 64
local FOOTER_STATS_HOVER_PADDING = 8
local FOOTER_MONEY_X_OFFSET = 0
local FOOTER_MONEY_Y_OFFSET = 0
local FOOTER_MONEY_HOVER_MIN_WIDTH = 96
local FOOTER_MONEY_HOVER_PADDING = 8
local FOOTER_FREE_SPACE_LOW_RATIO = 0.05
local FOOTER_FREE_SPACE_LOW_COLOR_R = 1
local FOOTER_FREE_SPACE_LOW_COLOR_G = 0.82
local FOOTER_FREE_SPACE_LOW_COLOR_B = 0.15
local FOOTER_FREE_SPACE_ZERO_COLOR_R = 1
local FOOTER_FREE_SPACE_ZERO_COLOR_G = 0.2
local FOOTER_FREE_SPACE_ZERO_COLOR_B = 0.15
local FOOTER_BAG_BUTTONS_X_OFFSET = 86
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
local SEARCH_BOX_LEFT_OFFSET = 86
local SEARCH_BOX_RIGHT_OFFSET = -6
local SEARCH_BOX_TOP_OFFSET = -28
local SEARCH_BOX_FRAME_LEVEL_OFFSET = 8
local RESIZE_BUTTON_TEMPLATE = "PanelResizeButtonTemplate"
local RESIZE_BUTTON_RIGHT_OFFSET = -6
local RESIZE_BUTTON_BOTTOM_OFFSET = 6
local PORTRAIT_TEX_COORD_LEFT = 0
local PORTRAIT_TEX_COORD_RIGHT = 1
local PORTRAIT_TEX_COORD_TOP = 0
local PORTRAIT_TEX_COORD_BOTTOM = 1
local FRAME_TYPE = "Frame"
local BUTTON_TYPE = "Button"
local TEXTURE_LAYER_BACKGROUND = "BACKGROUND"
local TEXTURE_LAYER_ARTWORK = "ARTWORK"
local TEXTURE_LAYER_OVERLAY = "OVERLAY"
local DEFAULT_FRAME_POINT = "CENTER"
local DEFAULT_FRAME_RELATIVE_POINT = "CENTER"
local DEBUG_FRAME_POSITION = true

-- Base WoW frame theme
local function ApplyBaseFrameTheme(frame)
    if frame.TopTileStreaks then
        frame.TopTileStreaks:Hide()
        frame.TopTileStreaks:SetAlpha(0)
    end
end

-- Persistence helpers
local function PreventClientPositionSaving(frame)
    if frame.SetDontSavePosition then
        frame:SetDontSavePosition(true)
    end
end

local function ClearClientPosition(frame)
    if frame.SetUserPlaced then
        frame:SetUserPlaced(false)
    end
end

local function GetNearestPixelSize(frame, size)
    if PixelUtil and PixelUtil.GetNearestPixelSize and frame.GetEffectiveScale then
        return PixelUtil.GetNearestPixelSize(size, frame:GetEffectiveScale())
    end

    return math.floor(size + 0.5)
end

local function SetPixelPerfectFrameSize(frame, width, height)
    frame:SetSize(GetNearestPixelSize(frame, width), GetNearestPixelSize(frame, height))
end

local function SnapFrameSize(frame)
    SetPixelPerfectFrameSize(frame, frame:GetWidth(), frame:GetHeight())
end

local function FormatDebugNumber(value)
    if type(value) == "number" then
        return ("%.3f"):format(value)
    end

    return tostring(value)
end

local function GetDebugRegionName(region)
    if not region then
        return "nil"
    end

    if region.GetName then
        return region:GetName() or tostring(region)
    end

    return tostring(region)
end

local function PrintFramePositionDebug(frame, reason)
    if not DEBUG_FRAME_POSITION or not NS.charDB or not NS.Print then
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    NS:Print(("Frame position [%s] frame point=%s relativeTo=%s relativePoint=%s x=%s y=%s width=%s height=%s left=%s top=%s right=%s bottom=%s scale=%s effectiveScale=%s"):format(
        tostring(reason),
        tostring(point),
        GetDebugRegionName(relativeTo),
        tostring(relativePoint),
        FormatDebugNumber(x),
        FormatDebugNumber(y),
        FormatDebugNumber(frame:GetWidth()),
        FormatDebugNumber(frame:GetHeight()),
        FormatDebugNumber(frame:GetLeft()),
        FormatDebugNumber(frame:GetTop()),
        FormatDebugNumber(frame:GetRight()),
        FormatDebugNumber(frame:GetBottom()),
        FormatDebugNumber(frame:GetScale()),
        FormatDebugNumber(frame:GetEffectiveScale())
    ))
    NS:Print(("Frame DB [%s] point=%s relativePoint=%s x=%s y=%s width=%s height=%s scale=%s"):format(
        tostring(reason),
        tostring(NS.charDB:Get("frame", "point")),
        tostring(NS.charDB:Get("frame", "relativePoint")),
        FormatDebugNumber(NS.charDB:Get("frame", "x")),
        FormatDebugNumber(NS.charDB:Get("frame", "y")),
        FormatDebugNumber(NS.charDB:Get("frame", "width")),
        FormatDebugNumber(NS.charDB:Get("frame", "height")),
        FormatDebugNumber(NS.charDB:Get("frame", "scale"))
    ))
end

local function SaveFrameGeometry(frame)
    if not NS.charDB then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    point = point or DEFAULT_FRAME_POINT
    relativePoint = relativePoint or DEFAULT_FRAME_RELATIVE_POINT

    NS.charDB:Set("frame", "point", point)
    NS.charDB:Set("frame", "relativePoint", relativePoint)
    NS.charDB:Set("frame", "x", x or 0)
    NS.charDB:Set("frame", "y", y or 0)
    NS.charDB:Set("frame", "width", frame:GetWidth())
    NS.charDB:Set("frame", "height", frame:GetHeight())
    PreventClientPositionSaving(frame)
    ClearClientPosition(frame)
end

local function RestoreFramePosition(frame)
    frame:ClearAllPoints()
    frame:SetPoint(
        NS.charDB:Get("frame", "point") or DEFAULT_FRAME_POINT,
        UIParent,
        NS.charDB:Get("frame", "relativePoint") or DEFAULT_FRAME_RELATIVE_POINT,
        NS.charDB:Get("frame", "x") or 0,
        NS.charDB:Get("frame", "y") or 0
    )
end

local function GetFrameHorizontalChromeWidth()
    return (FRAME_INSET_LEFT - FRAME_INSET_RIGHT) + (CONTENT_INSET_LEFT - CONTENT_INSET_RIGHT)
end

local function GetMaxFrameWidth()
    local listWidth = NS.ItemList and NS.ItemList.GetPreferredWidth and NS.ItemList.GetPreferredWidth() or MIN_FRAME_WIDTH
    return math.max(MIN_FRAME_WIDTH, listWidth + GetFrameHorizontalChromeWidth())
end

local function RestoreFrameSize(frame)
    local maxWidth = GetMaxFrameWidth()
    local savedWidth = NS.charDB:Get("frame", "width")
    local width = math.min(math.max(savedWidth or maxWidth, MIN_FRAME_WIDTH), maxWidth)
    local height = math.max(NS.charDB:Get("frame", "height") or MIN_FRAME_HEIGHT, MIN_FRAME_HEIGHT)
    SetPixelPerfectFrameSize(frame, width, height)
end

-- Footer rendering
local function GetPrimaryFont()
    return NS.Media and NS.Media.GetPrimaryFont and NS.Media.GetPrimaryFont() or STANDARD_TEXT_FONT
end

local function UpdateMoney(frame)
    if frame.moneyText then
        local copper = GetMoney and GetMoney() or 0
        local display = NS.Money and NS.Money.GetDisplay and NS.Money.GetDisplay(copper, true)
        local color = display and display.color

        frame.moneyText:SetText(display and display.text or "0")
        if frame.moneyHoverFrame then
            frame.moneyHoverFrame.copper = copper
            frame.moneyHoverFrame:SetWidth(math.max(FOOTER_MONEY_HOVER_MIN_WIDTH, frame.moneyText:GetStringWidth() + FOOTER_MONEY_HOVER_PADDING))
        end

        if color then
            frame.moneyText:SetTextColor(color.r, color.g, color.b)
        else
            frame.moneyText:SetTextColor(FOOTER_TEXT_COLOR_R, FOOTER_TEXT_COLOR_G, FOOTER_TEXT_COLOR_B)
        end
    end
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
    GameTooltip:SetText(MONEY or "Money", 1, 1, 1)

    if SetTooltipMoney then
        SetTooltipMoney(GameTooltip, copper, "STATIC")
    elseif NS.Money and NS.Money.FormatExact then
        GameTooltip:AddLine(NS.Money.FormatExact(copper, true), 1, 1, 1)
    end

    GameTooltip:Show()
end

local function HideMoneyTooltip()
    if GameTooltip_ClearMoney then
        GameTooltip_ClearMoney(GameTooltip)
    end

    GameTooltip:Hide()
end

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

local function AddTooltipDivider(tooltip)
    if GameTooltip_AddBlankLineToTooltip then
        GameTooltip_AddBlankLineToTooltip(tooltip)
    else
        tooltip:AddLine(" ")
    end
end

local function AddTooltipActionLine(tooltip, text)
    local r, g, b
    if NS.Media and NS.Media.GetAccentColor then
        r, g, b = NS.Media.GetAccentColor()
    else
        r, g, b = FOOTER_BAG_BUTTON_REAGENT_BORDER_R, FOOTER_BAG_BUTTON_REAGENT_BORDER_G, FOOTER_BAG_BUTTON_REAGENT_BORDER_B
    end

    tooltip:AddLine(text, r, g, b)
end

local function ShowInventoryStatsTooltip(frame)
    if not NS.Inventory then
        return
    end

    local stats = NS.Inventory:GetStats()
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:SetText(INVENTORY_TOOLTIP or "Inventory", 1, 1, 1)
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
    if NS.BagManagement and NS.BagManagement.CleanupBags then
        NS.BagManagement.CleanupBags()
    end
end

local function GetBagUsageCounts(button)
    if NS.Inventory and button.containerID then
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

local function UpdateInventoryStats(frame)
    if not frame.statsText or not NS.Inventory then
        return
    end

    local stats = NS.Inventory:GetStats()
    frame.statsText:SetText(("%d/%d"):format(
        stats.usedSlots or 0,
        stats.totalSlots or 0
    ))

    frame.statsText:SetTextColor(GetInventoryStatsTextColor(stats))

    if frame.statsHoverFrame then
        frame.statsHoverFrame:SetWidth(math.max(FOOTER_STATS_HOVER_MIN_WIDTH, frame.statsText:GetStringWidth() + FOOTER_STATS_HOVER_PADDING))
    end
end

local function RefreshFrame(frame)
    if NS.Inventory and frame.itemList then
        frame.itemList:SetItems(NS.Inventory:GetItems())
        UpdateInventoryStats(frame)
    end

    if frame.UpdateBagButtons then
        frame:UpdateBagButtons()
    end

    UpdateMoney(frame)
end

-- Frame construction
local function CreateContentFrame(frame)
    local content = CreateFrame(FRAME_TYPE, nil, frame)
    content:SetPoint("TOPLEFT", frame.Inset or frame, "TOPLEFT", CONTENT_INSET_LEFT, CONTENT_INSET_TOP)
    content:SetPoint("BOTTOMRIGHT", frame.Inset or frame, "BOTTOMRIGHT", CONTENT_INSET_RIGHT, CONTENT_INSET_BOTTOM)
    frame.content = content

    if NS.ItemList then
        frame.itemList = NS.ItemList.Create(content)
    end
end

local function CreateSearchBox(frame)
    if not frame.itemList or not frame.itemList.CreateSearchBox then
        return
    end

    local searchBox = frame.itemList:CreateSearchBox(frame)
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", SEARCH_BOX_LEFT_OFFSET, SEARCH_BOX_TOP_OFFSET)
    searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", SEARCH_BOX_RIGHT_OFFSET, SEARCH_BOX_TOP_OFFSET)
    searchBox:SetFrameLevel(frame:GetFrameLevel() + SEARCH_BOX_FRAME_LEVEL_OFFSET)
    frame.searchBox = searchBox
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
    if not button.isBackpack then
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

local function OnBagButtonEnter(button)
    if button.highlight then
        button.highlight:Show()
    end

    if NS.frame and NS.frame.itemList and NS.frame.itemList.SetHighlightedBagID then
        NS.frame.itemList:SetHighlightedBagID(button.containerID)
    end

    ShowBagButtonTooltip(button)
end

local function OnBagButtonLeave(button)
    if button.highlight then
        button.highlight:Hide()
    end

    if NS.frame and NS.frame.itemList and NS.frame.itemList.SetHighlightedBagID and NS.frame.itemList.highlightedBagID == button.containerID then
        NS.frame.itemList:SetHighlightedBagID(nil)
    end

    HideBagButtonTooltip()
end

local function OnBagButtonClick(button, mouseButton)
    if not NS.BagManagement then
        return
    end

    if mouseButton == "RightButton" then
        if NS.BagManagement.EmptyBag then
            NS.BagManagement.EmptyBag(button.containerID)
        end
    elseif not button.isBackpack and NS.BagManagement.HandleBagButtonClick then
        NS.BagManagement.HandleBagButtonClick(button.containerID)
    end
end

local function OnBagButtonDragStart(button)
    if not button.isBackpack and NS.BagManagement and NS.BagManagement.PickupBag then
        NS.BagManagement.PickupBag(button.containerID)
    end
end

local function OnBagButtonReceiveDrag(button)
    if not button.isBackpack and NS.BagManagement and NS.BagManagement.PutCursorInBagSlot then
        NS.BagManagement.PutCursorInBagSlot(button.containerID)
    end
end

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
    button.border:SetTexture(NS.Media and NS.Media.GetIconBorderTexture and NS.Media.GetIconBorderTexture() or nil)

    button:SetScript("OnClick", OnBagButtonClick)
    button:SetScript("OnDragStart", OnBagButtonDragStart)
    button:SetScript("OnReceiveDrag", OnBagButtonReceiveDrag)
    button:SetScript("OnEnter", OnBagButtonEnter)
    button:SetScript("OnLeave", OnBagButtonLeave)
    return button
end

local function CreateBagButtons(frame, footer)
    frame.bagButtons = {}

    local maxButtons = 1 + (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0)
    for index = 1, maxButtons do
        frame.bagButtons[index] = CreateBagButton(footer, index)
    end

    function frame:UpdateBagButtons()
        if not NS.BagManagement or not NS.BagManagement.GetBagSlots then
            return
        end

        local slots = NS.BagManagement.GetBagSlots()
        for index, button in ipairs(self.bagButtons) do
            local slot = slots[index]
            if slot then
                UpdateBagButton(button, slot)
            else
                button:Hide()
            end
        end
    end
end

local function CreateFooter(frame)
    local footer = CreateFrame(FRAME_TYPE, nil, frame)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FOOTER_LEFT_OFFSET, FOOTER_BOTTOM_OFFSET)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FOOTER_RIGHT_OFFSET, FOOTER_BOTTOM_OFFSET)
    footer:SetHeight(FOOTER_HEIGHT)
    frame.footer = footer

    local statsHoverFrame = CreateFrame(BUTTON_TYPE, nil, footer)
    statsHoverFrame:SetPoint("LEFT", footer, "LEFT", FOOTER_STATS_X_OFFSET, FOOTER_STATS_Y_OFFSET)
    statsHoverFrame:SetSize(FOOTER_STATS_HOVER_MIN_WIDTH, FOOTER_HEIGHT)
    statsHoverFrame:RegisterForClicks("LeftButtonUp")
    statsHoverFrame:SetScript("OnEnter", ShowInventoryStatsTooltip)
    statsHoverFrame:SetScript("OnLeave", HideInventoryStatsTooltip)
    statsHoverFrame:SetScript("OnClick", SortBagsFromStatsDisplay)
    frame.statsHoverFrame = statsHoverFrame

    local statsText = statsHoverFrame:CreateFontString(nil, FOOTER_FONT_LAYER)
    statsText:SetFont(GetPrimaryFont(), FOOTER_TEXT_SIZE)
    statsText:SetTextColor(FOOTER_TEXT_COLOR_R, FOOTER_TEXT_COLOR_G, FOOTER_TEXT_COLOR_B)
    statsText:SetPoint("LEFT", statsHoverFrame, "LEFT", 0, 0)
    statsText:SetJustifyH("LEFT")
    statsText:SetText("")
    frame.statsText = statsText

    CreateBagButtons(frame, footer)

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
    moneyText:SetPoint("RIGHT", moneyHoverFrame, "RIGHT", 0, 0)
    moneyText:SetJustifyH("RIGHT")
    moneyText:SetText("")
    frame.moneyText = moneyText
end

local function CreateResizeButton(frame)
    frame:SetResizable(true)

    local maxWidth = GetMaxFrameWidth()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT, maxWidth, nil)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT)
    end

    local resizeButton = CreateFrame(BUTTON_TYPE, nil, frame, RESIZE_BUTTON_TEMPLATE)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", RESIZE_BUTTON_RIGHT_OFFSET, RESIZE_BUTTON_BOTTOM_OFFSET)
    resizeButton:Init(frame, MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT, maxWidth, nil)
    resizeButton:SetOnResizeStoppedCallback(function(target)
        SnapFrameSize(target)
        SaveFrameGeometry(target)
        PrintFramePositionDebug(target, "resize-stop")
    end)
    frame.resizeButton = resizeButton
end

local function RegisterFrameCallbacks(frame)
    if frame.callbacksRegistered then
        return
    end

    if NS.Inventory then
        NS.Inventory:RegisterUpdateCallback(function()
            if NS.frame then
                RefreshFrame(NS.frame)
            end
        end)
    end

    NS:RegisterEventHandler("PLAYER_MONEY", function()
        if NS.frame then
            UpdateMoney(NS.frame)
        end
    end)

    NS:RegisterEventHandler("BAG_UPDATE_COOLDOWN", function()
        if NS.frame and NS.frame.itemList then
            NS.frame.itemList:RefreshVisibleCooldowns()
        end
    end)

    NS:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", function()
        if NS.frame then
            if NS.frame.UpdateBagButtons then
                NS.frame:UpdateBagButtons()
            end

            if NS.Inventory then
                NS.Inventory:ScheduleScan("PLAYER_EQUIPMENT_CHANGED")
            end
        end
    end)

    frame.callbacksRegistered = true
end

function NS:CreateMainFrame()
    if NS.frame then
        return NS.frame
    end

    local frame = CreateFrame(FRAME_TYPE, FRAME_NAME, UIParent, MAIN_FRAME_TEMPLATE)
    ApplyBaseFrameTheme(frame)
    PreventClientPositionSaving(frame)
    frame:SetScale(NS.charDB:Get("frame", "scale"))
    RestoreFrameSize(frame)
    frame:SetFrameStrata(MAIN_FRAME_STRATA)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    ClearClientPosition(frame)
    frame:EnableMouse(true)
    frame:Hide()

    if frame.SetTitle then
        frame:SetTitle(ADDON_NAME)
    end

    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset(MAIN_FRAME_PORTRAIT)
        frame:SetPortraitTexCoord(PORTRAIT_TEX_COORD_LEFT, PORTRAIT_TEX_COORD_RIGHT, PORTRAIT_TEX_COORD_TOP, PORTRAIT_TEX_COORD_BOTTOM)
    end

    RestoreFramePosition(frame)

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_INSET_LEFT, FRAME_INSET_TOP)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FRAME_INSET_RIGHT, FRAME_INSET_BOTTOM)
    end

    local dragRegion = frame.TitleContainer or frame
    dragRegion:EnableMouse(true)
    dragRegion:RegisterForDrag("LeftButton")
    dragRegion:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)

    dragRegion:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveFrameGeometry(frame)
        PrintFramePositionDebug(frame, "move-stop")
    end)

    CreateContentFrame(frame)
    CreateSearchBox(frame)
    CreateFooter(frame)
    CreateResizeButton(frame)
    RegisterFrameCallbacks(frame)

    frame:SetScript("OnShow", function(self)
        ClearClientPosition(self)
        PrintFramePositionDebug(self, "show")

        if NS.Inventory and not NS.Inventory.initialScanComplete then
            NS.Inventory:ScanNow("frame-show")
        end

        RefreshFrame(self)
    end)

    NS.frame = frame
    RefreshFrame(frame)
    PrintFramePositionDebug(frame, "addon-load")
    return frame
end

function NS:ShowFrame()
    local frame = NS.frame or NS:CreateMainFrame()
    frame:Show()
end

function NS:HideFrame()
    if NS.frame then
        NS.frame:Hide()
    end
end

function NS:ToggleFrame()
    local frame = NS.frame or NS:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

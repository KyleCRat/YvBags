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
local FOOTER_MONEY_X_OFFSET = 0
local FOOTER_MONEY_Y_OFFSET = 0
local FOOTER_MONEY_HOVER_MIN_WIDTH = 96
local FOOTER_MONEY_HOVER_PADDING = 8
local SEARCH_BOX_LEFT_OFFSET = 86
local SEARCH_BOX_TOP_OFFSET = -40
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
    frame:SetSize(width, height)
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

local function UpdateInventoryStats(frame)
    if not frame.statsText or not NS.Inventory then
        return
    end

    local stats = NS.Inventory:GetStats()
    frame.statsText:SetText(("%d/%d"):format(
        stats.usedSlots or 0,
        stats.totalSlots or 0
    ))
end

local function RefreshFrame(frame)
    if NS.Inventory and frame.itemList then
        frame.itemList:SetItems(NS.Inventory:GetItems())
        UpdateInventoryStats(frame)
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
    searchBox:SetFrameLevel(frame:GetFrameLevel() + SEARCH_BOX_FRAME_LEVEL_OFFSET)
    frame.searchBox = searchBox
end

local function CreateFooter(frame)
    local footer = CreateFrame(FRAME_TYPE, nil, frame)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FOOTER_LEFT_OFFSET, FOOTER_BOTTOM_OFFSET)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FOOTER_RIGHT_OFFSET, FOOTER_BOTTOM_OFFSET)
    footer:SetHeight(FOOTER_HEIGHT)
    frame.footer = footer

    local statsText = footer:CreateFontString(nil, FOOTER_FONT_LAYER)
    statsText:SetFont(GetPrimaryFont(), FOOTER_TEXT_SIZE)
    statsText:SetTextColor(FOOTER_TEXT_COLOR_R, FOOTER_TEXT_COLOR_G, FOOTER_TEXT_COLOR_B)
    statsText:SetPoint("LEFT", footer, "LEFT", FOOTER_STATS_X_OFFSET, FOOTER_STATS_Y_OFFSET)
    statsText:SetJustifyH("LEFT")
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

    frame.callbacksRegistered = true
end

function NS:CreateMainFrame()
    if NS.frame then
        return NS.frame
    end

    local frame = CreateFrame(FRAME_TYPE, FRAME_NAME, UIParent, MAIN_FRAME_TEMPLATE)
    ApplyBaseFrameTheme(frame)
    PreventClientPositionSaving(frame)
    RestoreFrameSize(frame)
    frame:SetScale(NS.charDB:Get("frame", "scale"))
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

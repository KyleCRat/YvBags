local _, NS = ...

local ItemList = {}
NS.ItemList = ItemList

local ROW_HEIGHT = 29
local HEADER_HEIGHT = 24
local ICON_SIZE = 23
local ICON_FRAME_SIZE = 29
local PROFESSION_QUALITY_ICON_SIZE = 22
local COLUMN_GAP = 6
local SCROLL_BAR_WIDTH = 14
local MINIMUM_WIDTH_PADDING = 28
local ICON_LEFT_OFFSET = 3
local ICON_TEX_COORD_LEFT = 0.08
local ICON_TEX_COORD_RIGHT = 0.92
local ICON_TEX_COORD_TOP = 0.08
local ICON_TEX_COORD_BOTTOM = 0.92
local ROW_TEXT_FONT = "GameFontHighlight"
local HEADER_TEXT_FONT = "GameFontNormalSmall"
local EMPTY_TEXT_FONT = "GameFontDisable"
local COOLDOWN_TEXT_FONT = "NumberFontNormalSmall"
local FONT_STRING_LAYER = "OVERLAY"
local DEFAULT_TEXT_COLOR_R = 0.86
local DEFAULT_TEXT_COLOR_G = 0.86
local DEFAULT_TEXT_COLOR_B = 0.86
local DEFAULT_NAME_COLOR_R = 1
local DEFAULT_NAME_COLOR_G = 1
local DEFAULT_NAME_COLOR_B = 1
local DEFAULT_HIGHLIGHT_COLOR_R = 1
local DEFAULT_HIGHLIGHT_COLOR_G = 1
local DEFAULT_HIGHLIGHT_COLOR_B = 1
local DEFAULT_ICON_BORDER_COLOR_R = 0.55
local DEFAULT_ICON_BORDER_COLOR_G = 0.55
local DEFAULT_ICON_BORDER_COLOR_B = 0.55
local ICON_BORDER_ALPHA = 0.85
local RARITY_HIGHLIGHT_ALPHA = 0.16
local DEFAULT_HIGHLIGHT_ALPHA = 0.08
local COOLDOWN_SHADE_COLOR_R = 0
local COOLDOWN_SHADE_COLOR_G = 0
local COOLDOWN_SHADE_COLOR_B = 0
local ROW_COOLDOWN_ALPHA = 0.38
local COOLDOWN_SHADE_LAYER = "OVERLAY"
local COOLDOWN_SHADE_SUBLEVEL = 1
local COOLDOWN_TEXT_LAYER = "OVERLAY"
local COOLDOWN_TEXT_SUBLEVEL = 7
local COOLDOWN_SHADE_TOP_LEFT_X_OFFSET = 0
local COOLDOWN_SHADE_TOP_LEFT_Y_OFFSET = 0
local COOLDOWN_SHADE_BOTTOM_LEFT_X_OFFSET = 0
local COOLDOWN_SHADE_BOTTOM_LEFT_Y_OFFSET = 0
local PROFESSION_QUALITY_LAYER = "ARTWORK"
local PROFESSION_QUALITY_SUBLEVEL = 7
local ROW_HIGHLIGHT_LAYER = "BACKGROUND"
local ROW_ICON_LAYER = "ARTWORK"
local ROW_ICON_SUBLEVEL = 5
local ICON_FRAME_LAYER = "ARTWORK"
local ICON_FRAME_SUBLEVEL = 6
local ICON_BORDER_LAYER = "ARTWORK"
local ICON_BORDER_SUBLEVEL = 7
local LIST_FRAME_TYPE = "Frame"
local ITEM_BUTTON_FRAME_TYPE = "Button"
local ITEM_BUTTON_TEMPLATE = "ContainerFrameItemButtonTemplate"
local ITEM_BUTTON_FRAME_LEVEL_OFFSET = 10
local SCROLL_BOX_TEMPLATE = "WowScrollBoxList"
local SCROLL_BAR_FRAME_TYPE = "EventFrame"
local SCROLL_BAR_TEMPLATE = "MinimalScrollBar"
local HEADER_LEFT_OFFSET = 0
local HEADER_TOP_OFFSET = 0
local HEADER_RIGHT_OFFSET = 0
local SCROLL_BOX_LEFT_OFFSET = 0
local SCROLL_BOX_RIGHT_OFFSET = 0
local SCROLL_BOX_TOP_GAP = -2
local SCROLL_BOX_BOTTOM_OFFSET = 0
local SCROLL_BAR_X_OFFSET = 4
local SCROLL_BAR_TOP_OFFSET = -2
local SCROLL_BAR_BOTTOM_OFFSET = 2
local EMPTY_TEXT_X_OFFSET = 0
local EMPTY_TEXT_Y_OFFSET = 0
local GCD_MAX_DURATION = 2
local COOLDOWN_UPDATE_INTERVAL = 0.05
local COOLDOWN_CACHE_TTL = 0.2
local FALLBACK_ITEM_ICON = 134400
local EMPTY_LIST_TEXT = "No bag items"
local ITEM_BUTTON_GLOBAL_NAME_PREFIX = "YvBagsItemListButton"
local ACTION_BUTTON_ICON_FRAME_ATLAS = "UI-HUD-ActionBar-IconFrame"
local ACTION_BUTTON_ICON_BORDER_ATLAS = "UI-HUD-ActionBar-IconFrame-Border"
local MONEY_DISPLAY_FORMAT = "%s |T%s:0|t"
local MONEY_GOLD_KEY = "gold"
local MONEY_SILVER_KEY = "silver"
local MONEY_COPPER_KEY = "copper"
local MONEY_DENOMINATIONS = {
    [MONEY_GOLD_KEY] = {
        icon = "Interface\\MoneyFrame\\UI-GoldIcon",
        color = { r = 1, g = 0.82, b = 0 },
    },
    [MONEY_SILVER_KEY] = {
        icon = "Interface\\MoneyFrame\\UI-SilverIcon",
        color = { r = 0.75, g = 0.75, b = 0.75 },
    },
    [MONEY_COPPER_KEY] = {
        icon = "Interface\\MoneyFrame\\UI-CopperIcon",
        color = { r = 0.78, g = 0.45, b = 0.25 },
    },
}
local buttonCount = 0
local moneyDisplayCache = {}
local professionQualityAtlasCache = {}
local cooldownCache = {}

-- Fixed v1 columns. Later column customization can replace this table without
-- changing the row rendering code.
local COLUMNS = {
    { key = "icon", label = "", width = 30 },
    { key = "name", label = NAME or "Name", width = 220 },
    { key = "count", label = "Qty", width = 40, justify = "RIGHT" },
    { key = "itemLevel", label = "Ilvl", width = 44, justify = "RIGHT" },
    { key = "requiredLevel", label = "Req", width = 44, justify = "RIGHT" },
    { key = "type", label = TYPE or "Type", width = 138 },
    { key = "binding", label = "Binding", width = 96 },
    { key = "expansion", label = "Exp", width = 48, justify = "RIGHT" },
    { key = "sellValue", label = SELL_PRICE or "Sell", width = 82, justify = "RIGHT" },
    { key = "location", label = "Bag/Slot", width = 68 },
    { key = "professionQuality", label = "Q", width = 28, justify = "CENTER" },
}

-- Column formatting
local function EmptyDash(value)
    if value == nil or value == "" then
        return "-"
    end

    return tostring(value)
end

local function FormatLargeMoneyAmount(amount)
    if AbbreviateNumbers then
        return AbbreviateNumbers(amount)
    elseif AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(amount)
    elseif BreakUpLargeNumbers then
        return BreakUpLargeNumbers(amount)
    end

    return tostring(amount)
end

local function GetMoneyDisplay(copper)
    if not copper or copper <= 0 then
        return nil
    end

    if moneyDisplayCache[copper] then
        return moneyDisplayCache[copper]
    end

    local copperPerGold = COPPER_PER_GOLD or 10000
    local copperPerSilver = COPPER_PER_SILVER or 100
    local gold = math.floor(copper / copperPerGold)
    local silver = math.floor((copper - (gold * copperPerGold)) / copperPerSilver)
    local copperOnly = copper - (gold * copperPerGold) - (silver * copperPerSilver)
    local key
    local amount

    if gold > 0 then
        key = MONEY_GOLD_KEY
        amount = gold
    elseif silver > 0 then
        key = MONEY_SILVER_KEY
        amount = silver
    else
        key = MONEY_COPPER_KEY
        amount = copperOnly
    end

    local denomination = MONEY_DENOMINATIONS[key]
    local display = {
        key = key,
        color = denomination.color,
        text = MONEY_DISPLAY_FORMAT:format(FormatLargeMoneyAmount(amount), denomination.icon),
    }

    moneyDisplayCache[copper] = display
    return display
end

local function FormatMoney(copper)
    local display = GetMoneyDisplay(copper)
    return display and display.text or "-"
end

local function FormatType(item)
    if item.type and item.subtype and item.subtype ~= "" and item.subtype ~= item.type then
        return item.type .. " / " .. item.subtype
    end

    return item.type or item.subtype or "-"
end

local function FormatBinding(item)
    if not item.bindingKey or item.bindingKey == "none" then
        return "-"
    end

    if item.bindingKey == "pickup" then
        return "BoP"
    elseif item.bindingKey == "equip" then
        return "BoE"
    elseif item.bindingKey == "use" then
        return "BoU"
    elseif item.bindingKey == "bound" then
        return ITEM_SOULBOUND or "Soulbound"
    elseif item.bindingKey == "account" then
        return ITEM_BIND_TO_ACCOUNT or "Warbound"
    elseif item.bindingKey == "accountUntilEquipped" then
        return "Warbound Eq"
    end

    return item.bindingText or item.bindingKey
end

local function FormatColumn(item, columnKey)
    if columnKey == "name" then
        return item.name or UNKNOWN or "Unknown"
    elseif columnKey == "count" then
        return item.count and item.count > 1 and tostring(item.count) or ""
    elseif columnKey == "itemLevel" then
        return EmptyDash(item.itemLevel)
    elseif columnKey == "requiredLevel" then
        return EmptyDash(item.requiredLevel)
    elseif columnKey == "type" then
        return FormatType(item)
    elseif columnKey == "binding" then
        return FormatBinding(item)
    elseif columnKey == "expansion" then
        return EmptyDash(item.expansionID)
    elseif columnKey == "sellValue" then
        return FormatMoney(item.totalSellValue or item.sellValue)
    elseif columnKey == "location" then
        return item.bagSlotText or "-"
    elseif columnKey == "professionQuality" then
        return ""
    end

    return ""
end

local function GetProfessionQualityAtlas(item)
    if not item.professionQuality or not C_TradeSkillUI then
        return nil
    end

    local itemInfo = item.link or item.staticLink or item.itemID
    if not itemInfo then
        return nil
    end

    local cacheKey = tostring(itemInfo)
    if professionQualityAtlasCache[cacheKey] ~= nil then
        return professionQualityAtlasCache[cacheKey]
    end

    local qualityInfo
    if C_TradeSkillUI.GetItemReagentQualityInfo then
        qualityInfo = C_TradeSkillUI.GetItemReagentQualityInfo(itemInfo)
    end

    if not qualityInfo and C_TradeSkillUI.GetItemCraftedQualityInfo then
        qualityInfo = C_TradeSkillUI.GetItemCraftedQualityInfo(itemInfo)
    end

    local atlas = qualityInfo and (qualityInfo.icon or qualityInfo.iconSmall or qualityInfo.iconChat or qualityInfo.iconInventory)
    professionQualityAtlasCache[cacheKey] = atlas or false
    return professionQualityAtlasCache[cacheKey]
end

local function UpdateRowHighlightColor(row, item)
    if not row.highlight then
        return
    end

    local color = item and item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color then
        row.highlight:SetColorTexture(color.r, color.g, color.b, RARITY_HIGHLIGHT_ALPHA)
    else
        row.highlight:SetColorTexture(DEFAULT_HIGHLIGHT_COLOR_R, DEFAULT_HIGHLIGHT_COLOR_G, DEFAULT_HIGHLIGHT_COLOR_B, DEFAULT_HIGHLIGHT_ALPHA)
    end
end

local function UpdateIconBorderColor(row, item)
    if not row.iconBorder then
        return
    end

    local color = item and item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color then
        row.iconBorder:SetVertexColor(color.r, color.g, color.b, ICON_BORDER_ALPHA)
    else
        row.iconBorder:SetVertexColor(DEFAULT_ICON_BORDER_COLOR_R, DEFAULT_ICON_BORDER_COLOR_G, DEFAULT_ICON_BORDER_COLOR_B, ICON_BORDER_ALPHA)
    end

    row.iconBorder:Show()
end

local function ClearHoverTooltipState()
    if GameTooltip_HideShoppingTooltips then
        GameTooltip_HideShoppingTooltips(GameTooltip)
    end

    GameTooltip:Hide()
    if ResetCursor and not (SpellIsTargeting and SpellIsTargeting()) then
        ResetCursor()
    end

    if ClearCursorHoveredItem then
        ClearCursorHoveredItem()
    end
end

local function SetNameTextColor(fontString, item)
    local color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    else
        fontString:SetTextColor(DEFAULT_NAME_COLOR_R, DEFAULT_NAME_COLOR_G, DEFAULT_NAME_COLOR_B)
    end
end

local function SetSellValueTextColor(fontString, item)
    local display = GetMoneyDisplay(item.totalSellValue or item.sellValue)
    local color = display and display.color
    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    else
        fontString:SetTextColor(DEFAULT_TEXT_COLOR_R, DEFAULT_TEXT_COLOR_G, DEFAULT_TEXT_COLOR_B)
    end
end

local function GetContentWidth()
    local width = 0

    for index, column in ipairs(COLUMNS) do
        width = width + column.width
        if index < #COLUMNS then
            width = width + COLUMN_GAP
        end
    end

    return width
end

-- Header and row layout
local function CreateHeader(parent)
    local header = CreateFrame(LIST_FRAME_TYPE, nil, parent)
    header:SetHeight(HEADER_HEIGHT)

    local xOffset = 0
    for _, column in ipairs(COLUMNS) do
        local text = header:CreateFontString(nil, FONT_STRING_LAYER, HEADER_TEXT_FONT)
        text:SetPoint("LEFT", header, "LEFT", xOffset, 0)
        text:SetSize(column.width, HEADER_HEIGHT)
        text:SetJustifyH(column.justify or "LEFT")
        text:SetJustifyV("MIDDLE")
        text:SetText(column.label)

        xOffset = xOffset + column.width + COLUMN_GAP
    end

    return header
end

local function LayoutRow(row)
    local xOffset = 0
    local iconCenterX = ICON_LEFT_OFFSET + (ICON_FRAME_SIZE / 2)

    if row.iconFrame then
        row.iconFrame:ClearAllPoints()
        row.iconFrame:SetPoint("CENTER", row, "LEFT", iconCenterX, 0)
        row.iconFrame:SetSize(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
    end

    if row.iconBorder then
        row.iconBorder:ClearAllPoints()
        row.iconBorder:SetPoint("CENTER", row, "LEFT", iconCenterX, 0)
        row.iconBorder:SetSize(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
    end

    if row.icon then
        row.icon:ClearAllPoints()
        row.icon:SetPoint("CENTER", row, "LEFT", iconCenterX, 0)
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    end

    if row.iconCooldownText and row.icon then
        row.iconCooldownText:ClearAllPoints()
        row.iconCooldownText:SetAllPoints(row.icon)
    end

    if row.cooldownShade then
        row.cooldownShade:ClearAllPoints()
        row.cooldownShade:SetPoint("TOPLEFT", row, "TOPLEFT", COOLDOWN_SHADE_TOP_LEFT_X_OFFSET, COOLDOWN_SHADE_TOP_LEFT_Y_OFFSET)
        row.cooldownShade:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", COOLDOWN_SHADE_BOTTOM_LEFT_X_OFFSET, COOLDOWN_SHADE_BOTTOM_LEFT_Y_OFFSET)
    end

    xOffset = xOffset + COLUMNS[1].width + COLUMN_GAP

    for index = 2, #COLUMNS do
        local column = COLUMNS[index]
        local text = row.text[column.key]
        text:ClearAllPoints()
        text:SetPoint("LEFT", row, "LEFT", xOffset, 0)
        text:SetSize(column.width, ROW_HEIGHT)
        text:SetJustifyH(column.justify or "LEFT")
        xOffset = xOffset + column.width + COLUMN_GAP
    end

    if row.professionQualityIcon then
        local column = COLUMNS[#COLUMNS]
        row.professionQualityIcon:ClearAllPoints()
        row.professionQualityIcon:SetPoint("CENTER", row, "LEFT", xOffset - column.width - COLUMN_GAP + (column.width / 2), 0)
    end
end

-- Cooldown display
local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function IsSafeNumber(value)
    if IsSecretValue(value) then
        return false
    end

    return type(value) == "number"
end

local function FormatCooldownText(remaining)
    if not IsSafeNumber(remaining) then
        return ""
    end

    if remaining >= 3600 then
        return ("%dh"):format(math.ceil(remaining / 3600))
    elseif remaining >= 60 then
        return ("%dm"):format(math.ceil(remaining / 60))
    elseif remaining >= 10 then
        return tostring(math.ceil(remaining))
    end

    return ("%.1f"):format(remaining)
end

local function ClearRowCooldown(row)
    row.cooldownStart = nil
    row.cooldownDuration = nil
    row.cooldownModRate = nil
    row.cooldownIsGCD = nil
    row.cooldownElapsed = nil
    row:SetScript("OnUpdate", nil)

    if row.cooldownShade then
        row.cooldownShade:Hide()
        row.cooldownShade:SetWidth(1)
    end

    if row.iconCooldownText then
        row.iconCooldownText:SetText("")
        row.iconCooldownText:Hide()
    end
end

local function RefreshRowCooldown(row)
    local startTime = row.cooldownStart
    local duration = row.cooldownDuration
    local modRate = row.cooldownModRate or 1

    if not IsSafeNumber(startTime) or not IsSafeNumber(duration) or not IsSafeNumber(modRate) or duration <= 0 or modRate <= 0 then
        ClearRowCooldown(row)
        return
    end

    local cooldownRemaining = duration - ((GetTime() - startTime) * modRate)
    if cooldownRemaining <= 0 then
        ClearRowCooldown(row)
        return
    end

    local remainingRatio = cooldownRemaining / duration
    if remainingRatio < 0 then
        remainingRatio = 0
    elseif remainingRatio > 1 then
        remainingRatio = 1
    end

    local rowWidth = row:GetWidth()
    if not IsSafeNumber(rowWidth) or rowWidth <= 0 then
        rowWidth = GetContentWidth()
    end

    if row.cooldownShade then
        row.cooldownShade:SetWidth(math.max(1, rowWidth * remainingRatio))
        row.cooldownShade:Show()
    end

    if row.iconCooldownText then
        if row.cooldownIsGCD then
            row.iconCooldownText:SetText("")
            row.iconCooldownText:Hide()
        else
            row.iconCooldownText:SetText(FormatCooldownText(cooldownRemaining / modRate))
            row.iconCooldownText:Show()
        end
    end
end

local function OnRowCooldownUpdate(row, elapsed)
    row.cooldownElapsed = (row.cooldownElapsed or 0) + elapsed
    if row.cooldownElapsed < COOLDOWN_UPDATE_INTERVAL then
        return
    end

    row.cooldownElapsed = 0
    RefreshRowCooldown(row)
end

local function GetItemCooldown(item)
    if not item or not C_Container or not C_Container.GetContainerItemCooldown then
        return nil
    end

    local now = GetTime()
    local cacheKey = item.locationKey or item.bagSlotText
    local cached = cacheKey and cooldownCache[cacheKey]
    if cached and (now - cached.checkedAt) <= COOLDOWN_CACHE_TTL then
        return cached.startTime, cached.duration, cached.modRate, cached.isGCD
    end

    local startTime, duration, enable, modRate = C_Container.GetContainerItemCooldown(item.bagID, item.slotIndex)
    if IsSecretValue(startTime) or IsSecretValue(duration) or IsSecretValue(enable) or IsSecretValue(modRate) then
        if cacheKey then
            cooldownCache[cacheKey] = { checkedAt = now }
        end
        return nil
    end

    if not IsSafeNumber(startTime) or not IsSafeNumber(duration) then
        if cacheKey then
            cooldownCache[cacheKey] = { checkedAt = now }
        end
        return nil
    end

    if not IsSafeNumber(modRate) or modRate <= 0 then
        modRate = 1
    end

    if enable == 0 or startTime <= 0 or duration <= 0 then
        if cacheKey then
            cooldownCache[cacheKey] = { checkedAt = now }
        end
        return nil
    end

    local cooldownRemaining = duration - ((now - startTime) * modRate)
    if cooldownRemaining <= 0 then
        if cacheKey then
            cooldownCache[cacheKey] = { checkedAt = now }
        end
        return nil
    end

    local isGCD = duration <= GCD_MAX_DURATION
    if cacheKey then
        cooldownCache[cacheKey] = {
            checkedAt = now,
            startTime = startTime,
            duration = duration,
            modRate = modRate,
            isGCD = isGCD,
        }
    end

    return startTime, duration, modRate, isGCD
end

local function UpdateRowCooldown(row, item)
    local startTime, duration, modRate, isGCD = GetItemCooldown(item)
    if not startTime then
        ClearRowCooldown(row)
        return
    end

    row.cooldownStart = startTime
    row.cooldownDuration = duration
    row.cooldownModRate = modRate
    row.cooldownIsGCD = isGCD
    row.cooldownElapsed = COOLDOWN_UPDATE_INTERVAL
    RefreshRowCooldown(row)
    row:SetScript("OnUpdate", OnRowCooldownUpdate)
end

-- Native item button bridge
-- Keep Blizzard's bag item button as the full-row click/drag target, but render
-- all visuals on the row so native button art never stretches across the list.
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

local function SuppressNativeItemButtonVisuals(button)
    -- The container template provides item behavior; row-owned textures provide
    -- every visible pixel.
    for _, region in pairs(button) do
        if region ~= button.parent and region ~= button:GetParent() and type(region) == "table" and region.Hide then
            ClearNativeTexture(region)
        end
    end

    local name = button:GetName()
    ClearNativeTexture(button.GetNormalTexture and button:GetNormalTexture())
    ClearNativeTexture(button.GetHighlightTexture and button:GetHighlightTexture())
    ClearNativeTexture(button.GetPushedTexture and button:GetPushedTexture())
    ClearNativeTexture(button.GetDisabledTexture and button:GetDisabledTexture())
    ClearNativeTexture(button.GetCheckedTexture and button:GetCheckedTexture())

    if name then
        ClearNativeTexture(_G[name .. "IconTexture"])
        ClearNativeTexture(_G[name .. "Icon"])
        ClearNativeTexture(_G[name .. "NormalTexture"])
        ClearNativeTexture(_G[name .. "Count"])
    end

    if button.SetNormalTexture then
        button:SetNormalTexture("")
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("")
    end
    if button.SetPushedTexture then
        button:SetPushedTexture("")
    end
    if button.SetDisabledTexture then
        button:SetDisabledTexture("")
    end
    if button.SetCheckedTexture then
        button:SetCheckedTexture("")
    end

    if button.flashAnim then
        button.flashAnim:Stop()
    end
    if button.newitemglowAnim then
        button.newitemglowAnim:Stop()
    end
    if button.AugmentBorderAnim then
        button.AugmentBorderAnim:Stop()
    end
end

local function ConfigureNativeItemButton(button, row)
    button:ClearAllPoints()
    button:SetAllPoints(row)
    button:SetFrameLevel(row:GetFrameLevel() + ITEM_BUTTON_FRAME_LEVEL_OFFSET)
    button:SetAlpha(1)
    button:EnableMouse(true)
    SuppressNativeItemButtonVisuals(button)
end

local function InitializeRow(row)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(false)
    row:SetID(0)

    row.highlight = row:CreateTexture(nil, ROW_HIGHLIGHT_LAYER)
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(DEFAULT_HIGHLIGHT_COLOR_R, DEFAULT_HIGHLIGHT_COLOR_G, DEFAULT_HIGHLIGHT_COLOR_B, DEFAULT_HIGHLIGHT_ALPHA)
    row.highlight:Hide()

    row.icon = row:CreateTexture(nil, ROW_ICON_LAYER)
    row.icon:SetDrawLayer(ROW_ICON_LAYER, ROW_ICON_SUBLEVEL)
    row.icon:SetTexCoord(ICON_TEX_COORD_LEFT, ICON_TEX_COORD_RIGHT, ICON_TEX_COORD_TOP, ICON_TEX_COORD_BOTTOM)
    row.icon:Hide()

    row.iconFrame = row:CreateTexture(nil, ICON_FRAME_LAYER)
    row.iconFrame:SetDrawLayer(ICON_FRAME_LAYER, ICON_FRAME_SUBLEVEL)
    row.iconFrame:SetAtlas(ACTION_BUTTON_ICON_FRAME_ATLAS, false)
    row.iconFrame:Hide()

    row.iconBorder = row:CreateTexture(nil, ICON_BORDER_LAYER)
    row.iconBorder:SetDrawLayer(ICON_BORDER_LAYER, ICON_BORDER_SUBLEVEL)
    row.iconBorder:SetAtlas(ACTION_BUTTON_ICON_BORDER_ATLAS, false)
    row.iconBorder:Hide()

    row.cooldownShade = row:CreateTexture(nil, COOLDOWN_SHADE_LAYER)
    row.cooldownShade:SetDrawLayer(COOLDOWN_SHADE_LAYER, COOLDOWN_SHADE_SUBLEVEL)
    row.cooldownShade:SetColorTexture(COOLDOWN_SHADE_COLOR_R, COOLDOWN_SHADE_COLOR_G, COOLDOWN_SHADE_COLOR_B, ROW_COOLDOWN_ALPHA)
    row.cooldownShade:Hide()

    buttonCount = buttonCount + 1
    row.itemButton = CreateFrame(ITEM_BUTTON_FRAME_TYPE, ITEM_BUTTON_GLOBAL_NAME_PREFIX .. buttonCount, row, ITEM_BUTTON_TEMPLATE)
    row.itemButton.parent = row
    ConfigureNativeItemButton(row.itemButton, row)
    row.itemButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.itemButton:RegisterForDrag("LeftButton")
    row.itemButton:Show()
    SuppressNativeItemButtonVisuals(row.itemButton)
    row.itemButton:HookScript("OnEnter", function(button)
        local parent = button.parent
        parent.highlight:Show()
    end)
    row.itemButton:HookScript("OnLeave", function(button)
        local parent = button.parent
        parent.highlight:Hide()
    end)

    row.text = {}
    for index = 2, #COLUMNS do
        local column = COLUMNS[index]
        local text = row:CreateFontString(nil, FONT_STRING_LAYER, ROW_TEXT_FONT)
        text:SetJustifyV("MIDDLE")
        text:SetWordWrap(false)
        text:SetMaxLines(1)
        if column.key ~= "name" then
            text:SetTextColor(DEFAULT_TEXT_COLOR_R, DEFAULT_TEXT_COLOR_G, DEFAULT_TEXT_COLOR_B)
        end
        row.text[column.key] = text
    end

    row.professionQualityIcon = row:CreateTexture(nil, PROFESSION_QUALITY_LAYER)
    row.professionQualityIcon:SetSize(PROFESSION_QUALITY_ICON_SIZE, PROFESSION_QUALITY_ICON_SIZE)
    row.professionQualityIcon:SetDrawLayer(PROFESSION_QUALITY_LAYER, PROFESSION_QUALITY_SUBLEVEL)
    row.professionQualityIcon:Hide()

    row.iconCooldownText = row:CreateFontString(nil, COOLDOWN_TEXT_LAYER, COOLDOWN_TEXT_FONT)
    row.iconCooldownText:SetDrawLayer(COOLDOWN_TEXT_LAYER, COOLDOWN_TEXT_SUBLEVEL)
    row.iconCooldownText:SetJustifyH("CENTER")
    row.iconCooldownText:SetJustifyV("MIDDLE")
    row.iconCooldownText:Hide()

    LayoutRow(row)
    row.rowInitialized = true
end

local function UpdateItemButton(button, item)
    button:GetParent():SetID(item.bagID)
    button:SetID(item.slotIndex)
    button.bagID = nil
    button.bag = item.bagID
    button.slot = item.slotIndex
    button.count = item.count
    if button.SetHasItem then
        button:SetHasItem(true)
    else
        button.hasItem = 1
    end
    if button.SetReadable then
        button:SetReadable(item.isReadable)
    end
end

local function ResetItemButton(button)
    button:GetParent():SetID(0)
    button:SetID(0)
    button.bagID = nil
    button.bag = nil
    button.slot = nil
    button.count = nil
    if button.SetHasItem then
        button:SetHasItem(false)
    else
        button.hasItem = nil
    end
    if button.SetReadable then
        button:SetReadable(nil)
    end

    if button.Cooldown then
        button.Cooldown:Hide()
    end
end

local function RenderRow(row, item)
    if not row.rowInitialized then
        InitializeRow(row)
    end

    row.item = item
    UpdateRowHighlightColor(row, item)
    UpdateIconBorderColor(row, item)
    UpdateItemButton(row.itemButton, item)

    if row.icon then
        row.icon:SetTexture(item.icon or FALLBACK_ITEM_ICON)
        row.icon:SetDesaturated(item.isLocked)
        row.icon:Show()
    end

    if row.iconFrame then
        row.iconFrame:Show()
    end

    local professionQualityAtlas = GetProfessionQualityAtlas(item)
    if professionQualityAtlas then
        row.professionQualityIcon:SetAtlas(professionQualityAtlas, false)
        row.professionQualityIcon:Show()
    else
        row.professionQualityIcon:Hide()
    end

    for index = 2, #COLUMNS do
        local column = COLUMNS[index]
        local text = row.text[column.key]
        text:SetText(FormatColumn(item, column.key))

        if column.key == "name" then
            SetNameTextColor(text, item)
        elseif column.key == "sellValue" then
            SetSellValueTextColor(text, item)
        end
    end

    UpdateRowCooldown(row, item)
end

local function ResetRow(row)
    if row.IsMouseOver and row:IsMouseOver() then
        ClearHoverTooltipState()
    end

    row.item = nil
    row:SetID(0)

    if row.highlight then
        row.highlight:Hide()
    end

    ClearRowCooldown(row)

    if row.icon then
        row.icon:SetTexture(nil)
        row.icon:SetDesaturated(false)
        row.icon:Hide()
    end

    if row.iconBorder then
        row.iconBorder:Hide()
    end

    if row.iconFrame then
        row.iconFrame:Hide()
    end

    if row.itemButton then
        ResetItemButton(row.itemButton)
    end

    if row.professionQualityIcon then
        row.professionQualityIcon:Hide()
    end

    if row.text then
        for _, text in pairs(row.text) do
            text:SetText("")
        end
    end
end

-- Public list API
function ItemList.GetMinimumWidth()
    return GetContentWidth() + SCROLL_BAR_WIDTH + MINIMUM_WIDTH_PADDING
end

function ItemList.Create(parent)
    local list = {}

    local frame = CreateFrame(LIST_FRAME_TYPE, nil, parent)
    frame:SetAllPoints(parent)
    list.frame = frame

    local header = CreateHeader(frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_LEFT_OFFSET, HEADER_TOP_OFFSET)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SCROLL_BAR_WIDTH, HEADER_RIGHT_OFFSET)
    list.header = header

    local scrollBox = CreateFrame(LIST_FRAME_TYPE, nil, frame, SCROLL_BOX_TEMPLATE)
    scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", SCROLL_BOX_LEFT_OFFSET, SCROLL_BOX_TOP_GAP)
    scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLL_BAR_WIDTH + SCROLL_BOX_RIGHT_OFFSET, SCROLL_BOX_BOTTOM_OFFSET)
    list.scrollBox = scrollBox

    local scrollBar = CreateFrame(SCROLL_BAR_FRAME_TYPE, nil, frame, SCROLL_BAR_TEMPLATE)
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", SCROLL_BAR_X_OFFSET, SCROLL_BAR_TOP_OFFSET)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", SCROLL_BAR_X_OFFSET, SCROLL_BAR_BOTTOM_OFFSET)
    list.scrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", RenderRow)
    view:SetElementResetter(ResetRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    list.view = view

    local emptyText = frame:CreateFontString(nil, FONT_STRING_LAYER, EMPTY_TEXT_FONT)
    emptyText:SetPoint("CENTER", scrollBox, "CENTER", EMPTY_TEXT_X_OFFSET, EMPTY_TEXT_Y_OFFSET)
    emptyText:SetText(EMPTY_LIST_TEXT)
    emptyText:Hide()
    list.emptyText = emptyText

    function list:SetItems(items)
        local rows = {}

        if items then
            for _, item in ipairs(items) do
                rows[#rows + 1] = item
            end
        end

        local dataProvider = CreateDataProvider(rows)
        wipe(cooldownCache)
        self.scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
        self.emptyText:SetShown(#rows == 0)
        self.dataProvider = dataProvider
    end

    function list:RefreshVisibleRows()
        for _, row in ipairs(self.view:GetFrames()) do
            if row.item then
                RenderRow(row, row.item)
            end
        end
    end

    function list:RefreshVisibleCooldowns()
        wipe(cooldownCache)
        for _, row in ipairs(self.view:GetFrames()) do
            if row.item then
                UpdateRowCooldown(row, row.item)
            end
        end
    end

    return list
end

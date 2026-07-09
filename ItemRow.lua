local _, NS = ...

local ItemRow = {}
NS.ItemRow = ItemRow

local Columns = NS.ItemListColumns

local ROW_HEIGHT = 31
local ICON_SIZE = 23
local ICON_FRAME_SIZE = 29
local PROFESSION_QUALITY_ICON_SIZE = 22
local BINDING_ICON_SIZE = 22
local ICON_LEFT_OFFSET = 3
local ICON_TEX_COORD_LEFT = 0.08
local ICON_TEX_COORD_RIGHT = 0.92
local ICON_TEX_COORD_TOP = 0.08
local ICON_TEX_COORD_BOTTOM = 0.92
local ROW_TEXT_SIZE = 16
local COOLDOWN_TEXT_FONT = "NumberFontNormalSmall"
local FONT_STRING_LAYER = "OVERLAY"
local DEFAULT_HIGHLIGHT_COLOR_R = 1
local DEFAULT_HIGHLIGHT_COLOR_G = 1
local DEFAULT_HIGHLIGHT_COLOR_B = 1
local DEFAULT_ICON_BORDER_COLOR_R = 0.55
local DEFAULT_ICON_BORDER_COLOR_G = 0.55
local DEFAULT_ICON_BORDER_COLOR_B = 0.55
local ICON_BORDER_ALPHA = 1
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
local BINDING_ICON_LAYER = "ARTWORK"
local BINDING_ICON_SUBLEVEL = 7
local ROW_HIGHLIGHT_LAYER = "BACKGROUND"
local ROW_ICON_LAYER = "ARTWORK"
local ROW_ICON_SUBLEVEL = 5
local ICON_BORDER_LAYER = "ARTWORK"
local ICON_BORDER_SUBLEVEL = 7
local ITEM_BUTTON_FRAME_TYPE = "Button"
local ITEM_BUTTON_TEMPLATE = "ContainerFrameItemButtonTemplate"
local ITEM_BUTTON_FRAME_LEVEL_OFFSET = 10
local GCD_MAX_DURATION = 2
local COOLDOWN_TEXT_UPDATE_INTERVAL = 0.1
local COOLDOWN_CACHE_TTL = 0.2
local FALLBACK_ITEM_ICON = 134400
local ITEM_BUTTON_GLOBAL_NAME_PREFIX = "YvBagsItemListButton"

local buttonCount = 0
local cooldownCache = {}

local function GetPrimaryFont()
    return NS.Media and NS.Media.GetPrimaryFont and NS.Media.GetPrimaryFont() or STANDARD_TEXT_FONT
end

local function IsTextColumn(column)
    return column.key ~= "icon" and column.key ~= "binding" and column.key ~= "professionQuality"
end

local function GetRightClipPadding(row)
    return row.rightClipPadding or 0
end

-- Row color helpers
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

    local color = Columns.GetItemIconBorderColor and Columns.GetItemIconBorderColor(item)
    if not color then
        color = item and item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    end

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

-- Row layout
local function LayoutRow(row)
    local columns = Columns.GetColumns()
    local columnGap = Columns.GetColumnGap()
    local xOffset = 0
    local contentFrame = row.contentClip or row

    if row.contentClip then
        row.contentClip:ClearAllPoints()
        row.contentClip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.contentClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -GetRightClipPadding(row), 0)
    end

    if row.cooldownShade then
        row.cooldownShade:ClearAllPoints()
        row.cooldownShade:SetPoint("TOPLEFT", row, "TOPLEFT", COOLDOWN_SHADE_TOP_LEFT_X_OFFSET, COOLDOWN_SHADE_TOP_LEFT_Y_OFFSET)
        row.cooldownShade:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", COOLDOWN_SHADE_BOTTOM_LEFT_X_OFFSET, COOLDOWN_SHADE_BOTTOM_LEFT_Y_OFFSET)
    end

    for _, column in ipairs(columns) do
        local columnCenterX = xOffset + (column.width / 2)

        if column.key == "icon" then
            local iconCenterX = xOffset + ICON_LEFT_OFFSET + (ICON_FRAME_SIZE / 2)
            if row.iconBorder then
                row.iconBorder:ClearAllPoints()
                row.iconBorder:SetPoint("CENTER", contentFrame, "LEFT", iconCenterX, 0)
                row.iconBorder:SetSize(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
            end

            if row.icon then
                row.icon:ClearAllPoints()
                row.icon:SetPoint("CENTER", contentFrame, "LEFT", iconCenterX, 0)
                row.icon:SetSize(ICON_SIZE, ICON_SIZE)
            end

            if row.iconCooldownText and row.icon then
                row.iconCooldownText:ClearAllPoints()
                row.iconCooldownText:SetAllPoints(row.icon)
            end
        elseif column.key == "binding" and row.bindingIcon then
            row.bindingIcon:ClearAllPoints()
            row.bindingIcon:SetPoint("CENTER", contentFrame, "LEFT", columnCenterX, 0)
        elseif column.key == "professionQuality" and row.professionQualityIcon then
            row.professionQualityIcon:ClearAllPoints()
            row.professionQualityIcon:SetPoint("CENTER", contentFrame, "LEFT", columnCenterX, 0)
        end

        if IsTextColumn(column) then
            local text = row.text[column.key]
            text:ClearAllPoints()
            text:SetPoint("LEFT", contentFrame, "LEFT", xOffset, 0)
            text:SetSize(column.width, ROW_HEIGHT)
            text:SetJustifyH(column.justify or "LEFT")
        end

        xOffset = xOffset + column.width + columnGap
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
    row.cooldownTextElapsed = nil
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

local function RefreshRowCooldown(row, updateText)
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
        rowWidth = Columns.GetContentWidth()
    end

    if row.cooldownShade then
        row.cooldownShade:SetWidth(math.max(1, rowWidth * remainingRatio))
        row.cooldownShade:Show()
    end

    if updateText and row.iconCooldownText then
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
    row.cooldownTextElapsed = (row.cooldownTextElapsed or 0) + elapsed
    local updateText = row.cooldownTextElapsed >= COOLDOWN_TEXT_UPDATE_INTERVAL

    if updateText then
        row.cooldownTextElapsed = 0
    end

    RefreshRowCooldown(row, updateText)
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
    row.cooldownTextElapsed = 0
    RefreshRowCooldown(row, true)
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
        if region ~= button.row and region ~= button:GetParent() and type(region) == "table" and region.Hide then
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
    local columns = Columns.GetColumns()

    row:SetHeight(ROW_HEIGHT)
    if row.SetClipsChildren then
        row:SetClipsChildren(true)
    end
    row:EnableMouse(false)
    row:SetID(0)

    row.highlight = row:CreateTexture(nil, ROW_HIGHLIGHT_LAYER)
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(DEFAULT_HIGHLIGHT_COLOR_R, DEFAULT_HIGHLIGHT_COLOR_G, DEFAULT_HIGHLIGHT_COLOR_B, DEFAULT_HIGHLIGHT_ALPHA)
    row.highlight:Hide()

    row.contentClip = CreateFrame("Frame", nil, row)
    row.contentClip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.contentClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -GetRightClipPadding(row), 0)
    if row.contentClip.SetClipsChildren then
        row.contentClip:SetClipsChildren(true)
    end

    row.icon = row.contentClip:CreateTexture(nil, ROW_ICON_LAYER)
    row.icon:SetDrawLayer(ROW_ICON_LAYER, ROW_ICON_SUBLEVEL)
    row.icon:SetTexCoord(ICON_TEX_COORD_LEFT, ICON_TEX_COORD_RIGHT, ICON_TEX_COORD_TOP, ICON_TEX_COORD_BOTTOM)
    row.icon:Hide()

    row.iconBorder = row.contentClip:CreateTexture(nil, ICON_BORDER_LAYER)
    row.iconBorder:SetDrawLayer(ICON_BORDER_LAYER, ICON_BORDER_SUBLEVEL)
    row.iconBorder:SetTexture(NS.Media and NS.Media.GetIconBorderTexture and NS.Media.GetIconBorderTexture() or nil)
    row.iconBorder:Hide()

    row.cooldownShade = row:CreateTexture(nil, COOLDOWN_SHADE_LAYER)
    row.cooldownShade:SetDrawLayer(COOLDOWN_SHADE_LAYER, COOLDOWN_SHADE_SUBLEVEL)
    row.cooldownShade:SetColorTexture(COOLDOWN_SHADE_COLOR_R, COOLDOWN_SHADE_COLOR_G, COOLDOWN_SHADE_COLOR_B, ROW_COOLDOWN_ALPHA)
    row.cooldownShade:Hide()

    buttonCount = buttonCount + 1
    row.itemButton = CreateFrame(ITEM_BUTTON_FRAME_TYPE, ITEM_BUTTON_GLOBAL_NAME_PREFIX .. buttonCount, row, ITEM_BUTTON_TEMPLATE)
    row.itemButton.row = row
    if NS.ItemTooltip then
        NS.ItemTooltip.RegisterRowButton(row.itemButton)
    end
    ConfigureNativeItemButton(row.itemButton, row)
    row.itemButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.itemButton:RegisterForDrag("LeftButton")
    row.itemButton:Show()
    SuppressNativeItemButtonVisuals(row.itemButton)
    row.itemButton:HookScript("OnEnter", function(button)
        local buttonRow = button.row
        buttonRow.highlight:Show()
    end)
    row.itemButton:HookScript("OnLeave", function(button)
        local buttonRow = button.row
        buttonRow.highlight:Hide()
    end)

    row.text = {}
    for _, column in ipairs(columns) do
        if IsTextColumn(column) then
            local text = row.contentClip:CreateFontString(nil, FONT_STRING_LAYER)
            text:SetFont(GetPrimaryFont(), ROW_TEXT_SIZE)
            text:SetJustifyV("MIDDLE")
            text:SetWordWrap(false)
            text:SetMaxLines(1)
            if column.key ~= "name" then
                Columns.SetDefaultTextColor(text)
            end
            row.text[column.key] = text
        end
    end

    row.professionQualityIcon = row.contentClip:CreateTexture(nil, PROFESSION_QUALITY_LAYER)
    row.professionQualityIcon:SetSize(PROFESSION_QUALITY_ICON_SIZE, PROFESSION_QUALITY_ICON_SIZE)
    row.professionQualityIcon:SetDrawLayer(PROFESSION_QUALITY_LAYER, PROFESSION_QUALITY_SUBLEVEL)
    row.professionQualityIcon:Hide()

    row.bindingIcon = row.contentClip:CreateTexture(nil, BINDING_ICON_LAYER)
    row.bindingIcon:SetSize(BINDING_ICON_SIZE, BINDING_ICON_SIZE)
    row.bindingIcon:SetDrawLayer(BINDING_ICON_LAYER, BINDING_ICON_SUBLEVEL)
    row.bindingIcon:Hide()

    row.iconCooldownText = row.contentClip:CreateFontString(nil, COOLDOWN_TEXT_LAYER, COOLDOWN_TEXT_FONT)
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

-- Public row API
function ItemRow.GetRowHeight()
    return ROW_HEIGHT
end

function ItemRow.ClearCooldownCache()
    wipe(cooldownCache)
end

function ItemRow.RefreshCooldown(row)
    if row.item then
        UpdateRowCooldown(row, row.item)
    end
end

function ItemRow.Render(row, item)
    if not row.rowInitialized then
        InitializeRow(row)
    end

    local columns = Columns.GetColumns()

    row.item = item
    UpdateRowHighlightColor(row, item)
    UpdateIconBorderColor(row, item)
    UpdateItemButton(row.itemButton, item)

    if row.icon then
        row.icon:SetTexture(item.icon or FALLBACK_ITEM_ICON)
        row.icon:SetDesaturated(item.isLocked)
        row.icon:Show()
    end

    local professionQualityAtlas = Columns.GetProfessionQualityAtlas(item)
    if professionQualityAtlas then
        row.professionQualityIcon:SetAtlas(professionQualityAtlas, false)
        row.professionQualityIcon:Show()
    else
        row.professionQualityIcon:Hide()
    end

    local bindingIconInfo = Columns.GetBindingIconInfo(item)
    if bindingIconInfo then
        local bindingIconSize = bindingIconInfo.size or BINDING_ICON_SIZE
        row.bindingIcon:SetSize(bindingIconSize, bindingIconSize)
        if bindingIconInfo.atlas then
            row.bindingIcon:SetAtlas(bindingIconInfo.atlas, false)
        else
            row.bindingIcon:SetTexture(bindingIconInfo.texture)
            row.bindingIcon:SetTexCoord(0, 1, 0, 1)
        end
        row.bindingIcon:SetDesaturated(bindingIconInfo.desaturated)
        if bindingIconInfo.color then
            row.bindingIcon:SetVertexColor(bindingIconInfo.color.r, bindingIconInfo.color.g, bindingIconInfo.color.b, 1)
        else
            row.bindingIcon:SetVertexColor(1, 1, 1, 1)
        end
        row.bindingIcon:Show()
    else
        row.bindingIcon:Hide()
    end

    for _, column in ipairs(columns) do
        if IsTextColumn(column) then
            local text = row.text[column.key]
            text:SetText(Columns.FormatColumn(item, column.key))
            Columns.ApplyTextColor(text, column.key, item)
        end
    end

    UpdateRowCooldown(row, item)
end

function ItemRow.Reset(row)
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

    if row.itemButton then
        ResetItemButton(row.itemButton)
    end

    if row.professionQualityIcon then
        row.professionQualityIcon:Hide()
    end

    if row.bindingIcon then
        row.bindingIcon:SetSize(BINDING_ICON_SIZE, BINDING_ICON_SIZE)
        row.bindingIcon:SetTexture(nil)
        row.bindingIcon:SetTexCoord(0, 1, 0, 1)
        row.bindingIcon:SetDesaturated(false)
        row.bindingIcon:SetVertexColor(1, 1, 1, 1)
        row.bindingIcon:Hide()
    end

    if row.text then
        for _, text in pairs(row.text) do
            text:SetText("")
        end
    end
end

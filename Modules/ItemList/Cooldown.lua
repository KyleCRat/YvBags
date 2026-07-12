local _, NS = ...

-- Visible-row cooldown contract, including secret-safe timing and name prefixes.
local Cooldown = {}
NS.ItemRowCooldown = Cooldown

local Columns = NS.ItemListColumns

local GCD_MAX_DURATION = 2
local TEXT_UPDATE_INTERVAL = 0.1
local CACHE_TTL = 0.2
local SHADE_ALPHA = 0.38
local SHADE_LAYER = "OVERLAY"
local SHADE_SUBLEVEL = 1

local cooldownCache = {}

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function IsSafeNumber(value)
    return not IsSecretValue(value) and type(value) == "number"
end

local function ShouldShowInName()
    return NS.db:Get("display", "showCooldownsInName") ~= false
end

local function FormatRemaining(remaining)
    if not IsSafeNumber(remaining) then
        return ""
    end

    local seconds = math.max(0, math.ceil(remaining))
    if seconds >= 3600 then
        return ("%dh"):format(math.ceil(seconds / 3600))
    elseif seconds >= 60 then
        return ("%dm"):format(math.ceil(seconds / 60))
    end

    return ("%ds"):format(seconds)
end

function Cooldown.SetName(row, cooldownText)
    local nameText = row.text and row.text.name
    if not nameText then
        return
    end

    if not row.item then
        nameText:SetText("")
        return
    end

    local itemName = Columns.FormatColumn(row.item, "name")
    if cooldownText and cooldownText ~= "" then
        nameText:SetText(("(%s) %s"):format(cooldownText, itemName))
    else
        nameText:SetText(itemName)
    end
end

function Cooldown.Clear(row)
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

    Cooldown.SetName(row)
end

local function Refresh(row, updateText)
    local startTime = row.cooldownStart
    local duration = row.cooldownDuration
    local modRate = row.cooldownModRate or 1

    if not IsSafeNumber(startTime) or not IsSafeNumber(duration) or not IsSafeNumber(modRate) or duration <= 0 or modRate <= 0 then
        Cooldown.Clear(row)
        return
    end

    local remaining = duration - ((GetTime() - startTime) * modRate)
    if remaining <= 0 then
        Cooldown.Clear(row)
        return
    end

    local remainingRatio = math.max(0, math.min(1, remaining / duration))
    local rowWidth = row:GetWidth()
    if not IsSafeNumber(rowWidth) or rowWidth <= 0 then
        rowWidth = Columns.GetContentWidth()
    end

    row.cooldownShade:SetWidth(math.max(1, rowWidth * remainingRatio))
    row.cooldownShade:Show()

    if updateText then
        if row.cooldownIsGCD or not ShouldShowInName() then
            Cooldown.SetName(row)
        else
            Cooldown.SetName(row, FormatRemaining(remaining / modRate))
        end
    end
end

local function OnUpdate(row, elapsed)
    row.cooldownTextElapsed = (row.cooldownTextElapsed or 0) + elapsed
    local updateText = row.cooldownTextElapsed >= TEXT_UPDATE_INTERVAL
    if updateText then
        row.cooldownTextElapsed = 0
    end

    Refresh(row, updateText)
end

local function GetItemCooldown(item)
    if not item or not C_Container or not C_Container.GetContainerItemCooldown then
        return nil
    end

    local now = GetTime()
    local cacheKey = item.locationKey or item.bagSlotText
    local cached = cacheKey and cooldownCache[cacheKey]
    if cached and (now - cached.checkedAt) <= CACHE_TTL then
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

    local remaining = duration - ((now - startTime) * modRate)
    if remaining <= 0 then
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

function Cooldown.Update(row, item)
    local startTime, duration, modRate, isGCD = GetItemCooldown(item)
    if not startTime then
        Cooldown.Clear(row)
        return
    end

    row.cooldownStart = startTime
    row.cooldownDuration = duration
    row.cooldownModRate = modRate
    row.cooldownIsGCD = isGCD
    row.cooldownTextElapsed = 0
    Refresh(row, true)
    row:SetScript("OnUpdate", OnUpdate)
end

function Cooldown.Refresh(row)
    if row.item then
        Cooldown.Update(row, row.item)
    end
end

function Cooldown.ClearCache()
    wipe(cooldownCache)
end

function Cooldown.CreateShade(row)
    local shade = row:CreateTexture(nil, SHADE_LAYER)
    shade:SetDrawLayer(SHADE_LAYER, SHADE_SUBLEVEL)
    shade:SetColorTexture(0, 0, 0, SHADE_ALPHA)
    shade:Hide()
    row.cooldownShade = shade
end

function Cooldown.LayoutShade(row)
    row.cooldownShade:ClearAllPoints()
    row.cooldownShade:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.cooldownShade:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
end

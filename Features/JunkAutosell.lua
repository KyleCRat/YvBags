local _, NS = ...

local JunkAutosell = {}
NS.JunkAutosell = JunkAutosell

local SELL_DELAY_SECONDS = 0.1

local merchantOpen = false
local sellScheduled = false

local function IsEnabled()
    return NS.db and NS.db:Get("features", "autosellGrayJunk") == true
end

local function CanSellJunk()
    return merchantOpen
        and IsEnabled()
        and C_MerchantFrame
        and C_MerchantFrame.SellAllJunkItems
        and (not C_MerchantFrame.IsSellAllJunkEnabled or C_MerchantFrame.IsSellAllJunkEnabled())
        and (not C_MerchantFrame.GetNumJunkItems or C_MerchantFrame.GetNumJunkItems() > 0)
end

local function SellJunk()
    sellScheduled = false

    if not CanSellJunk() then
        return
    end

    C_MerchantFrame.SellAllJunkItems()
end

function JunkAutosell.ScheduleSell()
    if sellScheduled or not CanSellJunk() then
        return
    end

    sellScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(SELL_DELAY_SECONDS, SellJunk)
    else
        SellJunk()
    end
end

local function OnMerchantShow()
    merchantOpen = true
    JunkAutosell.ScheduleSell()
end

local function OnMerchantUpdate()
    JunkAutosell.ScheduleSell()
end

local function OnMerchantClosed()
    merchantOpen = false
    sellScheduled = false
end

NS:RegisterInitCallback(function()
    NS:RegisterEventHandler("MERCHANT_SHOW", OnMerchantShow)
    NS:RegisterEventHandler("MERCHANT_UPDATE", OnMerchantUpdate)
    NS:RegisterEventHandler("MERCHANT_CLOSED", OnMerchantClosed)

    if NS.db and NS.db.RegisterCallback then
        NS.db:RegisterCallback("features.autosellGrayJunk", function(_, enabled)
            if enabled == true then
                JunkAutosell.ScheduleSell()
            end
        end)
    end
end)

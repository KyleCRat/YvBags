local _, NS = ...

-- Profile-backed bag and bank list-setting ownership.
local ListSettings = {}
NS.ItemListSettings = ListSettings

ListSettings.Scopes = {
    Bags = "bags",
    Bank = "bank",
}

local LIST_KEYS = {
    "sortKey",
    "sortAscending",
    "secondarySortKey",
    "secondarySortAscending",
    "groupKey",
}

local function IsBankScope(scope)
    return scope == ListSettings.Scopes.Bank
end

function ListSettings.IsBankMirroring()
    return NS.db:Get("bank", "useBagListSettings") ~= false
end

local function UsesBagSettings(scope)
    return not IsBankScope(scope) or ListSettings.IsBankMirroring()
end

function ListSettings.GetListValue(scope, key)
    if UsesBagSettings(scope) then
        return NS.db:Get("list", key)
    end

    return NS.db:Get("bank", "list", key)
end

function ListSettings.SetListValue(scope, key, value)
    if UsesBagSettings(scope) then
        NS.db:Set("list", key, value)
    else
        NS.db:Set("bank", "list", key, value)
    end
end

function ListSettings.GetPinDisplayMode(scope)
    if UsesBagSettings(scope) then
        return NS.db:Get("pins", "displayMode")
    end

    return NS.db:Get("bank", "pins", "displayMode")
end

function ListSettings.SetPinDisplayMode(scope, displayMode)
    if UsesBagSettings(scope) then
        NS.db:Set("pins", "displayMode", displayMode)
    else
        NS.db:Set("bank", "pins", "displayMode", displayMode)
    end
end

function ListSettings.SetBankMirroring(enabled)
    enabled = enabled == true

    if not enabled
        and NS.db:Get("bank", "independentInitialized") ~= true then
        for index = 1, #LIST_KEYS do
            local key = LIST_KEYS[index]
            NS.db:Set("bank", "list", key, NS.db:Get("list", key))
        end

        NS.db:Set(
            "bank",
            "pins",
            "displayMode",
            NS.db:Get("pins", "displayMode")
        )
        NS.db:Set("bank", "independentInitialized", true)
    end

    NS.db:Set("bank", "useBagListSettings", enabled)
end

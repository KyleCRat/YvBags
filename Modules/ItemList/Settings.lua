local _, NS = ...

-- Profile-backed bag and bank list-setting ownership.
local ListSettings = {}
NS.ItemListSettings = ListSettings

local Columns = NS.ItemListColumns

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

-- Column transactions use detached, normalized configurations. Reads never
-- rewrite a profile, and the complete registry remains available to sorting.
local function IsColumnHidden(column, hidden)
    if type(hidden) ~= "table" then
        return column.defaultHidden == true
    end
    local value = hidden[column.key]
    if type(value) ~= "boolean" then
        return column.defaultHidden == true
    end
    return value
end

function ListSettings.NormalizeColumns(value)
    value = type(value) == "table" and value or {}
    local order = type(value.order) == "table" and value.order or {}
    local hidden = type(value.hidden) == "table" and value.hidden or {}
    local widths = type(value.widths) == "table" and value.widths or {}
    local result = { order = {}, hidden = {}, widths = {} }
    local included = {}

    for _, key in ipairs(order) do
        if type(key) == "string" and Columns.GetColumn(key) and not included[key] then
            result.order[#result.order + 1] = key
            included[key] = true
        end
    end

    for _, column in ipairs(Columns.GetAvailableColumns()) do
        local key = column.key
        if not included[key] then
            result.order[#result.order + 1] = key
        end
        local isHidden = IsColumnHidden(column, hidden)
        if isHidden or column.defaultHidden then
            -- Retain explicit false so showing a default-hidden column persists.
            result.hidden[key] = isHidden
        end
        local width = Columns.ClampWidth(column, widths[key])
        if width ~= column.width then
            result.widths[key] = width
        end
    end
    return result
end

function ListSettings.GetColumns(scope)
    return ListSettings.NormalizeColumns(ListSettings.GetListValue(scope, "columns"))
end

function ListSettings.IsColumnVisible(scope, key)
    local column = Columns.GetColumn(key)
    if not column then
        return false
    end
    -- Menu predicates read the current effective profile without constructing
    -- a transaction snapshot or retaining one across profile/mirroring changes.
    local value = ListSettings.GetListValue(scope, "columns")
    return not IsColumnHidden(column, type(value) == "table" and value.hidden)
end

function ListSettings.ColumnsEqual(left, right)
    if #left.order ~= #right.order then
        return false
    end
    for index, key in ipairs(left.order) do
        if right.order[index] ~= key or left.hidden[key] ~= right.hidden[key]
            or left.widths[key] ~= right.widths[key] then
            return false
        end
    end
    return true
end

function ListSettings.CanEditColumns()
    return not InCombatLockdown()
end

local function CommitColumns(scope, config)
    if not ListSettings.CanEditColumns() then
        return false
    end
    ListSettings.SetListValue(scope, "columns", config)
    return true
end

function ListSettings.SetColumnVisible(scope, key, visible)
    local column = Columns.GetColumn(key)
    if not column then
        return false
    end
    local config = ListSettings.GetColumns(scope)
    config.hidden[key] = not visible
    if visible and not column.defaultHidden then
        config.hidden[key] = nil
    end
    return CommitColumns(scope, config)
end

function ListSettings.SetColumnWidth(scope, key, width)
    local column = Columns.GetColumn(key)
    if not column then
        return false
    end
    local config = ListSettings.GetColumns(scope)
    width = Columns.ClampWidth(column, width)
    config.widths[key] = width ~= column.width and width or nil
    return CommitColumns(scope, config)
end

function ListSettings.MoveColumn(scope, key, targetKey, after)
    if key == targetKey or not Columns.GetColumn(key) or not Columns.GetColumn(targetKey) then
        return false
    end
    local config = ListSettings.GetColumns(scope)
    for index, entryKey in ipairs(config.order) do
        if entryKey == key then
            table.remove(config.order, index)
            break
        end
    end
    for index, entryKey in ipairs(config.order) do
        if entryKey == targetKey then
            table.insert(config.order, index + (after and 1 or 0), key)
            break
        end
    end
    return CommitColumns(scope, config)
end

function ListSettings.ResetColumns(scope)
    return CommitColumns(scope, ListSettings.NormalizeColumns(nil))
end

function ListSettings.SetBankMirroring(enabled)
    enabled = enabled == true

    if not enabled
        and NS.db:Get("bank", "independentInitialized") ~= true then
        for index = 1, #LIST_KEYS do
            local key = LIST_KEYS[index]
            NS.db:Set("bank", "list", key, NS.db:Get("list", key))
        end

        NS.db:Set("bank", "list", "columns", ListSettings.GetColumns(ListSettings.Scopes.Bags))

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

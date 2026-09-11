local _, NS = ...

-- Scope-aware column actions shared by headers and the Settings canvases.
local ColumnMenu = {}
NS.ItemListColumnMenu = ColumnMenu

local Columns = NS.ItemListColumns
local ListSettings = NS.ItemListSettings

function ColumnMenu.PopulateColumnActions(rootDescription, scope, columnKey)
    local column = Columns.GetColumn(columnKey)
    local label = Columns.GetLabel(column)
    rootDescription:CreateButton("Hide " .. label, function()
        ListSettings.SetColumnVisible(scope, columnKey, false)
        return MenuResponse.Refresh
    end):SetEnabled(function()
        return ListSettings.CanEditColumns() and not ListSettings.GetColumns(scope).hidden[columnKey]
    end)

    local reset = rootDescription:CreateButton("Reset " .. label, function()
        ListSettings.SetColumnWidth(scope, columnKey, column.width)
        return MenuResponse.Refresh
    end)
    reset:SetEnabled(ListSettings.CanEditColumns)
    reset:SetTooltip(function(tooltip)
        tooltip:SetText("Reset " .. label)
        tooltip:AddLine("Restore this column's original width. Its order and visibility are unchanged.", 1, 1, 1, true)
    end)
end

function ColumnMenu.Populate(rootDescription, scope)
    if InCombatLockdown() then
        rootDescription:CreateTitle("Column editing is unavailable during combat.")
    end

    local function IsVisible(key)
        return not ListSettings.GetColumns(scope).hidden[key]
    end
    local function ToggleVisible(key)
        ListSettings.SetColumnVisible(scope, key, not IsVisible(key))
        return MenuResponse.Refresh
    end

    for _, column in ipairs(Columns.GetAvailableColumns()) do
        rootDescription:CreateCheckbox(
            Columns.GetLabel(column), IsVisible, ToggleVisible, column.key
        ):SetEnabled(ListSettings.CanEditColumns)
    end

    rootDescription:CreateDivider()
    local reset = rootDescription:CreateButton("Reset Columns", function()
        ListSettings.ResetColumns(scope)
        return MenuResponse.Refresh
    end)
    reset:SetEnabled(ListSettings.CanEditColumns)
    reset:SetTooltip(function(tooltip)
        tooltip:SetText("Reset Columns")
        tooltip:AddLine("Restore the original column visibility, order, and widths. Other settings are unchanged.", 1, 1, 1, true)
        if ListSettings.IsBankMirroring() then
            tooltip:AddLine("Bags and Bank share this layout while Use Bag List Settings is enabled.", 1, 0.82, 0, true)
        end
    end)
end

function ColumnMenu.Open(owner, scope)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        ColumnMenu.Populate(rootDescription, scope)
    end)
end

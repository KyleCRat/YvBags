local _, NS = ...

local AddonSettings = {}
NS.Settings = AddonSettings

local ADDON_NAME = NS.ADDON_NAME

local SETTING_REPLACE_BLIZZARD_BAGS = ADDON_NAME .. "_REPLACE_BLIZZARD_BAGS"
local SETTING_AUTOSELL_GRAY_JUNK = ADDON_NAME .. "_AUTOSELL_GRAY_JUNK"
local SETTING_SHOW_COOLDOWNS_IN_NAME = ADDON_NAME .. "_SHOW_COOLDOWNS_IN_NAME"
local SETTING_FRAME_SCALE = ADDON_NAME .. "_FRAME_SCALE"
local SETTING_GROUP_KEY = ADDON_NAME .. "_GROUP_KEY"
local SETTING_PRIMARY_SORT_KEY = ADDON_NAME .. "_PRIMARY_SORT_KEY"
local SETTING_PRIMARY_SORT_DIRECTION = ADDON_NAME .. "_PRIMARY_SORT_DIRECTION"
local SETTING_SECONDARY_SORT_KEY = ADDON_NAME .. "_SECONDARY_SORT_KEY"
local SETTING_SECONDARY_SORT_DIRECTION = ADDON_NAME .. "_SECONDARY_SORT_DIRECTION"

local SCALE_MIN_PERCENT = 50
local SCALE_MAX_PERCENT = 150
local SCALE_STEP_PERCENT = 5
local NO_SECONDARY_SORT_LABEL = "None"
local ASCENDING_LABEL = "Ascending"
local DESCENDING_LABEL = "Descending"

local function GetItemList()
    return NS.frame and NS.frame.itemList
end

local function NotifySettingChanged(variable)
    if Settings and Settings.NotifyUpdate then
        Settings.NotifyUpdate(variable)
    end
end

local function AddSection(layout, title)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
    end
end

local function GetSortLabel(sortKey)
    if NS.ItemListColumns and NS.ItemListColumns.GetSortLabel then
        return NS.ItemListColumns.GetSortLabel(sortKey)
    end

    return sortKey or ""
end

local function GetGroupLabel(groupKey)
    if NS.ItemListModel and NS.ItemListModel.GetGroupLabel then
        return NS.ItemListModel.GetGroupLabel(groupKey)
    end

    return groupKey or ""
end

local function GetBooleanSetting(section, key)
    return NS.db and NS.db:Get(section, key) == true
end

local function SetBooleanSetting(section, key, value)
    if NS.db then
        NS.db:Set(section, key, value == true)
    end
end

local function FormatScalePercent(value)
    return ("%d%%"):format(math.floor((tonumber(value) or 0) + 0.5))
end

local function GetFrameScalePercent()
    local scale = NS.defaults.character.frame.scale
    if NS.charDB then
        scale = NS.charDB:Get("frame", "scale") or scale
    end

    return math.floor((scale * 100) + 0.5)
end

local function SetFrameScalePercent(value)
    value = math.max(SCALE_MIN_PERCENT, math.min(SCALE_MAX_PERCENT, tonumber(value) or 100))

    if NS.SetFrameScale then
        NS:SetFrameScale(value / 100)
    elseif NS.charDB then
        NS.charDB:Set("frame", "scale", value / 100)
    end
end

local function SetReplaceBlizzardBags(value)
    SetBooleanSetting("features", "replaceBlizzardBags", value)

    if value ~= false and NS.BlizzardBags then
        NS.BlizzardBags.HideBlizzardBags()
    end
end

local function SetAutosellGrayJunk(value)
    SetBooleanSetting("features", "autosellGrayJunk", value)

    if value == true and NS.JunkAutosell then
        NS.JunkAutosell.ScheduleSell()
    end
end

local function SetShowCooldownsInName(value)
    SetBooleanSetting("display", "showCooldownsInName", value)

    local list = GetItemList()
    if list and list.RefreshVisibleRows then
        list:RefreshVisibleRows()
    end
end

local function GetListValue(key)
    return NS.db and NS.db:Get("list", key)
end

local function SetStoredPrimarySort(sortKey)
    local ListModel = NS.ItemListModel
    sortKey = ListModel.NormalizeSortKey(sortKey)
    NS.db:Set("list", "sortKey", sortKey)

    if sortKey == ListModel.GetManualSortKey() then
        NS.db:Set("list", "sortAscending", true)
        NS.db:Set("list", "secondarySortKey", ListModel.GetNoSecondarySortKey())
        NS.db:Set("list", "secondarySortAscending", true)
        NotifySettingChanged(SETTING_PRIMARY_SORT_DIRECTION)
        NotifySettingChanged(SETTING_SECONDARY_SORT_KEY)
        NotifySettingChanged(SETTING_SECONDARY_SORT_DIRECTION)
    end
end

local function SetPrimarySort(sortKey)
    local ListModel = NS.ItemListModel
    sortKey = ListModel.NormalizeSortKey(sortKey)

    local list = GetItemList()
    if list and list.SetSort then
        list:SetSort(sortKey, GetListValue("sortAscending") ~= false)
    else
        SetStoredPrimarySort(sortKey)
    end

    if sortKey == ListModel.GetManualSortKey() then
        NotifySettingChanged(SETTING_PRIMARY_SORT_DIRECTION)
        NotifySettingChanged(SETTING_SECONDARY_SORT_KEY)
        NotifySettingChanged(SETTING_SECONDARY_SORT_DIRECTION)
    end
end

local function SetPrimarySortDirection(sortAscending)
    sortAscending = sortAscending == true

    local ListModel = NS.ItemListModel
    if ListModel.NormalizeSortKey(GetListValue("sortKey")) == ListModel.GetManualSortKey() then
        sortAscending = true
    end

    NS.db:Set("list", "sortAscending", sortAscending)

    local list = GetItemList()
    if list and list.SetSort then
        list:SetSort(GetListValue("sortKey"), sortAscending)
    end
end

local function SetSecondarySort(sortKey)
    local list = GetItemList()
    if list and list.SetSecondarySort then
        list:SetSecondarySort(sortKey, GetListValue("secondarySortAscending") ~= false)
        return
    end

    local ListModel = NS.ItemListModel
    sortKey = ListModel.NormalizeSecondarySortKey(sortKey)
    if not ListModel.IsSecondarySortEnabled(sortKey, GetListValue("sortKey")) then
        sortKey = ListModel.GetNoSecondarySortKey()
    end

    NS.db:Set("list", "secondarySortKey", sortKey)
end

local function SetSecondarySortDirection(sortAscending)
    sortAscending = sortAscending == true
    NS.db:Set("list", "secondarySortAscending", sortAscending)

    local list = GetItemList()
    if list and list.SetSecondarySortDirection then
        list:SetSecondarySortDirection(sortAscending)
    end
end

local function SetGroup(groupKey)
    local list = GetItemList()
    if list and list.SetGroup then
        list:SetGroup(groupKey)
    else
        NS.db:Set("list", "groupKey", NS.ItemListModel.NormalizeGroupKey(groupKey))
    end
end

local function CreateSortOptions()
    local container = Settings.CreateControlTextContainer()
    for _, sortKey in ipairs(NS.ItemListModel.GetSortKeyList()) do
        container:Add(sortKey, GetSortLabel(sortKey))
    end

    return container:GetData()
end

local function CreateSecondarySortOptions()
    local container = Settings.CreateControlTextContainer()
    for _, sortKey in ipairs(NS.ItemListModel.GetSecondarySortKeyList()) do
        local label = sortKey == NS.ItemListModel.GetNoSecondarySortKey() and NO_SECONDARY_SORT_LABEL or GetSortLabel(sortKey)
        container:Add(sortKey, label)
    end

    return container:GetData()
end

local function CreateGroupOptions()
    local container = Settings.CreateControlTextContainer()
    for _, groupKey in ipairs(NS.ItemListModel.GetGroupKeyList()) do
        container:Add(groupKey, GetGroupLabel(groupKey))
    end

    return container:GetData()
end

local function CreateDirectionOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(true, ASCENDING_LABEL)
    container:Add(false, DESCENDING_LABEL)
    return container:GetData()
end

local function RegisterCheckbox(category, variable, name, defaultValue, getValue, setValue, tooltip)
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, name, defaultValue, getValue, setValue)
    Settings.CreateCheckbox(category, setting, tooltip)
    return setting
end

local function RegisterDropdown(category, variable, name, defaultValue, getValue, setValue, getOptions, tooltip, variableType)
    local setting = Settings.RegisterProxySetting(category, variable, variableType or Settings.VarType.String, name, defaultValue, getValue, setValue)
    Settings.CreateDropdown(category, setting, getOptions, tooltip)
    return setting
end

local function RegisterSlider(category, variable, name, defaultValue, getValue, setValue, minValue, maxValue, step, tooltip)
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Number, name, defaultValue, getValue, setValue)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)

    if options.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label and MinimalSliderWithSteppersMixin.Label.Right then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatScalePercent)
    end

    Settings.CreateSlider(category, setting, options, tooltip)
    return setting
end

function AddonSettings.Open()
    if Settings and Settings.OpenToCategory and AddonSettings.category then
        Settings.OpenToCategory(AddonSettings.category:GetID())
    end
end

function AddonSettings.NotifyFrameScaleChanged()
    NotifySettingChanged(SETTING_FRAME_SCALE)
end

function AddonSettings.Register()
    if AddonSettings.registered or not Settings or not Settings.RegisterVerticalLayoutCategory then
        return
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
    AddonSettings.category = category

    AddSection(layout, "General")
    RegisterCheckbox(
        category,
        SETTING_REPLACE_BLIZZARD_BAGS,
        "Replace Blizzard Bags",
        true,
        function() return NS.db:Get("features", "replaceBlizzardBags") ~= false end,
        SetReplaceBlizzardBags,
        ("Use %s for standard player bag open, close, and toggle actions."):format(ADDON_NAME)
    )
    RegisterCheckbox(
        category,
        SETTING_AUTOSELL_GRAY_JUNK,
        "Sell Gray Junk At Vendors",
        false,
        function() return GetBooleanSetting("features", "autosellGrayJunk") end,
        SetAutosellGrayJunk,
        "Automatically sell Blizzard gray-quality junk items when a merchant opens."
    )
    RegisterCheckbox(
        category,
        SETTING_SHOW_COOLDOWNS_IN_NAME,
        "Show Cooldowns In Item Names",
        true,
        function() return NS.db:Get("display", "showCooldownsInName") ~= false end,
        SetShowCooldownsInName,
        "Prefix item cooldown timers in the item name column."
    )
    RegisterSlider(
        category,
        SETTING_FRAME_SCALE,
        "Scale",
        NS.defaults.character.frame.scale * 100,
        GetFrameScalePercent,
        SetFrameScalePercent,
        SCALE_MIN_PERCENT,
        SCALE_MAX_PERCENT,
        SCALE_STEP_PERCENT,
        ("Resize the %s frame."):format(ADDON_NAME)
    )

    AddSection(layout, "List")
    RegisterDropdown(
        category,
        SETTING_GROUP_KEY,
        "Group By",
        NS.defaults.global.list.groupKey,
        function() return NS.ItemListModel.NormalizeGroupKey(GetListValue("groupKey")) end,
        SetGroup,
        CreateGroupOptions,
        "Choose how the list groups visible bag items."
    )
    RegisterDropdown(
        category,
        SETTING_PRIMARY_SORT_KEY,
        "Primary Sort",
        NS.defaults.global.list.sortKey,
        function() return NS.ItemListModel.NormalizeSortKey(GetListValue("sortKey")) end,
        SetPrimarySort,
        CreateSortOptions,
        "Choose the primary item sort order."
    )
    RegisterDropdown(
        category,
        SETTING_PRIMARY_SORT_DIRECTION,
        "Primary Sort Direction",
        true,
        function() return GetListValue("sortAscending") ~= false end,
        SetPrimarySortDirection,
        CreateDirectionOptions,
        "Choose the primary sort direction.",
        Settings.VarType.Boolean
    )
    RegisterDropdown(
        category,
        SETTING_SECONDARY_SORT_KEY,
        "Secondary Sort",
        NS.defaults.global.list.secondarySortKey,
        function() return NS.ItemListModel.NormalizeSecondarySortKey(GetListValue("secondarySortKey")) end,
        SetSecondarySort,
        CreateSecondarySortOptions,
        "Choose the secondary item sort order. Manual primary sorting disables secondary sorting."
    )
    RegisterDropdown(
        category,
        SETTING_SECONDARY_SORT_DIRECTION,
        "Secondary Sort Direction",
        true,
        function() return GetListValue("secondarySortAscending") ~= false end,
        SetSecondarySortDirection,
        CreateDirectionOptions,
        "Choose the secondary sort direction.",
        Settings.VarType.Boolean
    )

    Settings.RegisterAddOnCategory(category)
    AddonSettings.registered = true
end

NS:RegisterInitCallback(function()
    AddonSettings.Register()
end)

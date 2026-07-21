local _, NS = ...

local AddonSettings = {}
NS.Settings = AddonSettings

local ADDON_NAME = NS.ADDON_NAME

-- Setting IDs
local SETTING_REPLACE_BLIZZARD_BAGS = ADDON_NAME .. "_REPLACE_BLIZZARD_BAGS"
local SETTING_AUTOSELL_GRAY_JUNK = ADDON_NAME .. "_AUTOSELL_GRAY_JUNK"
local SETTING_SHOW_COOLDOWNS_IN_NAME = ADDON_NAME .. "_SHOW_COOLDOWNS_IN_NAME"
local SETTING_FRAME_SCALE = ADDON_NAME .. "_FRAME_SCALE"
local SETTING_GROUP_KEY = ADDON_NAME .. "_GROUP_KEY"
local SETTING_PRIMARY_SORT_KEY = ADDON_NAME .. "_PRIMARY_SORT_KEY"
local SETTING_PRIMARY_SORT_DIRECTION = ADDON_NAME .. "_PRIMARY_SORT_DIRECTION"
local SETTING_SECONDARY_SORT_KEY = ADDON_NAME .. "_SECONDARY_SORT_KEY"
local SETTING_SECONDARY_SORT_DIRECTION = ADDON_NAME .. "_SECONDARY_SORT_DIRECTION"
local SETTING_PIN_DISPLAY_MODE = ADDON_NAME .. "_PIN_DISPLAY_MODE"
local SETTING_ACTIVE_PROFILE = ADDON_NAME .. "_ACTIVE_PROFILE"

-- Control values and labels
local SCALE_MIN_PERCENT = 50
local SCALE_MAX_PERCENT = 150
local SCALE_STEP_PERCENT = 5
local NO_SECONDARY_SORT_LABEL = "None"
local ASCENDING_LABEL = "Ascending"
local DESCENDING_LABEL = "Descending"
local PIN_DISPLAY_TOP_LABEL = "Top Rows"
local PIN_DISPLAY_GROUP_LABEL = "Collapsible Group"
local PIN_DISPLAY_GROUP_TOP_LABEL = "Top of Groups"
local PIN_DISPLAY_NORMAL_LABEL = "Normal Sort Order"
local PROFILE_GLOBAL_TOKEN = "permanent:global"

local PERMANENT_PROFILE_LABELS = {
    character = "Character",
    spec = "Specialization",
    class = "Class",
    realm = "Realm",
    faction = "Faction",
    global = "Global",
}

local PROFILE_SETTING_VARIABLES = {
    SETTING_SHOW_COOLDOWNS_IN_NAME,
    SETTING_GROUP_KEY,
    SETTING_PIN_DISPLAY_MODE,
    SETTING_PRIMARY_SORT_KEY,
    SETTING_PRIMARY_SORT_DIRECTION,
    SETTING_SECONDARY_SORT_KEY,
    SETTING_SECONDARY_SORT_DIRECTION,
}

local PROFILE_DESCRIPTOR_EVENTS = {
    "OnProfileChanged",
    "OnProfileCreated",
    "OnProfileCopied",
    "OnProfileRenamed",
    "OnProfileDeleted",
    "OnProfileReset",
    "OnCharacterInfoChanged",
}

local profileDescriptors = {}
local profileRefsByToken = {}

-- Stored values and live UI dispatch
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
    return NS.ItemListColumns.GetSortLabel(sortKey)
end

local function GetGroupLabel(groupKey)
    return NS.ItemListModel.GetGroupLabel(groupKey)
end

local function GetBooleanSetting(database, section, key)
    return database:Get(section, key) == true
end

local function SetBooleanSetting(database, section, key, value)
    database:Set(section, key, value == true)
end

local function FormatScalePercent(value)
    return ("%d%%"):format(math.floor((tonumber(value) or 0) + 0.5))
end

local function GetFrameScalePercent()
    local scale = NS.charDB:Get("frame", "scale") or NS.defaults.character.frame.scale

    return math.floor((scale * 100) + 0.5)
end

local function SetFrameScalePercent(value)
    value = math.max(SCALE_MIN_PERCENT, math.min(SCALE_MAX_PERCENT, tonumber(value) or 100))
    NS.MainFrameGeometry.SetScale(value / 100)
end

local function SetReplaceBlizzardBags(value)
    SetBooleanSetting(NS.globalDB, "features", "replaceBlizzardBags", value)

    if value ~= false and NS.BlizzardBags then
        NS.BlizzardBags.HideBlizzardBags()
    end
end

local function SetAutosellGrayJunk(value)
    SetBooleanSetting(NS.globalDB, "features", "autosellGrayJunk", value)

    if value == true and NS.JunkAutosell then
        NS.JunkAutosell.ScheduleSell()
    end
end

local function SetShowCooldownsInName(value)
    SetBooleanSetting(NS.db, "display", "showCooldownsInName", value)

    local list = GetItemList()
    if list and list.RefreshVisibleRows then
        list:RefreshVisibleRows()
    end
end

local function GetListValue(key)
    return NS.db:Get("list", key)
end

-- List setting updates
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

local function SetPinDisplayMode(displayMode)
    NS.ItemPins.SetDisplayMode(displayMode)

    local list = GetItemList()
    if list then
        list:RefreshDataProvider(true)
    end
end

-- Dropdown option data
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

local function CreatePinDisplayOptions()
    local displayModes = NS.ItemPins.DisplayModes
    local container = Settings.CreateControlTextContainer()
    container:Add(displayModes.Top, PIN_DISPLAY_TOP_LABEL)
    container:Add(displayModes.Group, PIN_DISPLAY_GROUP_LABEL)
    container:Add(displayModes.TopOfGroups, PIN_DISPLAY_GROUP_TOP_LABEL)
    container:Add(displayModes.Normal, PIN_DISPLAY_NORMAL_LABEL)
    return container:GetData()
end

-- Profile descriptors and operations
local function GetProfileToken(profileRef)
    if profileRef.kind == "permanent" then
        return "permanent:" .. profileRef.profile
    end

    return "user:" .. profileRef.name
end

local function GetProfileLabel(descriptor)
    if descriptor.permanent then
        local profileType = descriptor.profileRef.profile
        local label = PERMANENT_PROFILE_LABELS[profileType] or descriptor.displayName

        if profileType == "global" then
            return label
        end

        return ("%s: %s"):format(label, descriptor.displayName)
    end

    if descriptor.nameCollision then
        return ("%s (User)"):format(descriptor.displayName)
    end

    return descriptor.displayName
end

local function RefreshProfileDescriptors()
    profileDescriptors = NS.profileManager:GetProfiles()
    profileRefsByToken = {}

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]
        profileRefsByToken[GetProfileToken(descriptor.profileRef)] = descriptor.profileRef
    end
end

local function FindProfileDescriptor(profileRef)
    local token = GetProfileToken(profileRef)

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]

        if GetProfileToken(descriptor.profileRef) == token then
            return descriptor
        end
    end

    return nil
end

local function ReportProfileError(action, errorCode)
    local messages = {
        INVALID_NAME = "The profile name is not valid UTF-8 or contains unsupported control characters.",
        PROFILE_EXISTS = "A profile with that name already exists.",
        PROFILE_NOT_FOUND = "That profile no longer exists.",
        ACTIVE_PROFILE = "The active profile cannot be deleted.",
    }
    NS:Print(("%s failed: %s"):format(action, messages[errorCode] or tostring(errorCode)))
end

local function GetActiveProfileToken()
    return GetProfileToken(NS.profileManager:GetActiveProfile().profileRef)
end

local function SetActiveProfileToken(token)
    local profileRef = profileRefsByToken[token]

    if not profileRef then
        RefreshProfileDescriptors()
        profileRef = profileRefsByToken[token]
    end

    if not profileRef then
        ReportProfileError("Selecting profile", "PROFILE_NOT_FOUND")
        return
    end

    local descriptor, errorCode = NS.profileManager:SetProfile(profileRef)
    if not descriptor then
        ReportProfileError("Selecting profile", errorCode)
    end
end

local function CreateProfileOptions()
    RefreshProfileDescriptors()
    local container = Settings.CreateControlTextContainer()

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]
        container:Add(GetProfileToken(descriptor.profileRef), GetProfileLabel(descriptor))
    end

    return container:GetData()
end

local function ShowProfileNameInput(text, textArgument, acceptText, callback)
    StaticPopup_ShowCustomGenericInputBox({
        text = text,
        text_arg1 = textArgument,
        callback = callback,
        acceptText = acceptText,
        maxLetters = 0,
    })
end

local function CreateProfile()
    ShowProfileNameInput(
        "Enter a name for the new profile.",
        nil,
        "Create",
        function(name)
            local profileRef, errorCode = NS.profileManager:CreateProfile(name)

            if not profileRef then
                ReportProfileError("Creating profile", errorCode)
                return
            end

            local descriptor, selectionError = NS.profileManager:SetProfile(profileRef)
            if not descriptor then
                ReportProfileError("Selecting profile", selectionError)
            end
        end
    )
end

local function CopyIntoActiveProfile()
    RefreshProfileDescriptors()
    local activeProfile = NS.profileManager:GetActiveProfile()
    local options = {}

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]

        if not descriptor.active then
            options[#options + 1] = {
                text = GetProfileLabel(descriptor),
                value = descriptor.profileRef,
            }
        end
    end

    if #options == 0 then
        NS:Print("There is no other profile to copy.")
        return
    end

    StaticPopup_ShowGenericDropdown(
        ("Choose a profile to copy into %s. This replaces all settings in the active profile."):format(
            GetProfileLabel(activeProfile)
        ),
        function(sourceRef)
            local descriptor, errorCode = NS.profileManager:CopyProfile(
                sourceRef,
                activeProfile.profileRef
            )

            if not descriptor then
                ReportProfileError("Copying profile", errorCode)
            end
        end,
        options,
        true
    )
end

local function ResetActiveProfile()
    local activeProfile = NS.profileManager:GetActiveProfile()

    if not activeProfile.canReset then
        return
    end

    StaticPopup_ShowCustomGenericConfirmation({
        text = "Reset %s to its default settings?",
        text_arg1 = GetProfileLabel(activeProfile),
        acceptText = "Reset",
        showAlert = true,
        callback = function()
            local descriptor, errorCode = NS.profileManager:ResetProfile(activeProfile.profileRef)

            if not descriptor then
                ReportProfileError("Resetting profile", errorCode)
            end
        end,
    })
end

local function RenameActiveProfile()
    local activeProfile = NS.profileManager:GetActiveProfile()

    if not activeProfile.canRename then
        NS:Print("Only user-created profiles can be renamed.")
        return
    end

    ShowProfileNameInput(
        "Enter a new name for %s.",
        GetProfileLabel(activeProfile),
        "Rename",
        function(name)
            local descriptor, errorCode = NS.profileManager:RenameProfile(
                activeProfile.profileRef,
                name
            )

            if not descriptor then
                ReportProfileError("Renaming profile", errorCode)
            end
        end
    )
end

local function ConfirmDeleteProfile(profileRef)
    RefreshProfileDescriptors()
    local descriptor = FindProfileDescriptor(profileRef)

    if not descriptor or not descriptor.canDelete then
        ReportProfileError("Deleting profile", descriptor and "ACTIVE_PROFILE" or "PROFILE_NOT_FOUND")
        return
    end

    local usage, errorCode = NS.profileManager:GetProfileUsage(descriptor.profileRef)
    if not usage then
        ReportProfileError("Deleting profile", errorCode)
        return
    end

    local confirmationText
    if usage.selectionCount > 0 then
        confirmationText = "Delete %s? %d character(s) will no longer have this profile selected."
    else
        confirmationText = "Delete %s?"
    end

    StaticPopup_ShowCustomGenericConfirmation({
        text = confirmationText,
        text_arg1 = GetProfileLabel(descriptor),
        text_arg2 = usage.selectionCount,
        acceptText = "Delete",
        showAlert = true,
        callback = function()
            local deleted, deleteError = NS.profileManager:DeleteProfile(descriptor.profileRef)

            if not deleted then
                ReportProfileError("Deleting profile", deleteError)
            end
        end,
    })
end

local function DeleteProfile()
    RefreshProfileDescriptors()
    local options = {}

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]

        if descriptor.canDelete then
            options[#options + 1] = {
                text = GetProfileLabel(descriptor),
                value = descriptor.profileRef,
            }
        end
    end

    if #options == 0 then
        NS:Print("There is no inactive user profile to delete.")
        return
    end

    StaticPopup_ShowGenericDropdown(
        "Choose a profile to delete.",
        ConfirmDeleteProfile,
        options,
        false
    )
end

local function NotifyProfileSettingControls()
    for index = 1, #PROFILE_SETTING_VARIABLES do
        NotifySettingChanged(PROFILE_SETTING_VARIABLES[index])
    end
end

local function NotifyProfileDescriptorControls()
    RefreshProfileDescriptors()
    NotifySettingChanged(SETTING_ACTIVE_PROFILE)
end

-- Blizzard Settings control registration
local function RegisterCheckbox(category, variable, name, defaultValue, getValue, setValue, tooltip)
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, name, defaultValue, getValue, setValue)
    Settings.CreateCheckbox(category, setting, tooltip)
    return setting
end

local function RegisterDropdown(category, variable, name, defaultValue, getValue, setValue, getOptions, tooltip, variableType)
    local setting = Settings.RegisterProxySetting(category, variable, variableType or Settings.VarType.String, name, defaultValue, getValue, setValue)
    local initializer = Settings.CreateDropdown(category, setting, getOptions, tooltip)
    return setting, initializer
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

local function RegisterButton(layout, name, buttonText, callback, tooltip)
    local initializer = CreateSettingsButtonInitializer(
        name,
        buttonText,
        callback,
        tooltip,
        true
    )
    layout:AddInitializer(initializer)
    return initializer
end

-- Public settings contract
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

    AddSection(layout, "Profiles")
    RefreshProfileDescriptors()
    local _, profileInitializer = RegisterDropdown(
        category,
        SETTING_ACTIVE_PROFILE,
        "Active Profile",
        PROFILE_GLOBAL_TOKEN,
        GetActiveProfileToken,
        SetActiveProfileToken,
        CreateProfileOptions,
        "Choose the settings profile used by this character."
    )
    profileInitializer.reinitializeOnValueChanged = true
    RegisterButton(
        layout,
        "New Profile",
        "Create",
        CreateProfile,
        "Create and select a new profile."
    )
    RegisterButton(
        layout,
        "Copy Into Active",
        "Choose",
        CopyIntoActiveProfile,
        "Replace the active profile's settings with settings from another profile."
    )
    RegisterButton(
        layout,
        "Rename Active",
        "Rename",
        RenameActiveProfile,
        "Rename the active user-created profile. Permanent profiles cannot be renamed."
    )
    RegisterButton(
        layout,
        "Reset Active",
        "Reset",
        ResetActiveProfile,
        "Reset the active profile to YvBags defaults."
    )
    RegisterButton(
        layout,
        "Delete Profile",
        "Choose",
        DeleteProfile,
        "Delete an inactive user-created profile."
    )

    AddSection(layout, "General")
    RegisterCheckbox(
        category,
        SETTING_REPLACE_BLIZZARD_BAGS,
        "Replace Blizzard Bags",
        true,
        function() return NS.globalDB:Get("features", "replaceBlizzardBags") ~= false end,
        SetReplaceBlizzardBags,
        ("Use %s for standard player bag open, close, and toggle actions."):format(ADDON_NAME)
    )
    RegisterCheckbox(
        category,
        SETTING_AUTOSELL_GRAY_JUNK,
        "Sell Gray Junk At Vendors",
        false,
        function() return GetBooleanSetting(NS.globalDB, "features", "autosellGrayJunk") end,
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
        NS.defaults.profile.list.groupKey,
        function() return NS.ItemListModel.NormalizeGroupKey(GetListValue("groupKey")) end,
        SetGroup,
        CreateGroupOptions,
        "Choose how the list groups visible bag items."
    )
    RegisterDropdown(
        category,
        SETTING_PIN_DISPLAY_MODE,
        "Pinned Items",
        NS.defaults.profile.pins.displayMode,
        function() return NS.ItemPins.GetDisplayMode() end,
        SetPinDisplayMode,
        CreatePinDisplayOptions,
        "Choose how pinned items participate in the active grouping and sort order. Pin state is retained in every mode."
    )
    RegisterDropdown(
        category,
        SETTING_PRIMARY_SORT_KEY,
        "Primary Sort",
        NS.defaults.profile.list.sortKey,
        function() return NS.ItemListModel.NormalizeSortKey(GetListValue("sortKey")) end,
        SetPrimarySort,
        CreateSortOptions,
        "Choose the primary item sort order."
    )
    RegisterDropdown(
        category,
        SETTING_PRIMARY_SORT_DIRECTION,
        "Primary Sort Direction",
        NS.defaults.profile.list.sortAscending,
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
        NS.defaults.profile.list.secondarySortKey,
        function() return NS.ItemListModel.NormalizeSecondarySortKey(GetListValue("secondarySortKey")) end,
        SetSecondarySort,
        CreateSecondarySortOptions,
        "Choose the secondary item sort order. Manual primary sorting disables secondary sorting."
    )
    RegisterDropdown(
        category,
        SETTING_SECONDARY_SORT_DIRECTION,
        "Secondary Sort Direction",
        NS.defaults.profile.list.secondarySortAscending,
        function() return GetListValue("secondarySortAscending") ~= false end,
        SetSecondarySortDirection,
        CreateDirectionOptions,
        "Choose the secondary sort direction.",
        Settings.VarType.Boolean
    )

    Settings.RegisterAddOnCategory(category)

    for index = 1, #PROFILE_DESCRIPTOR_EVENTS do
        NS.profileManager:RegisterLifecycleCallback(
            PROFILE_DESCRIPTOR_EVENTS[index],
            NotifyProfileDescriptorControls
        )
    end

    NS.db:RegisterLifecycleCallback("OnDataChanged", NotifyProfileSettingControls)
    NS.db:RegisterLifecycleCallback("OnReset", NotifyProfileSettingControls)
    AddonSettings.registered = true
end

NS:RegisterInitCallback(function()
    AddonSettings.Register()
end)

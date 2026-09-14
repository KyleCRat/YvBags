local _, NS = ...

local AddonSettings = {}
NS.Settings = AddonSettings

local ModernSettings = LibStub("LibModernSettings-1.0")
local ADDON_NAME = NS.ADDON_NAME

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
local PROFILE_ACTION_NONE_TOKEN = "profile-action:none"

-- Inline List field geometry, shared by the bag and bank sections.
local LIST_LABEL_WIDTH = 160
local LIST_FIELD_GAP = 8

-- Replacement-dependent settings remain visible and retain their saved values.
local BAGS_DISABLED_TOOLTIP = "Enable Replace Blizzard Bags to edit these settings."
local BANK_DISABLED_TOOLTIP = "Enable Replace Blizzard Bank to edit these settings."

local PERMANENT_PROFILE_LABELS = {
    character = "Character",
    spec = "Specialization",
    class = "Class",
    realm = "Realm",
    faction = "Faction",
    global = "Global",
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

local controls = {}
local bankControls = {}
local profileDescriptors = {}
local profileRefsByToken = {}
local pendingSettingsCategoryID
local controlRefreshScheduled = {}
local BAG_SCOPE = NS.ItemListSettings.Scopes.Bags
local BANK_SCOPE = NS.ItemListSettings.Scopes.Bank

-- Stored values and list updates
local function GetItemList()
    return NS.frame.itemList
end

local function GetBankItemList()
    return NS.bankFrame.itemList
end

local function GetBooleanSetting(database, section, key)
    return database:Get(section, key) == true
end

local function SetBooleanSetting(database, section, key, value)
    database:Set(section, key, value == true)
end

local function GetFrameScalePercent()
    local scale = NS.charDB:Get("frame", "scale")
        or NS.defaults.character.frame.scale

    return math.floor((scale * 100) + 0.5)
end

local function SetFrameScalePercent(value)
    value = math.max(
        SCALE_MIN_PERCENT,
        math.min(SCALE_MAX_PERCENT, tonumber(value) or 100)
    )
    NS.MainFrameGeometry.SetScale(value / 100)
end

local function SetReplaceBlizzardBags(value)
    SetBooleanSetting(
        NS.globalDB,
        "features",
        "replaceBlizzardBags",
        value
    )

    if value ~= false then
        NS.BlizzardBags.HideBlizzardBags()
    end
end

local function SetReplaceBlizzardBank(value)
    SetBooleanSetting(
        NS.globalDB,
        "features",
        "replaceBlizzardBank",
        value
    )
end

local function SetAutosellGrayJunk(value)
    SetBooleanSetting(NS.globalDB, "features", "autosellGrayJunk", value)

    if value == true then
        NS.JunkAutosell.ScheduleSell()
    end
end

local function SetShowCooldownsInName(value)
    SetBooleanSetting(NS.db, "display", "showCooldownsInName", value)
    GetItemList():RefreshVisibleRows()
    GetBankItemList():RefreshVisibleRows()
end

local function GetListValue(key)
    return NS.ItemListSettings.GetListValue(BAG_SCOPE, key)
end

local function SetPrimarySort(sortKey)
    sortKey = NS.ItemListModel.NormalizeSortKey(sortKey)
    GetItemList():SetSort(
        sortKey,
        GetListValue("sortAscending") ~= false
    )
end

local function SetPrimarySortDirection(sortAscending)
    GetItemList():SetSort(
        GetListValue("sortKey"),
        sortAscending == true
    )
end

local function SetSecondarySort(sortKey)
    GetItemList():SetSecondarySort(
        sortKey,
        GetListValue("secondarySortAscending") ~= false
    )
end

local function SetSecondarySortDirection(sortAscending)
    GetItemList():SetSecondarySortDirection(sortAscending == true)
end

local function SetGroup(groupKey)
    GetItemList():SetGroup(groupKey)
end

local function SetPinDisplayMode(displayMode)
    NS.ItemListSettings.SetPinDisplayMode(
        BAG_SCOPE,
        NS.ItemPins.NormalizeDisplayMode(displayMode)
    )
    GetItemList():RefreshProfileSettings()
end

local function GetBankFrameScalePercent()
    local scale = NS.charDB:Get("bankFrame", "scale")
        or NS.defaults.character.bankFrame.scale
    return math.floor((scale * 100) + 0.5)
end

local function SetBankFrameScalePercent(value)
    value = math.max(
        SCALE_MIN_PERCENT,
        math.min(SCALE_MAX_PERCENT, tonumber(value) or 100)
    )
    NS.BankFrameGeometry.SetScale(value / 100)
end

local function GetBankListValue(key)
    return NS.ItemListSettings.GetListValue(BANK_SCOPE, key)
end

local function SetBankMirroring(value)
    NS.ItemListSettings.SetBankMirroring(value == true)
end

local function SetBankPrimarySort(sortKey)
    GetBankItemList():SetSort(
        NS.ItemListModel.NormalizeSortKey(sortKey),
        GetBankListValue("sortAscending") ~= false
    )
end

local function SetBankPrimarySortDirection(sortAscending)
    GetBankItemList():SetSort(
        GetBankListValue("sortKey"),
        sortAscending == true
    )
end

local function SetBankSecondarySort(sortKey)
    GetBankItemList():SetSecondarySort(
        sortKey,
        GetBankListValue("secondarySortAscending") ~= false
    )
end

local function SetBankSecondarySortDirection(sortAscending)
    GetBankItemList():SetSecondarySortDirection(sortAscending == true)
end

local function SetBankGroup(groupKey)
    GetBankItemList():SetGroup(groupKey)
end

local function SetBankPinDisplayMode(displayMode)
    NS.ItemListSettings.SetPinDisplayMode(
        BANK_SCOPE,
        NS.ItemPins.NormalizeDisplayMode(displayMode)
    )
    GetBankItemList():RefreshProfileSettings()
end

-- Dropdown choices
local function CreateSortChoices()
    local choices = {}

    for _, sortKey in ipairs(NS.ItemListModel.GetSortKeyList()) do
        choices[#choices + 1] = {
            value = sortKey,
            label = NS.ItemListColumns.GetSortLabel(sortKey),
        }
    end

    return choices
end

local function CreateSecondarySortChoices()
    local choices = {}

    for _, sortKey in ipairs(NS.ItemListModel.GetSecondarySortKeyList()) do
        choices[#choices + 1] = {
            value = sortKey,
            label = sortKey == NS.ItemListModel.GetNoSecondarySortKey()
                and NO_SECONDARY_SORT_LABEL
                or NS.ItemListColumns.GetSortLabel(sortKey),
        }
    end

    return choices
end

local function CreateGroupChoices()
    local choices = {}

    for _, groupKey in ipairs(NS.ItemListModel.GetGroupKeyList()) do
        choices[#choices + 1] = {
            value = groupKey,
            label = NS.ItemListModel.GetGroupLabel(groupKey),
        }
    end

    return choices
end

local function CreateDirectionChoices()
    return {
        { value = true, label = ASCENDING_LABEL },
        { value = false, label = DESCENDING_LABEL },
    }
end

local function CreatePinDisplayChoices()
    local displayModes = NS.ItemPins.DisplayModes

    return {
        { value = displayModes.Top, label = PIN_DISPLAY_TOP_LABEL },
        { value = displayModes.Group, label = PIN_DISPLAY_GROUP_LABEL },
        {
            value = displayModes.TopOfGroups,
            label = PIN_DISPLAY_GROUP_TOP_LABEL,
        },
        { value = displayModes.Normal, label = PIN_DISPLAY_NORMAL_LABEL },
    }
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
        local label = PERMANENT_PROFILE_LABELS[profileType]
            or descriptor.displayName

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

        profileRefsByToken[GetProfileToken(descriptor.profileRef)] =
            descriptor.profileRef
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
end

local function ReportProfileError(action, errorCode)
    local messages = {
        INVALID_NAME = "The profile name is not valid UTF-8 or contains unsupported control characters.",
        PROFILE_EXISTS = "A profile with that name already exists.",
        PROFILE_NOT_FOUND = "That profile no longer exists.",
        ACTIVE_PROFILE = "The active profile cannot be deleted.",
    }

    NS:Print(("%s failed: %s"):format(
        action,
        messages[errorCode] or tostring(errorCode)
    ))
end

local function GetActiveProfileToken()
    local activeProfile = NS.profileManager:GetActiveProfile()

    return GetProfileToken(activeProfile.profileRef)
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

local function CreateProfileChoices()
    local choices = {}

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]

        choices[#choices + 1] = {
            value = GetProfileToken(descriptor.profileRef),
            label = GetProfileLabel(descriptor),
        }
    end

    return choices
end

local function CreateRenameProfileChoices()
    local choices = {
        {
            value = PROFILE_ACTION_NONE_TOKEN,
            label = "Choose a profile...",
        },
    }

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]

        if descriptor.canRename then
            choices[#choices + 1] = {
                value = GetProfileToken(descriptor.profileRef),
                label = GetProfileLabel(descriptor),
            }
        end
    end

    return choices
end

local function CreateDeleteProfileChoices()
    local choices = {
        {
            value = PROFILE_ACTION_NONE_TOKEN,
            label = "Choose a profile...",
        },
    }

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]

        if descriptor.canDelete then
            choices[#choices + 1] = {
                value = GetProfileToken(descriptor.profileRef),
                label = GetProfileLabel(descriptor),
            }
        end
    end

    return choices
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
            local profileRef, errorCode =
                NS.profileManager:CreateProfile(name)

            if not profileRef then
                ReportProfileError("Creating profile", errorCode)
                return
            end

            local descriptor, selectionError =
                NS.profileManager:SetProfile(profileRef)

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
            local descriptor, errorCode =
                NS.profileManager:ResetProfile(activeProfile.profileRef)

            if not descriptor then
                ReportProfileError("Resetting profile", errorCode)
            end
        end,
    })
end

local function RenameProfile(profileRef)
    RefreshProfileDescriptors()

    local descriptor = FindProfileDescriptor(profileRef)

    if not descriptor or not descriptor.canRename then
        NS:Print("Only user-created profiles can be renamed.")
        return
    end

    ShowProfileNameInput(
        "Enter a new name for %s.",
        GetProfileLabel(descriptor),
        "Rename",
        function(name)
            local renamedDescriptor, errorCode =
                NS.profileManager:RenameProfile(
                    descriptor.profileRef,
                    name
                )

            if not renamedDescriptor then
                ReportProfileError("Renaming profile", errorCode)
            end
        end
    )
end

local function ResetProfileActionDropdown(controlKey)
    C_Timer.After(0, function()
        controls[controlKey]:SetValue(PROFILE_ACTION_NONE_TOKEN)
    end)
end

local function SelectRenameProfileToken(token)
    if token == PROFILE_ACTION_NONE_TOKEN then
        return
    end

    ResetProfileActionDropdown("renameProfile")

    local profileRef = profileRefsByToken[token]

    if not profileRef then
        RefreshProfileDescriptors()
        profileRef = profileRefsByToken[token]
    end

    if not profileRef then
        ReportProfileError("Renaming profile", "PROFILE_NOT_FOUND")
        return
    end

    RenameProfile(profileRef)
end

local function ConfirmDeleteProfile(profileRef)
    RefreshProfileDescriptors()

    local descriptor = FindProfileDescriptor(profileRef)

    if not descriptor or not descriptor.canDelete then
        ReportProfileError(
            "Deleting profile",
            descriptor and "ACTIVE_PROFILE" or "PROFILE_NOT_FOUND"
        )
        return
    end

    local usage, errorCode =
        NS.profileManager:GetProfileUsage(descriptor.profileRef)

    if not usage then
        ReportProfileError("Deleting profile", errorCode)
        return
    end

    local confirmationText = "Delete %s?"

    if usage.selectionCount > 0 then
        confirmationText = "Delete %s? %d character(s) will no longer have this profile selected."
    end

    StaticPopup_ShowCustomGenericConfirmation({
        text = confirmationText,
        text_arg1 = GetProfileLabel(descriptor),
        text_arg2 = usage.selectionCount,
        acceptText = "Delete",
        showAlert = true,
        callback = function()
            local deleted, deleteError =
                NS.profileManager:DeleteProfile(descriptor.profileRef)

            if not deleted then
                ReportProfileError("Deleting profile", deleteError)
            end
        end,
    })
end

local function SelectDeleteProfileToken(token)
    if token == PROFILE_ACTION_NONE_TOKEN then
        return
    end

    ResetProfileActionDropdown("deleteProfile")

    local profileRef = profileRefsByToken[token]

    if not profileRef then
        RefreshProfileDescriptors()
        profileRef = profileRefsByToken[token]
    end

    if not profileRef then
        ReportProfileError("Deleting profile", "PROFILE_NOT_FOUND")
        return
    end

    ConfirmDeleteProfile(profileRef)
end

-- Canvas synchronization
local function RefreshProfileControls()
    RefreshProfileDescriptors()

    local activeProfile = NS.profileManager:GetActiveProfile()
    local canCopy = #profileDescriptors > 1
    local canRename = false
    local canDelete = false

    for index = 1, #profileDescriptors do
        local descriptor = profileDescriptors[index]

        if descriptor.canRename then
            canRename = true
        end

        if descriptor.canDelete then
            canDelete = true
        end
    end

    controls.activeProfile:SetChoices(CreateProfileChoices())
    controls.activeProfile:SetValue(GetActiveProfileToken())
    controls.renameProfile:SetChoices(CreateRenameProfileChoices())
    controls.renameProfile:SetValue(PROFILE_ACTION_NONE_TOKEN)
    controls.deleteProfile:SetChoices(CreateDeleteProfileChoices())
    controls.deleteProfile:SetValue(PROFILE_ACTION_NONE_TOKEN)
    controls.copyProfile:SetControlEnabled(
        canCopy,
        "There is no other profile to copy."
    )
    controls.renameProfile:SetControlEnabled(
        canRename,
        "There is no user-created profile to rename."
    )
    controls.resetProfile:SetControlEnabled(activeProfile.canReset)
    controls.deleteProfile:SetControlEnabled(
        canDelete,
        "There is no inactive user profile to delete."
    )
end

local function RefreshGlobalAndCharacterControls()
    local enabled = NS.globalDB:Get("features", "replaceBlizzardBags") ~= false
    controls.replaceBlizzardBags:SetValue(enabled)
    controls.autosellGrayJunk:SetValue(
        GetBooleanSetting(NS.globalDB, "features", "autosellGrayJunk")
    )
    controls.frameScale:SetValue(GetFrameScalePercent())
    controls.autosellGrayJunk:SetControlEnabled(enabled, BAGS_DISABLED_TOOLTIP)
    controls.frameScale:SetControlEnabled(enabled, BAGS_DISABLED_TOOLTIP)
end

local function RefreshProfileSettingControls()
    local ListModel = NS.ItemListModel
    local enabled = NS.globalDB:Get("features", "replaceBlizzardBags") ~= false
    local primarySortKey =
        ListModel.NormalizeSortKey(GetListValue("sortKey"))
    local secondarySortKey = ListModel.NormalizeSecondarySortKey(
        GetListValue("secondarySortKey")
    )
    local manual = ListModel.IsManualSortKey(primarySortKey)
    local secondaryEnabled = not manual
        and secondarySortKey ~= ListModel.GetNoSecondarySortKey()

    controls.showCooldownsInName:SetValue(
        NS.db:Get("display", "showCooldownsInName") ~= false
    )
    controls.groupKey:GetControl():SetValue(
        ListModel.NormalizeGroupKey(GetListValue("groupKey"))
    )
    controls.pinDisplayMode:GetControl():SetValue(NS.ItemPins.GetDisplayMode())
    controls.primarySortKey:GetControl():SetValue(primarySortKey)
    controls.primarySortDirection:GetControl():SetValue(
        GetListValue("sortAscending") ~= false
    )
    controls.secondarySortKey:GetControl():SetValue(secondarySortKey)
    controls.secondarySortDirection:GetControl():SetValue(
        GetListValue("secondarySortAscending") ~= false
    )

    controls.showCooldownsInName:SetControlEnabled(enabled, BAGS_DISABLED_TOOLTIP)
    controls.groupKey:SetControlEnabled(enabled, BAGS_DISABLED_TOOLTIP)
    controls.pinDisplayMode:SetControlEnabled(enabled, BAGS_DISABLED_TOOLTIP)
    controls.primarySortKey:SetControlEnabled(enabled, BAGS_DISABLED_TOOLTIP)
    controls.columns:SetControlEnabled(enabled, BAGS_DISABLED_TOOLTIP)
    controls.primarySortDirection:SetControlEnabled(
        enabled and not manual,
        not enabled and BAGS_DISABLED_TOOLTIP
            or "Manual sorting always follows bag and slot order."
    )
    controls.secondarySortKey:SetControlEnabled(
        enabled and not manual,
        not enabled and BAGS_DISABLED_TOOLTIP
            or "Manual primary sorting disables secondary sorting."
    )
    controls.secondarySortDirection:SetControlEnabled(
        enabled and secondaryEnabled,
        not enabled and BAGS_DISABLED_TOOLTIP
            or manual
            and "Manual primary sorting disables secondary sorting."
            or "Choose a secondary sort before setting its direction."
    )
end

local function RefreshBankControls()
    local ListModel = NS.ItemListModel
    local enabled = NS.globalDB:Get("features", "replaceBlizzardBank") ~= false
    local primarySortKey = ListModel.NormalizeSortKey(
        GetBankListValue("sortKey")
    )
    local secondarySortKey = ListModel.NormalizeSecondarySortKey(
        GetBankListValue("secondarySortKey")
    )
    local manual = ListModel.IsManualSortKey(primarySortKey)
    local secondaryEnabled = not manual
        and secondarySortKey ~= ListModel.GetNoSecondarySortKey()

    bankControls.replaceBlizzardBank:SetValue(enabled)
    bankControls.useBagListSettings:SetValue(
        NS.ItemListSettings.IsBankMirroring()
    )
    bankControls.frameScale:SetValue(GetBankFrameScalePercent())
    bankControls.groupKey:GetControl():SetValue(ListModel.NormalizeGroupKey(
        GetBankListValue("groupKey")
    ))
    bankControls.pinDisplayMode:GetControl():SetValue(
        NS.ItemPins.NormalizeDisplayMode(
            NS.ItemListSettings.GetPinDisplayMode(BANK_SCOPE)
        )
    )
    bankControls.primarySortKey:GetControl():SetValue(primarySortKey)
    bankControls.primarySortDirection:GetControl():SetValue(
        GetBankListValue("sortAscending") ~= false
    )
    bankControls.secondarySortKey:GetControl():SetValue(secondarySortKey)
    bankControls.secondarySortDirection:GetControl():SetValue(
        GetBankListValue("secondarySortAscending") ~= false
    )

    bankControls.useBagListSettings:SetControlEnabled(enabled, BANK_DISABLED_TOOLTIP)
    bankControls.frameScale:SetControlEnabled(enabled, BANK_DISABLED_TOOLTIP)
    bankControls.groupKey:SetControlEnabled(enabled, BANK_DISABLED_TOOLTIP)
    bankControls.pinDisplayMode:SetControlEnabled(enabled, BANK_DISABLED_TOOLTIP)
    bankControls.primarySortKey:SetControlEnabled(enabled, BANK_DISABLED_TOOLTIP)
    bankControls.columns:SetControlEnabled(enabled, BANK_DISABLED_TOOLTIP)
    bankControls.primarySortDirection:SetControlEnabled(
        enabled and not manual,
        not enabled and BANK_DISABLED_TOOLTIP
            or "Manual sorting always follows bank tab and slot order."
    )
    bankControls.secondarySortKey:SetControlEnabled(
        enabled and not manual,
        not enabled and BANK_DISABLED_TOOLTIP
            or "Manual primary sorting disables secondary sorting."
    )
    bankControls.secondarySortDirection:SetControlEnabled(
        enabled and secondaryEnabled,
        not enabled and BANK_DISABLED_TOOLTIP
            or manual
            and "Manual primary sorting disables secondary sorting."
            or "Choose a secondary sort before setting its direction."
    )
end

local function RefreshInventorySettingsFrame()
    RefreshGlobalAndCharacterControls()
    RefreshProfileSettingControls()
    RefreshBankControls()
end

local function ScheduleControlRefresh(frame, key, callback)
    if not frame:IsShown() or controlRefreshScheduled[key] then
        return
    end

    controlRefreshScheduled[key] = true
    C_Timer.After(0, function()
        controlRefreshScheduled[key] = nil

        if frame:IsShown() then
            callback()
        end
    end)
end

local function RefreshProfileControlsIfShown()
    ScheduleControlRefresh(AddonSettings.frame, "profiles", RefreshProfileControls)
end

local function RefreshGlobalAndCharacterControlsIfShown()
    ScheduleControlRefresh(
        AddonSettings.inventorySettingsFrame,
        "globalAndCharacter",
        RefreshGlobalAndCharacterControls
    )
end

local function RefreshProfileSettingControlsIfShown()
    ScheduleControlRefresh(
        AddonSettings.inventorySettingsFrame,
        "profileSettings",
        RefreshProfileSettingControls
    )
end

local function RefreshBankSettingsIfShown()
    ScheduleControlRefresh(
        AddonSettings.inventorySettingsFrame,
        "bankSettings",
        RefreshBankControls
    )
end

local function ResetBagSettings()
    local globalDefaults = NS.defaults.global.features
    local profileDefaults = NS.defaults.profile
    local listDefaults = profileDefaults.list

    SetReplaceBlizzardBags(globalDefaults.replaceBlizzardBags)
    SetAutosellGrayJunk(globalDefaults.autosellGrayJunk)
    SetShowCooldownsInName(
        profileDefaults.display.showCooldownsInName
    )
    SetFrameScalePercent(NS.defaults.character.frame.scale * 100)
    SetGroup(listDefaults.groupKey)
    SetPinDisplayMode(profileDefaults.pins.displayMode)
    SetPrimarySort(listDefaults.sortKey)
    SetPrimarySortDirection(listDefaults.sortAscending)
    SetSecondarySort(listDefaults.secondarySortKey)
    SetSecondarySortDirection(listDefaults.secondarySortAscending)
    NS.ItemListSettings.ResetColumns(NS.ItemListSettings.Scopes.Bags)
end

local function ResetBankSettings()
    NS.globalDB:Set(
        "features",
        "replaceBlizzardBank",
        NS.defaults.global.features.replaceBlizzardBank
    )
    NS.db:Delete("bank")
    SetBankFrameScalePercent(
        NS.defaults.character.bankFrame.scale * 100
    )
end

local function ResetInventorySettings()
    ResetBagSettings()
    ResetBankSettings()
end

-- Main page composition
local function CreateProfileButtonRow(parent)
    local buttonDefinitions = {
        {
            key = "createProfile",
            text = "New Profile",
            tooltip = "Create and select a new profile.",
            onClick = CreateProfile,
        },
        {
            key = "copyProfile",
            text = "Copy Into Active",
            tooltip = "Replace the active profile's settings with settings from another profile.",
            onClick = CopyIntoActiveProfile,
        },
        {
            key = "resetProfile",
            text = "Reset Active",
            tooltip = "Reset the active profile to YvBags defaults.",
            onClick = ResetActiveProfile,
        },
    }
    local gap = 8
    local width = (parent:GetWidth() - (gap * 2)) / 3
    local previousButton

    for index = 1, #buttonDefinitions do
        local definition = buttonDefinitions[index]
        local button = ModernSettings:CreateButton(parent, {
            text = definition.text,
            width = width,
            tooltip = definition.tooltip,
            onClick = definition.onClick,
        })

        if previousButton then
            button:SetPoint("LEFT", previousButton, "RIGHT", gap, 0)
        else
            button:SetPoint("LEFT", parent, "LEFT", 0, 0)
        end

        controls[definition.key] = button
        previousButton = button
    end
end

local function AddListDropdown(flow, options)
    return flow:AddControl("field", {
        label = options.label,
        labelPosition = "left",
        labelWidth = LIST_LABEL_WIDTH,
        gap = LIST_FIELD_GAP,
        controlType = "dropdown",
        controlOptions = {
            choices = options.choices,
            tooltip = options.tooltip,
            onChanged = options.onChanged,
        },
    })
end

local function AddAppearanceSettings(flow)
    flow:AddSection("Appearance", { marginTop = 0 })
    local skin = flow:AddControl("field", {
        label = "Skin",
        description = NS.Appearance.GetStatusText(),
        controlType = "dropdown",
        controlOptions = {
            choices = {
                { value = "modern", label = "WoW Modern" },
                { value = "flat", label = "Flat" },
            },
            onChanged = NS.Appearance.SetSkin,
        },
        tooltip = "Change both the bag and bank windows. Skin selection is shared across profiles. Changes wait until combat or moving, resizing, and scaling finish.",
    })
    local function Refresh()
        skin:GetControl():SetValue(NS.Appearance.GetSkin())
        skin:SetDescription(NS.Appearance.GetStatusText())
    end
    NS.Appearance.RegisterCallback(Refresh)
    Refresh()
end

local function BuildMainSettingsFrame(frame, measurementFrame)
    local layout = ModernSettings:CreateCanvasLayout(frame, {
        measurementFrame = measurementFrame,
        scrollable = true,
    })
    local root = layout:GetRootFlow()

    layout:AddHeader(
        ADDON_NAME,
        "Manage profiles and the shared appearance of your bag and bank windows."
    )
    root:AddSection("Profiles", { marginTop = 0 })

    controls.activeProfile = root:AddControl("dropdown", {
        label = "Active Profile",
        getChoices = CreateProfileChoices,
        tooltip = "Choose the settings profile used by this character.",
        onChanged = SetActiveProfileToken,
    })

    local profileButtons = root:AddCustom(34, {
        marginTop = 4,
        marginBottom = 4,
    })

    CreateProfileButtonRow(profileButtons)

    local profileSelectors = root:BeginColumns()

    controls.renameProfile = profileSelectors.left:AddControl(
        "dropdown",
        {
            label = "Rename Profile",
            choices = CreateRenameProfileChoices(),
            value = PROFILE_ACTION_NONE_TOKEN,
            tooltip = "Choose a user-created profile to rename.",
            onChanged = SelectRenameProfileToken,
        }
    )
    controls.deleteProfile = profileSelectors.right:AddControl(
        "dropdown",
        {
            label = "Delete Profile",
            choices = CreateDeleteProfileChoices(),
            value = PROFILE_ACTION_NONE_TOKEN,
            tooltip = "Choose an inactive user-created profile to delete.",
            onChanged = SelectDeleteProfileToken,
        }
    )
    profileSelectors:Finish({ marginBottom = 12 })

    local appearanceColumns = root:BeginColumns()

    AddAppearanceSettings(appearanceColumns.left)
    appearanceColumns:Finish()
    layout:Finalize()
    frame.layout = layout
end

-- Inventory page composition
local function AddBagGeneralSettings(flow)
    flow:AddSection("Bags", { fontObject = GameFontNormalHuge, marginTop = 0 })
    flow:AddSection("General", { marginTop = 0 })
    controls.replaceBlizzardBags = flow:AddControl("checkbox", {
        label = "Replace Blizzard Bags",
        tooltip = ("Use %s for standard player bag open, close, and toggle actions."):format(
            ADDON_NAME
        ),
        onChanged = SetReplaceBlizzardBags,
    })
    controls.autosellGrayJunk = flow:AddControl("checkbox", {
        label = "Sell Gray Junk At Vendors",
        tooltip = "Automatically sell Blizzard gray-quality junk items when a merchant opens.",
        onChanged = SetAutosellGrayJunk,
    })
    controls.showCooldownsInName = flow:AddControl("checkbox", {
        label = "Show Cooldowns In Item Names",
        tooltip = "Prefix item cooldown timers in the item name column.",
        onChanged = SetShowCooldownsInName,
    })
    controls.frameScale = flow:AddControl("slider", {
        label = "Scale",
        minValue = SCALE_MIN_PERCENT,
        maxValue = SCALE_MAX_PERCENT,
        step = SCALE_STEP_PERCENT,
        suffix = "%",
        tooltip = ("Resize the %s frame."):format(ADDON_NAME),
        onChanged = SetFrameScalePercent,
    })
end

local function AddBagListSettings(flow)
    flow:AddSection("List")
    controls.groupKey = AddListDropdown(flow, {
        label = "Group By",
        choices = CreateGroupChoices(),
        tooltip = "Choose how the list groups visible bag items.",
        onChanged = SetGroup,
    })
    controls.pinDisplayMode = AddListDropdown(flow, {
        label = "Pinned Items",
        choices = CreatePinDisplayChoices(),
        tooltip = "Choose how pinned items participate in the active grouping and sort order. Pin state is retained in every mode.",
        onChanged = SetPinDisplayMode,
    })
    controls.primarySortKey = AddListDropdown(flow, {
        label = "Primary Sort",
        choices = CreateSortChoices(),
        tooltip = "Choose the primary item sort order.",
        onChanged = SetPrimarySort,
    })
    controls.primarySortDirection = AddListDropdown(flow, {
        label = "Primary Sort Direction",
        choices = CreateDirectionChoices(),
        tooltip = "Choose the primary sort direction.",
        onChanged = SetPrimarySortDirection,
    })
    controls.secondarySortKey = AddListDropdown(flow, {
        label = "Secondary Sort",
        choices = CreateSecondarySortChoices(),
        tooltip = "Choose the secondary item sort order.",
        onChanged = SetSecondarySort,
    })
    controls.secondarySortDirection = AddListDropdown(flow, {
        label = "Secondary Sort Direction",
        choices = CreateDirectionChoices(),
        tooltip = "Choose the secondary sort direction.",
        onChanged = SetSecondarySortDirection,
    })
    controls.columns = flow:AddControl("button", {
        text = "Columns",
        tooltip = "Show, hide, or reset columns. Drag list headers to reorder and their dividers to resize. Column editing is unavailable during combat.",
        onClick = function(button)
            NS.ItemListColumnMenu.Open(button, NS.ItemListSettings.Scopes.Bags)
        end,
    })
end

local function AddBankGeneralSettings(flow)
    flow:AddSection("Bank", { fontObject = GameFontNormalHuge, marginTop = 0 })
    flow:AddSection("General", { marginTop = 0 })
    bankControls.replaceBlizzardBank = flow:AddControl(
        "checkbox",
        {
            label = "Replace Blizzard Bank",
            tooltip = "Use YvBags for Character and Warband bank access.",
            onChanged = SetReplaceBlizzardBank,
        }
    )
    bankControls.useBagListSettings = flow:AddControl(
        "checkbox",
        {
            label = "Use Bag List Settings",
            tooltip = "Keep bank grouping, sorting, directions, columns, and pinned-item presentation synchronized with the bag list. Changes made from either window update both while enabled.",
            onChanged = SetBankMirroring,
        }
    )
    bankControls.frameScale = flow:AddControl("slider", {
        label = "Scale",
        minValue = SCALE_MIN_PERCENT,
        maxValue = SCALE_MAX_PERCENT,
        step = SCALE_STEP_PERCENT,
        suffix = "%",
        tooltip = "Resize the YvBags bank frame.",
        onChanged = SetBankFrameScalePercent,
    })
end

local function AddBankListSettings(flow)
    flow:AddSection("List")
    bankControls.groupKey = AddListDropdown(flow, {
        label = "Group By",
        choices = CreateGroupChoices(),
        tooltip = "Choose how both bank views group items.",
        onChanged = SetBankGroup,
    })
    bankControls.pinDisplayMode = AddListDropdown(
        flow,
        {
            label = "Pinned Items",
            choices = CreatePinDisplayChoices(),
            tooltip = "Choose how account-wide pins appear in both bank views.",
            onChanged = SetBankPinDisplayMode,
        }
    )
    bankControls.primarySortKey = AddListDropdown(
        flow,
        {
            label = "Primary Sort",
            choices = CreateSortChoices(),
            tooltip = "Choose the primary bank-item sort order.",
            onChanged = SetBankPrimarySort,
        }
    )
    bankControls.primarySortDirection = AddListDropdown(
        flow,
        {
            label = "Primary Sort Direction",
            choices = CreateDirectionChoices(),
            tooltip = "Choose the primary bank sort direction.",
            onChanged = SetBankPrimarySortDirection,
        }
    )
    bankControls.secondarySortKey = AddListDropdown(
        flow,
        {
            label = "Secondary Sort",
            choices = CreateSecondarySortChoices(),
            tooltip = "Choose the secondary bank-item sort order.",
            onChanged = SetBankSecondarySort,
        }
    )
    bankControls.secondarySortDirection = AddListDropdown(
        flow,
        {
            label = "Secondary Sort Direction",
            choices = CreateDirectionChoices(),
            tooltip = "Choose the secondary bank sort direction.",
            onChanged = SetBankSecondarySortDirection,
        }
    )
    bankControls.columns = flow:AddControl("button", {
        text = "Columns",
        tooltip = "Show, hide, or reset columns for both bank views. Drag list headers to reorder and their dividers to resize. Column editing is unavailable during combat.",
        onClick = function(button)
            NS.ItemListColumnMenu.Open(button, NS.ItemListSettings.Scopes.Bank)
        end,
    })
end

local function BuildInventorySettingsFrame(frame, measurementFrame)
    local layout = ModernSettings:CreateCanvasLayout(frame, {
        measurementFrame = measurementFrame,
        scrollable = true,
    })
    local root = layout:GetRootFlow()
    local generalColumns = root:BeginColumns()

    AddBagGeneralSettings(generalColumns.left)
    AddBankGeneralSettings(generalColumns.right)
    generalColumns:Finish()

    local listColumns = root:BeginColumns()

    AddBagListSettings(listColumns.left)
    AddBankListSettings(listColumns.right)
    listColumns:Finish()
    layout:Finalize()
    frame.layout = layout
end

-- Settings registration and public contract
local function OpenSettingsCategory(categoryID)
    pendingSettingsCategoryID = nil
    Settings.OpenToCategory(categoryID)
end

local function OnPlayerRegenEnabled()
    if InCombatLockdown() or not pendingSettingsCategoryID then
        return
    end

    local categoryID = pendingSettingsCategoryID

    C_Timer.After(0, function()
        NS:UnregisterEventHandler(
            "PLAYER_REGEN_ENABLED",
            OnPlayerRegenEnabled
        )
    end)
    OpenSettingsCategory(categoryID)
end

function AddonSettings.Open(categoryID)
    categoryID = categoryID
        or (AddonSettings.category and AddonSettings.category:GetID())

    if not categoryID then
        return false
    end

    if InCombatLockdown() then
        if not pendingSettingsCategoryID then
            NS:RegisterEventHandler(
                "PLAYER_REGEN_ENABLED",
                OnPlayerRegenEnabled
            )
        end

        pendingSettingsCategoryID = categoryID
        NS:Print("Can't open settings in combat. They will open when combat ends.")
        return false
    end

    OpenSettingsCategory(categoryID)
    return true
end

function AddonSettings.OpenInventory()
    return AddonSettings.Open(AddonSettings.inventoryCategory:GetID())
end

function AddonSettings.NotifyFrameScaleChanged()
    local value = GetFrameScalePercent()

    if controls.frameScale and controls.frameScale:GetValue() ~= value then
        controls.frameScale:SetValue(value)
    end
end

function AddonSettings.NotifyBankFrameScaleChanged()
    local value = GetBankFrameScalePercent()

    if bankControls.frameScale
        and bankControls.frameScale:GetValue() ~= value then
        bankControls.frameScale:SetValue(value)
    end
end

function AddonSettings.Register()
    if AddonSettings.registered then
        return
    end

    local measurementFrame = SettingsPanel:GetSettingsCanvas()
    local mainFrame = CreateFrame("Frame")

    BuildMainSettingsFrame(mainFrame, measurementFrame)

    mainFrame.OnRefresh = RefreshProfileControls
    mainFrame.OnDefault = NS.Appearance.Reset

    local category = Settings.RegisterCanvasLayoutCategory(
        mainFrame,
        ADDON_NAME
    )
    local inventoryFrame = CreateFrame("Frame")
    BuildInventorySettingsFrame(inventoryFrame, measurementFrame)
    inventoryFrame.OnRefresh = RefreshInventorySettingsFrame
    inventoryFrame.OnDefault = ResetInventorySettings
    local inventoryCategory = Settings.RegisterCanvasLayoutSubcategory(
        category,
        inventoryFrame,
        "Inventory"
    )
    local categoriesFrame = NS.CategoryEditor.CreateFrame(measurementFrame)
    local categoriesCategory = Settings.RegisterCanvasLayoutSubcategory(
        category,
        categoriesFrame,
        "Categories"
    )

    Settings.RegisterAddOnCategory(category)

    AddonSettings.frame = mainFrame
    AddonSettings.category = category
    AddonSettings.inventorySettingsFrame = inventoryFrame
    AddonSettings.inventoryCategory = inventoryCategory
    AddonSettings.categoriesFrame = categoriesFrame
    AddonSettings.categoriesCategory = categoriesCategory

    for index = 1, #PROFILE_DESCRIPTOR_EVENTS do
        NS.profileManager:RegisterLifecycleCallback(
            PROFILE_DESCRIPTOR_EVENTS[index],
            RefreshProfileControlsIfShown
        )
    end

    NS.globalDB:RegisterTreeCallback(
        RefreshGlobalAndCharacterControlsIfShown,
        "features"
    )
    NS.globalDB:RegisterTreeCallback(
        RefreshProfileSettingControlsIfShown,
        "features", "replaceBlizzardBags"
    )
    NS.globalDB:RegisterTreeCallback(
        RefreshBankSettingsIfShown,
        "features"
    )
    NS.db:RegisterTreeCallback(
        RefreshProfileSettingControlsIfShown,
        "display"
    )
    NS.db:RegisterTreeCallback(
        RefreshProfileSettingControlsIfShown,
        "list"
    )
    NS.db:RegisterTreeCallback(
        RefreshProfileSettingControlsIfShown,
        "pins"
    )
    NS.db:RegisterTreeCallback(RefreshBankSettingsIfShown, "list")
    NS.db:RegisterTreeCallback(RefreshBankSettingsIfShown, "pins")
    NS.db:RegisterTreeCallback(RefreshBankSettingsIfShown, "bank")
    NS.db:RegisterLifecycleCallback(
        "OnDataChanged",
        RefreshProfileSettingControlsIfShown
    )
    NS.db:RegisterLifecycleCallback(
        "OnReset",
        RefreshProfileSettingControlsIfShown
    )
    NS.db:RegisterLifecycleCallback(
        "OnDataChanged",
        RefreshBankSettingsIfShown
    )
    NS.db:RegisterLifecycleCallback(
        "OnReset",
        RefreshBankSettingsIfShown
    )

    AddonSettings.registered = true
    RefreshProfileControls()
    RefreshInventorySettingsFrame()
end

NS:RegisterInitCallback(AddonSettings.Register)

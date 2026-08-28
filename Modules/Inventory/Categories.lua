local _, NS = ...

-- Profile-backed category registry, mutation API, and rule evaluation facade.
local Categories = {}
NS.Categories = Categories

local Rules = NS.CategoryRules
local DB_KEY = "categories"
local CATEGORY_SCHEMA_VERSION = 1
local OTHER_CATEGORY_ID = "other"
local CUSTOM_CATEGORY_PREFIX = "custom:"
local DEFAULT_ROOT = NS.defaults.profile.categories

Categories.ChangeTypes = {
    Created = "created",
    Renamed = "renamed",
    Moved = "moved",
    Removed = "removed",
    Reset = "reset",
    RulesChanged = "rulesChanged",
    RuleMoved = "ruleMoved",
    Changed = "changed",
    ProfileChanged = "profileChanged",
    ProfileReset = "profileReset",
}

Categories.ErrorCodes = {
    InvalidName = "invalid-name",
    DuplicateName = "duplicate-name",
    MissingCategory = "missing-category",
    RequiredCategory = "required-category",
    InvalidIndex = "invalid-index",
    InvalidRuleMode = "invalid-rule-mode",
    InvalidRuleField = "invalid-rule-field",
    InvalidRuleOperator = "invalid-rule-operator",
    InvalidRuleValue = "invalid-rule-value",
    InvalidRuleValueIndex = "invalid-rule-value-index",
    MissingRule = "missing-rule",
    RulesNotAllowed = "rules-not-allowed",
}

local activeRoot
local orderedDefinitions = {}
local definitionsByID = {}
local categoryLabels = {}
local categorySortPriorities = {}
local compiledRuleSets = {}
local callbacks = {}
local callbackLookup = {}
local pendingChangeType
local pendingCategoryID

Categories.labels = categoryLabels

-- Category storage normalization
local function HasASCIIControl(value)
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte <= 31 or byte == 127 then
            return true
        end
    end

    return false
end

local function NormalizeCategoryName(name)
    if type(name) ~= "string" then
        return nil, Categories.ErrorCodes.InvalidName
    end

    name = strtrim(name)
    if name == "" or HasASCIIControl(name) then
        return nil, Categories.ErrorCodes.InvalidName
    end

    local success, length = pcall(strlenutf8, name)
    if not success or type(length) ~= "number" then
        return nil, Categories.ErrorCodes.InvalidName
    end

    return name
end

local function GetDefaultDefinition(categoryID)
    local definitions = DEFAULT_ROOT.definitions
    return definitions and definitions[categoryID]
end

local function GetStoredName(categoryID, definition)
    local name = NormalizeCategoryName(definition and definition.name)
    if name then
        return name
    end

    local defaultDefinition = GetDefaultDefinition(categoryID)
    if defaultDefinition then
        return defaultDefinition.name
    end

    return categoryID
end

local function NormalizeNextCustomID(root, definitions)
    local nextCustomID = root.nextCustomID
    if type(nextCustomID) ~= "number" or nextCustomID < 1 or nextCustomID % 1 ~= 0 then
        nextCustomID = 1
    end

    for categoryID in pairs(definitions) do
        local numericID = tonumber(categoryID:match("^custom:(%d+)$"))
        if numericID and numericID >= nextCustomID then
            nextCustomID = numericID + 1
        end
    end

    return nextCustomID
end

local function NormalizeRoot(root)
    if type(root) ~= "table" then
        root = CopyTable(DEFAULT_ROOT)
    end

    local schemaVersion = root.schemaVersion
    if schemaVersion ~= nil and schemaVersion ~= CATEGORY_SCHEMA_VERSION then
        error(("YvBags: unsupported category schema %s"):format(tostring(schemaVersion)), 3)
    end

    local sourceDefinitions = type(root.definitions) == "table" and root.definitions or {}
    local definitions = {}

    for categoryID, definition in pairs(sourceDefinitions) do
        if type(categoryID) == "string" and categoryID ~= "" and type(definition) == "table" then
            local normalizedDefinition = CopyTable(definition)
            normalizedDefinition.name = GetStoredName(categoryID, normalizedDefinition)
            if categoryID == OTHER_CATEGORY_ID then
                normalizedDefinition.rules = nil
            else
                normalizedDefinition.rules = Rules.NormalizeRuleSet(
                    normalizedDefinition.rules
                )
            end
            definitions[categoryID] = normalizedDefinition
        end
    end

    if not definitions[OTHER_CATEGORY_ID] then
        definitions[OTHER_CATEGORY_ID] = CopyTable(GetDefaultDefinition(OTHER_CATEGORY_ID))
    end

    local order = {}
    local orderedIDs = {}
    local sourceOrder = type(root.order) == "table" and root.order or {}

    for _, categoryID in ipairs(sourceOrder) do
        if definitions[categoryID] and not orderedIDs[categoryID] then
            order[#order + 1] = categoryID
            orderedIDs[categoryID] = true
        end
    end

    local remainingIDs = {}
    for categoryID in pairs(definitions) do
        if not orderedIDs[categoryID] then
            remainingIDs[#remainingIDs + 1] = categoryID
        end
    end
    table.sort(remainingIDs)

    for _, categoryID in ipairs(remainingIDs) do
        order[#order + 1] = categoryID
    end

    return {
        schemaVersion = CATEGORY_SCHEMA_VERSION,
        nextCustomID = NormalizeNextCustomID(root, definitions),
        order = order,
        definitions = definitions,
    }
end

local function RebuildCaches(root)
    activeRoot = NormalizeRoot(root)
    wipe(orderedDefinitions)
    wipe(definitionsByID)
    wipe(categoryLabels)
    wipe(categorySortPriorities)
    wipe(compiledRuleSets)

    for sortPriority, categoryID in ipairs(activeRoot.order) do
        local definition = activeRoot.definitions[categoryID]
        if definition then
            local cachedDefinition = CopyTable(definition)
            cachedDefinition.id = categoryID
            orderedDefinitions[#orderedDefinitions + 1] = cachedDefinition
            definitionsByID[categoryID] = cachedDefinition
            categoryLabels[categoryID] = cachedDefinition.name
            categorySortPriorities[categoryID] = sortPriority
            if categoryID ~= OTHER_CATEGORY_ID then
                compiledRuleSets[categoryID] = Rules.CompileRuleSet(
                    cachedDefinition.rules
                )
            end
        end
    end
end

local function NotifyCallbacks(changeType, categoryID)
    local snapshot = {}
    for index, callback in ipairs(callbacks) do
        snapshot[index] = callback
    end

    for _, callback in ipairs(snapshot) do
        xpcall(function()
            callback(Categories, changeType, categoryID)
        end, geterrorhandler())
    end
end

local function ReloadFromActiveProfile(changeType, categoryID)
    RebuildCaches(NS.db:GetCopy(DB_KEY))
    NotifyCallbacks(changeType, categoryID)
end

local function OnCategoriesChanged()
    local changeType = pendingChangeType or Categories.ChangeTypes.Changed
    local categoryID = pendingCategoryID
    pendingChangeType = nil
    pendingCategoryID = nil
    ReloadFromActiveProfile(changeType, categoryID)
end

local function OnProfileDataChanged()
    pendingChangeType = nil
    pendingCategoryID = nil
    ReloadFromActiveProfile(Categories.ChangeTypes.ProfileChanged)
end

local function OnProfileReset()
    pendingChangeType = nil
    pendingCategoryID = nil
    ReloadFromActiveProfile(Categories.ChangeTypes.ProfileReset)
end

local function CommitRoot(root, changeType, categoryID)
    pendingChangeType = changeType
    pendingCategoryID = categoryID

    local success, result = pcall(NS.db.Set, NS.db, DB_KEY, root)
    if not success then
        pendingChangeType = nil
        pendingCategoryID = nil
        error(result, 3)
    end

    pendingChangeType = nil
    pendingCategoryID = nil
    return true
end

local function ValidateName(name, excludedCategoryID)
    local normalizedName, errorCode = NormalizeCategoryName(name)
    if not normalizedName then
        return nil, errorCode
    end

    for categoryID, definition in pairs(definitionsByID) do
        if categoryID ~= excludedCategoryID
            and strcmputf8i(definition.name, normalizedName) == 0 then
            return nil, Categories.ErrorCodes.DuplicateName
        end
    end

    return normalizedName
end

local function FindCategoryIndex(root, categoryID)
    for index, orderedCategoryID in ipairs(root.order) do
        if orderedCategoryID == categoryID then
            return index
        end
    end

    return nil
end

local function GetMutableRuleSet(root, categoryID)
    if categoryID == OTHER_CATEGORY_ID then
        return nil, Categories.ErrorCodes.RulesNotAllowed
    end

    local definition = root.definitions[categoryID]
    if not definition then
        return nil, Categories.ErrorCodes.MissingCategory
    end

    definition.rules = Rules.NormalizeRuleSet(definition.rules)
    return definition.rules
end

local function GetMutableTextRule(root, categoryID, ruleID)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    local rule = Rules.FindRule(ruleSet, ruleID)
    if not rule then
        return nil, Categories.ErrorCodes.MissingRule
    end

    if Rules.GetFieldValueKind(rule.field) ~= Rules.ValueKinds.Text
        or not Rules.OperatorNeedsValue(rule.operator) then
        return nil, Categories.ErrorCodes.InvalidRuleValue
    end

    return rule
end

local function NormalizeTextValueIndex(values, valueIndex)
    if type(valueIndex) ~= "number"
        or valueIndex % 1 ~= 0
        or valueIndex < 1
        or valueIndex > math.max(1, #values) then
        return nil
    end

    return valueIndex
end

local function SetTextRuleValue(rule, valueIndex, value)
    local values = Rules.GetRuleTextValues(rule)

    valueIndex = NormalizeTextValueIndex(values, valueIndex)
    if not valueIndex then
        return nil, nil, Categories.ErrorCodes.InvalidRuleValueIndex
    end

    local normalizedValue
    local isValid

    normalizedValue, isValid = Rules.NormalizeInputValue(rule.field, value)
    if not isValid then
        return nil, nil, Categories.ErrorCodes.InvalidRuleValue
    end

    if #values > 0 and values[valueIndex] == normalizedValue then
        return normalizedValue, false
    end

    values[valueIndex] = normalizedValue
    rule.value = values
    return normalizedValue, true
end

-- Public category registry
function Categories.GetCategoryKey(item)
    for _, definition in ipairs(orderedDefinitions) do
        local categoryID = definition.id
        if categoryID ~= OTHER_CATEGORY_ID
            and Rules.Matches(compiledRuleSets[categoryID], item) then
            return categoryID
        end
    end

    return OTHER_CATEGORY_ID
end

function Categories.GetCategoryName(categoryKey)
    return categoryLabels[categoryKey] or categoryLabels[OTHER_CATEGORY_ID]
end

function Categories.GetSortPriority(categoryKey)
    return categorySortPriorities[categoryKey] or categorySortPriorities[OTHER_CATEGORY_ID]
end

function Categories.GetLabels()
    return categoryLabels
end

function Categories.GetOrderedDefinitions()
    local result = {}
    for index, definition in ipairs(orderedDefinitions) do
        result[index] = CopyTable(definition)
    end
    return result
end

function Categories.GetDefinition(categoryID)
    local definition = definitionsByID[categoryID]
    return definition and CopyTable(definition) or nil
end

function Categories.RegisterCallback(callback)
    if type(callback) ~= "function" then
        error("Usage: Categories.RegisterCallback(callback)", 2)
    end

    if not callbackLookup[callback] then
        callbacks[#callbacks + 1] = callback
        callbackLookup[callback] = true
    end

    return callback
end

function Categories.UnregisterCallback(callback)
    if not callbackLookup[callback] then
        return false
    end

    callbackLookup[callback] = nil
    for index, registeredCallback in ipairs(callbacks) do
        if registeredCallback == callback then
            table.remove(callbacks, index)
            return true
        end
    end

    return false
end

-- Public category mutations
function Categories.CreateCategory(name)
    local validatedName, errorCode = ValidateName(name)
    if not validatedName then
        return nil, errorCode
    end

    local root = CopyTable(activeRoot)
    local numericID = root.nextCustomID
    local categoryID = CUSTOM_CATEGORY_PREFIX .. tostring(numericID)
    while root.definitions[categoryID] do
        numericID = numericID + 1
        categoryID = CUSTOM_CATEGORY_PREFIX .. tostring(numericID)
    end

    root.nextCustomID = numericID + 1
    root.definitions[categoryID] = {
        name = validatedName,
        rules = Rules.CreateEmptyRuleSet(),
    }
    root.order[#root.order + 1] = categoryID
    CommitRoot(root, Categories.ChangeTypes.Created, categoryID)
    return categoryID
end

function Categories.RenameCategory(categoryID, name)
    if not definitionsByID[categoryID] then
        return nil, Categories.ErrorCodes.MissingCategory
    end

    local validatedName, errorCode = ValidateName(name, categoryID)
    if not validatedName then
        return nil, errorCode
    end

    if definitionsByID[categoryID].name == validatedName then
        return validatedName
    end

    local root = CopyTable(activeRoot)
    root.definitions[categoryID].name = validatedName
    CommitRoot(root, Categories.ChangeTypes.Renamed, categoryID)
    return validatedName
end

function Categories.MoveCategory(categoryID, targetIndex)
    local root = CopyTable(activeRoot)
    local currentIndex = FindCategoryIndex(root, categoryID)
    if not currentIndex then
        return nil, Categories.ErrorCodes.MissingCategory
    end

    if type(targetIndex) ~= "number"
        or targetIndex % 1 ~= 0
        or targetIndex < 1
        or targetIndex > #root.order then
        return nil, Categories.ErrorCodes.InvalidIndex
    end

    if currentIndex == targetIndex then
        return targetIndex
    end

    table.remove(root.order, currentIndex)
    table.insert(root.order, targetIndex, categoryID)
    CommitRoot(root, Categories.ChangeTypes.Moved, categoryID)
    return targetIndex
end

function Categories.RemoveCategory(categoryID)
    if categoryID == OTHER_CATEGORY_ID then
        return nil, Categories.ErrorCodes.RequiredCategory
    end

    if not definitionsByID[categoryID] then
        return nil, Categories.ErrorCodes.MissingCategory
    end

    local root = CopyTable(activeRoot)
    local categoryIndex = FindCategoryIndex(root, categoryID)
    if categoryIndex then
        table.remove(root.order, categoryIndex)
    end
    root.definitions[categoryID] = nil
    CommitRoot(root, Categories.ChangeTypes.Removed, categoryID)
    return true
end

-- Public Rule Set mutations
function Categories.SetRuleMode(categoryID, mode)
    if not Rules.IsModeValid(mode) then
        return nil, Categories.ErrorCodes.InvalidRuleMode
    end

    local root = CopyTable(activeRoot)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    if ruleSet.mode == mode then
        return mode
    end

    ruleSet.mode = mode
    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return mode
end

function Categories.CreateRule(categoryID)
    local root = CopyTable(activeRoot)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    local ruleID = Rules.AllocateRule(ruleSet)
    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return ruleID
end

function Categories.MoveRule(categoryID, ruleID, targetIndex)
    local root = CopyTable(activeRoot)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    local _, currentIndex = Rules.FindRule(ruleSet, ruleID)
    if not currentIndex then
        return nil, Categories.ErrorCodes.MissingRule
    end

    if type(targetIndex) ~= "number"
        or targetIndex % 1 ~= 0
        or targetIndex < 1
        or targetIndex > #ruleSet.entries then
        return nil, Categories.ErrorCodes.InvalidIndex
    end

    if currentIndex == targetIndex then
        return targetIndex
    end

    local rule = table.remove(ruleSet.entries, currentIndex)
    table.insert(ruleSet.entries, targetIndex, rule)
    CommitRoot(root, Categories.ChangeTypes.RuleMoved, categoryID)
    return targetIndex
end

function Categories.UpdateRuleField(categoryID, ruleID, fieldID)
    if not Rules.IsFieldValid(fieldID) then
        return nil, Categories.ErrorCodes.InvalidRuleField
    end

    local root = CopyTable(activeRoot)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    local rule = Rules.FindRule(ruleSet, ruleID)
    if not rule then
        return nil, Categories.ErrorCodes.MissingRule
    end

    if rule.field == fieldID
        and Rules.IsOperatorValid(fieldID, rule.operator) then
        return fieldID
    end

    rule.field = fieldID
    rule.operator = Rules.GetDefaultOperator(fieldID)
    rule.value = nil
    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return fieldID
end

function Categories.UpdateRuleOperator(categoryID, ruleID, operatorID)
    local root = CopyTable(activeRoot)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    local rule = Rules.FindRule(ruleSet, ruleID)
    if not rule then
        return nil, Categories.ErrorCodes.MissingRule
    end

    if not Rules.IsOperatorValid(rule.field, operatorID) then
        return nil, Categories.ErrorCodes.InvalidRuleOperator
    end

    if rule.operator == operatorID then
        return operatorID
    end

    rule.operator = operatorID
    if not Rules.OperatorNeedsValue(operatorID) then
        rule.value = nil
    end

    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return operatorID
end

function Categories.UpdateRuleValue(categoryID, ruleID, value)
    local root = CopyTable(activeRoot)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    local rule = Rules.FindRule(ruleSet, ruleID)
    if not rule then
        return nil, Categories.ErrorCodes.MissingRule
    end

    if not Rules.OperatorNeedsValue(rule.operator) then
        return nil, Categories.ErrorCodes.InvalidRuleValue
    end

    if Rules.GetFieldValueKind(rule.field) == Rules.ValueKinds.Text then
        local normalizedValue
        local changed

        normalizedValue, changed, errorCode = SetTextRuleValue(
            rule,
            1,
            value
        )
        if normalizedValue == nil then
            return nil, errorCode
        end

        if not changed then
            return normalizedValue
        end

        CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
        return normalizedValue
    end

    local normalizedValue
    local isValid
    normalizedValue, isValid = Rules.NormalizeInputValue(rule.field, value)
    if not isValid then
        return nil, Categories.ErrorCodes.InvalidRuleValue
    end

    if rule.value == normalizedValue then
        return normalizedValue
    end

    rule.value = normalizedValue
    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return normalizedValue
end

function Categories.UpdateRuleTextValue(
    categoryID,
    ruleID,
    valueIndex,
    value
)
    local root = CopyTable(activeRoot)
    local rule, errorCode = GetMutableTextRule(root, categoryID, ruleID)
    if not rule then
        return nil, errorCode
    end

    local normalizedValue
    local changed

    normalizedValue, changed, errorCode = SetTextRuleValue(
        rule,
        valueIndex,
        value
    )
    if normalizedValue == nil then
        return nil, errorCode
    end

    if not changed then
        return normalizedValue
    end

    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return normalizedValue
end

function Categories.AddRuleTextValue(categoryID, ruleID)
    local root = CopyTable(activeRoot)
    local rule, errorCode = GetMutableTextRule(root, categoryID, ruleID)
    if not rule then
        return nil, errorCode
    end

    local values = Rules.GetRuleTextValues(rule)
    if #values == 0 then
        values[1] = ""
    end

    values[#values + 1] = ""
    rule.value = values
    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return #values
end

function Categories.RemoveRuleTextValue(categoryID, ruleID, valueIndex)
    local root = CopyTable(activeRoot)
    local rule, errorCode = GetMutableTextRule(root, categoryID, ruleID)
    if not rule then
        return nil, errorCode
    end

    local values = Rules.GetRuleTextValues(rule)
    if type(valueIndex) ~= "number"
        or valueIndex % 1 ~= 0
        or valueIndex < 1
        or valueIndex > #values then
        return nil, Categories.ErrorCodes.InvalidRuleValueIndex
    end

    table.remove(values, valueIndex)
    rule.value = #values > 0 and values or nil
    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return true
end

function Categories.RemoveRule(categoryID, ruleID)
    local root = CopyTable(activeRoot)
    local ruleSet, errorCode = GetMutableRuleSet(root, categoryID)
    if not ruleSet then
        return nil, errorCode
    end

    local _, ruleIndex = Rules.FindRule(ruleSet, ruleID)
    if not ruleIndex then
        return nil, Categories.ErrorCodes.MissingRule
    end

    table.remove(ruleSet.entries, ruleIndex)
    CommitRoot(root, Categories.ChangeTypes.RulesChanged, categoryID)
    return true
end

function Categories.ResetCategories()
    if not NS.db:IsModified(DB_KEY) then
        return false
    end

    pendingChangeType = Categories.ChangeTypes.Reset
    pendingCategoryID = nil

    local success, result = pcall(NS.db.ResetPath, NS.db, DB_KEY)
    if not success then
        pendingChangeType = nil
        pendingCategoryID = nil
        error(result, 2)
    end

    if pendingChangeType then
        pendingChangeType = nil
        pendingCategoryID = nil
        ReloadFromActiveProfile(Categories.ChangeTypes.Reset)
    end

    pendingChangeType = nil
    pendingCategoryID = nil
    return true
end

function Categories.Initialize()
    if Categories.initialized then
        return
    end

    RebuildCaches(NS.db:GetCopy(DB_KEY))
    Categories.initialized = true
    NS.db:RegisterCallback(OnCategoriesChanged, DB_KEY)
    NS.db:RegisterLifecycleCallback("OnDataChanged", OnProfileDataChanged)
    NS.db:RegisterLifecycleCallback("OnReset", OnProfileReset)
end

RebuildCaches(CopyTable(DEFAULT_ROOT))
NS:RegisterInitCallback(Categories.Initialize)

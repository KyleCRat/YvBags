local _, NS = ...

-- Profile-backed category registry, mutation API, and built-in classification.
local Categories = {}
NS.Categories = Categories

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
}

local activeRoot
local orderedDefinitions = {}
local definitionsByID = {}
local categoryLabels = {}
local categorySortPriorities = {}
local callbacks = {}
local callbackLookup = {}
local pendingChangeType
local pendingCategoryID

Categories.labels = categoryLabels

-- Blizzard enum compatibility
local function EnumValue(enumName, key, fallback)
    if Enum and Enum[enumName] and Enum[enumName][key] ~= nil then
        return Enum[enumName][key]
    end

    return fallback
end

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

    for sortPriority, categoryID in ipairs(activeRoot.order) do
        local definition = activeRoot.definitions[categoryID]
        if definition then
            local cachedDefinition = CopyTable(definition)
            cachedDefinition.id = categoryID
            orderedDefinitions[#orderedDefinitions + 1] = cachedDefinition
            definitionsByID[categoryID] = cachedDefinition
            categoryLabels[categoryID] = cachedDefinition.name
            categorySortPriorities[categoryID] = sortPriority
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

-- Consumable subclasses presented as openable items
local CONSUMABLE_CLASS_ID = EnumValue("ItemClass", "Consumable", 0)
local OPENABLE_CONSUMABLE_SUBCLASSES = {
    [EnumValue("ItemConsumableSubclass", "UtilityCurio", 10)] = true,
    [EnumValue("ItemConsumableSubclass", "CombatCurio", 11)] = true,
    [EnumValue("ItemConsumableSubclass", "Relic", 12)] = true,
}

local function IsOpenableConsumable(item)
    return item.classID == CONSUMABLE_CLASS_ID
        and OPENABLE_CONSUMABLE_SUBCLASSES[item.subclassID] == true
end

-- Item class to default category mapping
local ITEM_CLASS_CATEGORIES = {}

local function SetItemClassCategory(enumKey, fallback, categoryKey)
    ITEM_CLASS_CATEGORIES[EnumValue("ItemClass", enumKey, fallback)] = categoryKey
end

SetItemClassCategory("Consumable", 0, "consumable")
SetItemClassCategory("Container", 1, "container")
SetItemClassCategory("Weapon", 2, "equipment")
SetItemClassCategory("Gem", 3, "gem")
SetItemClassCategory("Armor", 4, "equipment")
SetItemClassCategory("Reagent", 5, "reagent")
SetItemClassCategory("Tradegoods", 7, "tradegoods")
SetItemClassCategory("ItemEnhancement", 8, "enhancement")
SetItemClassCategory("Recipe", 9, "recipe")
SetItemClassCategory("Questitem", 12, "quest")
SetItemClassCategory("Miscellaneous", 15, "miscellaneous")
SetItemClassCategory("Glyph", 16, "glyph")
SetItemClassCategory("WoWToken", 18, "token")
SetItemClassCategory("Profession", 19, "profession")
SetItemClassCategory("Housing", 20, "housing")

local function GetBuiltInCategoryKey(item)
    if item.isKeystone then
        return "keystone"
    end

    if item.hasLoot or IsOpenableConsumable(item) then
        return "openable"
    end

    if item.collectionKind then
        return "collectables"
    end

    if item.isCosmetic then
        return "cosmetic"
    end

    if ITEM_CLASS_CATEGORIES[item.classID] == "quest" then
        return "quest"
    end

    if item.quality == EnumValue("ItemQuality", "Poor", 0) and (item.sellValue or 0) > 0 then
        return "junk"
    end

    if item.isCraftingReagent then
        return "reagent"
    end

    return ITEM_CLASS_CATEGORIES[item.classID] or "other"
end

-- Public category registry
function Categories.GetCategoryKey(item)
    local categoryID = GetBuiltInCategoryKey(item)
    if definitionsByID[categoryID] then
        return categoryID
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

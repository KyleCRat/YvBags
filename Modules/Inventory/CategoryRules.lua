local _, NS = ...

-- Structured category-rule registry, compiler, and normalized-item evaluator.
local CategoryRules = {}
NS.CategoryRules = CategoryRules

local BindingKeys = NS.Binding.Keys
local DEFAULT_CATEGORY_ROOT = NS.defaults.profile.categories
local OTHER_CATEGORY_ID = "other"
local RULE_ID_PREFIX = "rule:"
local DEFAULT_MODE = "all"

CategoryRules.Modes = {
    All = "all",
    Any = "any",
}

CategoryRules.ValueKinds = {
    Text = "text",
    Integer = "integer",
    Enum = "enum",
    OrderedEnum = "orderedEnum",
    Boolean = "boolean",
}

local function IsPublicValue(value)
    if issecretvalue(value) then
        return false
    end

    return value ~= nil
end

local function IsPublicTrue(value)
    return IsPublicValue(value) and value == true
end

-- Existing built-in classification, retained as normalized rule input
local CONSUMABLE_CLASS_ID = Enum.ItemClass.Consumable
local OPENABLE_CONSUMABLE_SUBCLASSES = {
    [Enum.ItemConsumableSubclass.UtilityCurio] = true,
    [Enum.ItemConsumableSubclass.CombatCurio] = true,
    [Enum.ItemConsumableSubclass.Relic] = true,
}
local ITEM_CLASS_CATEGORIES = {
    [Enum.ItemClass.Consumable] = "consumable",
    [Enum.ItemClass.Container] = "container",
    [Enum.ItemClass.Weapon] = "equipment",
    [Enum.ItemClass.Gem] = "gem",
    [Enum.ItemClass.Armor] = "equipment",
    [Enum.ItemClass.Reagent] = "reagent",
    [Enum.ItemClass.Tradegoods] = "tradegoods",
    [Enum.ItemClass.ItemEnhancement] = "enhancement",
    [Enum.ItemClass.Recipe] = "recipe",
    [Enum.ItemClass.Questitem] = "quest",
    [Enum.ItemClass.Miscellaneous] = "miscellaneous",
    [Enum.ItemClass.Glyph] = "glyph",
    [Enum.ItemClass.WoWToken] = "token",
    [Enum.ItemClass.Profession] = "profession",
    [Enum.ItemClass.Housing] = "housing",
}

local function IsOpenableConsumable(item)
    local classID = item.classID
    local subclassID = item.subclassID

    return IsPublicValue(classID)
        and IsPublicValue(subclassID)
        and classID == CONSUMABLE_CLASS_ID
        and OPENABLE_CONSUMABLE_SUBCLASSES[subclassID] == true
end

function CategoryRules.GetDefaultCategoryID(item)
    if IsPublicTrue(item.isKeystone) then
        return "keystone"
    end

    if IsPublicTrue(item.hasLoot) or IsOpenableConsumable(item) then
        return "openable"
    end

    if IsPublicValue(item.collectionKind) then
        return "collectables"
    end

    if IsPublicTrue(item.isCosmetic) then
        return "cosmetic"
    end

    local classID = item.classID
    local classCategory
    if IsPublicValue(classID) then
        classCategory = ITEM_CLASS_CATEGORIES[classID]
    end

    if classCategory == "quest" then
        return "quest"
    end

    local quality = item.quality
    local sellValue = item.sellValue
    if IsPublicValue(quality)
        and quality == Enum.ItemQuality.Poor
        and IsPublicValue(sellValue)
        and type(sellValue) == "number"
        and sellValue > 0 then
        return "junk"
    end

    if IsPublicTrue(item.isCraftingReagent) then
        return "reagent"
    end

    return classCategory or OTHER_CATEGORY_ID
end

function CategoryRules.MakeClassSubclassKey(classID, subclassID)
    if not IsPublicValue(classID) or not IsPublicValue(subclassID) then
        return nil
    end

    if type(classID) ~= "number" or type(subclassID) ~= "number" then
        return nil
    end

    return tostring(classID) .. ":" .. tostring(subclassID)
end

function CategoryRules.NormalizeRuleText(value)
    if not IsPublicValue(value)
        or type(value) ~= "string"
        or value == "" then
        return nil
    end

    return strlower(value)
end

-- Rule storage normalization
local function IsValidRuleID(ruleID)
    if type(ruleID) ~= "string" then
        return false
    end

    local digits = ruleID:match("^rule:(%d+)$")
    local numericID = tonumber(digits)
    return numericID ~= nil
        and numericID >= 1
        and tostring(numericID) == digits
end

local function FindUnusedRuleID(usedIDs, nextRuleID)
    local ruleID = RULE_ID_PREFIX .. tostring(nextRuleID)

    while usedIDs[ruleID] do
        nextRuleID = nextRuleID + 1
        ruleID = RULE_ID_PREFIX .. tostring(nextRuleID)
    end

    return ruleID, nextRuleID + 1
end

function CategoryRules.CreateEmptyRuleSet()
    return {
        mode = DEFAULT_MODE,
        nextRuleID = 1,
        entries = {},
    }
end

function CategoryRules.NormalizeRuleSet(ruleSet)
    if type(ruleSet) ~= "table" then
        return CategoryRules.CreateEmptyRuleSet()
    end

    local mode = ruleSet.mode
    if mode ~= CategoryRules.Modes.All and mode ~= CategoryRules.Modes.Any then
        mode = DEFAULT_MODE
    end

    local nextRuleID = ruleSet.nextRuleID
    if type(nextRuleID) ~= "number"
        or nextRuleID < 1
        or nextRuleID % 1 ~= 0 then
        nextRuleID = 1
    end

    local entries = {}
    local usedIDs = {}
    local sourceEntries = type(ruleSet.entries) == "table"
        and ruleSet.entries
        or {}

    for _, sourceRule in ipairs(sourceEntries) do
        if type(sourceRule) == "table" then
            local rule = CopyTable(sourceRule)
            local numericID = IsValidRuleID(rule.id)
                and tonumber(rule.id:match("^rule:(%d+)$"))
                or nil

            if not numericID or usedIDs[rule.id] then
                rule.id = nil
            else
                usedIDs[rule.id] = true
                if numericID >= nextRuleID then
                    nextRuleID = numericID + 1
                end
            end

            if type(rule.field) ~= "string" then
                rule.field = nil
            end

            if type(rule.operator) ~= "string" then
                rule.operator = nil
            end

            entries[#entries + 1] = rule
        end
    end

    for _, rule in ipairs(entries) do
        if not rule.id then
            rule.id, nextRuleID = FindUnusedRuleID(usedIDs, nextRuleID)
            usedIDs[rule.id] = true
        end
    end

    local normalizedRuleSet = CopyTable(ruleSet)
    normalizedRuleSet.mode = mode
    normalizedRuleSet.nextRuleID = nextRuleID
    normalizedRuleSet.entries = entries
    return normalizedRuleSet
end

function CategoryRules.FindRule(ruleSet, ruleID)
    if type(ruleSet) ~= "table" or type(ruleSet.entries) ~= "table" then
        return nil, nil
    end

    for index, rule in ipairs(ruleSet.entries) do
        if rule.id == ruleID then
            return rule, index
        end
    end

    return nil, nil
end

function CategoryRules.AllocateRule(ruleSet)
    local usedIDs = {}
    for _, rule in ipairs(ruleSet.entries) do
        usedIDs[rule.id] = true
    end

    local ruleID
    ruleID, ruleSet.nextRuleID = FindUnusedRuleID(
        usedIDs,
        ruleSet.nextRuleID
    )
    ruleSet.entries[#ruleSet.entries + 1] = {
        id = ruleID,
    }

    return ruleID
end

-- Editor choice builders
local function CopyChoices(choices)
    local result = {}
    for index, choice in ipairs(choices) do
        result[index] = {
            label = choice.label,
            value = choice.value,
        }
    end
    return result
end

local function SortChoices(choices)
    table.sort(choices, function(left, right)
        local comparison = strcmputf8i(left.label, right.label)
        if comparison ~= 0 then
            return comparison < 0
        end

        return tostring(left.value) < tostring(right.value)
    end)

    return choices
end

local function BuildDefaultCategoryChoices()
    local choices = {}
    for _, categoryID in ipairs(DEFAULT_CATEGORY_ROOT.order) do
        local definition = DEFAULT_CATEGORY_ROOT.definitions[categoryID]
        if definition then
            choices[#choices + 1] = {
                label = definition.name,
                value = categoryID,
            }
        end
    end
    return choices
end

local function BuildQualityChoices()
    local choices = {}
    local qualityValues = {}
    local seenQualities = {}
    for _, quality in pairs(Enum.ItemQuality) do
        if type(quality) == "number"
            and quality >= 0
            and not seenQualities[quality] then
            qualityValues[#qualityValues + 1] = quality
            seenQualities[quality] = true
        end
    end
    table.sort(qualityValues)

    for _, quality in ipairs(qualityValues) do
        choices[#choices + 1] = {
            label = _G["ITEM_QUALITY" .. quality .. "_DESC"],
            value = quality,
        }
    end
    return choices
end

local itemClassChoices
local function BuildItemClassChoices()
    if itemClassChoices then
        return itemClassChoices
    end

    local classIDs = {}
    local seenClassIDs = {}
    for _, classID in pairs(Enum.ItemClass) do
        if type(classID) == "number" and not seenClassIDs[classID] then
            classIDs[#classIDs + 1] = classID
            seenClassIDs[classID] = true
        end
    end
    table.sort(classIDs)

    itemClassChoices = {}
    for _, classID in ipairs(classIDs) do
        local label = C_Item.GetItemClassInfo(classID)
        if label and label ~= "" then
            itemClassChoices[#itemClassChoices + 1] = {
                label = label,
                value = classID,
            }
        end
    end

    SortChoices(itemClassChoices)
    return itemClassChoices
end

local itemSubclassChoices
local function BuildItemSubclassChoices()
    if itemSubclassChoices then
        return itemSubclassChoices
    end

    local subclassIDs = {}
    local seenSubclassIDs = {}
    for enumName, enumTable in pairs(Enum) do
        if type(enumName) == "string"
            and enumName:match("^Item.*Subclass$")
            and type(enumTable) == "table" then
            for _, subclassID in pairs(enumTable) do
                if type(subclassID) == "number"
                    and subclassID >= 0
                    and not seenSubclassIDs[subclassID] then
                    subclassIDs[#subclassIDs + 1] = subclassID
                    seenSubclassIDs[subclassID] = true
                end
            end
        end
    end
    table.sort(subclassIDs)

    itemSubclassChoices = {}
    for _, classChoice in ipairs(BuildItemClassChoices()) do
        local classID = classChoice.value
        for _, subclassID in ipairs(subclassIDs) do
            local subclassName = C_Item.GetItemSubClassInfo(
                classID,
                subclassID
            )
            if subclassName and subclassName ~= "" then
                itemSubclassChoices[#itemSubclassChoices + 1] = {
                    label = classChoice.label .. ": " .. subclassName,
                    value = CategoryRules.MakeClassSubclassKey(
                        classID,
                        subclassID
                    ),
                }
            end
        end
    end

    SortChoices(itemSubclassChoices)
    return itemSubclassChoices
end

local function BuildEquipmentSlotChoices()
    local choices = {}
    local inventoryTypes = {}
    local seenInventoryTypes = {}
    local seenKeys = {}
    local labelCounts = {}

    for _, inventoryType in pairs(Enum.InventoryType) do
        if type(inventoryType) == "number"
            and inventoryType >= 0
            and not seenInventoryTypes[inventoryType] then
            inventoryTypes[#inventoryTypes + 1] = inventoryType
            seenInventoryTypes[inventoryType] = true
        end
    end
    table.sort(inventoryTypes)

    for _, inventoryType in ipairs(inventoryTypes) do
        local equipLoc = C_Item.GetItemInventorySlotKey(inventoryType)
        if equipLoc and equipLoc ~= "" and not seenKeys[equipLoc] then
            local label = C_Item.GetItemInventorySlotInfo(inventoryType)
            choices[#choices + 1] = {
                label = label,
                value = equipLoc,
            }
            seenKeys[equipLoc] = true
            labelCounts[label] = (labelCounts[label] or 0) + 1
        end
    end

    for _, choice in ipairs(choices) do
        if labelCounts[choice.label] > 1 then
            choice.label = choice.label
                .. " ("
                .. choice.value:gsub("^INVTYPE_", "")
                .. ")"
        end
    end

    return SortChoices(choices)
end

local function BuildBindingChoices()
    return {
        { label = NONE, value = BindingKeys.None },
        { label = UNKNOWN, value = BindingKeys.Unknown },
        {
            label = ITEM_BIND_ON_PICKUP,
            value = BindingKeys.Pickup,
        },
        {
            label = ITEM_BIND_ON_EQUIP,
            value = BindingKeys.Equip,
        },
        {
            label = ITEM_BIND_ON_USE,
            value = BindingKeys.Use,
        },
        { label = ITEM_BIND_QUEST, value = BindingKeys.Quest },
        {
            label = ITEM_BIND_TO_ACCOUNT,
            value = BindingKeys.Account,
        },
        {
            label = ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIPPED,
            value = BindingKeys.AccountUntilEquipped,
        },
        { label = "Bound", value = BindingKeys.Bound },
    }
end

local function GetExpansionName(expansionID)
    local expansionInfo = GetExpansionDisplayInfo(expansionID)
    if expansionInfo and expansionInfo.name then
        return expansionInfo.name
    end

    return "Expansion " .. tostring(expansionID)
end

local function BuildExpansionChoices()
    local choices = {}

    for expansionID = 0, LE_EXPANSION_LEVEL_CURRENT do
        choices[#choices + 1] = {
            label = GetExpansionName(expansionID),
            value = expansionID,
        }
    end
    return choices
end

local function BuildProfessionQualityChoices()
    local choices = {}
    for quality = 1, 5 do
        choices[#choices + 1] = {
            label = "Quality " .. tostring(quality),
            value = quality,
        }
    end
    return choices
end

local function BuildCollectionKindChoices()
    return {
        { label = "Toy", value = "toy" },
        { label = "Mount", value = "mount" },
        { label = "Pet", value = "pet" },
        { label = "Battle Pet", value = "battlepet" },
    }
end

local VALUE_CHOICE_BUILDERS = {
    defaultCategory = BuildDefaultCategoryChoices,
    quality = BuildQualityChoices,
    classID = BuildItemClassChoices,
    classSubclass = BuildItemSubclassChoices,
    equipLoc = BuildEquipmentSlotChoices,
    binding = BuildBindingChoices,
    expansion = BuildExpansionChoices,
    professionQuality = BuildProfessionQualityChoices,
    collectionKind = BuildCollectionKindChoices,
}
local valueChoiceCache = {}

-- Field and operator registries
local OPERATORS = {
    equals = { id = "equals", label = "Equals", needsValue = true },
    notEquals = { id = "notEquals", label = "Does Not Equal", needsValue = true },
    contains = { id = "contains", label = "Contains", needsValue = true },
    notContains = { id = "notContains", label = "Does Not Contain", needsValue = true },
    greaterOrEqual = { id = "greaterOrEqual", label = "At Least", needsValue = true },
    lessOrEqual = { id = "lessOrEqual", label = "At Most", needsValue = true },
    isTrue = { id = "isTrue", label = "True", needsValue = false },
    isFalse = { id = "isFalse", label = "False", needsValue = false },
}

local EQUALITY_OPERATORS = { "equals", "notEquals" }
local TEXT_OPERATORS = { "contains", "notContains", "equals", "notEquals" }
local ORDERED_OPERATORS = { "equals", "notEquals", "greaterOrEqual", "lessOrEqual" }
local BOOLEAN_OPERATORS = { "isTrue", "isFalse" }
local FIELD_ORDER = {
    "defaultCategory",
    "name",
    "tooltipText",
    "itemID",
    "quality",
    "itemLevel",
    "requiredLevel",
    "classID",
    "classSubclass",
    "equipLoc",
    "binding",
    "expansion",
    "professionQuality",
    "collectionKind",
    "isCraftingReagent",
    "isCosmetic",
    "isKeystone",
    "hasLoot",
    "isReadable",
    "isBound",
}
local FIELDS = {
    defaultCategory = { label = "YvBags Category", property = "defaultCategoryID", kind = CategoryRules.ValueKinds.Enum, operators = EQUALITY_OPERATORS },
    name = { label = "Item Name", property = "ruleName", kind = CategoryRules.ValueKinds.Text, operators = TEXT_OPERATORS },
    tooltipText = { label = "Tooltip Text", property = "ruleTooltipText", kind = CategoryRules.ValueKinds.Text, operators = TEXT_OPERATORS },
    itemID = { label = "Item ID", property = "itemID", kind = CategoryRules.ValueKinds.Integer, operators = EQUALITY_OPERATORS, minimum = 1 },
    quality = { label = "Quality", property = "quality", kind = CategoryRules.ValueKinds.OrderedEnum, operators = ORDERED_OPERATORS },
    itemLevel = { label = "Item Level", property = "itemLevel", kind = CategoryRules.ValueKinds.Integer, operators = ORDERED_OPERATORS, minimum = 0 },
    requiredLevel = { label = "Required Level", property = "requiredLevel", kind = CategoryRules.ValueKinds.Integer, operators = ORDERED_OPERATORS, minimum = 0 },
    classID = { label = "Item Type", property = "classID", kind = CategoryRules.ValueKinds.Enum, operators = EQUALITY_OPERATORS },
    classSubclass = { label = "Item Subtype", property = "classSubclassKey", kind = CategoryRules.ValueKinds.Enum, operators = EQUALITY_OPERATORS },
    equipLoc = { label = "Equipment Slot", property = "equipLoc", kind = CategoryRules.ValueKinds.Enum, operators = EQUALITY_OPERATORS },
    binding = { label = "Binding", property = "bindingKey", kind = CategoryRules.ValueKinds.Enum, operators = EQUALITY_OPERATORS },
    expansion = { label = "Expansion", property = "expansionID", kind = CategoryRules.ValueKinds.OrderedEnum, operators = ORDERED_OPERATORS },
    professionQuality = { label = "Profession Quality", property = "professionQuality", kind = CategoryRules.ValueKinds.OrderedEnum, operators = ORDERED_OPERATORS },
    collectionKind = { label = "Collection Type", property = "collectionKind", kind = CategoryRules.ValueKinds.Enum, operators = EQUALITY_OPERATORS },
    isCraftingReagent = { label = "Crafting Reagent", property = "isCraftingReagent", kind = CategoryRules.ValueKinds.Boolean, operators = BOOLEAN_OPERATORS },
    isCosmetic = { label = "Cosmetic", property = "isCosmetic", kind = CategoryRules.ValueKinds.Boolean, operators = BOOLEAN_OPERATORS },
    isKeystone = { label = "Mythic Keystone", property = "isKeystone", kind = CategoryRules.ValueKinds.Boolean, operators = BOOLEAN_OPERATORS },
    hasLoot = { label = "Contains Loot", property = "hasLoot", kind = CategoryRules.ValueKinds.Boolean, operators = BOOLEAN_OPERATORS },
    isReadable = { label = "Readable", property = "isReadable", kind = CategoryRules.ValueKinds.Boolean, operators = BOOLEAN_OPERATORS },
    isBound = { label = "Bound", property = "isBound", kind = CategoryRules.ValueKinds.Boolean, operators = BOOLEAN_OPERATORS },
}

local MODE_CHOICES = {
    { label = "All Rules", value = CategoryRules.Modes.All },
    { label = "Any Rule", value = CategoryRules.Modes.Any },
}

function CategoryRules.GetModeChoices()
    return CopyChoices(MODE_CHOICES)
end

function CategoryRules.IsModeValid(mode)
    return mode == CategoryRules.Modes.All or mode == CategoryRules.Modes.Any
end

function CategoryRules.GetFieldChoices()
    local choices = {}
    for _, fieldID in ipairs(FIELD_ORDER) do
        choices[#choices + 1] = {
            label = FIELDS[fieldID].label,
            value = fieldID,
        }
    end
    return choices
end

function CategoryRules.GetFieldValueKind(fieldID)
    local field = FIELDS[fieldID]
    return field and field.kind or nil
end

local function FieldSupportsOperator(field, operatorID)
    if not field or not OPERATORS[operatorID] then
        return false
    end

    for _, supportedOperatorID in ipairs(field.operators) do
        if supportedOperatorID == operatorID then
            return true
        end
    end

    return false
end

function CategoryRules.IsFieldValid(fieldID)
    return FIELDS[fieldID] ~= nil
end

function CategoryRules.IsOperatorValid(fieldID, operatorID)
    return FieldSupportsOperator(FIELDS[fieldID], operatorID)
end

function CategoryRules.GetDefaultOperator(fieldID)
    local field = FIELDS[fieldID]
    return field and field.operators[1] or nil
end

function CategoryRules.GetOperatorChoices(fieldID)
    local choices = {}
    local field = FIELDS[fieldID]
    if not field then
        return choices
    end

    for _, operatorID in ipairs(field.operators) do
        local operator = OPERATORS[operatorID]
        choices[#choices + 1] = {
            label = operator.label,
            value = operator.id,
        }
    end
    return choices
end

function CategoryRules.OperatorNeedsValue(operatorID)
    local operator = OPERATORS[operatorID]
    return operator and operator.needsValue == true or false
end

function CategoryRules.GetValueChoices(fieldID)
    if not VALUE_CHOICE_BUILDERS[fieldID] then
        return {}
    end

    if not valueChoiceCache[fieldID] then
        valueChoiceCache[fieldID] = VALUE_CHOICE_BUILDERS[fieldID]()
    end

    return CopyChoices(valueChoiceCache[fieldID])
end

local function HasASCIIControl(value)
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte <= 31 or byte == 127 then
            return true
        end
    end

    return false
end

local function NormalizeTextValue(value, allowEmpty)
    if not IsPublicValue(value) or type(value) ~= "string" then
        return nil
    end

    value = strtrim(value)
    if value == "" then
        return allowEmpty and "" or nil
    end

    if HasASCIIControl(value) then
        return nil
    end

    local success, length = pcall(strlenutf8, value)
    if not success or type(length) ~= "number" then
        return nil
    end

    return value
end

local function CopyStoredTextValues(value)
    local values = {}

    if type(value) == "string" then
        values[1] = value
        return values
    end

    if type(value) ~= "table" then
        return values
    end

    for _, storedValue in ipairs(value) do
        if type(storedValue) == "string" then
            values[#values + 1] = storedValue
        end
    end

    return values
end

function CategoryRules.GetRuleTextValues(rule)
    return CopyStoredTextValues(rule and rule.value)
end

function CategoryRules.GetRuleTextValueCount(rule)
    local value = rule and rule.value
    if type(value) == "string" then
        return 1
    end

    if type(value) ~= "table" then
        return 1
    end

    local count = 0
    for _, storedValue in ipairs(value) do
        if type(storedValue) == "string" then
            count = count + 1
        end
    end

    return math.max(1, count)
end

local function NormalizeIntegerValue(field, value)
    if type(value) == "string" then
        value = tonumber(strtrim(value))
    end

    if type(value) ~= "number"
        or value ~= value
        or value % 1 ~= 0
        or (field.minimum and value < field.minimum) then
        return nil
    end

    return value
end

local function IsChoiceValue(fieldID, value)
    for _, choice in ipairs(CategoryRules.GetValueChoices(fieldID)) do
        if choice.value == value then
            return true
        end
    end

    return false
end

function CategoryRules.NormalizeInputValue(fieldID, value)
    local field = FIELDS[fieldID]
    if not field then
        return nil, false
    end

    if field.kind == CategoryRules.ValueKinds.Text then
        local normalized = NormalizeTextValue(value, true)
        return normalized, normalized ~= nil
    elseif field.kind == CategoryRules.ValueKinds.Integer then
        local normalized = NormalizeIntegerValue(field, value)
        return normalized, normalized ~= nil
    elseif field.kind == CategoryRules.ValueKinds.Enum
        or field.kind == CategoryRules.ValueKinds.OrderedEnum then
        if IsChoiceValue(fieldID, value) then
            return value, true
        end
    elseif field.kind == CategoryRules.ValueKinds.Boolean then
        return nil, true
    end

    return nil, false
end

function CategoryRules.GetRuleValueText(rule)
    if not rule or rule.value == nil then
        return ""
    end

    if type(rule.value) == "table" then
        local values = CopyStoredTextValues(rule.value)
        return values[1] or ""
    end

    return tostring(rule.value)
end

-- Compiled rule evaluation
local function NormalizeStoredValue(field, value)
    if field.kind == CategoryRules.ValueKinds.Integer then
        return NormalizeIntegerValue(field, value)
    elseif field.kind == CategoryRules.ValueKinds.Enum then
        if type(value) == "string" and value ~= "" then
            return value
        elseif type(value) == "number" and value == value then
            return value
        end
    elseif field.kind == CategoryRules.ValueKinds.OrderedEnum then
        if type(value) == "number" and value == value then
            return value
        end
    elseif field.kind == CategoryRules.ValueKinds.Boolean then
        return true
    end

    return nil
end

local function CompileStoredTextValues(value)
    local values = {}
    local seenValues = {}

    for _, storedValue in ipairs(CopyStoredTextValues(value)) do
        local normalized = NormalizeTextValue(storedValue)
        normalized = normalized and strlower(normalized) or nil

        if normalized and not seenValues[normalized] then
            values[#values + 1] = normalized
            seenValues[normalized] = true
        end
    end

    return #values > 0 and values or nil
end

local function CompileRule(rule)
    local field = type(rule) == "table" and FIELDS[rule.field]
    if not field or not FieldSupportsOperator(field, rule.operator) then
        return nil
    end

    local operator = OPERATORS[rule.operator]
    local value
    local values
    if operator.needsValue then
        if field.kind == CategoryRules.ValueKinds.Text then
            values = CompileStoredTextValues(rule.value)
            if not values then
                return nil
            end
        else
            value = NormalizeStoredValue(field, rule.value)
            if value == nil then
                return nil
            end
        end
    end

    return {
        property = field.property,
        operator = operator.id,
        value = value,
        values = values,
        kind = field.kind,
    }
end

function CategoryRules.CompileRuleSet(ruleSet)
    local compiled = {
        mode = type(ruleSet) == "table" and ruleSet.mode or DEFAULT_MODE,
        entries = {},
    }

    if not CategoryRules.IsModeValid(compiled.mode) then
        compiled.mode = DEFAULT_MODE
    end

    local entries = type(ruleSet) == "table"
        and type(ruleSet.entries) == "table"
        and ruleSet.entries
        or {}

    for _, rule in ipairs(entries) do
        local compiledRule = CompileRule(rule)
        if compiledRule then
            compiled.entries[#compiled.entries + 1] = compiledRule
        end
    end

    return compiled
end

local function EvaluateTextRule(rule, itemValue)
    local matchesAny = false
    local usesEquality = rule.operator == "equals"
        or rule.operator == "notEquals"

    for _, value in ipairs(rule.values) do
        if (usesEquality and itemValue == value)
            or (not usesEquality
                and string.find(itemValue, value, 1, true) ~= nil) then
            matchesAny = true
            break
        end
    end

    if rule.operator == "notEquals"
        or rule.operator == "notContains" then
        return not matchesAny
    end

    return matchesAny
end

local function EvaluateRule(rule, item)
    local itemValue = item[rule.property]
    if issecretvalue(itemValue) or itemValue == nil then
        return false
    end

    if rule.kind == CategoryRules.ValueKinds.Integer
        or rule.kind == CategoryRules.ValueKinds.OrderedEnum then
        if type(itemValue) ~= "number" or itemValue ~= itemValue then
            return false
        end
    elseif rule.kind == CategoryRules.ValueKinds.Text then
        if type(itemValue) ~= "string" then
            return false
        end
    elseif rule.kind == CategoryRules.ValueKinds.Enum then
        if type(itemValue) ~= type(rule.value) then
            return false
        end
    elseif rule.kind == CategoryRules.ValueKinds.Boolean
        and type(itemValue) ~= "boolean" then
        return false
    end

    if rule.kind == CategoryRules.ValueKinds.Text then
        return EvaluateTextRule(rule, itemValue)
    end

    if rule.operator == "equals" then
        return itemValue == rule.value
    elseif rule.operator == "notEquals" then
        return itemValue ~= rule.value
    elseif rule.operator == "contains" then
        return string.find(itemValue, rule.value, 1, true) ~= nil
    elseif rule.operator == "notContains" then
        return string.find(itemValue, rule.value, 1, true) == nil
    elseif rule.operator == "greaterOrEqual" then
        return itemValue >= rule.value
    elseif rule.operator == "lessOrEqual" then
        return itemValue <= rule.value
    elseif rule.operator == "isTrue" then
        return itemValue == true
    elseif rule.operator == "isFalse" then
        return itemValue == false
    end

    return false
end

function CategoryRules.Matches(compiledRuleSet, item)
    if not compiledRuleSet
        or #compiledRuleSet.entries == 0 then
        return false
    end

    if compiledRuleSet.mode == CategoryRules.Modes.Any then
        for _, rule in ipairs(compiledRuleSet.entries) do
            if EvaluateRule(rule, item) then
                return true
            end
        end

        return false
    end

    for _, rule in ipairs(compiledRuleSet.entries) do
        if not EvaluateRule(rule, item) then
            return false
        end
    end

    return true
end

local _, NS = ...

-- Occupied-slot normalization, async fallbacks, and special item-link handling.
local ItemModel = {}
NS.ItemModel = ItemModel

local Categories = NS.Categories
local Containers = NS.Containers
local Binding = NS.Binding
local BindingKeys = Binding.Keys

local UNKNOWN_ITEM_ICON = 134400
local CAGED_BATTLE_PET_ITEM_ID = 82800
local tooltipSearchCache = {}

-- Blizzard enum compatibility
local function EnumValue(enumName, key, fallback)
    if Enum and Enum[enumName] and Enum[enumName][key] ~= nil then
        return Enum[enumName][key]
    end

    return fallback
end

-- Binding display mapping
local BIND_TYPE_INFO = {}

local function SetBindTypeInfo(enumKey, fallback, key, label)
    BIND_TYPE_INFO[EnumValue("ItemBind", enumKey, fallback)] = {
        key = key,
        label = label,
    }
end

SetBindTypeInfo("None", 0, BindingKeys.None, NONE or "None")
SetBindTypeInfo("OnAcquire", 1, BindingKeys.Pickup, ITEM_BIND_ON_PICKUP or "Bind on pickup")
SetBindTypeInfo("OnEquip", 2, BindingKeys.Equip, ITEM_BIND_ON_EQUIP or "Bind on equip")
SetBindTypeInfo("OnUse", 3, BindingKeys.Use, ITEM_BIND_ON_USE or "Bind on use")
SetBindTypeInfo("Quest", 4, BindingKeys.Quest, ITEM_BIND_QUEST or "Quest item")
SetBindTypeInfo("ToWoWAccount", 7, BindingKeys.Account, ITEM_BIND_TO_ACCOUNT or "Warbound")
SetBindTypeInfo("ToBnetAccount", 8, BindingKeys.Account, ITEM_BIND_TO_BNETACCOUNT or "Account bound")
SetBindTypeInfo("ToBnetAccountUntilEquipped", 9, BindingKeys.AccountUntilEquipped, ITEM_BIND_TO_BNETACCOUNT_UNTIL_EQUIPPED or "Account bound until equipped")

local function GetAccountUntilEquippedLabel()
    return ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIPPED or ITEM_BIND_TO_BNETACCOUNT_UNTIL_EQUIPPED or "Warbound until equipped"
end

local function IsBindType(bindType, key)
    local info = BIND_TYPE_INFO[bindType]
    return info and info.key == key
end

local function GetBindingInfo(bindType, isBound, isAccountBound, isAccountUntilEquipped)
    if isAccountUntilEquipped or IsBindType(bindType, BindingKeys.AccountUntilEquipped) then
        return BindingKeys.AccountUntilEquipped, GetAccountUntilEquippedLabel()
    end

    if isAccountBound or IsBindType(bindType, BindingKeys.Account) then
        local info = IsBindType(bindType, BindingKeys.Account) and BIND_TYPE_INFO[bindType]
        return BindingKeys.Account, info and info.label or ITEM_BIND_TO_ACCOUNT or "Warbound"
    end

    if isBound then
        return BindingKeys.Bound, "Bound"
    end

    local info = BIND_TYPE_INFO[bindType]
    if info then
        return info.key, info.label
    end

    return BindingKeys.Unknown, UNKNOWN or "Unknown"
end

local function IsBagItemAccountUntilEquipped(bagID, slotIndex, itemInfo)
    if not C_Item then
        return false
    end

    if C_Item.IsBoundToAccountUntilEquip and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
        if itemLocation and itemLocation.IsValid and itemLocation:IsValid() then
            local success, isAccountUntilEquipped = pcall(C_Item.IsBoundToAccountUntilEquip, itemLocation)
            if success and isAccountUntilEquipped then
                return true
            end
        end
    end

    if C_Item.IsItemBindToAccountUntilEquip and itemInfo then
        local success, isAccountUntilEquipped = pcall(C_Item.IsItemBindToAccountUntilEquip, itemInfo)
        if success and isAccountUntilEquipped then
            return true
        end
    end

    return false
end

local function IsItemInfoAccountBound(itemInfo)
    if not C_Item or not C_Item.IsItemBindToAccount or not itemInfo then
        return false
    end

    local success, isAccountBound = pcall(C_Item.IsItemBindToAccount, itemInfo)
    return success and isAccountBound
end

-- Link parsing helpers
local function StripLinkDisplayBrackets(displayText)
    if not displayText then
        return nil
    end

    return displayText:gsub("^%[", ""):gsub("%]$", "")
end

local function GetHyperlinkInfo(hyperlink)
    if not hyperlink then
        return nil, nil, nil
    end

    local linkType
    local linkOptions
    local displayText

    if LinkUtil and LinkUtil.ExtractLink then
        linkType, linkOptions, displayText = LinkUtil.ExtractLink(hyperlink)
    else
        linkType, linkOptions, displayText = hyperlink:match("|H([^:]*):([^|]*)|h(.*)|h")
    end

    return linkType, linkOptions, StripLinkDisplayBrackets(displayText)
end

-- Item API wrappers
local function GetItemInfoFields(itemInfo)
    if C_Item and C_Item.GetItemInfo and itemInfo then
        return C_Item.GetItemInfo(itemInfo)
    end

    return nil
end

local function GetProfessionQuality(itemInfo)
    if not itemInfo or not C_TradeSkillUI then
        return nil, nil
    end

    if C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local craftedQuality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemInfo)
        if craftedQuality ~= nil then
            return craftedQuality, "crafted"
        end
    end

    if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local reagentQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemInfo)
        if reagentQuality ~= nil then
            return reagentQuality, "reagent"
        end
    end

    return nil, nil
end

-- Tooltip search text
local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function GetTooltipText(value)
    if IsSecretValue(value) then
        return nil
    end

    if type(value) ~= "string" or value == "" then
        return nil
    end

    local text = C_StringUtil.StripHyperlinks(value)
    if IsSecretValue(text) then
        return nil
    end

    if type(text) == "string" and text ~= "" then
        return text
    end

    return nil
end

local function GetTooltipSearchText(item)
    local itemReference = item.link
    if IsSecretValue(itemReference) then
        return ""
    end

    if not itemReference then
        itemReference = item.staticLink
        if IsSecretValue(itemReference) then
            return ""
        end
    end

    if not itemReference then
        itemReference = item.itemID
        if IsSecretValue(itemReference) then
            return ""
        end
    end

    if not itemReference then
        return ""
    end

    local cached = tooltipSearchCache[item.locationKey]
    if cached
        and cached.itemReference == itemReference
        and cached.count == item.count
        and cached.bindingKey == item.bindingKey
        and cached.isBound == item.isBound
        and cached.isPendingItemInfo == item.isPendingItemInfo then
        return cached.text
    end

    local tooltipData = C_TooltipInfo.GetBagItem(item.bagID, item.slotIndex)
    if IsSecretValue(tooltipData) or type(tooltipData) ~= "table" then
        return ""
    end

    local lines = tooltipData.lines
    if IsSecretValue(lines) or type(lines) ~= "table" then
        return ""
    end

    local values = {}
    for _, line in ipairs(lines) do
        if not IsSecretValue(line) and type(line) == "table" then
            local leftText = GetTooltipText(line.leftText)
            local rightText = GetTooltipText(line.rightText)
            if leftText and rightText then
                values[#values + 1] = leftText .. " " .. rightText
            elseif leftText or rightText then
                values[#values + 1] = leftText or rightText
            end
        end
    end

    local text = table.concat(values, "\n")
    tooltipSearchCache[item.locationKey] = {
        itemReference = itemReference,
        count = item.count,
        bindingKey = item.bindingKey,
        isBound = item.isBound,
        isPendingItemInfo = item.isPendingItemInfo,
        text = text,
    }
    return text
end

local function GetCurrentBagItemLevel(bagID, slotIndex)
    if not ItemLocation or not ItemLocation.CreateFromBagAndSlot or not C_Item or not C_Item.GetCurrentItemLevel then
        return nil
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
    if itemLocation and itemLocation.IsValid and itemLocation:IsValid() then
        return C_Item.GetCurrentItemLevel(itemLocation)
    end

    return nil
end

-- Keystone special handling
local function IsKeystoneItem(itemInfo)
    if C_Item and C_Item.IsItemKeystoneByID and itemInfo then
        return C_Item.IsItemKeystoneByID(itemInfo)
    end

    return false
end

local function GetOwnedKeystoneInfo()
    if not C_MythicPlus then
        return nil, nil, nil
    end

    local keystoneLevel
    if C_MythicPlus.GetOwnedKeystoneLevel then
        keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    end

    local mapID
    if C_MythicPlus.GetOwnedKeystoneChallengeMapID then
        mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    end

    if not mapID and C_MythicPlus.GetOwnedKeystoneMapID then
        mapID = C_MythicPlus.GetOwnedKeystoneMapID()
    end

    local mapName
    if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        mapName = C_ChallengeMode.GetMapUIInfo(mapID)
    end

    return keystoneLevel, mapID, mapName
end

-- Battle pet special handling
local function GetBattlePetLinkInfo(hyperlink)
    if not hyperlink or not BattlePetToolTip_UnpackBattlePetLink then
        return nil, nil, nil, nil, nil, nil, nil
    end

    local speciesID
    local level
    local quality
    local maxHealth
    local power
    local speed
    local name
    speciesID, level, quality, maxHealth, power, speed, name = BattlePetToolTip_UnpackBattlePetLink(hyperlink)

    return speciesID, level, quality, maxHealth, power, speed, StripLinkDisplayBrackets(name)
end

local function GetBattlePetSpeciesIcon(speciesID)
    if not speciesID or not C_PetJournal or not C_PetJournal.GetPetInfoBySpeciesID then
        return nil
    end

    local _, icon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
    return icon
end

-- Normalized item builder
function ItemModel.Normalize(container, slotIndex, containerItemInfo)
    -- Resolve the link or item ID used for Blizzard item metadata.
    local itemInfo = containerItemInfo.hyperlink or containerItemInfo.itemID
    local staticItemInfo = containerItemInfo.itemID
    local linkType
    local linkOptions
    local hyperlinkDisplayText
    linkType, linkOptions, hyperlinkDisplayText = GetHyperlinkInfo(containerItemInfo.hyperlink)
    if linkType == "battlepet" and staticItemInfo then
        itemInfo = staticItemInfo
    end

    local instantItemID
    local instantItemType
    local instantItemSubType
    local instantEquipLoc
    local instantIcon
    local instantClassID
    local instantSubClassID

    -- Fetch synchronous fields first so icons/classes are available on cache misses.
    if C_Item and C_Item.GetItemInfoInstant and itemInfo then
        instantItemID, instantItemType, instantItemSubType, instantEquipLoc, instantIcon, instantClassID, instantSubClassID = C_Item.GetItemInfoInstant(itemInfo)
    end

    if not instantItemID and C_Item and C_Item.GetItemInfoInstant and staticItemInfo and staticItemInfo ~= itemInfo then
        instantItemID, instantItemType, instantItemSubType, instantEquipLoc, instantIcon, instantClassID, instantSubClassID = C_Item.GetItemInfoInstant(staticItemInfo)
    end

    local fullName
    local fullLink
    local itemQuality
    local staticItemLevel
    local requiredLevel
    local fullItemType
    local fullItemSubType
    local maxStack
    local fullEquipLoc
    local fullIcon
    local sellValue
    local classID
    local subClassID
    local bindType
    local expansionID
    local setID
    local isCraftingReagent
    local itemDescription

    -- Fetch async item fields, with static item ID fallback for dynamic links.
    fullName, fullLink, itemQuality, staticItemLevel, requiredLevel, fullItemType, fullItemSubType, maxStack, fullEquipLoc, fullIcon, sellValue, classID, subClassID, bindType, expansionID, setID, isCraftingReagent, itemDescription = GetItemInfoFields(itemInfo)

    local usedStaticFallback = false
    if not fullName and staticItemInfo and staticItemInfo ~= itemInfo then
        fullName, fullLink, itemQuality, staticItemLevel, requiredLevel, fullItemType, fullItemSubType, maxStack, fullEquipLoc, fullIcon, sellValue, classID, subClassID, bindType, expansionID, setID, isCraftingReagent, itemDescription = GetItemInfoFields(staticItemInfo)
        usedStaticFallback = fullName ~= nil
    end

    -- Apply special handling for item-like links that need extra Blizzard APIs.
    local isKeystone = IsKeystoneItem(staticItemInfo or itemInfo)
    local keystoneLevel
    local keystoneMapID
    local keystoneMapName
    if isKeystone then
        keystoneLevel, keystoneMapID, keystoneMapName = GetOwnedKeystoneInfo()
        fullItemType = "Keystone"
        fullItemSubType = "Mythic Keystone"
        sellValue = 0
        bindType = bindType or EnumValue("ItemBind", "OnAcquire", 1)
        isCraftingReagent = false
    end

    if isKeystone and not fullName then
        fullName = containerItemInfo.itemName or hyperlinkDisplayText or "Mythic Keystone"
        itemQuality = itemQuality or containerItemInfo.quality
        staticItemLevel = staticItemLevel or 1
    end

    local isBattlePet = linkType == "battlepet" or containerItemInfo.itemID == CAGED_BATTLE_PET_ITEM_ID
    local battlePetSpeciesID
    local battlePetLevel
    local battlePetQuality
    local battlePetMaxHealth
    local battlePetPower
    local battlePetSpeed
    local battlePetName
    local battlePetIcon
    if isBattlePet then
        battlePetSpeciesID, battlePetLevel, battlePetQuality, battlePetMaxHealth, battlePetPower, battlePetSpeed, battlePetName = GetBattlePetLinkInfo(containerItemInfo.hyperlink)
        battlePetIcon = GetBattlePetSpeciesIcon(battlePetSpeciesID)
        itemQuality = battlePetQuality or itemQuality or containerItemInfo.quality
        staticItemLevel = battlePetLevel or staticItemLevel
        fullItemType = BATTLE_PET or "Battle Pet"
        fullItemSubType = "Caged Pet"
    end

    -- Resolve derived fields used by columns, sorting, and diagnostics.
    local actualItemLevel
    local previewLevel
    local sparseItemLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo and itemInfo then
        actualItemLevel, previewLevel, sparseItemLevel = C_Item.GetDetailedItemLevelInfo(itemInfo)
    end

    local professionQuality
    local professionQualityType
    professionQuality, professionQualityType = GetProfessionQuality(itemInfo)

    local currentItemLevel = GetCurrentBagItemLevel(container.id, slotIndex)
    local isAccountUntilEquipped = IsBagItemAccountUntilEquipped(container.id, slotIndex, itemInfo)
    if not isAccountUntilEquipped and staticItemInfo and staticItemInfo ~= itemInfo then
        isAccountUntilEquipped = IsBagItemAccountUntilEquipped(container.id, slotIndex, staticItemInfo)
    end

    local isAccountBound = IsItemInfoAccountBound(itemInfo)
    if not isAccountBound and staticItemInfo and staticItemInfo ~= itemInfo then
        isAccountBound = IsItemInfoAccountBound(staticItemInfo)
    end

    local bindingKey
    local bindingText
    bindingKey, bindingText = GetBindingInfo(bindType, containerItemInfo.isBound, isAccountBound, isAccountUntilEquipped)
    local displayItemLevel = currentItemLevel or actualItemLevel or staticItemLevel

    if isKeystone and keystoneLevel then
        displayItemLevel = keystoneLevel
    elseif isBattlePet and battlePetLevel then
        displayItemLevel = battlePetLevel
    end

    local displayName = hyperlinkDisplayText or fullName or containerItemInfo.itemName or (containerItemInfo.itemID and ("Item " .. tostring(containerItemInfo.itemID))) or "Unknown Item"
    if isBattlePet and battlePetName then
        displayName = (containerItemInfo.itemName or fullName or "Pet Cage") .. ": " .. battlePetName
    end

    -- Build the normalized row model consumed by UI and sorting.
    local item = {
        locationKey = Containers.MakeLocationKey(container.id, slotIndex),
        bagID = container.id,
        slotIndex = slotIndex,
        bagSlotText = ("%d/%d"):format(container.id, slotIndex),
        containerKind = container.kind,
        containerName = container.name,
        itemID = containerItemInfo.itemID or instantItemID,
        name = displayName,
        link = containerItemInfo.hyperlink or fullLink,
        staticLink = fullLink,
        linkType = linkType,
        linkOptions = linkOptions,
        icon = battlePetIcon or fullIcon or containerItemInfo.iconFileID or instantIcon or UNKNOWN_ITEM_ICON,
        count = containerItemInfo.stackCount or 1,
        quality = itemQuality or containerItemInfo.quality,
        itemLevel = displayItemLevel,
        currentItemLevel = currentItemLevel,
        actualItemLevel = actualItemLevel,
        previewItemLevel = previewLevel,
        sparseItemLevel = sparseItemLevel or staticItemLevel,
        requiredLevel = requiredLevel,
        type = fullItemType or instantItemType,
        subtype = fullItemSubType or instantItemSubType,
        classID = classID or instantClassID,
        subclassID = subClassID or instantSubClassID,
        equipLoc = fullEquipLoc or instantEquipLoc,
        maxStack = maxStack,
        bindType = bindType,
        bindingKey = bindingKey,
        bindingText = bindingText,
        isBound = containerItemInfo.isBound,
        isAccountBound = isAccountBound,
        isAccountUntilEquipped = isAccountUntilEquipped,
        sellValue = sellValue or 0,
        totalSellValue = (sellValue or 0) * (containerItemInfo.stackCount or 1),
        expansionID = expansionID,
        setID = setID,
        isCraftingReagent = isCraftingReagent,
        itemDescription = itemDescription,
        isKeystone = isKeystone,
        keystoneLevel = keystoneLevel,
        keystoneMapID = keystoneMapID,
        keystoneMapName = keystoneMapName,
        isBattlePet = isBattlePet,
        battlePetSpeciesID = battlePetSpeciesID,
        battlePetLevel = battlePetLevel,
        battlePetQuality = battlePetQuality,
        battlePetMaxHealth = battlePetMaxHealth,
        battlePetPower = battlePetPower,
        battlePetSpeed = battlePetSpeed,
        battlePetName = battlePetName,
        battlePetIcon = battlePetIcon,
        professionQuality = professionQuality,
        professionQualityType = professionQualityType,
        isLocked = containerItemInfo.isLocked,
        isReadable = containerItemInfo.isReadable,
        hasLoot = containerItemInfo.hasLoot,
        hasNoValue = containerItemInfo.hasNoValue,
        isFiltered = containerItemInfo.isFiltered,
        isPendingItemInfo = fullName == nil,
        usedStaticItemInfoFallback = usedStaticFallback,
    }

    item.categoryKey = Categories.GetCategoryKey(item)
    item.categoryName = Categories.GetCategoryName(item.categoryKey)
    item.tooltipSearchText = GetTooltipSearchText(item)

    return item, itemInfo
end

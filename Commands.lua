local _, NS = ...

local function HasInventoryModule()
    if not NS.Inventory then
        NS:Print("Inventory module is not loaded.")
        return false
    end

    return true
end

local function PrintInventoryStats()
    if not HasInventoryModule() then
        return
    end

    if not NS.Inventory.initialScanComplete then
        NS.Inventory:ScanNow("slash-stats")
    end

    local stats = NS.Inventory:GetStats()
    NS:Print(("Inventory: %d items, %d used, %d free, %d total, %d containers, %d pending item info."):format(
        stats.itemCount or 0,
        stats.usedSlots or 0,
        stats.freeSlots or 0,
        stats.totalSlots or 0,
        stats.containerCount or 0,
        stats.pendingItemInfoCount or 0
    ))
end

local function PrintInventoryContainers()
    if not HasInventoryModule() then
        return
    end

    local containers = NS.Inventory:GetContainers()
    if #containers == 0 then
        NS.Inventory:ScanNow("slash-containers")
    end

    for _, container in ipairs(NS.Inventory:GetContainers()) do
        NS:Print(("%s %d: %s, %d/%d used, family %s"):format(
            container.kind,
            container.id,
            container.name,
            container.usedSlots or 0,
            container.numSlots or 0,
            tostring(container.bagFamily or 0)
        ))
    end
end

local function PrintPendingItems()
    if not HasInventoryModule() then
        return
    end

    NS.Inventory:ScanNow("slash-pending")

    local pendingItems = NS.Inventory:GetPendingItems()
    if #pendingItems == 0 then
        NS:Print("No pending item info.")
        return
    end

    NS:Print(("Pending item info: %d item(s)."):format(#pendingItems))

    for _, item in ipairs(pendingItems) do
        NS:Print(("%s itemID=%s name=%s"):format(
            item.bagSlotText or item.locationKey or "?",
            tostring(item.itemID or "?"),
            item.link or item.name or item.containerItemName or "Unknown"
        ))

        NS:Print(("  fallback type=%s/%s class=%s/%s quality=%s category=%s bind=%s expansion=%s sell=%s ilvl=%s req=%s profQ=%s requested=%s"):format(
            tostring(item.type or "?"),
            tostring(item.subtype or "?"),
            tostring(item.classID or "?"),
            tostring(item.subclassID or "?"),
            tostring(item.quality or item.containerQuality or "?"),
            tostring(item.categoryKey or "?"),
            tostring(item.bindingKey or "?"),
            tostring(item.expansionID or "?"),
            tostring(item.sellValue or "?"),
            tostring(item.itemLevel or "?"),
            tostring(item.requiredLevel or "?"),
            tostring(item.professionQuality or "?"),
            tostring(item.requestedLoad)
        ))

        NS:Print(("  itemInfoSource=%s hasContainerLink=%s containerName=%s"):format(
            tostring(item.itemInfoType or "?"),
            tostring(item.hasContainerHyperlink),
            tostring(item.containerItemName or "?")
        ))

        NS:Print(("  linkType=%s staticFallback=%s keystone=%s keyLevel=%s keyMap=%s battlePet=%s species=%s petLevel=%s petQuality=%s"):format(
            tostring(item.linkType or "?"),
            tostring(item.usedStaticItemInfoFallback),
            tostring(item.isKeystone),
            tostring(item.keystoneLevel or "?"),
            tostring(item.keystoneMapName or item.keystoneMapID or "?"),
            tostring(item.isBattlePet),
            tostring(item.battlePetSpeciesID or "?"),
            tostring(item.battlePetLevel or "?"),
            tostring(item.battlePetQuality or "?")
        ))
    end
end

local function JoinKeys(keys)
    return table.concat(keys or {}, ", ")
end

local function GetItemList()
    if not NS:IsInitialized() then
        return nil
    end

    if not NS.frame and InCombatLockdown and InCombatLockdown() then
        NS:Print("Open YvBags once before changing list settings in combat.")
        return nil
    end

    local frame = NS.frame or (NS.CreateMainFrame and NS:CreateMainFrame())
    if not frame or not frame.itemList then
        NS:Print("Item list is not loaded.")
        return nil
    end

    return frame.itemList
end

local function PrintSortUsage()
    local ListModel = NS.ItemListModel
    NS:Print(("Usage: /ybags sort <%s> [asc|desc]"):format(JoinKeys(ListModel.GetSortKeyList())))
end

local function PrintSecondarySortUsage()
    local ListModel = NS.ItemListModel
    NS:Print(("Usage: /ybags sort2 <%s> [asc|desc]"):format(JoinKeys(ListModel.GetSecondarySortKeyList())))
end

local function PrintGroupUsage()
    local ListModel = NS.ItemListModel
    NS:Print(("Usage: /ybags group <%s>"):format(JoinKeys(ListModel.GetGroupKeyList())))
end

local function ParseSortDirection(direction)
    direction = strtrim(direction or "")
    if direction == "" then
        return true, nil
    elseif direction == "asc" or direction == "ascending" then
        return true, true
    elseif direction == "desc" or direction == "descending" then
        return true, false
    end

    return false, direction
end

local function SetSortCommand(arguments)
    local ListModel = NS.ItemListModel
    arguments = strtrim(arguments or "")

    if arguments == "" then
        PrintSortUsage()
        return
    end

    local sortKey, direction = arguments:match("^(%S+)%s*(.-)$")
    if not sortKey or not ListModel.IsValidSortKey(sortKey) then
        NS:Print(("Unknown sort key: %s"):format(sortKey or ""))
        PrintSortUsage()
        return
    end

    local validDirection, sortAscending = ParseSortDirection(direction)
    if not validDirection then
        NS:Print(("Unknown sort direction: %s"):format(sortAscending))
        PrintSortUsage()
        return
    end

    local list = GetItemList()
    if not list then
        return
    end

    list:SetSort(sortKey, sortAscending)
    NS:Print(("Sorting by %s (%s)."):format(list.sortKey, list.sortAscending and "ascending" or "descending"))
end

local function SetSecondarySortCommand(arguments)
    local ListModel = NS.ItemListModel
    arguments = strtrim(arguments or "")

    if arguments == "" then
        PrintSecondarySortUsage()
        return
    end

    local sortKey, direction = arguments:match("^(%S+)%s*(.-)$")
    if not sortKey or not ListModel.IsValidSecondarySortKey(sortKey) then
        NS:Print(("Unknown secondary sort key: %s"):format(sortKey or ""))
        PrintSecondarySortUsage()
        return
    end

    local validDirection, sortAscending = ParseSortDirection(direction)
    if not validDirection then
        NS:Print(("Unknown sort direction: %s"):format(sortAscending))
        PrintSecondarySortUsage()
        return
    end

    local list = GetItemList()
    if not list then
        return
    end

    list:SetSecondarySort(sortKey, sortAscending)
    if list.secondarySortKey == ListModel.GetNoSecondarySortKey() then
        NS:Print("Secondary sorting disabled.")
    else
        NS:Print(("Secondary sorting by %s (%s)."):format(list.secondarySortKey, list.secondarySortAscending and "ascending" or "descending"))
    end
end

local function SetGroupCommand(arguments)
    local ListModel = NS.ItemListModel
    arguments = strtrim(arguments or "")

    if arguments == "" then
        PrintGroupUsage()
        return
    end

    if not ListModel.IsValidGroupKey(arguments) then
        NS:Print(("Unknown group key: %s"):format(arguments))
        PrintGroupUsage()
        return
    end

    local list = GetItemList()
    if not list then
        return
    end

    list:SetGroup(arguments)
    NS:Print(("Grouping by %s."):format(list.groupKey))
end

local COMMANDS = {
    {
        triggers = { "", "toggle" },
        name = "Toggle",
        description = "Toggle the YvBags frame",
        func = function()
            if NS:IsInitialized() then
                NS:ToggleFrame()
            end
        end,
    },
    {
        triggers = { "show", "open" },
        name = "Open",
        description = "Open the YvBags frame",
        func = function()
            if NS:IsInitialized() then
                NS:ShowFrame()
            end
        end,
    },
    {
        triggers = { "hide", "close" },
        name = "Close",
        description = "Close the YvBags frame",
        func = function()
            if NS:IsInitialized() then
                NS:HideFrame()
            end
        end,
    },
    {
        triggers = { "scan", "rescan" },
        name = "Scan",
        description = "Rescan player bags and print inventory stats",
        func = function()
            if NS:IsInitialized() and HasInventoryModule() then
                NS.Inventory:ScanNow("slash")
                PrintInventoryStats()
            end
        end,
    },
    {
        triggers = { "stats", "info" },
        name = "Stats",
        description = "Print current inventory scan stats",
        func = function()
            if NS:IsInitialized() then
                PrintInventoryStats()
            end
        end,
    },
    {
        triggers = { "containers", "bags" },
        name = "Containers",
        description = "Print discovered player bag containers",
        func = function()
            if NS:IsInitialized() then
                PrintInventoryContainers()
            end
        end,
    },
    {
        triggers = { "pending" },
        name = "Pending",
        description = "Print items still missing full item info",
        func = function()
            if NS:IsInitialized() then
                PrintPendingItems()
            end
        end,
    },
    {
        triggers = { "sort" },
        name = "Sort",
        description = "Set or toggle list sorting",
        func = PrintSortUsage,
    },
    {
        triggers = { "sort2", "secondarysort" },
        name = "Secondary Sort",
        description = "Set secondary list sorting",
        func = PrintSecondarySortUsage,
    },
    {
        triggers = { "group" },
        name = "Group",
        description = "Set list grouping",
        func = PrintGroupUsage,
    },
}

local function PrintHelp()
    for _, command in ipairs(COMMANDS) do
        NS:Print(("/ybags %s - %s"):format(command.triggers[1], command.description))
    end
end

SLASH_YVBAGS1 = "/ybags"
SLASH_YVBAGS2 = "/yvbags"

SlashCmdList.YVBAGS = function(message)
    local msg = strtrim((message or ""):lower())
    local command, arguments = msg:match("^(%S+)%s*(.-)$")

    if command == "sort" then
        SetSortCommand(arguments)
        return
    elseif command == "sort2" or command == "secondarysort" then
        SetSecondarySortCommand(arguments)
        return
    elseif command == "group" then
        SetGroupCommand(arguments)
        return
    end

    for _, command in ipairs(COMMANDS) do
        for _, trigger in ipairs(command.triggers) do
            if msg == trigger then
                command.func()
                return
            end
        end
    end

    PrintHelp()
end

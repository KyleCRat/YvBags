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

local ADDON_NAME, NS = ...

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

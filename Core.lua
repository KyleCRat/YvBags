local ADDON_NAME, NS = ...

local LibSimpleDB = LibStub("LibSimpleDB-1.0")

NS.initialized = false
NS.eventFrame = CreateFrame("Frame")

local EVENT_HANDLERS = {}
local INIT_CALLBACKS = {}

function NS:Print(message)
    print(("|cff33ccff%s|r %s"):format(ADDON_NAME, tostring(message)))
end

function NS:RegisterEvent(event)
    NS.eventFrame:RegisterEvent(event)
end

function NS:UnregisterEvent(event)
    NS.eventFrame:UnregisterEvent(event)
end

function NS:RegisterEventHandler(event, handler)
    if type(event) ~= "string" or type(handler) ~= "function" then
        error("Usage: NS:RegisterEventHandler(event, handler)", 2)
    end

    EVENT_HANDLERS[event] = EVENT_HANDLERS[event] or {}
    EVENT_HANDLERS[event][#EVENT_HANDLERS[event] + 1] = handler
    NS:RegisterEvent(event)
end

function NS:UnregisterEventHandler(event, handler)
    local handlers = EVENT_HANDLERS[event]
    if not handlers then
        return
    end

    if not handler then
        EVENT_HANDLERS[event] = nil
        NS:UnregisterEvent(event)
        return
    end

    for index = #handlers, 1, -1 do
        if handlers[index] == handler then
            tremove(handlers, index)
        end
    end

    if #handlers == 0 then
        EVENT_HANDLERS[event] = nil
        NS:UnregisterEvent(event)
    end
end

function NS:RegisterInitCallback(callback)
    if type(callback) ~= "function" then
        error("Usage: NS:RegisterInitCallback(callback)", 2)
    end

    if NS.initialized then
        callback()
        return
    end

    INIT_CALLBACKS[#INIT_CALLBACKS + 1] = callback
end

function NS:IsInitialized()
    return NS.initialized == true
end

function NS:InitializeDatabases()
    _G[NS.ACCOUNT_DB_NAME] = _G[NS.ACCOUNT_DB_NAME] or {}
    _G[NS.CHARACTER_DB_NAME] = _G[NS.CHARACTER_DB_NAME] or {}

    NS.db = LibSimpleDB:New(_G[NS.ACCOUNT_DB_NAME], NS.defaults.global)
    NS.charDB = LibSimpleDB:New(_G[NS.CHARACTER_DB_NAME], NS.defaults.character)
end

function NS:Initialize()
    if NS.initialized then
        return
    end

    NS:InitializeDatabases()
    NS.initialized = true

    for _, callback in ipairs(INIT_CALLBACKS) do
        callback()
    end

    NS.MainFrame.Create()
end

local function OnAddonLoaded(self, loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    NS:Initialize()
end

EVENT_HANDLERS.ADDON_LOADED = { OnAddonLoaded }

NS.eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = EVENT_HANDLERS[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(self, ...)
        end
    end
end)

NS.eventFrame:RegisterEvent("ADDON_LOADED")

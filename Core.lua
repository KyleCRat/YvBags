local ADDON_NAME, NS = ...

local LibSimpleDB = LibStub("LibSimpleDB-1.0")

NS.initialized = false
NS.eventFrame = CreateFrame("Frame")

local EVENT_HANDLERS = {}

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

    EVENT_HANDLERS[event] = handler
    NS:RegisterEvent(event)
end

function NS:UnregisterEventHandler(event)
    EVENT_HANDLERS[event] = nil
    NS:UnregisterEvent(event)
end

function NS:IsInitialized()
    return NS.initialized == true
end

function NS:InitializeDatabases()
    YvBagsDB = YvBagsDB or {}
    YvBagsCharacterDB = YvBagsCharacterDB or {}

    NS.db = LibSimpleDB:New(YvBagsDB, NS.defaults.global)
    NS.charDB = LibSimpleDB:New(YvBagsCharacterDB, NS.defaults.character)
end

function NS:Initialize()
    if NS.initialized then
        return
    end

    NS:InitializeDatabases()
    NS.initialized = true

    if NS.CreateMainFrame then
        NS:CreateMainFrame()
    end
end

local function OnAddonLoaded(self, loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    NS:Initialize()
end

EVENT_HANDLERS.ADDON_LOADED = OnAddonLoaded

NS.eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = EVENT_HANDLERS[event]
    if handler then
        handler(self, ...)
    end
end)

NS.eventFrame:RegisterEvent("ADDON_LOADED")

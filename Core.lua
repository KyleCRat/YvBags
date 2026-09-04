local ADDON_NAME, NS = ...

local LibSimpleDB = LibStub("LibSimpleDB-2.0")
local LibSimpleDBProfiles = LibStub("LibSimpleDBProfiles-1.0")

local LEGACY_ACCOUNT_ROOT_KEYS = {
    "debug",
    "features",
    "list",
    "pins",
    "display",
}

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

local function CreateAccountStorage()
    return {
        [NS.ACCOUNT_STORAGE_METADATA_KEY] = {
            schema = NS.ACCOUNT_STORAGE_SCHEMA_VERSION,
        },
        global = {},
        profiles = {},
    }
end

local function IsLegacyAccountStorage(storage)
    for index = 1, #LEGACY_ACCOUNT_ROOT_KEYS do
        if storage[LEGACY_ACCOUNT_ROOT_KEYS[index]] ~= nil then
            return true
        end
    end

    return false
end

local function MoveLegacyRoot(legacyPayload, globalPayload, key)
    if legacyPayload[key] ~= nil then
        globalPayload[key] = legacyPayload[key]
        legacyPayload[key] = nil
    end
end

local function AdoptLegacyAccountStorage(legacyPayload)
    local accountStorage = CreateAccountStorage()
    local globalPayload = accountStorage.global

    MoveLegacyRoot(legacyPayload, globalPayload, "debug")
    MoveLegacyRoot(legacyPayload, globalPayload, "features")

    local legacyPins = legacyPayload.pins
    if type(legacyPins) == "table" and legacyPins.items ~= nil then
        globalPayload.pins = {
            items = legacyPins.items,
        }
        legacyPins.items = nil

        if next(legacyPins) == nil then
            legacyPayload.pins = nil
        end
    end

    -- Retain the original flat payload by reference, but only after the new
    -- outer container exists. This avoids a SavedVariables reference cycle.
    accountStorage.profiles.global = legacyPayload
    return accountStorage
end

local function NormalizeAccountStorage(storage)
    local metadata = storage[NS.ACCOUNT_STORAGE_METADATA_KEY]

    if metadata ~= nil then
        if type(metadata) ~= "table"
            or metadata.schema ~= NS.ACCOUNT_STORAGE_SCHEMA_VERSION then
            error("YvBags: unsupported or corrupt account storage schema", 2)
        end

        if type(storage.global) ~= "table" or type(storage.profiles) ~= "table" then
            error("YvBags: corrupt account storage containers", 2)
        end

        return storage
    end

    if next(storage) == nil then
        return CreateAccountStorage()
    end

    if IsLegacyAccountStorage(storage) then
        return AdoptLegacyAccountStorage(storage)
    end

    error("YvBags: unrecognized unversioned account storage", 2)
end

function NS:InitializeDatabases()
    local accountStorage = _G[NS.ACCOUNT_DB_NAME]
    if accountStorage == nil then
        accountStorage = {}
    elseif type(accountStorage) ~= "table" then
        error("YvBags: account SavedVariables must be a table", 2)
    end

    accountStorage = NormalizeAccountStorage(accountStorage)
    _G[NS.ACCOUNT_DB_NAME] = accountStorage

    local characterStorage = _G[NS.CHARACTER_DB_NAME]
    if characterStorage == nil then
        characterStorage = {}
        _G[NS.CHARACTER_DB_NAME] = characterStorage
    elseif type(characterStorage) ~= "table" then
        error("YvBags: character SavedVariables must be a table", 2)
    end

    NS.globalDB = LibSimpleDB:New(accountStorage.global, NS.defaults.global)
    NS.charDB = LibSimpleDB:New(characterStorage, NS.defaults.character)
    NS.profileManager = LibSimpleDBProfiles:New(
        ADDON_NAME,
        accountStorage.profiles,
        NS.defaults.profile
    )
    NS.db = NS.profileManager:GetActiveDB()
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
    NS.BankFrame.Create()
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

local _, NS = ...

local BlizzardBags = {}
NS.BlizzardBags = BlizzardBags

local BAG_FUNCTION_NAMES = {
    "ToggleAllBags",
    "OpenAllBags",
    "CloseAllBags",
    "ToggleBag",
    "OpenBag",
    "CloseBag",
    "ToggleBackpack",
    "OpenBackpack",
    "CloseBackpack",
    "IsAnyBagOpen",
}

local originals = {}
local wrappersInstalled = false
local callingOriginal = false

local function GetFeatureEnabled()
    return not NS.db or NS.db:Get("features", "replaceBlizzardBags") ~= false
end

local function CanOpenBags()
    if ContainerFrame_AllowedToOpenBags then
        return ContainerFrame_AllowedToOpenBags()
    end

    return true
end

local function IsReplacementFrameShown()
    return NS.frame and NS.frame:IsShown()
end

local function CallOriginal(name, ...)
    local original = originals[name]
    if not original then
        return nil
    end

    local wasCallingOriginal = callingOriginal
    callingOriginal = true
    local results = { original(...) }
    callingOriginal = wasCallingOriginal
    return unpack(results)
end

local function ShouldUseReplacement()
    return not callingOriginal and GetFeatureEnabled()
end

local function AnyBlizzardBagOpen()
    if originals.IsAnyBagOpen then
        return CallOriginal("IsAnyBagOpen")
    end

    return false
end

function BlizzardBags.IsReplacementEnabled()
    return GetFeatureEnabled()
end

function BlizzardBags.HideBlizzardBags()
    if not GetFeatureEnabled() or not AnyBlizzardBagOpen() then
        return false
    end

    return CallOriginal("CloseAllBags")
end

function BlizzardBags.ShowReplacement()
    if not CanOpenBags() then
        return false
    end

    BlizzardBags.HideBlizzardBags()

    if NS.ShowFrame then
        NS:ShowFrame()
        return true
    end

    return false
end

function BlizzardBags.ToggleReplacement()
    if not CanOpenBags() then
        return false
    end

    if IsReplacementFrameShown() then
        NS:HideFrame()
        return true
    end

    if AnyBlizzardBagOpen() then
        BlizzardBags.HideBlizzardBags()
        return true
    end

    return BlizzardBags.ShowReplacement()
end

function BlizzardBags.CloseReplacement(frame, forceUpdate)
    local wasShown = IsReplacementFrameShown()
    if wasShown and NS.HideFrame then
        NS:HideFrame()
    end

    local closedBlizzardBags = CallOriginal("CloseAllBags", frame, forceUpdate)
    return wasShown or closedBlizzardBags
end

function BlizzardBags.ShowBlizzardBags()
    if NS.HideFrame then
        NS:HideFrame()
    end

    if originals.OpenAllBags then
        CallOriginal("OpenAllBags", nil, true)
    elseif originals.OpenBackpack then
        CallOriginal("OpenBackpack")
    end
end

local function WrapBagFunctions()
    if wrappersInstalled then
        return
    end

    for _, name in ipairs(BAG_FUNCTION_NAMES) do
        originals[name] = _G[name]
    end

    _G.ToggleAllBags = function()
        if ShouldUseReplacement() then
            return BlizzardBags.ToggleReplacement()
        end

        return CallOriginal("ToggleAllBags")
    end

    _G.OpenAllBags = function(frame, forceUpdate)
        if ShouldUseReplacement() then
            return BlizzardBags.ShowReplacement()
        end

        return CallOriginal("OpenAllBags", frame, forceUpdate)
    end

    _G.CloseAllBags = function(frame, forceUpdate)
        if ShouldUseReplacement() then
            return BlizzardBags.CloseReplacement(frame, forceUpdate)
        end

        return CallOriginal("CloseAllBags", frame, forceUpdate)
    end

    _G.ToggleBag = function(id)
        if ShouldUseReplacement() then
            return BlizzardBags.ToggleReplacement()
        end

        return CallOriginal("ToggleBag", id)
    end

    _G.OpenBag = function(id, force)
        if ShouldUseReplacement() then
            return BlizzardBags.ShowReplacement()
        end

        return CallOriginal("OpenBag", id, force)
    end

    _G.CloseBag = function(id)
        if ShouldUseReplacement() then
            local wasShown = IsReplacementFrameShown()
            if wasShown and NS.HideFrame then
                NS:HideFrame()
            end

            local closedBlizzardBag = CallOriginal("CloseBag", id)
            return wasShown or closedBlizzardBag
        end

        return CallOriginal("CloseBag", id)
    end

    _G.ToggleBackpack = function()
        if ShouldUseReplacement() then
            return BlizzardBags.ToggleReplacement()
        end

        return CallOriginal("ToggleBackpack")
    end

    _G.OpenBackpack = function()
        if ShouldUseReplacement() then
            return BlizzardBags.ShowReplacement()
        end

        return CallOriginal("OpenBackpack")
    end

    _G.CloseBackpack = function()
        if ShouldUseReplacement() then
            local wasShown = IsReplacementFrameShown()
            if wasShown and NS.HideFrame then
                NS:HideFrame()
            end

            local closedBlizzardBackpack = CallOriginal("CloseBackpack")
            return wasShown or closedBlizzardBackpack
        end

        return CallOriginal("CloseBackpack")
    end

    wrappersInstalled = true
end

NS:RegisterInitCallback(function()
    WrapBagFunctions()
    BlizzardBags.HideBlizzardBags()

    if NS.db and NS.db.RegisterCallback then
        NS.db:RegisterCallback("features.replaceBlizzardBags", function(_, enabled)
            if enabled ~= false then
                BlizzardBags.HideBlizzardBags()
            end
        end)
    end
end)

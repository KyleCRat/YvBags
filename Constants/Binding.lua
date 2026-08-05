local _, NS = ...

local Binding = {}
NS.Binding = Binding

Binding.Keys = {
    None = "none",
    Unknown = "unknown",
    Pickup = "pickup",
    Equip = "equip",
    Use = "use",
    Quest = "quest",
    Account = "account",
    AccountUntilEquipped = "accountUntilEquipped",
    Bound = "bound",
}

local Keys = Binding.Keys

function Binding.IsWarboundKey(key)
    return key == Keys.Account or key == Keys.AccountUntilEquipped
end

function Binding.HasBindingIcon(key)
    return key
        and key ~= Keys.None
        and key ~= Keys.Unknown
        and key ~= Keys.Equip
        and key ~= Keys.Use
end

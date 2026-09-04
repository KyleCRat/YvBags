# YvBags

YvBags is a World of Warcraft inventory replacement addon that shows your bags,
Character bank, and Warband bank as sortable, searchable lists instead of grids.

## Features

- Replaces standard Blizzard player bag open, close, and toggle behavior.
- Supports the backpack, equipped bag slots, and equipped reagent bag.
- Independently replaces the Blizzard bank with one movable and resizable frame
  containing separate Character and Warband views.
- Combines all purchased physical tabs within each bank view while retaining
  native tab configuration, purchase, cleanup, money, and deposit actions.
- Shows inventory contents in a virtualized list for fast scrolling.
- Uses full-row item interaction for tooltips, item use, drag, pickup, and cooldown display.
- Supports name, column, and tooltip search plus collapsible groups, primary sorting, secondary sorting, and manual bag-slot ordering.
- Surfaces unseen items in accent-highlighted top rows until they are hovered and the bag is reopened.
- Supports account-wide item pinning with top-row, collapsible-group, top-of-group, or normal-sort presentation in every grouping and sort mode.
- Keeps the Mythic Keystone in its own prioritized category unless the keystone kind is pinned.
- Includes explicitly ordered built-in categories, leading with Openable, Cosmetic, Collectables, Mythic Keystone, Consumable, and Equipment while keeping Junk last.
- Classifies Blizzard loot containers plus Utility Curio, Combat Curio, and Relic consumables as Openable.
- Groups Blizzard-recognized Toy, Mount, learnable Pet, and caged Battle Pet items into Collectables without relying on tooltip text.
- Displays quantity, binding, rarity/icon, profession quality, name, expansion, sell value, item level, required level, type, and subtype columns.
- Shows item rarity through name color and icon border color.
- Shows equipped bag buttons for bag swapping and right-click emptying.
- Supports dropping cursor-held items into available bag space.
- Shows used/total bag space and calls Blizzard bag cleanup when clicked.
- Shows current character money and tracked backpack currencies in the footer.
- Can restore the original Blizzard bag frames from the backpack button.
- Includes optional gray-quality junk autosell when a merchant opens.
- Includes Character, Specialization, Class, Realm, Faction, Global, and user-created settings profiles.
- Includes a modern profile-backed category and rule editor for creating,
  ordering, and defining custom item classifications.

## Usage

YvBags opens from normal bag keybinds when **Replace Blizzard Bags** is enabled. You can also use `/ybags` to toggle the frame.

When **Replace Blizzard Bank** is enabled, interacting with a banker opens the
custom bank window. Use its Character and Warband buttons to switch views;
YvBags remembers the last available view used by each character.

Middle-click an item row to pin or unpin that item type. Pinning a Mythic Keystone applies to every future keystone regardless of its dungeon or level.

Pinned-item presentation can place pins above the full list, in one collapsible Pinned group, at the top of their respective groups, or in normal sort order. Manual sorting preserves physical bag-slot order within each resulting section.

Items Blizzard marks as new appear above pinned rows and groups. When pins use Top Rows presentation, a divider separates the new-item and pinned sections. Hovering a new row acknowledges it and removes its breathing highlight without moving it or removing its new-item marker. The marker remains until the row returns to its normal sorted position after YvBags is closed and reopened, or until the item is physically moved. Unseen rows remain at the top across bag opens.

While the YvBags frame is open and you are out of combat, press `Ctrl+F` to focus the search field. The shortcut is inactive while the frame is closed or during combat and does not change the player's saved binding.

Right-click a column header to change grouping, primary sort, or secondary sort. Left-click sortable headers to sort by that column.

The footer includes:

- Bag space: left-click to run Blizzard's bag cleanup.
- Backpack button: left-click to show Blizzard bags, right-click to empty the backpack into other compatible bags.
- Equipped bag buttons: left-click or drag to pick up the bag, right-click to empty that bag first.
- Tracked currencies: left-click opens the character currency pane, middle-click stops tracking that currency.

The bank footer shows every purchased tab as an icon. Hover an icon to inspect
its usage and deposit rules, or click it to open Blizzard's tab configurator.
Only the next available tab purchase is shown. The footer also retains
Blizzard's native bank cleanup, money transfer, Character-bank reagent deposit,
and Warband deposit controls, including the tradeable-reagent option.

## Settings

Open settings with `/ybags settings` or through the Blizzard AddOns settings panel.

Settings include:

- Active profile plus create, copy, rename, reset, and delete actions
- Replace Blizzard Bags
- Sell Gray Junk At Vendors
- Show Cooldowns In Item Names
- Frame scale
- Group By
- Pinned Items presentation
- Primary Sort and direction
- Secondary Sort and direction
- Categories subpage with category and Rule Set management
- Bank subpage with replacement, frame scale, list mirroring, grouping, pin
  presentation, and sorting controls

Profile settings include bag grouping and sorting, bank list mirroring or its
independent list configuration, pinned-item presentation, cooldown-name
display, and the complete shared category registry. Bag and bank replacement,
gray-junk selling, and pinned item identities remain shared across the addon.
Bag and bank frame position, size, and scale remain stored per character.

## Categories And Rules

Each category except **Other** owns one flat Rule Set. Choose **All Rules** to
require every rule or **Any Rule** to require at least one matching rule.
Categories are evaluated from top to bottom, and each item is assigned to the
first matching category. **Other** receives everything that remains unmatched
and therefore has no rules of its own.

Rules can be reordered for readability. Their order does not affect matching;
the Rule Set's **All Rules** or **Any Rule** mode determines how they combine.

Item Name and Tooltip Text rules can contain multiple text alternatives.
**Equals** and **Contains** match any entered alternative, while their negative
operators match only when none of the alternatives match. Use separate text
rules with **All Rules** when multiple text matches must all be present.

Rules can match normalized item properties such as YvBags' built-in category,
name, tooltip text, item ID, quality, levels, type, subtype, equipment slot,
binding, expansion, profession quality, collection type, and supported boolean
item flags. New categories begin with no rules and therefore remain empty until
a complete rule is added. Incomplete rules are ignored while they are being
configured.

## Profiles

Permanent profiles and user-created profiles appear together in the **Active Profile** selector. Permanent profiles can be selected, copied, and reset, but cannot be renamed or deleted. User profiles can also be created and renamed; inactive user profiles can be deleted.

Each character remembers its selected profile. On first use, YvBags checks Character, Specialization, Class, Realm, Faction, then Global and keeps the first profile that already contains settings. Global is the fallback. Selecting Specialization follows that character's current specialization while the selection remains Specialization.

If specialization information is still loading, YvBags finishes this one-time selection during login rather than permanently falling back to a broader profile.

## Slash Commands

| Command | Description |
| --- | --- |
| `/ybags` | Toggle the YvBags frame |
| `/ybags show` | Open the YvBags frame |
| `/ybags hide` | Close the YvBags frame |
| `/ybags scan` | Rescan player bags and print inventory stats |
| `/ybags stats` | Print current inventory scan stats |
| `/ybags containers` | Print discovered player bag containers |
| `/ybags pending` | Print items still missing full item info |
| `/ybags sort <key> [asc\|desc]` | Set or toggle primary sorting |
| `/ybags sort2 <key> [asc\|desc]` | Set secondary sorting |
| `/ybags group <key>` | Set list grouping |
| `/ybags settings` | Open YvBags settings |

Aliases:

- `/yvbags` also works for all commands.
- `open` aliases `show`.
- `close` aliases `hide`.
- `rescan` aliases `scan`.
- `info` aliases `stats`.
- `bags` aliases `containers`.
- `secondarysort` aliases `sort2`.
- `options` and `config` alias `settings`.

Sort keys: `manual`, `name`, `quality`, `itemLevel`, `requiredLevel`, `quantity`, `type`, `subtype`, `sellValue`, `expansion`, `professionQuality`, `binding`, `category`.

Group keys: `none`, `category`, `type`, `quality`, `binding`, `expansion`.

## Compatibility

The current release supports World of Warcraft: Midnight, interface version 12.1.0.

All required libraries are included with the addon.

When the optional Icon Browser addon is enabled, its searchable and filterable
browser replaces the native icon list in YvBags' bank-tab configurator.

## Limitations

- Guild banks, void storage, cached-character inventories, and currency-list
  replacement are not included.
- Grid mode is not included.
- Column visibility, resizing, and reordering are not included.

## Author

Yvairel

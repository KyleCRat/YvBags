# YvBags

YvBags is a World of Warcraft bag replacement addon that shows your current character's bags as a sortable, searchable list instead of a grid.

## Features

- Replaces standard Blizzard player bag open, close, and toggle behavior.
- Supports the backpack, equipped bag slots, and equipped reagent bag.
- Shows bag contents in a virtualized list for fast scrolling.
- Uses full-row item interaction for tooltips, item use, drag, pickup, and cooldown display.
- Supports name, column, and tooltip search plus collapsible groups, primary sorting, secondary sorting, and manual bag-slot ordering.
- Supports account-wide item pinning with top-row, collapsible-group, top-of-group, or normal-sort presentation in every grouping and sort mode.
- Keeps the Mythic Keystone in its own prioritized category unless the keystone kind is pinned.
- Includes explicitly ordered built-in categories, leading with Openable, Cosmetic, Collectables, Mythic Keystone, Consumable, and Equipment while keeping Junk last.
- Groups Blizzard-recognized Toy, Mount, learnable Pet, and caged Battle Pet items into Collectables without relying on tooltip text.
- Displays quantity, binding, rarity/icon, profession quality, name, expansion, sell value, item level, required level, type, and subtype columns.
- Shows item rarity through name color and icon border color.
- Shows equipped bag buttons for bag swapping and right-click emptying.
- Supports dropping cursor-held items into available bag space.
- Shows used/total bag space and calls Blizzard bag cleanup when clicked.
- Shows current character money and tracked backpack currencies in the footer.
- Can restore the original Blizzard bag frames from the backpack button.
- Includes optional gray-quality junk autosell when a merchant opens.

## Usage

YvBags opens from normal bag keybinds when **Replace Blizzard Bags** is enabled. You can also use `/ybags` to toggle the frame.

Middle-click an item row to pin or unpin that item type. Pinning a Mythic Keystone applies to every future keystone regardless of its dungeon or level.

Pinned-item presentation can place pins above the full list, in one collapsible Pinned group, at the top of their respective groups, or in normal sort order. Manual sorting preserves physical bag-slot order within each resulting section.

While the YvBags frame is open and you are out of combat, press `Ctrl+F` to focus the search field. The shortcut is inactive while the frame is closed or during combat and does not change the player's saved binding.

Right-click a column header to change grouping, primary sort, or secondary sort. Left-click sortable headers to sort by that column.

The footer includes:

- Bag space: left-click to run Blizzard's bag cleanup.
- Backpack button: left-click to show Blizzard bags, right-click to empty the backpack into other compatible bags.
- Equipped bag buttons: left-click or drag to pick up the bag, right-click to empty that bag first.
- Tracked currencies: left-click opens the character currency pane, middle-click stops tracking that currency.

## Settings

Open settings with `/ybags settings` or through the Blizzard AddOns settings panel.

Settings include:

- Replace Blizzard Bags
- Sell Gray Junk At Vendors
- Show Cooldowns In Item Names
- Frame scale
- Group By
- Pinned Items presentation
- Primary Sort and direction
- Secondary Sort and direction

Frame position, size, and scale are stored per character. General addon settings are stored account-wide.

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

The current release supports World of Warcraft: Midnight, interface version 12.0.7.

All required libraries are included with the addon.

## Limitations

- Player bags only; bank, warband bank, guild bank, void storage, and currency-list replacement are not included.
- Grid mode is not included.
- Categories are built in for the initial release; custom category editing is not included.
- Column visibility, resizing, and reordering are not included.
- Profile management is not included.

## Author

Yvairel

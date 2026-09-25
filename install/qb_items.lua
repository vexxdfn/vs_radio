-- For qb-inventory, ps-inventory, lj-inventory, qs-inventory and other
-- inventories that use QBCore's items list.
--
-- Add to qb-core/shared/items.lua (or your inventory's shared items file).
-- Put images/radio.png in your inventory's image folder, e.g.
-- qb-inventory/html/images/ or qs-inventory/html/images/

radio = { name = 'radio', label = 'Radio', weight = 200, type = 'item', image = 'radio.png', unique = true, useable = true, shouldClose = true, description = 'A handheld radio.' },

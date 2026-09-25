-- Add to ox_inventory/data/items.lua
-- Put images/radio.png in ox_inventory/web/images/

['radio'] = {
    label = 'Radio',
    weight = 200,
    stack = false,
    close = true,
    description = 'A handheld radio.',
    client = {
        export = 'vs_radio.useRadio',
    },
},

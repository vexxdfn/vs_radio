Locales = Locales or {}

function _L(key, ...)
    local lang = Locales[Config.Locale or 'en'] or Locales.en or {}
    local text = lang[key] or (Locales.en and Locales.en[key]) or key
    if select('#', ...) > 0 then return text:format(...) end
    return text
end

function UIStrings()
    local out = {}
    local lang = Locales[Config.Locale or 'en'] or {}
    for key, value in pairs(Locales.en or {}) do
        if key:sub(1, 3) == 'ui_' then out[key] = lang[key] or value end
    end
    return out
end

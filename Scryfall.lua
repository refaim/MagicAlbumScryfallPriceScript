local function sleep(ms)
    local t = ms * 1250000
    local s = 0
    for i = 1, t do s = s + i end
    return s
end

local function load_library(name)
    local path = 'Prices\\lib\\' .. name .. '.lua'
    local file = ma.GetFile(path)
    if file == nil then error('Unable to load library ' .. path) end
    local lib, err = load(file)
    if err ~= nil then error(err) end
    local result = lib()
    return result
end

local json = load_library('JSON')

local SC_API_URL = 'https://api.scryfall.com'
local MY_API_URL = 'http://151.248.120.179/api/scryfall'

local function evaluate_set(set_id)
    local code = 'mma' --TODO ZALEPA
    local lang_id = 1 --TODO ZALEPA
    local more = true
    local url = MY_API_URL .. '/cards/search?q=e:' .. code
    while more do
        -- TODO log each batch
        -- TODO log set
        sleep(100)

        local response = ma.GetUrl(url)
        if response == nil then error('Unable to load ' .. url) end
        local data = json:decode(response)
        if data['object'] == 'error' then error('Error ' .. data['status'] .. ': ' .. data['details']) end

        for _, card in ipairs(data['data']) do
            ma.SetPrice(set_id, lang_id, card['name'], '*', card['usd'], 0)
        end

        more = data['has_more']
        if more then url = string.gsub(data['next_page'], SC_API_URL, MY_API_URL) end
    end
end

function ImportPrice(foil_string, langs_to_import, sets_to_import)
    -- TODO handle languages
    -- TODO handle foil_string
    if foil_string == 'O' then return end

    -- TODO progress
    for set_id, set_name in pairs(sets_to_import) do
        evaluate_set(set_id)
    end
end

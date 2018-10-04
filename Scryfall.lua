local function count(table)
    local result = 0
    for _, _ in pairs(table) do result = result + 1 end
    return result
end

local function sleep(ms)
    local t = ms * 1250000
    local s = 0
    for i = 1, t do s = s + i end
    return s
end

local function read_file(path)
    local file = ma.GetFile(string.format('Prices\\%s', path))
    if file == nil then error(string.format('Unable to read file %s', path)) end
    return file
end

local function load_library(name)
    local lib, err = load(read_file(string.format('lib\\%s.lua', name)))
    if err ~= nil then error(err) end
    return lib()
end

local json = load_library('JSON')

local SC_API_URL = 'https://api.scryfall.com'
local MY_API_URL = 'http://151.248.120.179/api/scryfall'

local SC_SET_CODES = json:decode(read_file('scryfall_set_codes.json'))
-- TODO tokens and stuff
local MA_OBJECT_TYPES = {
    card = 1
}

local g_progress_title = ''
local g_progress_value = 0

local function add_progress(value)
    g_progress_value = g_progress_value + value
    ma.SetProgress(g_progress_title, g_progress_value)
end

local function display_string(value)
    g_progress_title = value
    ma.SetProgress(g_progress_title, g_progress_value)
end

local function evaluate_set(ma_set_id, sc_set_code, progress_fraction)
    local more = true
    local url = string.format('%s/cards/search?q=e:%s', MY_API_URL, sc_set_code)
    while more do
        sleep(100)

        local response = ma.GetUrl(url)
        if response == nil then error(string.format('Unable to load %s', url)) end
        local data = json:decode(response)
        if data['object'] == 'error' then error(string.format('Error %s: %s', data['status'], data['details'])) end

        for _, card in ipairs(data['data']) do
            -- TODO handle scryfall card language
            local regular_price = card['usd']
            local foil_price = 0
            if card['foil'] and not card['nonfoil'] then
                foil_price = regular_price
                regular_price = 0
            end

            local object_type = MA_OBJECT_TYPES[card['object']]
            if object_type == nil then
                object_type = 0
                ma.Log(string.format('Unknown object type %s for card %s in set %s', card['object'], card['name'], card['set_name']))
            end

            -- TODO pass lang id
            -- TODO check result (modified num)
            -- TODO use name substitution for split cards and stuff
            ma.SetPrice(ma_set_id, 1, card['name'], '*', regular_price, foil_price, object_type)
            add_progress(progress_fraction * 1 / data['total_cards'])
        end

        more = data['has_more']
        if more then url = string.gsub(data['next_page'], SC_API_URL, MY_API_URL) end
    end
end

-- TODO handle langs_to_import, foil_string
function ImportPrice(foil_string, langs_to_import, sets_to_import)
    local set_progress_fraction = 100.0 / count(sets_to_import)
    for set_id, set_name in pairs(sets_to_import) do
        display_string(set_name)
        local set_codes = SC_SET_CODES[tostring(set_id)]
        if set_codes == nil then
            ma.Log(string.format('Unable to find codes for set %s', set_id))
        else
            local num_codes = count(set_codes)
            if num_codes == 0 then add_progress(set_progress_fraction) end
            for _, set_code in pairs(set_codes) do
                -- TODO pass array of set codes and use e:s1,s2,s3 syntax (do not forget to sort sets)
                evaluate_set(set_id, set_code, set_progress_fraction / num_codes)
            end
        end
    end
end

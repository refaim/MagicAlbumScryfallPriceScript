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
    local file = ma.GetFile('Prices\\' .. path)
    if file == nil then error('Unable to load library ' .. path) end
    return file
end

local function load_library(name)
    local lib, err = load(read_file('lib\\' .. name .. '.lua'))
    if err ~= nil then error(err) end
    return lib()
end

local json = load_library('JSON')

local SC_API_URL = 'https://api.scryfall.com'
local MY_API_URL = 'http://151.248.120.179/api/scryfall'
local SCRYFALL_SET_CODES = json:decode(read_file('scryfall_set_codes.json'))

local function evaluate_set(set_id, set_code)
    local lang_id = 1 --TODO ZALEPA
    local more = true
    local url = MY_API_URL .. '/cards/search?q=e:' .. set_code
    while more do
        -- TODO log each batch
        -- TODO log set
        sleep(100)

        local response = ma.GetUrl(url)
        if response == nil then error('Unable to load ' .. url) end
        local data = json:decode(response)
        if data['object'] == 'error' then error('Error ' .. data['status'] .. ': ' .. data['details']) end

        -- TODO track progress by card and page num
        for _, card in ipairs(data['data']) do
            -- TODO review all card fields and use some of them
            ma.SetPrice(set_id, lang_id, card['name'], '*', card['usd'], 0)
        end

        more = data['has_more']
        if more then url = string.gsub(data['next_page'], SC_API_URL, MY_API_URL) end
    end
end

function ImportPrice(foil_string, langs_to_import, sets_to_import)
    -- TODO handle languages
    -- TODO handle foil_string
    -- if foil_string == 'O' then return end

    local progress = 0
    local set_progress_part = 100.0 / count(sets_to_import)
    ma.Log(set_progress_part)
    for set_id, set_name in pairs(sets_to_import) do
        local set_codes = SCRYFALL_SET_CODES[tostring(set_id)]
        if set_codes == nil then
            ma.Log('Unable to find codes for set ' .. set_id)
        else
            local num_codes = count(set_codes)
            if num_codes == 0 then progress = progress + set_progress_part end
            ma.SetProgress(set_name, progress)
            local code_progress_part = set_progress_part / num_codes
            for _, set_code in pairs(set_codes) do
                evaluate_set(set_id, set_code)
                progress = progress + code_progress_part
                ma.SetProgress(set_name, progress)
            end
        end
    end
end

-- TODO add version and date

local function count(table)
    local result = 0
    for _, _ in pairs(table) do result = result + 1 end
    return result
end

-- TODO use ma.GetTime when it's released
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

local function load_resource(name)
    return json:decode(read_file(string.format('res\\scryfall\\%s.json', name)))
end

local SC_API_URL = 'https://api.scryfall.com'
local MY_API_URL = 'http://151.248.120.179/api/scryfall'

local SC_MA_LANGUAGES = load_resource('ma_languages')
local SC_SET_CODES = load_resource('set_codes')
local SC_NAME_REPLACEMENTS = load_resource('name_replacements')

local CC_KEY = 'EUR_USD'
local CC_URL = string.format('http://free.currencyconverterapi.com/api/v5/convert?q=%s&compact=y', CC_KEY)

local g_eur_to_usd = nil
local g_cc_attempt_failed = false
local g_progress_title = ''
local g_progress_value = 0

-- TODO display (really display) 100% when all work is done
local function print_progress()
    local value = math.ceil(g_progress_value)
    ma.SetProgress(string.format('%s (%d%%)', g_progress_title, value), value)
end

local function add_progress(value)
    g_progress_value = g_progress_value + value
    print_progress()
end

-- TODO display ETA
local function display_string(value)
    g_progress_title = value
    print_progress()
end

local function evaluate_set(ma_set_id, sc_set_codes, import_regular, import_foil, progress_fraction)
    table.sort(sc_set_codes)
    local url = string.format('%s/cards/search?q=e:%s&unique=prints', MY_API_URL, table.concat(sc_set_codes, ','))
    local more = true
    while more do
        sleep(100)

        local response = ma.GetUrl(url)
        if response == nil then error(string.format('Unable to load %s', url)) end
        local data = json:decode(response)
        if data['object'] == 'error' then error(string.format('Error %s: %s', data['status'], data['details'])) end

        -- TODO support lands
        -- TODO support tokens
        -- TODO support planes
        -- TODO support schemes
        for _, card in ipairs(data['data']) do
            local ma_lang_id = SC_MA_LANGUAGES[card['lang']]
            if ma_lang_id == nil then
                ma.Log(string.format('Unhandled language %s', card['lang']))
                ma_lang_id = SC_MA_LANGUAGES['en']
            end

            local name = SC_NAME_REPLACEMENTS[card['name']]
            if name == nil then name = card['name']:gsub(' // ', '|') end

            local usd = tonumber(card['usd'])
            local eur = tonumber(card['eur'])
            if usd == nil and eur ~= nil and not g_cc_attempt_failed then
                if g_eur_to_usd == nil then
                    local cc_response = ma.GetUrl(CC_URL)
                    if cc_response ~= nil then
                        g_eur_to_usd = json:decode(cc_response)[CC_KEY]['val']
                    else
                        g_cc_attempt_failed = true
                    end
                end
                if g_eur_to_usd ~= nil then usd = eur * g_eur_to_usd end
            end

            local regular_price = usd
            if regular_price ~= nil then
                local foil_price = 0
                if import_foil and card['foil'] and not card['nonfoil'] then
                    foil_price = regular_price
                    regular_price = 0
                end
                if not import_regular then regular_price = 0 end
                if not import_foil then foil_price = 0 end

                if regular_price > 0 or foil_price > 0 then
                    local version = '*'
                    local version_letter = card['collector_number']:match('^%d+(%a)$')
                    if version_letter ~= nil then version = version_letter:byte() - string.byte('a') + 1 end
                    -- TODO https://scryfall.com/card/10e/361%E2%98%85/treetop-village
                    -- TODO https://scryfall.com/card/pbfz/2s/blight-herder (and others)
                    -- TODO objtype: 0:all, 1:card, 2:token, 3:nontraditional, 4:insert, 5:replica
                    ma.SetPrice(ma_set_id, ma_lang_id, name, version, regular_price, foil_price)
                end
            end
            add_progress(progress_fraction / data['total_cards'])
        end

        more = data['has_more']
        if more then url = data['next_page']:gsub(SC_API_URL, MY_API_URL) end
    end
end

function ImportPrice(foil_string, langs_to_import, sets_to_import)
    local import_foil = foil_string == "Y" or foil_string == "O"
    local import_regular = foil_string == "Y" or foil_string == "N"

    for _, v in pairs(langs_to_import) do
        if v ~= nil and v ~= 'English' then
            display_string('Only English language is supported')
            sleep(300)
            return
        end
    end

    local set_progress_fraction = 100.0 / count(sets_to_import)
    for set_id, set_name in pairs(sets_to_import) do
        display_string(set_name)
        -- TODO map all scryfall sets
        -- TODO map all MA cards without price
        local set_codes = SC_SET_CODES[tostring(set_id)]
        if set_codes ~= nil and count(set_codes) > 0 then
            evaluate_set(set_id, set_codes, import_regular, import_foil, set_progress_fraction)
        else
            ma.Log(string.format('Unable to find codes for set %s', set_id))
            add_progress(set_progress_fraction)
        end
    end
end

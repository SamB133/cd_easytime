self = {}
local resource_name = GetCurrentResourceName()
local WeatherGroup = Config.Weather.GameWeather.WeatherGroups[1]
local LastWeatherGroup = WeatherGroup
local LastWeatherTable = {}
local TimesChanged = 0
local RealTimezone = 0


if Config.Weather.METHOD ~= 'game' and Config.Weather.METHOD ~= 'real' then
    print('^1Error: Invalid Config.Weather.METHOD - '..Config.Weather.METHOD..'.^0')
end

if Config.Time.METHOD ~= 'game' and Config.Time.METHOD ~= 'real' then
    print('^1Error: Invalid Config.Time.METHOD - '..Config.Time.METHOD..'.^0')
end

if (Config.Weather.METHOD == 'real' or Config.Time.METHOD == 'real') and Config.APIKey == 'CHANGE_ME' then
    print('^1Error: Invalid Config.APIKey - '..Config.APIKey..'.^0')
end

if Config.Time.GameTime.time_cycle_speed < 1 or Config.Time.GameTime.time_cycle_speed > 10 then
    print('^1Error: Invalid Config.Time.GameTime.time_cycle_speed - '..Config.Time.GameTime.time_cycle_speed..'.^0')
end

local function FoundWeatherGroup(group, weather)
    for _, value in ipairs(group) do
        if value == weather then
            return true
        end
    end
    return false
end

local function GetRealTime()
    local dt = os.time()+RealTimezone
    return os.date("!*t", dt).hour, os.date("!*t", dt).min
end

function GetRealWorldData(city)
    local data = {}
    PerformHttpRequest('https://api.openweathermap.org/data/2.5/weather?q='..city..'&appid='..Config.APIKey..'&units=metric', function(error, result, header)
        if error == 200 then
            local result = json.decode(result)
            for c, d in pairs(Config.Weather.RealWeather.weather_types) do
                for cd = 1, #d do
                    if d[cd] == result.weather[1].id then
                        data.weather = c
                        data.info = {
                            weather = result.weather[1].main,
                            weather_description = result.weather[1].description,
                            country = result.sys.country,
                            city = result.name,
                        }
                        break
                    end
                end
            end
            RealTimezone = result.timezone
            data.hours, data.mins = GetRealTime()            
        else
            print('^1Error: Invalid City Name or API Key.^0')
        end
    end,'GET','',{["Content-Type"]='application/json'})
    local timeout = 0 while not data.weather and timeout <= 100 do Wait(0) timeout=timeout+1  end
    return data
end

CreateThread(function()
    if Config.Weather.METHOD =='real' and Config.Time.METHOD == 'real' then
        local real_world_data = GetRealWorldData(Config.Weather.RealWeather.city)
        self.real_info = real_world_data.info
        self.weather = real_world_data.weather or 'CLEAR'
        self.hours = real_world_data.hours or 08
        self.mins = real_world_data.mins or 00
        self.dynamic = false
        self.freeze = false
        self.instantweather = false
        self.instanttime = false

    elseif Config.Weather.METHOD =='real' then
        local real_world_data = GetRealWorldData(Config.Weather.RealWeather.city)
        self.real_info = real_world_data.info
        self.weather = real_world_data.weather or 'CLEAR'
        self.dynamic = false
        self.instantweather = false

    elseif Config.Time.METHOD == 'real' then
        local real_world_data = GetRealWorldData(Config.Time.RealTime.city)
        self.real_info = real_world_data.info
        self.hours = real_world_data.hours or 08
        self.mins = real_world_data.mins or 00
        self.freeze = false
        self.instanttime = false
    end

    self.weathermethod = Config.Weather.METHOD
    self.timemethod = Config.Time.METHOD

    local settings = json.decode(LoadResourceFile(resource_name,'./settings.txt'))
    if self.weather == nil then self.weather = settings.weather or 'CLEAR' end
    if self.hours == nil then self.hours = settings.hours or 08 end
    if self.mins == nil then self.mins = settings.mins or 00 end
    if self.dynamic == nil then self.dynamic = settings.dynamic == true and true or false end
    if self.freeze == nil then self.freeze = settings.freeze == true and true or false end
    if self.instanttime == nil then self.instanttime = settings.instanttime == true and true or false end
    if self.instantweather == nil then self.instantweather = settings.instantweather == true and true or false end
    self.blackout = settings.blackout == true and true or false
    self.tsunami = false

    print('^3['..resource_name..'] - Settings Applied.^0')
    if Config.Framework ~= 'aceperms' or Config.Framework ~= 'identifiers' then
        Wait(2000)
        local temp = json.decode(json.encode(self))
        temp.instanttime = true
        temp.instantweather = true
        TriggerClientEvent('cd_easytime:ForceUpdate', -1, temp)
    end
end)

RegisterServerEvent('cd_easytime:SyncMe', function(instant)
    local source = source
    local temp = json.decode(json.encode(self))
    temp.instanttime = true
    temp.instantweather = true
    TriggerClientEvent('cd_easytime:ForceUpdate', source, temp)
end)

RegisterServerEvent('cd_easytime:SyncMe_basics', function(data)
    local source = source
    if data.weather then
        TriggerClientEvent('cd_easytime:SyncWeather', source, {weather = self.weather, instantweather = true})
    end
    if data.time then
        TriggerClientEvent('cd_easytime:SyncTime', source, {hours = self.hours, mins = self.mins})
    end
end)

RegisterServerEvent('cd_easytime:ForceUpdate', function(data)
    local source = source
    local _prev = {
        weather        = self.weather,
        hours          = self.hours,
        mins           = self.mins,
        dynamic        = self.dynamic,
        blackout       = self.blackout,
        freeze         = self.freeze,
        instanttime    = self.instanttime,
        instantweather = self.instantweather,
        tsunami        = self.tsunami,
        weathermethod  = self.weathermethod,
        timemethod     = self.timemethod
    }
    if PermissionsCheck(source) then
        if data.hours then
            self.hours = data.hours
            self.mins = data.mins
        end
        if data.weather and data.weather ~= self.weather then
            self.weather = data.weather
            TimesChanged = 0
            LastWeatherTable = {}
        
            for _, weather_group in pairs(Config.Weather.GameWeather.WeatherGroups) do
                if FoundWeatherGroup(weather_group, self.weather) then
                    WeatherGroup = weather_group
                    break
                end
            end
        
            for _, weather_type in ipairs(WeatherGroup) do
                if weather_type == self.weather then
                    break
                end
                LastWeatherTable[weather_type] = true
                TimesChanged = TimesChanged + 1
            end
        end
        if data.dynamic ~= nil then
            self.dynamic = data.dynamic
        end
        if data.blackout ~= nil then
            self.blackout = data.blackout
        end
        if data.freeze ~= nil then
            self.freeze = data.freeze
            data.hours = self.hours
            data.mins = self.mins
        end
        if data.instanttime ~= nil then
            self.instanttime = data.instanttime
        end
        if data.instantweather ~= nil then
            self.instantweather = data.instantweather
        end
        if data.tsunami ~= nil and Config.TsunamiWarning.ENABLE then
            self.tsunami = data.tsunami
        end
        if data.weathermethod ~= nil and data.weathermethod ~= self.weathermethod then
            self.weathermethod = data.weathermethod
            WewatherMethodChange(data.weathermethod)
        end
        if data.timemethod ~= nil and data.timemethod ~= self.timemethod then
            self.timemethod = data.timemethod
            TimeMethodChange(data.timemethod)
        end
        TriggerClientEvent('cd_easytime:ForceUpdate', -1, data, source)

        local parts = {}
        if _prev.weather ~= self.weather then
            parts[#parts+1] = ("Weather → %s"):format(tostring(self.weather))
        end
        if (_prev.hours ~= self.hours) or (_prev.mins ~= self.mins) then
            parts[#parts+1] = ("Time → %02d:%02d"):format(tonumber(self.hours) or 0, tonumber(self.mins) or 0)
        end
        if _prev.dynamic ~= self.dynamic then
            parts[#parts+1] = ("Dynamic → %s"):format(tostring(self.dynamic))
        end
        if _prev.blackout ~= self.blackout then
            parts[#parts+1] = ("Blackout → %s"):format(tostring(self.blackout))
        end
        if _prev.freeze ~= self.freeze then
            parts[#parts+1] = ("Freeze Time → %s"):format(tostring(self.freeze))
        end
        if _prev.instanttime ~= self.instanttime then
            parts[#parts+1] = ("Instant Time → %s"):format(tostring(self.instanttime))
        end
        if _prev.instantweather ~= self.instantweather then
            parts[#parts+1] = ("Instant Weather → %s"):format(tostring(self.instantweather))
        end
        if _prev.weathermethod ~= self.weathermethod then
            parts[#parts+1] = ("Weather Method → %s"):format(tostring(self.weathermethod))
        end
        if _prev.timemethod ~= self.timemethod then
            parts[#parts+1] = ("Time Method → %s"):format(tostring(self.timemethod))
        end
        if Config.Logging.ENABLE and Config.Logging.location ~= '' and Config.Logging.location ~= nil and Config.Logging.location ~= 'CHANGE_ME' and #parts > 0 then
            if Config.Logging.type == 'JD_logsV3' and GetResourceState('JD_logsV3') == 'started' then
                local who = ("%s [%d]"):format(GetPlayerName(source) or "Unknown", source)
                exports.JD_logsV3:createLog({
                    EmbedMessage = who .. " changed EasyTime:\n- " .. table.concat(parts, "\n- "),
                    player_id = source,
                    channel = Config.Logging.location,
                    screenshot = false
                })
            elseif Config.Logging.type == 'webhook' then
                local discord_webhook = Config.Logging.location
                local connect = {
                    {
                        ["color"] = 16711680,
                        ["title"] = "EasyTime Change Log",
                        ["description"] = "**"..GetPlayerName(source).."** [ID: "..source.."] changed EasyTime:\n- " .. table.concat(parts, "\n- "),
                        ["footer"] = {
                            ["text"] = "EasyTime Logger",
                        },
                    }
                }
                PerformHttpRequest(discord_webhook, function(err, text, headers) end, 'POST', json.encode({username = "EasyTime Logger", embeds = connect}), { ['Content-Type'] = 'application/json' })
            elseif Config.Logging.type == 'other' then
                -- Custom logging methods can be added here
            end
        end
    else
        DropPlayer(source, L('drop_player'))
    end
end)

local function RealWeatherChange()
    local real_world_data = GetRealWorldData(Config.Time.RealTime.city)
    self.real_info = real_world_data.info
    if real_world_data.weather ~= self.weather then
        self.weather = real_world_data.weather
        TriggerClientEvent('cd_easytime:SyncWeather', -1, {weather = self.weather, instantweather = false})
        if Config.ConsolePrints then
            print('^3['..resource_name..'] - Weather changed to '..self.weather..'^0')
        end
    end
end

local function GameWeatherChange()
    if TimesChanged >= #WeatherGroup then
        WeatherGroup = ChooseWeatherType()
        TimesChanged = 0
        LastWeatherTable = {}
        LastWeatherGroup = WeatherGroup
    end

    for _, new_weather in ipairs(WeatherGroup) do
        if not LastWeatherTable[new_weather] then
            if new_weather == 'THUNDER' and math.random(1, 100) > Config.Weather.GameWeather.thunder_chance then
                LastWeatherTable[new_weather] = true
                TimesChanged = TimesChanged + 1
                break
            end

            self.weather = new_weather
            LastWeatherTable[new_weather] = true
            TimesChanged = TimesChanged + 1

            TriggerClientEvent('cd_easytime:SyncWeather', -1, {weather = self.weather,instantweather = self.instantweather})

            if Config.ConsolePrints then
                print('^3Weather changed to '..self.weather..'.^0')
            end

            break
        end
    end
end

function WewatherMethodChange(new_weather_method)
    if new_weather_method == 'real' then
        self.weathermethod = 'real'
        self.dynamic = false
        self.instantweather = false
        RealWeatherChange()

    elseif new_weather_method == 'game' then
        self.weathermethod = 'game'
        GameWeatherChange()
    end
    TriggerClientEvent('cd_easytime:WeatherMethodChange', -1, new_weather_method)
end

CreateThread(function()
    Wait(1000)
    while true do
        if self.weathermethod =='real' then
            RealWeatherChange()
            Wait(Config.Weather.RealWeather.weather_check*60*1000)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    Wait(1000)
    while true do
        if self.weathermethod =='game' and self.dynamic then
            GameWeatherChange()
            Wait(Config.Weather.GameWeather.dynamic_weather_time*60*1000)
        else
            Wait(1000)
        end
    end
end)



local function RealTimeChange()
    self.hours, self.mins = GetRealTime()
    TriggerClientEvent('cd_easytime:SyncTime', -1, {hours = self.hours, mins = self.mins})
end

function GameTimeChange(time)
    local total = (self.hours * 60 + self.mins + time) % (24 * 60)
    if total < 0 then total = total + 24 * 60 end
    self.hours = math.floor(total / 60)
    self.mins  = total % 60

    TriggerClientEvent('cd_easytime:SyncTime', -1, { hours = self.hours, mins = self.mins })
end


function TimeMethodChange(new_time_method)
    if new_time_method == 'real' then
        self.timemethod = new_time_method
        self.freeze = false
        self.instanttime = false
        RealTimeChange()
        
    elseif new_time_method == 'game' then
        self.timemethod = new_time_method
        TriggerClientEvent('cd_easytime:SyncTime', -1, {hours = self.hours, mins = self.mins})
    end
    TriggerClientEvent('cd_easytime:TimeMethodChange', -1, new_time_method)
end

RegisterServerEvent('cd_easytime:SetNewGameTime', function(time)
    local prev_h, prev_m = self.hours, self.mins
    self.hours = time.hours
    self.mins = time.mins

    if Config.Logging.ENABLE and Config.Logging.location ~= '' and Config.Logging.location ~= nil and Config.Logging.location ~= 'CHANGE_ME' then
        if (prev_h ~= self.hours) or (prev_m ~= self.mins) then
            if Config.Logging.type == 'JD_logsV3' and GetResourceState('JD_logsV3') == 'started' then
                local who = ("%s [%d]"):format(GetPlayerName(source) or "Unknown", source)
                exports.JD_logsV3:createLog({
                    EmbedMessage = who .. string.format(" set Time: %02d:%02d → %02d:%02d",
                        tonumber(prev_h) or 0, tonumber(prev_m) or 0,
                        tonumber(self.hours) or 0, tonumber(self.mins) or 0),
                    player_id = source,
                    channel = Config.Logging.location,
                    screenshot = false
                })
            elseif Config.Logging.type == 'webhook' then
                local discord_webhook = Config.Logging.location
                local connect = {
                    {
                        ["color"] = 16711680,
                        ["title"] = "EasyTime Change Log",
                        ["description"] = "**"..GetPlayerName(source).."** [ID: "..source.."] set Time: "..string.format("%02d:%02d → %02d:%02d",
                            tonumber(prev_h) or 0, tonumber(prev_m) or 0,
                            tonumber(self.hours) or 0, tonumber(self.mins) or 0),
                        ["footer"] = {
                            ["text"] = "EasyTime Logger",
                        },
                    }
                }
                PerformHttpRequest(discord_webhook, function(err, text, headers) end, 'POST', json.encode({username = "EasyTime Logger", embeds = connect}), { ['Content-Type'] = 'application/json' })
            elseif Config.Logging.type == 'other' then
                -- Custom logging methods can be added here
            end
        end
    end
end)

CreateThread(function()
    Wait(1000)
    while true do
        if self.timemethod == 'real' then
            local secs = os.date("!*t", os.time() + RealTimezone).sec
            local wait_timer = (60 - secs) * 1000
            if wait_timer == 0 then
                wait_timer = 60000
            end
            RealTimeChange()
            Wait(wait_timer)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    Wait(1000)
    local wait_timer = Config.Time.GameTime.time_cycle_speed * 1000
    while true do
        if self.timemethod == 'game' and not self.freeze then
            GameTimeChange(1)
            Wait(wait_timer)
        else
            Wait(1000)
        end
    end
end)





function ChooseWeatherType()
    math.randomseed(GetGameTimer())
    local WeatherGroups = Config.Weather.GameWeather.WeatherGroups

    local function getRandomGroup(excluded_groups)
        local available_groups = {}
        for index, group in ipairs(WeatherGroups) do
            if not excluded_groups[group] then
                available_groups[#available_groups] = {index = index, group = group}
            end
        end
        if #available_groups == 0 then
            return 1
        else
            local selection = available_groups[math.random(1, #available_groups)]
            return selection.index
        end
    end

    local result = math.random(1, #WeatherGroups)

    if result == 2 then
        if math.random(1, 100) <= Config.Weather.GameWeather.rain_chance then
            return WeatherGroups[result]
        else
            result = getRandomGroup({[WeatherGroups[result]] = true})
            return WeatherGroups[result]
        end
        
    elseif result == 3 then
        if math.random(1, 100) <= Config.Weather.GameWeather.fog_chance then
            return WeatherGroups[result]
        else
            result = getRandomGroup({[WeatherGroups[result]] = true})
            return WeatherGroups[result]
        end

    elseif result == 4 then
        if math.random(1, 100) <= Config.Weather.GameWeather.snow_chance then
            return WeatherGroups[result]
        else
            result = getRandomGroup({[WeatherGroups[result]] = true})
            return WeatherGroups[result]
        end
    else
        return WeatherGroups[result]
    end
end


RegisterServerEvent('cd_easytime:ToggleInstantChange', function(action, boolean)
    local prev_time    = self.instanttime
    local prev_weather = self.instantweather
    if action == 'time' then
        self.instanttime = boolean
    elseif action == 'weather' then
        self.instantweather = boolean
    end

    if Config.Logging.ENABLE and Config.Logging.location ~= '' and Config.Logging.location ~= nil and Config.Logging.location ~= 'CHANGE_ME' then
        local changed, what = false, nil
        if action == 'time' and prev_time ~= self.instanttime then
            changed = true; what = ("Instant Time → %s"):format(tostring(self.instanttime))
        elseif action == 'weather' and prev_weather ~= self.instantweather then
            changed = true; what = ("Instant Weather → %s"):format(tostring(self.instantweather))
        end
        if Config.Logging.type == 'JD_logsV3' and GetResourceState('JD_logsV3') == 'started' then
            if changed then
                local who = ("%s [%d]"):format(GetPlayerName(source) or "Unknown", source)
                exports.JD_logsV3:createLog({
                    EmbedMessage = who .. " toggled EasyTime:\n- " .. what,
                    player_id = source,
                    channel = "weather",
                    screenshot = false
                })
            end
        elseif Config.Logging.type == 'webhook' then
            if changed then
                local discord_webhook = Config.Logging.location
                local connect = {
                    {
                        ["color"] = 16711680,
                        ["title"] = "EasyTime Toggle Log",
                        ["description"] = "**"..GetPlayerName(source).."** [ID: "..source.."] toggled EasyTime:\n- " .. what,
                        ["footer"] = {
                            ["text"] = "EasyTime Logger",
                        },
                    }
                }
                PerformHttpRequest(discord_webhook, function(err, text, headers) end, 'POST', json.encode({username = "EasyTime Logger", embeds = connect}), { ['Content-Type'] = 'application/json' })
            end
        elseif Config.Logging.type == 'other' then
            -- Custom logging methods can be added here
        end
    end
end)

local function SaveSettings()
    SaveResourceFile(resource_name,'settings.txt', json.encode(self), -1)
    print('^3['..resource_name..'] - Settings Saved.^0')
end

RegisterServerEvent('cd_easytime:SaveSettings', function()
    SaveSettings()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == resource_name then
        SaveSettings()
    end
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining == math.ceil(Config.TsunamiWarning.time*60) then
        SaveSettings()
        if not Config.TsunamiWarning.ENABLE then return end
        self.tsunami = true
        TriggerClientEvent('cd_easytime:StartTsunamiCountdown', -1, true)
    end
end)

RegisterServerEvent('cd_easytime:StartTsunamiCountdown', function(boolean)
    if not Config.TsunamiWarning.ENABLE then return end
    self.tsunami = boolean
    TriggerClientEvent('cd_easytime:StartTsunamiCountdown', -1, boolean)
end)

RegisterCommand('ape', function(source, args, rawCommand)
    TriggerClientEvent('table', -1, self)
end, false)
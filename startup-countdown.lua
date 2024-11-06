--[[
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
    Based on the countdown.lua script provided with OBS, modified to allow
    keyboard shortcuts for starting and resetting the countdown timer (so
    things like adv-ss can wrangle it), and probably a few other changes.
]]

obs             = obslua
source_name   = ""
total_seconds = 0

cur_seconds   = 0
last_text     = ""
stop_text     = "00:00"
activated     = false

reset_hotkey_id     = obs.OBS_INVALID_HOTKEY_ID
start_hotkey_id     = obs.OBS_INVALID_HOTKEY_ID

-- Function to set the time text
function set_time_text()
	local seconds       = math.floor(cur_seconds % 60)
	local total_minutes = math.floor(cur_seconds / 60)
	local minutes       = math.floor(total_minutes % 60)
	-- local hours         = math.floor(total_minutes / 60)
	local text          = string.format("%02d:%02d", minutes, seconds)

	if cur_seconds < 1 then
        print("Countdown timer expired!")
		text = stop_text
	end

	if text ~= last_text then
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
            -- print("setting source text for " .. source_name .. " to " .. text)
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end

	last_text = text
end

function timer_callback()
	cur_seconds = cur_seconds - 1
	if cur_seconds < 0 then
		obs.remove_current_callback()
		cur_seconds = 0
	end

	set_time_text()
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating

	if activating then
		-- cur_seconds = total_seconds
		set_time_text()
		obs.timer_add(timer_callback, 1000)
	else
		obs.timer_remove(timer_callback)
	end
end


function countdown_reset(pressed)
	if not pressed then
		return
	end

    activate(false)

    cur_seconds = total_seconds
    last_text = "xx:xx"
    set_time_text()

    print("Countdown timer reset to " .. last_text)
end

function countdown_start(pressed)
    if not pressed then
        return
    end

    activate(true)
    print("Countdown timer started")
end

function reset_button_clicked(_props, _p)
	countdown_reset(true)
	return false
end

function start_button_clicked(_props, _p)
	countdown_start(true)
	return false
end

----------------------------------------------------------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties() -- luacheck: ignore
	local props = obs.obs_properties_create()
	obs.obs_properties_add_int(props, "duration", "Duration (minutes)", 1, 100000, 5)

	local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	obs.obs_properties_add_text(props, "stop_text", "Final Text", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_button(props, "reset_button", "Reset", reset_button_clicked)
	obs.obs_properties_add_button(props, "start_button", "Start", start_button_clicked)

	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description() -- luacheck: ignore
	return "Sets a text source to act as a countdown timer when the source is active.\n\nMade by Lain"
end

-- A function named script_update will be called when settings are changed
function script_update(settings) -- luacheck: ignore
	activate(false)

	total_seconds = obs.obs_data_get_int(settings, "duration") * 60
	source_name = obs.obs_data_get_string(settings, "source")
	stop_text = obs.obs_data_get_string(settings, "stop_text")

	countdown_reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings) -- luacheck: ignore
	obs.obs_data_set_default_int(settings, "duration", 10)
	obs.obs_data_set_default_string(settings, "stop_text", "00:00")
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings) -- luacheck: ignore
	local hotkey_save_array = obs.obs_hotkey_save(reset_hotkey_id)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

	hotkey_save_array = obs.obs_hotkey_save(start_hotkey_id)
	obs.obs_data_set_array(settings, "start_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)  -- luacheck: ignore
	-- Connect hotkey and activation/deactivation signal callbacks
	reset_hotkey_id = obs.obs_hotkey_register_frontend(script_path(), "Startup Timer Reset", countdown_reset)
	local hotkey_save_array = obs.obs_data_get_array(settings, "reset_hotkey")
	obs.obs_hotkey_load(reset_hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)

    start_hotkey_id = obs.obs_hotkey_register_frontend(script_path(), "Startup Timer Start", countdown_start)
	hotkey_save_array = obs.obs_data_get_array(settings, "start_hotkey")
	obs.obs_hotkey_load(start_hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

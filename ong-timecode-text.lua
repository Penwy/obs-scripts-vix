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
    OBS RTC Timecode Generator for Text Sources
    Originally from https://github.com/spessoni/obs-timecode-text

    Modified by TDV Alinsa to display faux(ish) milliseconds instead
    of frames, since not everything in the streaming world runs at a consistent
    framerate. lua doesn't really offer a good way to get a current timestamp
    including milliseconds, so we're just going to treat the first frame that
    happens in a new second as though it happened at .000, and increment from
    there.
]]

obs           = obslua

-- Globals
source_active = false       -- The Source is in Program
cb_active     = false       -- Callback timer is active
mstime        = 0           -- Frame counter
ms_waiting    = 0           -- waiting for the next second
last_time     = ""          -- Last time (Stored)
frame_text    = ""          -- Frame text (String)

-- Properties
source_name   = ""          -- Text source name
time_mode     = "24 Hour"   -- Clock mode
show_ms       = false       -- Enable showing frames ".sss"
show_date     = false       -- Enable showing date (yyyy-mm-dd)
show_utc      = false       -- Enable showing date and time as UTC
pre_text      = ""          -- Text before timecode
post_text     = ""          -- Text after timecode
keep_updated  = false       -- Update when not in program

-- Debug
debug         = false       -- Enable or disable script output

-- Local Settings
Format12hr    = "%I:%M:%S"
Format24hr    = "%H:%M:%S"
FormatAmPm    = "%p"

FormatDate    = "%Y-%m-%d "
FormatUtc     = "!"

-- Description
-- Logo Image - Base64 Encoded Image - https://www.base64-image.de/
-- luacheck: no max line length
img_logo      = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAALwAAAA3BAMAAABEED2DAAAAGFBMVEUAAAAAAAD+//5XV1ebm5sqKysZGhrKysuA4j2YAAAAAXRSTlMAQObYZgAABChJREFUWMPtlk1z2jAQhvsTuvjjjiTqsyxoz5YVchbU5Gw+pndD/n/flQx1GSATmmbaTnfaQa8kPzGr1bt86IPeOHrse+J3TeOpQWBIlLUUI8fMCoueZ3dRcWBrS6v44IqVZ7W6ii+F+EQCgaGmhe7xCWYkWTEhi4Ulq+P8PAvDEjM5HobK1XW8c4UvnHO0EXKAd52raVrMyercLpWDCtsPTu0YnxSu00/KFY2kJ3kd7/HWikd2X+iIPy4QKZ7eiuWEYoQ/1jBt9ExPY3zfcibzTr+MT1VbTi7hhRjikfQs4CtKx9iT7eQa+iremEIXxvh0TEnEb4z5PMB/UeVSGnPC0xAPpfDyt45W8tHqH/iFEJMBHhQ+2qt4LN3Al9KTQrmlQER8hnIb4HOPt2+aq3hpqxv4pdBMIcZfzD2Gt3O/uJV7/0VGPJJzHX9/5SSF5rqP+INz+oSPdY/hWd0XUK+pe4GIeAyqE/7arYVS12/tP+SYb4n/Hy8H/dZ4F3zJNolbEp2YVQWl4ZeqXUQbxWK/VUbbl7DfEQZjqDnm58RqEm4X4wb46WPhdGIPbSppOynZDcrDo0yEsw/whk4LOEVLiE0BZaE2AY+dFVThE7xIiqY5D95QuEc5TE5yNL7Cl5NSQ+CJLlX0TcLZykpQH4tnKseWn1At8Gwa1sPHvoVGYgl7yc4UDOMiXhxExCsik04oYfxogK8o0QEvqhMeVglLkxHvaQE8XcZLISflrPGMpwEePabH7xpvoZCNnRo9NCu87FLM2MsG+ObrZfzYLvlox+d4nFWPX4TDrBJpaxxtPOg9d5UBHtsfLuPNZlLWRp/jjfE9foPcG6MTuS3UaG9mZK3UGWx/gC+6fXsZT8kp93Q596N4tDK3fe6XouVSHCZnLekFfJvbVEb8eoCf07rH06jHezsfJId7osqEPsdn5b6N+Bpf3tZTlQhT7he16TSSY8LX3SrTVRYq1v2ed/q0aE74L9IUM4WPc/zPt3bLd7EUhf751uZWyPbs1vrczk54UGR2Xvf5KvzOptzj365B4UG1lDUr/D/9KufYQfEGfmKVYeB3mGxZ4ZNOv8Pj9r/cMf/H+7TGj38Efuppq2t8ssCQUu2g2rjo5pQff9umDt1q6iBfgS81nCvewRVR9Bw4kGeV8PVd80Vmdey14j58JoGXWVeJ563wQe25Geq8Cw3n2K0Q9+DzGkAxFZVQpfBBwVUrG1JV/zKeY2GFrYQtOh/UnoEx8/fi2TEFIuKNQu63n5gSDZHW7KYcx2ZYvQp/cLZCd+si/nONbpVUwMfK6TQqR7UBf3A1Wef0/cmJzXCQg3JMlLP65dxncoiH6pthyy1V/Q68bOzYPizFLfz9yck7oSgVYn9/5Sw9bbQhMkFtPCVBtXHRfKbcGB1EookX/ihLe0P8d01J5Amxe24GAAAAAElFTkSuQmCC"
version       = "Version 1.01 - <a href='https://github.com/spessoni/obs-timecode-text'>spessoni</a>"
description   = [[
<center><img width='188' height='55' src=']] .. img_logo .. [['/><br>]] .. version .. [[</center>
<h3>Generates Real-Time Clock (RTC) Timecode on a text source</h3>
<p><strong>Tips:</strong></p>
<ul>
<li>Synchronize your computer's clock with an internet time server.</li>
<li>A monospaced / fixed-width font is recommended to prevent resizing of the timecode every frame.</li>
<li>Enable "Update when not in program" only if needed, otherwise keep it disabled to reduce CPU load.</li>
<li>Enabling "Show Frames" will require more processing power because every frame must be rendered.</li>
</ul>
]]

--------------------------------------------------------------------------------

function script_description() -- luacheck: ignore
	return description
end

-- Function to set the text
function set_text(seconds)
	-- Get HH:MM:SS in requested time format
	local format = Format24hr
	if time_mode == "12 Hour + AM/PM" or time_mode == "12 Hour" then
		format = Format12hr
	end

    if ( show_date ) then
       format = FormatDate .. format
    end

    if ( show_utc ) then
       format = FormatUtc .. format
    end

	local time = os.date(format)

	-- Get AM/PM if requested
	local ampm = ""
	if time_mode == "12 Hour + AM/PM" then
        format = FormatAmPm
        if ( show_utc ) then
            format = FormatUtc .. format
        end
		ampm = " " .. os.date(format)
	end


	-- Update frame counter if enabled
	frame_text = ""
	if show_ms then
        if seconds < 0 then
            ms_waiting = 2
        end

        -- Check if "HH:MM:SS" has changed, if it has, reset the frames
		if time ~= last_time then
			mstime = 0
            ms_waiting = ms_waiting - 1
        else
            mstime = mstime + seconds * 1000
		end

		-- Create ".sss" text to add to end of "HH:MM:SS"
        if ms_waiting > 0 then
            frame_text = ".---"
        else
		    frame_text = string.format(".%03d", mstime)
        end

		-- Store last "HH:MM:SS" value to check on next run
		last_time = time
	end

	-- Create the text string
	local text = pre_text .. time .. frame_text  .. ampm .. post_text

	-- If source exists then update the text
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", text)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end

end

function timer_callback()
	if debug then print ("TIMER CALLBACK: Triggered") end
	-- Timer callback is only called if we are NOT using frames
	set_text(0)
end

function script_tick(seconds) -- luacheck: ignore
	-- Only update every frame if frames are required
	if (keep_updated or source_active) and show_ms then
		set_text(seconds)
	end
end

----------------------------------------------------------

function script_properties() -- luacheck: ignore
	local props = obs.obs_properties_create()

	-- Text Source
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

	-- Timecode Format Mode
	local p_mode = obs.obs_properties_add_list(props, "time_mode", "Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(p_mode, "24 Hour", "24 Hour")
	obs.obs_property_list_add_string(p_mode, "12 Hour", "12 Hour")
	obs.obs_property_list_add_string(p_mode, "12 Hour + AM/PM", "12 Hour + AM/PM")

	-- Show Frames Checkbox
	local p_show_ms = obs.obs_properties_add_bool(props, "show_ms", "Show approx milliseconds")
	obs.obs_property_set_long_description(p_show_ms, "<b>NOTE:</b> This may require more CPU usage")

    -- Show Date Checkbox
	obs.obs_properties_add_bool(props, "show_date", "Show Date")

    -- Show UTC Checkbox
	obs.obs_properties_add_bool(props, "show_utc", "Show UTC(GMT)")

	-- Prefix Text
	obs.obs_properties_add_text(props, "pre_text", "Prefix Text", obs.OBS_TEXT_DEFAULT)

	-- Suffix Text
	obs.obs_properties_add_text(props, "post_text", "Suffix Text", obs.OBS_TEXT_DEFAULT)

	-- Update when not in Program Checkbox
	local p_keep_updated = obs.obs_properties_add_bool(props, "keep_updated", "Update when not in program")
	obs.obs_property_set_long_description(p_keep_updated, "Timecode will be updated even when not in program.\nThis is useful for projectors and isolated recording.")

	return props
end

-- A function named script_update will be called when settings are changed
function script_update(settings) -- luacheck: ignore
	source_name  = obs.obs_data_get_string(settings, "source")
	time_mode    = obs.obs_data_get_string(settings, "time_mode")
	show_ms      = obs.obs_data_get_bool(settings, "show_ms")
	show_date    = obs.obs_data_get_bool(settings, "show_date")
	show_utc     = obs.obs_data_get_bool(settings, "show_utc")
	pre_text     = obs.obs_data_get_string(settings, "pre_text")
	post_text    = obs.obs_data_get_string(settings, "post_text")
	keep_updated = obs.obs_data_get_bool(settings, "keep_updated")

	-- Check if source is active (in PGM), enable time callback if needed
	source_active = get_sceneitem_from_source_name_in_current_scene(source_name)

	-- Check what state we need to put the timer callback initially
	-- TODO: We could probably shorten this and just call activated(source_active). All this logic will happen in the function anyways.
	if (source_active or keep_updated) and not show_ms then
        if debug then print ("script_update(): Timer Callback ENABLED") end
		cb_toggle(true)
	else
		if debug then print ("script_update(): Timer Callback DISABLED") end
		cb_toggle(false)
	end

end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings) -- luacheck: ignore
	obs.obs_data_set_default_string(settings, "source", "timecode")
	obs.obs_data_set_default_string(settings, "time_mode", "24 Hour")
	obs.obs_data_set_default_bool(settings, "show_ms", true)
	obs.obs_data_set_default_bool(settings, "show_date", true)
	obs.obs_data_set_default_bool(settings, "show_utc", false)
	obs.obs_data_set_default_string(settings, "pre_text", "RTC ")
	obs.obs_data_set_default_string(settings, "post_text", "")
	obs.obs_data_set_default_bool(settings, "keep_updated", false)
end

-- a function named script_load will be called on startup
function script_load(settings) -- luacheck: ignore
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)
end

-- Toggle the callback on or off
-- active: true = activate callback timer  false = stop callback timer
function cb_toggle(active)
	if debug then print ("cb_toggle(" .. tostring(active) .. ")  Current Callback Active = " .. tostring(cb_active) ) end

	-- Check if callback is already in the requested state
	if cb_active == active then
		if debug then print ("cb_toggle(IGNORE) Matches current state, ignoring...") end
		return
	end

	-- Activate / Deactivate timer callback
	if active then
		if debug then print ("TIMER CALLBACK: Enabled") end
		obs.timer_add(timer_callback, 1000)
		-- Immediately trigger an update, otherwise old time will be visible for 1000ms
		set_text(-1)
	else
		if debug then print ("TIMER CALLBACK: Disabled") end
		obs.timer_remove(timer_callback)
	end

	-- Set callback status flag
	cb_active = active

end

-- Callback: ANY source is now in program
function source_activated(cd)
	activate_signal(cd, true)
end

-- Callback: ANY source is nolonger in program
function source_deactivated(cd)
	activate_signal(cd, false)
end

-- Called when ANY source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		-- Check if source activate/deactivate is OUR source
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activated(activating)
		end
	end
end

-- Handle our source becoming active or inactive
function activated(active)
	if debug then print ("activated(" .. tostring(active) .. ")  Is source active: " .. tostring(source_active) ) end

	-- Set source status flag
	source_active = active

    -- set our ms text to some dummy text pending the next second
    set_text(-1)

	-- Toggle Callback Timer ON if (source is active OR keep_update is check) AND are not showing frames
	-- TODO: We can probably just call cb_toggle without an if statement and just send the logic results to cb_toggle, but it reads easier
	if (active or keep_updated) and not show_ms then
		cb_toggle(true)
	else
		cb_toggle(false)
	end

end

-- Retrieves the scene item of the given source name in the current scene or nil if not found
function get_sceneitem_from_source_name_in_current_scene(name)
	local result_sceneitem = nil
	local current_scene_as_source = obs.obs_frontend_get_current_scene()
	if current_scene_as_source then
		local current_scene = obs.obs_scene_from_source(current_scene_as_source)
		result_sceneitem = obs.obs_scene_find_source_recursive(current_scene, name)
		obs.obs_source_release(current_scene_as_source)
	end
	return result_sceneitem
end

--[[Copyright (C) 2024 by Exeldro, see https://github.com/exeldro/obs-lua

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
    Automatically hide media sources when they end, so the OBS user doesn't
    need to manually hide them.
]]

obs = obslua
gs            = nil

function source_enable(source, enable)
    local sourcename = obs.obs_source_get_name(source)
    print("source_enable: " .. sourcename .. " " .. tostring(enable))
    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
        for _, scenesource in ipairs(scenes) do
            -- local scenename = obs.obs_source_get_name(scenesource)
            local scene = obs.obs_scene_from_source(scenesource)
            local sceneitems = obs.obs_scene_enum_items(scene)
            -- local index = 1
            for _, sceneitem in ipairs(sceneitems) do
                local group = obs.obs_group_from_source(obs.obs_sceneitem_get_source(sceneitem))
                if group ~= nil then
                    local groupitems = obs.obs_scene_enum_items(group)
                    for _, groupitem in ipairs(groupitems) do
                        if sourcename == obs.obs_source_get_name(obs.obs_sceneitem_get_source(groupitem)) then
                            if obs.obs_sceneitem_visible(groupitem) ~= enable then
                                obs.obs_sceneitem_set_visible(groupitem,enable)
                            end
                        end
                    end
		   obs.sceneitem_list_release(groupitems)
                end
                if sourcename == obs.obs_source_get_name(obs.obs_sceneitem_get_source(sceneitem)) then
                    if obs.obs_sceneitem_visible(sceneitem) ~= enable then
                        obs.obs_sceneitem_set_visible(sceneitem,enable)
                    end
                end
            end
            obs.sceneitem_list_release(sceneitems)
        end
        obs.source_list_release(scenes)
    end
end

function script_properties() -- luacheck: ignore
	local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "exclude", "Exclude")
    obs.obs_properties_add_editable_list(props, "sources", "Sources",obs.OBS_EDITABLE_LIST_TYPE_STRINGS,nil,nil)
    return props;
end

function script_description() -- luacheck: ignore
	return "Hide media sources when ended"
end

-- function media_ended(cd)
--     local source = obs.calldata_source(cd, "source")
--     source_enable(source, false);
-- end

-- modified version to exclude looping sources, courtesy Penwywern
function media_ended(cd)
    local source = obs.calldata_source(cd, "source")
    local settings = obs.obs_source_get_settings(source)
    if (obs.obs_source_get_unversioned_id(source) == "ffmpeg_source") and (not obs.obs_data_get_bool(settings, "looping")) then
        source_enable(source, false);
    end
    obs.obs_data_release(settings)
end

-- called only from script_update and source_create
-- (re)sets the signal handler for media ended signals, per-source
function update_source_media_ended(source, sourceNames, exclude)
    -- print("update_source_media_ended " .. tostring(source) .. " " .. tostring(sourceNames) .. " " .. tostring(exclude))
    local sh = obs.obs_source_get_signal_handler(source);
    obs.signal_handler_disconnect(sh,"media_ended",media_ended)
    local sn = obs.obs_source_get_name(source)
    local found = false
    local count = obs.obs_data_array_count(sourceNames);
    for i = 0,count do
        local item = obs.obs_data_array_item(sourceNames, i);
        if obs.obs_data_get_string(item, "value") == sn then
            found = true
        end
    end

    if (found == true and exclude == false) or (found == false and exclude == true) then
        -- print("add handler " .. sn)
        obs.signal_handler_connect(sh,"media_ended",media_ended)
    end
end

-- called at startup and when settings are changed
function script_update(settings) -- luacheck: ignore
    local exclude = obs.obs_data_get_bool(settings,"exclude")
    local sourceNames =  obs.obs_data_get_array(settings, "sources"); -- list of sources from options
    local sources = obs.obs_enum_sources()
    -- print("sources " .. sources)
    if sources ~= nil then
        for _, source in ipairs(sources) do
            update_source_media_ended(source, sourceNames, exclude)
        end
        obs.source_list_release(sources)
    end
end

function script_defaults(settings) -- luacheck: ignore

end

-- only called as a signal handler for source_create
function source_create(cd)
    if gs == nil then
        return
    end
    local sourceNames = obs.obs_data_get_array(gs, "sources");
    local exclude = obs.obs_data_get_bool(gs,"exclude")
    local source = obs.calldata_source(cd, "source")
    update_source_media_ended(source, sourceNames, exclude)
end

function script_load(settings) -- luacheck: ignore
    gs = settings
    local sh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(sh, "source_create", source_create)
end

function script_unload() -- luacheck: ignore

end

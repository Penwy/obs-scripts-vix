--[[Copyright (C) 2024 by Penwywern <gaspard.larrouturou@protonmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.]]


-- this script sets up a separate scene that will contain most other scenes
-- from the scene collection (anything that's not excluded) and will change
-- the visibility of each to match the currently selected scene, effectively
-- mirroring the current output of OBS, except without anything that would
-- normally be added by something like Downstream Keyer (DSK). This is useful
-- for recording a clean (no overlays) version of the output while still
-- having the overlays visible in the main output.

obs = obslua

prefix_default = "*"
record_scene_name_default = "* Scene Record"

prefix = nil
current_sceneitem = nil
record_scene_name = nil
record_scene_id = 0             -- obs_get_source_by_uuid(nil) apparently segfaults

function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        local scene_as_s = obs.obs_frontend_get_current_scene()
        if (obs.obs_source_get_uuid(scene_as_s) == record_scene_id) then
            obs.obs_source_release(scene_as_s)
            return
        end
        local scene_name = obs.obs_source_get_name(scene_as_s)
        obs.obs_source_release(scene_as_s)

        scene_as_s = obs.obs_get_source_by_uuid(record_scene_id)
        if scene_as_s then
            -- FIXME: is this intentionally global?
            record_scene = obs.obs_scene_from_source(scene_as_s)
        end
        obs.obs_source_release(scene_as_s)

        if (string.sub(scene_name, 0, 1) ~= prefix) then
            if current_sceneitem then
                local sceneneitem = obs.obs_scene_find_sceneitem_by_id(record_scene, current_sceneitem)
                obs.obs_sceneitem_set_visible(sceneneitem, false)
            end
            local sceneneitem = obs.obs_scene_find_source(record_scene, scene_name)
            if sceneneitem then
                current_sceneitem = obs.obs_sceneitem_get_id(sceneneitem)
                obs.obs_sceneitem_set_visible(sceneneitem, true)
            end
        end
    end
end

function on_scene_create(calldata)
    local created = obs.calldata_source(calldata, "source")
    if (obs.obs_source_get_unversioned_id(created) == "scene") and (string.sub(obs.obs_source_get_name(created), 0, 1) ~= prefix) then

        local scene_as_s = obs.obs_get_source_by_uuid(record_scene_id)
        if scene_as_s then
            -- FIXME: is this intentionally accessing record_scene as a global?
            local item = obs.obs_scene_add(record_scene, created)
            obs.obs_sceneitem_set_visible(item, false)
            obs.obs_sceneitem_set_order(item, obs.OBS_ORDER_MOVE_BOTTOM)
        end
        obs.obs_source_release(scene_as_s)
    end
    if (obs.obs_source_get_unversioned_id(created) == "scene") and (obs.obs_source_get_name(created) == record_scene_name) then
        record_scene_id = obs.obs_source_get_uuid(created)

        -- Wait for the scene to be fully created (when the program switches
        -- to a scene after creation) to populate it
        obs.obs_frontend_add_event_callback(on_record_scene_created)
    end
end

function on_record_scene_created(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        populate_record_scene()
        obs.remove_current_callback()
    end
end

function on_scene_rename(calldata)
    local renamed = obs.calldata_source(calldata, "source")
    if (obs.obs_source_get_unversioned_id(renamed) == "scene") then
        local new_name = obs.calldata_string(calldata, "new_name")
        local prev_name = obs.calldata_string(calldata, "prev_name")

        if (string.sub(new_name, 0, 1) == prefix) and (string.sub(prev_name, 0, 1) ~= prefix) then
            local scene_as_s = obs.obs_get_source_by_uuid(record_scene_id)
            if scene_as_s then
                record_scene = obs.obs_scene_from_source(scene_as_s)
                local sceneneitem = obs.obs_scene_find_source(record_scene, new_name)
                obs.obs_sceneitem_remove(sceneneitem)
            end
            obs.obs_source_release(scene_as_s)
        end

        if (string.sub(new_name, 0, 1) ~= prefix) and  (string.sub(prev_name, 0, 1) == prefix) then
            local scene_as_s = obs.obs_get_source_by_uuid(record_scene_id)
            if scene_as_s then
                record_scene = obs.obs_scene_from_source(scene_as_s)
                local item = obs.obs_scene_add(record_scene, renamed)
                obs.obs_sceneitem_set_visible(item, false)
                obs.obs_sceneitem_set_order(item, obs.OBS_ORDER_MOVE_BOTTOM)
            end
            obs.obs_source_release(scene_as_s)
        end
    end
end

function populate_record_scene()
    local scene_as_s = obs.obs_get_source_by_uuid(record_scene_id)
    if scene_as_s then
        record_scene = obs.obs_scene_from_source(scene_as_s)
    else
        return
    end
    obs.obs_source_release(scene_as_s)

    local items_list = obs.obs_scene_enum_items(record_scene)
    for _, item in ipairs(items_list) do
        if (obs.obs_source_get_unversioned_id(obs.obs_sceneitem_get_source(item)) == "scene") then
            obs.obs_sceneitem_remove(item)
        end
    end
    obs.sceneitem_list_release(items_list)
    local scene_list = obs.obs_frontend_get_scenes()
    for _, scene in ipairs(scene_list) do
        if (obs.obs_source_get_uuid(scene) ~= record_scene_id) and (string.sub(obs.obs_source_get_name(scene), 0, 1) ~= prefix) then
            local item = obs.obs_scene_add(record_scene, scene)
            obs.obs_sceneitem_set_visible(item, false)
            obs.obs_sceneitem_set_order(item, obs.OBS_ORDER_MOVE_BOTTOM)
        end
    end
    obs.source_list_release(scene_list)
end

function script_load(_settings) -- luacheck: ignore
    obs.obs_frontend_add_event_callback(on_frontend_event)
    local gsh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(gsh, "source_create", on_scene_create)
    obs.signal_handler_connect(gsh, "source_rename", on_scene_rename)
end

function script_unload() -- luacheck: ignore
    obs.obs_frontend_remove_event_callback(on_frontend_event)
    local gsh = obs.obs_get_signal_handler()
    obs.signal_handler_disconnect(gsh, "source_create", on_scene_create)
    obs.signal_handler_disconnect(gsh, "source_rename", on_scene_rename)
end

function script_defaults(settings) -- luacheck: ignore
    obs.obs_data_set_default_string(settings, "prefix", prefix_default)
    obs.obs_data_set_default_string(settings, "record_scene_name", record_scene_name_default)
end

function script_update(settings) -- luacheck: ignore
    prefix = obs.obs_data_get_string(settings, "prefix")
    record_scene_name = obs.obs_data_get_string(settings, "record_scene_name")
    local record_scene = obs.obs_get_source_by_name(record_scene_name)
    if record_scene and (obs.obs_source_get_uuid(record_scene) ~= record_scene_id) then
        record_scene_id = obs.obs_source_get_uuid(record_scene)
        populate_record_scene()
    end
    obs.obs_source_release(record_scene)
end

function script_properties() -- luacheck: ignore
    local props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "prefix", "Prefix for excluded scenes", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "record_scene_name", "Source-record scene name", obs.OBS_TEXT_DEFAULT)
    return props
end

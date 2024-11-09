# pylint: disable=C0301, R0902, R0903
"""
    Copyright (C) 2024 by Penwywern <gaspard.larrouturou@protonmail.com>

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
"""
# This script hooks into the transitions of specified scenes, and sends MIDI
# commands to an attached VR-4HD video switcher to switch it appropriately
# as scenes are selected. This makes it possible to have different inputs on
# the VR-4HD and treat them as though they were OBS scenes, with the
# limitation (of course) that only one of the possible inputs can be used
# by OBS at once. The scene being switched to should, of course, contain
# the VR-4HD source, if you actually want to be able to see it after the
# transition!
#
# For switching from non-VR-4HD scenes to VR-4HD scenes, the script will
# just send the midi command at the start of the transition, and let OBS
# do the actual transition. For switching between two VR-4HD scenes, the
# script will set the VR-4HD to use a "crossfade" transition, and disable
# OBS' transition, so that the VR-4HD can fade between its sources and
# still have things look natural.
#
# The writing of this script was powered by the eurobeat remix of "Come out ye
# black and tans"

# requires python-rtmidi and mido

from typing import Dict

import mido
import obspython as obs

transitions: Dict[str, bool] = {}  # FIXME: should probably be a set?

# Can use this to change the defaults of the scenes list
dest_scenes = ["[empty]", "Scene: RX2 Hands", "Scene: AX-Synth", "Scene: Alesis"]

# midi device to use (we should make this runtime selectable)
# MIDI_DEVICE_PATTERN = "Bome MIDI Translator 4"
MIDI_DEVICE_PATTERN = "VR-4HD"

midiout = None


def pick_midi_device(pattern):
    device_list = mido.get_output_names()

    print(f"VIDSWITCH: Available MIDI devices: {device_list}")

    for device in device_list:
        if pattern in device:
            print(f"VIDSWITCH: Picked MIDI device: {device}")
            return device

    print(f"VIDSWITCH: No MIDI device found matching pattern {pattern}")
    return None


def open_midi():
    global midiout
    midi_device = pick_midi_device(MIDI_DEVICE_PATTERN)

    if midi_device is None:
        midiout = None
        return

    try:
        midiout = mido.open_output(midi_device)
        print(f"VIDSWITCH: Successfully opened MIDI device {midi_device}")
    except OSError as e:
        print(f"VIDSWITCH: ERROR: Failed to open MIDI device {midi_device}: {e}")
        midiout = None


def script_update(settings):
    dest_scenes.clear()
    scenes_array = obs.obs_data_get_array(settings, "vidswitch_scenes")

    for index in range(obs.obs_data_array_count(scenes_array)):
        scene = obs.obs_data_array_item(scenes_array, index)
        dest_scenes.append(obs.obs_data_get_string(scene, "value"))
        obs.obs_data_release(scene)

    obs.obs_data_array_release(scenes_array)


def script_unload():
    obs.obs_frontend_remove_event_callback(on_fe_event)
    for uuid in transitions:
        transition = obs.obs_get_source_by_uuid(uuid)
        sh = obs.obs_source_get_signal_handler(transition)

        obs.signal_handler_disconnect(sh, "transition_start", on_transition_start)
        obs.signal_handler_disconnect(sh, "destroy", on_transition_destroy)

        obs.obs_source_release(transition)

    global midiout
    if midiout is not None:
        midiout.close()
        midiout = None
        print("VIDSWITCH: Closed MIDI output device")


def script_load(settings):
    sources = obs.obs_frontend_get_transitions()

    for transition in sources:
        if obs.obs_source_get_uuid(transition) not in transitions:
            sh = obs.obs_source_get_signal_handler(transition)

            obs.signal_handler_connect(sh, "transition_start", on_transition_start)
            obs.signal_handler_connect(sh, "destroy", on_transition_destroy)

            transitions[obs.obs_source_get_uuid(transition)] = True

    obs.source_list_release(sources)
    obs.obs_frontend_add_event_callback(on_fe_event)

    open_midi()


def script_defaults(settings):
    scenes_array = obs.obs_data_get_default_array(settings, "vidswitch_scenes")
    if not scenes_array:
        scenes_array = obs.obs_data_array_create()
        obs.obs_data_set_default_array(settings, "vidswitch_scenes", scenes_array)
    else:
        for index in range(obs.obs_data_array_count(scenes_array) - 1, -1, -1):
            obs.obs_data_array_erase(scenes_array, index)

    for scene in dest_scenes:
        scene_obj = obs.obs_data_create()

        obs.obs_data_set_string(scene_obj, "value", scene)
        obs.obs_data_set_bool(scene_obj, "selected", False)
        obs.obs_data_set_bool(scene_obj, "hidden", False)

        obs.obs_data_array_push_back(scenes_array, scene_obj)
        obs.obs_data_release(scene_obj)

    obs.obs_data_array_release(scenes_array)


def script_properties():
    props = obs.obs_properties_create()
    obs.obs_properties_add_editable_list(
        props, "vidswitch_scenes", "Scenes", obs.OBS_EDITABLE_LIST_TYPE_STRINGS, None, None)
    return props


def on_fe_event(event):
    if event in (obs.OBS_FRONTEND_EVENT_FINISHED_LOADING, obs.OBS_FRONTEND_EVENT_TRANSITION_LIST_CHANGED):
        sources = obs.obs_frontend_get_transitions()

        for transition in sources:
            if obs.obs_source_get_uuid(transition) not in transitions:
                sh = obs.obs_source_get_signal_handler(transition)

                obs.signal_handler_connect(sh, "transition_start", on_transition_start)
                obs.signal_handler_connect(sh, "destroy", on_transition_destroy)

                transitions[obs.obs_source_get_uuid(transition)] = True
        obs.source_list_release(sources)


def on_transition_destroy(calldata):
    transition = obs.calldata_source(calldata, "source")
    sh = obs.obs_source_get_signal_handler(transition)

    obs.signal_handler_disconnect(sh, "transition_start", on_transition_start)
    obs.signal_handler_disconnect(sh, "destroy", on_transition_destroy)

    del transitions[obs.obs_source_get_uuid(transition)]


def on_transition_start(calldata):
    global midiout

    transition = obs.calldata_source(calldata, "source")
    origin = obs.obs_transition_get_source(transition, obs.OBS_TRANSITION_SOURCE_A)
    dest = obs.obs_transition_get_source(transition, obs.OBS_TRANSITION_SOURCE_B)

    dest_name = obs.obs_source_get_name(dest)
    if midiout is None:
        print(
            f"VIDSWITCH: WARNING: Want to transition to {dest_name}, trying to open MIDI device")
        open_midi()

    if midiout is None:
        obs.obs_source_release(origin)
        obs.obs_source_release(dest)
        return

    if dest_name in dest_scenes:
        origin_name = obs.obs_source_get_name(origin)
        dest_index = dest_scenes.index(dest_name)

        # make sure these are released in case we end up in a python exception
        # when trying to actually send the midi commands.
        obs.obs_source_release(origin)
        obs.obs_source_release(dest)

        # We definitely need *some* transition, figure out if it's the special
        # case of switcher -> switcher or not
        if origin_name in dest_scenes:
            # Switcher -> switcher, we need to do a special transition
            print(
                f"VIDSWITCH: transition from {obs.obs_source_get_name(origin)} to {dest_name}")
            send_switch(dest_index, False)
        else:
            print(f"VIDSWITCH: direct switch to {dest_name} (index {dest_index})")
            send_switch(dest_index, True)


def send_switch(port_index: int, direct: bool):
    global midiout

    try:
        if direct:
            # switch immediately, OBS handles transition
            midiout.send(mido.Message("control_change", channel=0, control=46, value=0))  # cut
            midiout.send(mido.Message("control_change", channel=0,
                                      control=14, value=port_index))  # switch
        else:
            # transition between two different switcher ports, switcher handles transition
            midiout.send(mido.Message("control_change", channel=0,
                                      control=46, value=1))  # fade ("mix")
            midiout.send(mido.Message("control_change",
                         channel=0, control=47, value=4))  # 400ms
            midiout.send(mido.Message("control_change", channel=0,
                                      control=14, value=port_index))  # switch
    except OSError as e:
        print(f"VIDSWITCH: ERROR: Failed to send MIDI command: {e}")
        midiout.close()
        midiout = None

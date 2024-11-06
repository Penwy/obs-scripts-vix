-- allow globals to be implicitly defined at the top level
allow_defined_top = true

-- show luacheck's identifying code for each warning
codes = true

-- globals OBS automatically provides us (so don't need to be defined
globals = {
  "obslua",
  "script_path",
  "timer_add",
  "timer_remove",
}

max_line_length = 140

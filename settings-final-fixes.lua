-- Disable the obsolete pY equipment fuel manager when its startup setting exists.
-- The hidden optional dependency on pycoalprocessing ensures that this file runs
-- after the pY setting has been created.
local bool_settings = data.raw["bool-setting"]
local py_manager_setting = bool_settings and bool_settings["py-generator-equipment-manager"]

if py_manager_setting then
  py_manager_setting.hidden = true
  py_manager_setting.default_value = false
  py_manager_setting.forced_value = false
end

local SHORTCUT_BEHAVIOR_SETTING_NAME = "personal-equipment-fuel-manager-shortcut-behavior"

---@type data.StringSettingPrototype
local shortcut_behavior_setting = {
  type = "string-setting",
  name = SHORTCUT_BEHAVIOR_SETTING_NAME,
  setting_type = "runtime-per-user",
  default_value = "run-once",
  allowed_values = {
    "run-once",
    "toggle-continuous",
  },
  order = "a[shortcut-behavior]",
}

data:extend({shortcut_behavior_setting})

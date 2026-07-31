local shortcut_name = "personal-equipment-fuel-manager-toggle"

---@type data.ShortcutPrototype
local shortcut = {
  type = "shortcut",
  name = shortcut_name,
  action = "lua",
  toggleable = true,
  icon = "__personal-equipment-fuel-manager__/graphics/shortcut/equipment-fuel-manager-x56.png",
  icon_size = 56,
  small_icon = "__personal-equipment-fuel-manager__/graphics/shortcut/equipment-fuel-manager-x36.png",
  small_icon_size = 36,
  order = "z[personal-equipment-fuel-manager]",
  localised_name = {"shortcut-name.personal-equipment-fuel-manager-toggle"},
  localised_description = {"shortcut-description.personal-equipment-fuel-manager-toggle"},
}

data:extend({shortcut})

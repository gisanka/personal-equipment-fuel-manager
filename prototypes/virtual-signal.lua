local alert_signal_name = "personal-equipment-fuel-manager-alert"

---@type data.VirtualSignalPrototype
local alert_signal = {
  type = "virtual-signal",
  name = alert_signal_name,
  icon = "__personal-equipment-fuel-manager__/graphics/icons/equipment-fuel-manager-alert-x64.png",
  icon_size = 64,
  subgroup = "virtual-signal-special",
  order = "z[personal-equipment-fuel-manager-alert]",
  hidden = true,
  localised_name = {"virtual-signal-name.personal-equipment-fuel-manager-alert"},
}

data:extend({alert_signal})

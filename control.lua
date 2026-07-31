local equipment_fuel_manager = require("scripts.equipment-fuel-manager")

script.on_init(equipment_fuel_manager.on_init)
script.on_configuration_changed(equipment_fuel_manager.on_configuration_changed)
script.on_event(defines.events.on_lua_shortcut, equipment_fuel_manager.on_lua_shortcut)
script.on_event(defines.events.on_player_created, equipment_fuel_manager.on_player_created)
script.on_event(
  defines.events.on_runtime_mod_setting_changed,
  equipment_fuel_manager.on_runtime_mod_setting_changed
)
script.on_nth_tick(251, equipment_fuel_manager.on_nth_tick)

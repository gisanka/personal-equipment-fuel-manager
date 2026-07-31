local EquipmentFuelManager = {}

local SHORTCUT_NAME = "personal-equipment-fuel-manager-toggle"
local SHORTCUT_BEHAVIOR_SETTING_NAME = "personal-equipment-fuel-manager-shortcut-behavior"
local SHORTCUT_BEHAVIOR_RUN_ONCE = "run-once"
local SHORTCUT_BEHAVIOR_TOGGLE_CONTINUOUS = "toggle-continuous"
local ALERT_SIGNAL_NAME = "personal-equipment-fuel-manager-alert"
local DEFAULT_QUALITY_NAME = "normal"

---@class PersonalEquipmentFuelManagerBurner
---@field equipment LuaEquipment
---@field burner LuaBurner
---@field fuel_inventory LuaInventory
---@field burnt_result_inventory LuaInventory
---@field fuel_categories table<string, boolean>

---@class PersonalEquipmentFuelManagerBurntResult
---@field name string
---@field quality string

---@param value string|LuaItemPrototype|LuaQualityPrototype|nil
---@return string|nil
local function get_prototype_name(value)
  if type(value) == "string" then
    return value
  end

  if value then
    return value.name
  end

  return nil
end

---Returns the character inventory used as the source and destination for fuel transfers.
---@param player LuaPlayer
---@return LuaInventory|nil
local function get_player_inventory(player)
  return player.get_main_inventory()
end

---Returns the configured behavior for clicks on the manager shortcut.
---@param player LuaPlayer
---@return "run-once"|"toggle-continuous"
local function get_shortcut_behavior(player)
  local setting = player.mod_settings[SHORTCUT_BEHAVIOR_SETTING_NAME]

  if setting and setting.value == SHORTCUT_BEHAVIOR_TOGGLE_CONTINUOUS then
    return SHORTCUT_BEHAVIOR_TOGGLE_CONTINUOUS
  end

  return SHORTCUT_BEHAVIOR_RUN_ONCE
end

---Returns whether the shortcut controls continuous background transfers for this player.
---@param player LuaPlayer
---@return boolean
local function uses_continuous_shortcut_behavior(player)
  return get_shortcut_behavior(player) == SHORTCUT_BEHAVIOR_TOGGLE_CONTINUOUS
end

---Keeps the visual shortcut state consistent with the player's configured behavior.
---Run-once mode never leaves the shortcut in the toggled state.
---@param player LuaPlayer
local function normalise_shortcut_state(player)
  if not uses_continuous_shortcut_behavior(player) then
    player.set_shortcut_toggled(SHORTCUT_NAME, false)
  end
end

---Removes all alerts previously created by this mod for the player's current character.
---@param player LuaPlayer
---@param character LuaEntity
local function clear_manager_alerts(player, character)
  player.remove_alert({
    entity = character,
    type = defines.alert_type.custom,
    icon = {
      type = "virtual",
      name = ALERT_SIGNAL_NAME,
    },
  })
end

---Collects every burner-backed equipment instance from the player's personal equipment grid.
---@param character LuaEntity
---@return PersonalEquipmentFuelManagerBurner[]
local function collect_burner_equipment(character)
  local grid = character.grid
  if not grid then
    return {}
  end

  ---@type PersonalEquipmentFuelManagerBurner[]
  local managed_burners = {}

  for _, equipment in pairs(grid.equipment) do
    if equipment.valid then
      local burner = equipment.burner

      if burner and burner.valid then
        local fuel_categories = {}

        for category_name in pairs(burner.fuel_categories) do
          fuel_categories[category_name] = true
        end

        managed_burners[#managed_burners + 1] = {
          equipment = equipment,
          burner = burner,
          fuel_inventory = burner.inventory,
          burnt_result_inventory = burner.burnt_result_inventory,
          fuel_categories = fuel_categories,
        }
      end
    end
  end

  return managed_burners
end

---Transfers spent fuel products from one burner into the player's main inventory.
---LuaInventory.transfer_from_stack preserves the source stack's metadata, including quality and spoilage.
---@param burner_data PersonalEquipmentFuelManagerBurner
---@param player_inventory LuaInventory
local function unload_burnt_results(burner_data, player_inventory)
  local burnt_result_inventory = burner_data.burnt_result_inventory

  for slot_index = 1, #burnt_result_inventory do
    local source_stack = burnt_result_inventory[slot_index]

    if source_stack and source_stack.valid_for_read then
      player_inventory.transfer_from_stack(source_stack)
    end
  end
end

---Removes a burner from the active refuelling list without preserving list order.
---@param burners PersonalEquipmentFuelManagerBurner[]
---@param index uint
local function remove_burner_at_index(burners, index)
  burners[index] = burners[#burners]
  burners[#burners] = nil
end

---Returns whether a burner can accept the given fuel category.
---@param burner_data PersonalEquipmentFuelManagerBurner
---@param fuel_category string|nil
---@return boolean
local function accepts_fuel_category(burner_data, fuel_category)
  return fuel_category ~= nil and burner_data.fuel_categories[fuel_category] == true
end

---Distributes compatible fuel stacks across all burner equipment that still has fuel space.
---The rotating starting index prevents the first burner in the grid from always receiving fuel first.
---@param managed_burners PersonalEquipmentFuelManagerBurner[]
---@param player_inventory LuaInventory
local function refuel_burners(managed_burners, player_inventory)
  ---@type PersonalEquipmentFuelManagerBurner[]
  local refillable_burners = {}

  for _, burner_data in pairs(managed_burners) do
    if not burner_data.fuel_inventory.is_full() then
      refillable_burners[#refillable_burners + 1] = burner_data
    end
  end

  if #refillable_burners == 0 then
    return
  end

  local next_burner_index = 1

  for inventory_slot_index = 1, #player_inventory do
    local source_stack = player_inventory[inventory_slot_index]

    if source_stack and source_stack.valid_for_read then
      local fuel_category = source_stack.prototype.fuel_category

      if fuel_category then
        local made_progress = true

        while source_stack.valid_for_read and #refillable_burners > 0 and made_progress do
          made_progress = false
          local burners_checked = 0

          while source_stack.valid_for_read
            and #refillable_burners > 0
            and burners_checked < #refillable_burners
          do
            if next_burner_index > #refillable_burners then
              next_burner_index = 1
            end

            local burner_data = refillable_burners[next_burner_index]

            if burner_data.fuel_inventory.is_full() then
              remove_burner_at_index(refillable_burners, next_burner_index)
            else
              burners_checked = burners_checked + 1

              if accepts_fuel_category(burner_data, fuel_category) then
                local available_count = source_stack.count
                local inserted_count = burner_data.fuel_inventory.insert(source_stack)

                if inserted_count > 0 then
                  source_stack.count = available_count - inserted_count
                  made_progress = true
                end

                if burner_data.fuel_inventory.is_full() then
                  remove_burner_at_index(refillable_burners, next_burner_index)
                else
                  next_burner_index = next_burner_index + 1
                end
              else
                next_burner_index = next_burner_index + 1
              end
            end
          end
        end
      end
    end
  end
end

---Returns the next burnt-result item that the burner is expected to produce.
---The currently burning item is preferred; queued fuel is used when combustion has not started yet.
---@param burner_data PersonalEquipmentFuelManagerBurner
---@return PersonalEquipmentFuelManagerBurntResult|nil
local function get_expected_burnt_result(burner_data)
  local currently_burning = burner_data.burner.currently_burning
  local fuel_prototype = nil
  local fuel_quality_name = DEFAULT_QUALITY_NAME

  if currently_burning then
    local fuel_name = get_prototype_name(currently_burning.name)
    fuel_prototype = fuel_name and prototypes.item[fuel_name] or nil
    fuel_quality_name = get_prototype_name(currently_burning.quality) or DEFAULT_QUALITY_NAME
  else
    for slot_index = 1, #burner_data.fuel_inventory do
      local fuel_stack = burner_data.fuel_inventory[slot_index]

      if fuel_stack and fuel_stack.valid_for_read then
        fuel_prototype = fuel_stack.prototype
        fuel_quality_name = fuel_stack.quality.name
        break
      end
    end
  end

  if not fuel_prototype then
    return nil
  end

  local burnt_result_prototype = fuel_prototype.burnt_result
  if not burnt_result_prototype then
    return nil
  end

  return {
    name = burnt_result_prototype.name,
    quality = fuel_quality_name,
  }
end

---Returns true when no queued fuel and no actively burning fuel remains.
---@param burner_data PersonalEquipmentFuelManagerBurner
---@return boolean
local function is_out_of_fuel(burner_data)
  return burner_data.fuel_inventory.is_empty()
    and burner_data.burner.currently_burning == nil
end

---Returns true when the spent-fuel inventory is full or cannot accept the next expected result.
---@param burner_data PersonalEquipmentFuelManagerBurner
---@return boolean
local function is_burnt_result_blocked(burner_data)
  local burnt_result_inventory = burner_data.burnt_result_inventory

  if #burnt_result_inventory > 0
    and not burnt_result_inventory.is_empty()
    and burnt_result_inventory.is_full()
  then
    return true
  end

  local expected_burnt_result = get_expected_burnt_result(burner_data)
  if not expected_burnt_result then
    return false
  end

  return not burnt_result_inventory.can_insert({
    name = expected_burnt_result.name,
    quality = expected_burnt_result.quality,
    count = 1,
  })
end

---Creates one combined custom alert for the current problem state of an equipment burner.
---@param player LuaPlayer
---@param character LuaEntity
---@param burner_data PersonalEquipmentFuelManagerBurner
---@param out_of_fuel boolean
---@param burnt_result_blocked boolean
local function add_burner_alert(player, character, burner_data, out_of_fuel, burnt_result_blocked)
  local message_key

  if out_of_fuel and burnt_result_blocked then
    message_key = "personal-equipment-fuel-manager-alert.no-fuel-and-spent-blocked"
  elseif out_of_fuel then
    message_key = "personal-equipment-fuel-manager-alert.no-fuel"
  elseif burnt_result_blocked then
    message_key = "personal-equipment-fuel-manager-alert.spent-blocked"
  else
    return
  end

  player.add_custom_alert(
    character,
    {
      type = "virtual",
      name = ALERT_SIGNAL_NAME,
    },
    {
      message_key,
      burner_data.equipment.prototype.localised_name,
    },
    false
  )
end

---Updates all warning alerts for a player's personal burner equipment.
---@param player LuaPlayer
---@param character LuaEntity
---@param managed_burners PersonalEquipmentFuelManagerBurner[]
local function update_burner_alerts(player, character, managed_burners)
  for _, burner_data in pairs(managed_burners) do
    add_burner_alert(
      player,
      character,
      burner_data,
      is_out_of_fuel(burner_data),
      is_burnt_result_blocked(burner_data)
    )
  end
end

---Processes optional item transfers and always refreshes warnings for one player.
---@param player LuaPlayer
---@param transfer_items boolean Whether fuel and spent-fuel items may be moved during this pass.
local function process_player(player, transfer_items)
  local character = player.character
  if not character or not character.valid then
    return
  end

  clear_manager_alerts(player, character)

  local managed_burners = collect_burner_equipment(character)
  if #managed_burners == 0 then
    return
  end

  if transfer_items then
    local player_inventory = get_player_inventory(player)

    if player_inventory and player_inventory.valid then
      for _, burner_data in pairs(managed_burners) do
        unload_burnt_results(burner_data, player_inventory)
      end

      refuel_burners(managed_burners, player_inventory)
    end
  end

  update_burner_alerts(player, character, managed_burners)
end

---Initialises all existing players with continuous transfers disabled.
function EquipmentFuelManager.on_init()
  for _, player in pairs(game.players) do
    player.set_shortcut_toggled(SHORTCUT_NAME, false)
  end
end

---Normalises shortcut states when this mod version or its settings are introduced.
---@param _ ConfigurationChangedData
function EquipmentFuelManager.on_configuration_changed(_)
  for _, player in pairs(game.players) do
    normalise_shortcut_state(player)
  end
end

---Runs the manager once or toggles continuous background operation, depending on the player setting.
---Enabling continuous operation always performs its first transfer pass immediately.
---@param event EventData.on_lua_shortcut
function EquipmentFuelManager.on_lua_shortcut(event)
  if event.prototype_name ~= SHORTCUT_NAME then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if uses_continuous_shortcut_behavior(player) then
    local transfers_enabled = not player.is_shortcut_toggled(SHORTCUT_NAME)
    player.set_shortcut_toggled(SHORTCUT_NAME, transfers_enabled)

    if transfers_enabled then
      process_player(player, true)
    end
  else
    player.set_shortcut_toggled(SHORTCUT_NAME, false)
    process_player(player, true)
  end
end

---Ensures that newly created players start with continuous transfers disabled.
---@param event EventData.on_player_created
function EquipmentFuelManager.on_player_created(event)
  local player = game.get_player(event.player_index)

  if player then
    player.set_shortcut_toggled(SHORTCUT_NAME, false)
  end
end

---Untoggles the shortcut when the player switches back to run-once behavior.
---@param event EventData.on_runtime_mod_setting_changed
function EquipmentFuelManager.on_runtime_mod_setting_changed(event)
  if event.setting ~= SHORTCUT_BEHAVIOR_SETTING_NAME or not event.player_index then
    return
  end

  local player = game.get_player(event.player_index)
  if player then
    normalise_shortcut_state(player)
  end
end

---Runs periodic warnings for every connected player and transfers items only in enabled continuous mode.
---@param _ NthTickEventData
function EquipmentFuelManager.on_nth_tick(_)
  for _, player in pairs(game.connected_players) do
    local transfer_items = uses_continuous_shortcut_behavior(player)
      and player.is_shortcut_toggled(SHORTCUT_NAME)

    process_player(player, transfer_items)
  end
end

return EquipmentFuelManager

# Personal Equipment Fuel Manager

Personal Equipment Fuel Manager manages fuel and spent fuel in burner-backed personal equipment in Factorio 2.1.

## Default workflow: run once

By default, clicking the shortcut immediately runs one transfer pass:

1. Spent-fuel products are moved from personal burner equipment into the player's main inventory.
2. Compatible fuel is distributed from the player's main inventory across the personal burner equipment.
3. The current warning state is refreshed.

The shortcut does not remain enabled in this mode. This is useful for refuelling at a dedicated fuel station without carrying additional spare fuel containers permanently.

## Optional continuous operation

The per-player setting **Shortcut behavior** can be changed to **Toggle continuous operation**.

In this mode, clicking the shortcut enables or disables background transfers. Enabling it performs the first transfer pass immediately; subsequent passes run every 251 ticks while the shortcut remains enabled.

Warnings are checked every 251 ticks regardless of the selected shortcut behavior or toggle state.

## Features

- Supports every personal equipment instance that exposes a runtime burner, regardless of equipment prototype type.
- Moves compatible fuel from the player's main inventory into personal burner equipment.
- Distributes fuel across available burners instead of always filling only the first one.
- Moves spent-fuel products back into the player's main inventory.
- Preserves fuel quality, spoilage and other stack metadata when inserting fuel.
- Always warns when equipment is out of fuel, when its spent-fuel inventory is full or cannot accept the next expected result, or when both conditions apply.
- Leaves Factorio's prototype-level `auto_refuel` setting unchanged.

## pY compatibility

When `pycoalprocessing` defines the startup setting `py-generator-equipment-manager`, this mod hides the setting and forces it to `false`. This prevents the current pY runtime manager from running in parallel. The compatibility code is conditional, so the mod remains fully standalone.

Hidden optional dependencies on `pycoalprocessing` and `pyindustry` only control load order when those mods are installed.

## Scope

This mod only manages the equipment grid of the player's character. Vehicle and Spidertron equipment grids are intentionally outside its scope.

## Why this mod exists

PyCoalProcessing removed its previous Equipment Fuel Manager while updating to Factorio 2.1 and replaced its refuelling behavior with Factorio's `auto_refuel` mechanism.
Since behavior was not restored there, this mod provides the workflow independently. No pY source code, localisation text or graphical asset is included.

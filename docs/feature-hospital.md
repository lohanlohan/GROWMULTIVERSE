# Hospital Feature

> Feature doc for the hospital system in the nested loader architecture.
> This is a living reference for the modules under `hospital/` and the surgery subsystem.

---

## Purpose

The hospital feature handles:
- malady and cure data
- reception/owner management
- operating table behavior
- automated surgeon stations
- surgery minigame UI and callbacks
- reward/prize configuration

It is one of the most stateful systems in the codebase and relies heavily on dialog callbacks, tile visuals, and persistent station data.

---

## Load Structure

### Loaders
- `hospital_loader.lua` - base hospital feature loader
- `surgery_loader.lua` - surgery minigame loader

### Core Modules
- `hospital.lua` - shared hospital constants, helpers, DB access, and feature glue
- `malady_rng.lua` - malady definitions, display names, and RNG-related logic
- `reception_desk.lua` - receptionist/owner management panels and hospital admin UI
- `operating_table.lua` - operating table state, tile visuals, and surgery station workflow
- `auto_surgeon.lua` - auto surgeon station logic, illness picker, cure selection, and station state

### Surgery Subsystem
- `surgery_data.lua` - diagnosis data, symptoms, headline text, and surgery metadata
- `surgery_engine.lua` - session management, diagnosis flow, and win/fail evaluation
- `surgery_ui.lua` - surgery dialog UI and tool layout
- `surgery_callbacks.lua` - dialog callbacks, reward handling, and player interactions
- `surgprize.lua` - prize selection UI and diagnosis-based reward slots

---

## Module Responsibilities

| Module | Responsibility |
|---|---|
| `hospital.lua` | Shared state and cross-module helpers for the hospital feature. |
| `malady_rng.lua` | Defines maladies and their related display logic. |
| `reception_desk.lua` | Hospital management UI for owners and staff. |
| `operating_table.lua` | Controls the visible operating table state and surgery workflow on the world tile. |
| `auto_surgeon.lua` | Handles auto surgeon station setup, cure binding, storage, and illness picker dialogs. |
| `surgery_data.lua` | Source of truth for diagnosis entries and symptoms. |
| `surgery_engine.lua` | Creates and advances surgery sessions. |
| `surgery_ui.lua` | Renders the sequential surgery UI. |
| `surgery_callbacks.lua` | Processes dialog responses and final reward results. |
| `surgprize.lua` | Admin-facing prize configuration for surgery rewards. |

---

## Important Behavior Notes

- Dialog callbacks must be registered through the global callback system, not inline anonymous dialog callbacks.
- The hospital feature is tightly coupled to global state and `_G` exports from earlier loaders.
- Tile visual updates must be handled carefully; some states are visual-only, while others persist in station data.
- Surgery UI is intentionally split into data, engine, UI, and callback layers to keep the logic maintainable.
- Auto surgeon stations use per-world station state and an illness picker dialog that is driven by hospital level unlocks.

---

## Related Documentation

- `docs/02-world.md`
- `docs/03-tile.md`
- `docs/07-callbacks.md`
- `docs/08-server-global.md`
- `docs/11-dialog-syntax.md`
- `docs/12-constants-enums.md`
- `docs/lua-architecture-index.md`

---

## Notes For Future Expansion

This document should be expanded when:
- a hospital module gains a dedicated sub-feature
- a new surgery diagnosis or tool flow is added
- operating table visuals or auto surgeon behavior changes
- reward logic or station persistence changes

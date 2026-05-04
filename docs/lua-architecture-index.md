# Lua Architecture Index

> Living document for the active `lua scripts (nested loader architecture)` area.
> Purpose: make the repo easy to navigate, and mark where detailed docs still need to be written.

---

## 1. What Exists

The active Lua codebase is organized around a nested loader architecture:

```text
main.lua -> [feature]_loader.lua -> [module].lua
```

Core foundation files are loaded first, then feature loaders, then the feature modules.

### Top-Level Areas

| Area | Purpose |
|---|---|
| `core/` | Foundation runtime: config, db, logger, utilities. |
| `security/` | Anti-spam, anti-ban, warning, and abuse-prevention systems. |
| `economy/` | Currency, gifts, coupons, transfers, and reward logic. |
| `player/` | Player profile, login messages, slots, titles, rewards, starter pack, online state. |
| `machine/` | World machines and rental/entrance style interactions. |
| `item_info/` | Item browser, categorizer, and detailed item data display. |
| `backpack/` | Inventory UI and backpack management. |
| `carnival/` | Arcade mini-games and shared carnival systems. |
| `hospital/` | Malady system, surgery systems, operating table, auto surgeon, and related UI. |
| `events/` | Event systems, currently leaderboard/event style content. |
| `social/` | News, broadcast, portal, and player communication features. |
| `admin/` | Admin commands, reload, help, role injection, and debug tools. |
| `premium_store/` | Shop UI, purchase callbacks, and premium currency/data handling. |
| `automation/` | Automation menu and autofarm convenience tools. |
| `marvelous_missions/` | Mission/quest progression systems. |
| `consumable/` | Usable item effects, wands, foods, and special consumables. |
| `dev/` | Test and debug scripts. |
| root standalone files | Entry point and a small number of standalone or transitional scripts. |

---

## 2. Feature Map

| Feature | Loader | Notable Modules |
|---|---|---|
| `core` | n/a | `utils.lua`, `config.lua`, `db.lua`, `logger.lua`, `logger_loader.lua` |
| `security` | `security_loader.lua` | `anti_spam.lua`, `banwand.lua`, `fake_warn.lua` |
| `economy` | `economy_loader.lua` | `cashback_coupon.lua`, `transfer_pwl.lua`, `give_gems.lua`, `give_level.lua`, `give_skin.lua`, `give_supporter.lua`, `give_token.lua` |
| `player` | `player_loader.lua` | `login_message.lua`, `default_slots.lua`, `starter_pack.lua`, `profile.lua`, `set_slots.lua`, `daily_reward.lua`, `custom_titles.lua`, `online.lua` |
| `machine` | `machine_loader.lua` | `rent_entrance.lua`, `grow_matic.lua`, `store.lua`, `gsm.lua` |
| `item_info` | `item_info_loader.lua` | `item_categorizer.lua`, `item_browser.lua`, `item_info.lua` |
| `backpack` | `backpack_loader.lua` | `backpack.lua` |
| `carnival` | `carnival_loader.lua` | `carnival_shared.lua`, `challenge_fenrir.lua`, `clash_finale.lua`, `death_race.lua`, `mirror_maze.lua`, `growganoth_gulch.lua`, `spiky_survivor.lua`, `shooting_gallery.lua`, `ticket_booth.lua`, `ringmaster.lua` |
| `hospital` | `hospital_loader.lua` and `surgery_loader.lua` | `hospital.lua`, `malady_rng.lua`, `reception_desk.lua`, `operating_table.lua`, `auto_surgeon.lua`, `surgery_data.lua`, `surgery_engine.lua`, `surgery_ui.lua`, `surgery_callbacks.lua`, `surgprize.lua` |
| `events` | `events_loader.lua` | `lb_event.lua` |
| `social` | `social_loader.lua` | `news.lua`, `broadcast.lua`, `social_portal.lua` |
| `admin` | `admin_loader.lua` | `commands.lua`, `custom_help.lua`, `reload.lua`, `role_inject.lua`, `xqsb.lua` |
| `premium_store` | `premium_store_loader.lua` | `premium_store_ui.lua`, `premium_store_callbacks.lua`, `premium_store_data.lua`, `premium_currency.lua` |
| `automation` | `automation_menu_loader.lua` | `automation_menu.lua`, `autofarm_speed.lua` |
| `marvelous_missions` | `marvelous_missions_loader.lua` | `marvelous_missions.lua` |
| `consumable` | `consumable_loader.lua` | `green_beer.lua`, `coconut_tart.lua`, `consumable_coin.lua`, `antidote.lua`, `vile_vial.lua`, `firewand.lua`, `freezewand.lua`, `cursewand.lua`, `banwand.lua`, `duct_tape.lua`, `fireworks.lua`, `item_effect.lua`, `wolf_whistle.lua`, `snowball.lua`, `anti_consumable.lua`, `concentration.lua`, `brutal_bounce.lua` |
| `dev` | n/a | `xdata_debug.lua`, `ui_test.lua`, `tile_debug.lua`, `surgery_test.lua`, `store_test.lua`, `rml_test.lua`, `coins_test.lua` |

---

## 3. Root Files

| File | Role |
|---|---|
| `main.lua` | Entry point. Loads foundation files first, then all feature loaders. |
| `side-button.lua` | Standalone/experimental UI helper or feature file. Needs its own doc if it becomes stable. |
| `auto_surgeon.lua` | Transitional or standalone auto-surgeon implementation. There is also a hospital-scoped auto surgeon module in the active feature tree. |

---

## 4. Documentation That Already Exists

### Core repo docs
- `docs/structure.md` - architecture, load order, naming conventions
- `PROGRESS.md` - feature status and implementation notes
- `docs/conventions.md` - coding patterns and conventions
- `docs/GTPS-CLOUD-PROJECT.md` - project overview
- `docs/upload-workflow.md` - upload workflow

### API docs
- `docs/01-player.md`
- `docs/02-world.md`
- `docs/03-tile.md`
- `docs/04-item.md`
- `docs/05-inventory-item.md`
- `docs/06-drop.md`
- `docs/07-callbacks.md`
- `docs/08-server-global.md`
- `docs/09-http-json.md`
- `docs/10-os-library.md`
- `docs/11-dialog-syntax.md`
- `docs/12-constants-enums.md`
- `docs/13-item-editable-flags.md`

---

## 5. Documentation Gaps

The repo has strong API docs, but it is still missing feature-level docs for most of the codebase.

### Highest-priority missing docs
1. `docs/feature-hospital.md`
2. `docs/feature-carnival.md`
3. `docs/feature-consumable.md`
4. `docs/feature-premium-store.md`
5. `docs/feature-player.md`
6. `docs/feature-admin.md`

### Other useful docs to add
- `docs/feature-machine.md`
- `docs/feature-item-info.md`
- `docs/feature-security.md`
- `docs/feature-social.md`
- `docs/feature-automation.md`
- `docs/feature-missions.md`
- `docs/feature-events.md`
- `docs/feature-backpack.md`

---

## 6. Notes For Future Updates

- Update this document whenever modules move or loaders change.
- If a feature grows beyond a few modules, give it a dedicated feature doc.
- If a file is used by multiple features, document the dependency from the loader level, not only from the module level.
- Keep the active feature docs close to the module names so future searches stay fast.

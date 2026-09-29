# Polychromatic: how each effect gets its colour

Every recolour in the mod is one of seven mechanisms. This document says which mechanism each effect
family uses, why, and what blocks the ones that stay stock. It describes the mod as of 1.0.5
(2026-09-27). It lives in the repository under `docs/` and is excluded from the release zip.

Two engine facts decide the mechanism for every effect:

- **Boot residency, but per CHAIN not per file.** Anything carried by `packages/boot_assets` is
  loaded before any mod runs, so a redirect on *that* path is never served. A material is reached
  through a chain of loose stub files, and redirecting ANY non-boot-resident link in that chain
  delivers the patched parent. Judging by the parent alone is wrong and was the single most
  expensive mistake of 2026-09-24: it condemned 18 working effects, `lasgun_muzzle` among them.
  As of 1.0.0 all 261 registrations report served at load, and the parent's own path usually sits at
  zero opens forever because the engine asks for the child instead.
- **Binding is per bundle.** A particle binds a material whose record is in the same *bundle*.
  Having the material merely resident, loaded by some other package, is not enough: the layer
  silently draws nothing. The game's own bundles carry material records their package never lists,
  and a bundle the mod rebuilds may carry new ones too. That is what makes boot-resident shaders
  reachable after all.

## The sources, one by one

Seven sources ship.

### Inferno staff (`staff`: mine, team)

- **Streams and wall impacts**: mechanism B. The flame is drawn by the staff's code-control
  particles (`psyker_flame_staff_code_control` and its `_3p` twin), rebuilt as `.pyro` bundles with
  renamed clouds over `.livehsv` parents. The tint is written from the `FlamerGasEffects` hooks, which
  run both the stream and the impact loop.
- **Soulblaze flames on burning enemies**: mechanism E, 12 borrowed slots (`SOUL_SLOTS`), chosen per
  burn from the igniting player's staff profile, hooked at `MinionBuffExtension._on_add_buff`.
  Saturation and brightness bake at mod load; hue is live.
- **Soulblaze body glow**: mechanism F, 8 patched character materials (`BURN_REDIRECTS`, `.burnhsv`),
  driven through `Ailment.play_ailment_effect_template`. Daemonhost excluded.
- Stays stock: the floor decal.

### Flamer (`flamer`: mine, team)

- **Zealot flamer streams and impacts**: mechanism B, through the flamer code-control bundles
  (`flamer_code_control`, `_burst`, `_3p`) and the same `FlamerGasEffects` hooks as the staff.
- **Enemy flamers** (Scab `renegade_flame_thrower`, Tox `cultist_flame_thrower`): mechanism B,
  encoded per spawn. Their `_hit` effects are material-less and not mapped.
- **Burning enemies** (the `flamer_assault` burn, setting "Burning enemies follow these settings"):
  the Soulblaze recipe with appended records. Twelve hue copies of `buff_burning`, `_stack_lvl02` and
  `_stack_lvl03` sit in their own bundles; each flame layer points at a child material the mod bakes at
  load (`.burnmat`, hue per slot, saturation and brightness from the flamer setting). The copy is
  chosen by the igniter's profile in a spawn context around `MinionBuffExtension._add_buff`, which is
  where the game creates the particles (`_on_add_buff` runs after they exist). The body glow rides the
  Soulblaze ailment patch for the `burning` ailment. Live material writes cannot do this: particles
  created inside a particle group ignore them, which is also why Soulblaze bakes. Smoke, embers and
  the top stack layer stay stock.
- Owner: the slot-script hook makes the player's stream "mine" or "team" instead of falling back to
  "enemy".

### Servo-skull flamer (`skull`: mine, team)

- The Skitarii companion's flamer: mechanism B on `companion_servo_skull_flamer_code_control`,
  tinted from a hook on `servo_skull_flamer.update`. "Mine" when the skull belongs to the local
  player.

### Las weapons (`las`: mine, team)

The largest source: 25 encoded effects plus 2 direct ones.

- **Beams**: `lasgun_beam` and `lasgun_beam_crit` use mechanism A (`beam_color`, `color_a`). The
  elysian, krieg (charged, linger, bfg linger) and standard linger beams are mechanism B; the krieg
  beam cores need mechanism D.
- **Muzzle flashes** (lasgun, charged, bfg, elysian, laspistol, heavy laspistol, each with a crit
  variant): mechanism B for most layers, C for the muzzle core (`SPAWN_VECTOR_CLOUDS`, 10 effects,
  `lerp_color_a`), D for the red flare. The heavy laspistol's glow uses E (`GLOW_SLOTS`, 6 hues).
- **Trails**: `lasgun_crit_trail` and `lasgun_heavy_beam_crit_trail`, mechanism B, plus D for the
  cores.
- **Impacts**: `lasgun_impact_player` (enemy hits), `lasgun_impact_surface_player` (world hits),
  `lasgun_sparks_armor_player`, `impact_snow_laser_01`: mechanism B for the material layers plus a
  mechanism G 12-hue palette for the glare baked into the particle data.
- **Enemy**: `lasgun_muzzle_enemy`, `lasgun_beam_enemy` and `lasgun_beam_standard_linger_enemy` for
  Scab gunners and captains.
- Stays stock: the `super_armor_lasgun` baked colours and the light inside a muzzle flash.

### Plasma gun (`plasma`: mine, team)

23 encoded effects, all mechanism B unless noted.

- **Player gun**: muzzles (`ks`, `bfg`), charge, overcharge levels 1 to 3, vent valve, reload,
  penetration, beams (standard and orange, with their lingers), impacts small and large, charged
  explosions small, medium and large, and the snow variant.
- **Beam linger**: a mechanism G 12-hue palette on `plasma_beam_linger`, plus plasma trail slots.
- **Enemy**: the Scab plasma trooper's muzzle, flash and medium explosion, and `plasma_muzzle_captain`.
- Owner: the slot-script hook, as for the flamer.

### Force greatsword (`greatsword`: mine, team)

12 encoded effects: charge, activation (`psyker_activate_forcesword`), stage 2 and its loop,
fingertip wisps, block, parry, push, `force_sword_impact_02`, and the three wind-slash levels.

- Owner comes entirely from the slot-script and `_add_moving_vfx` hooks; before them nothing on this
  weapon ever tinted.
- **Wind-slash glow** (`forcesword_2h_special_low`, the level used below 10 charges): 12 palette
  records appended to its bundle, each pointing the 4 `d087c368` glow clouds at a `const_mask`
  parent (`.arcpal`) AND carrying the clouds' vertex colour graph (`38 153 235` x10 at `0x2965`)
  re-hued to that slot, picked at spawn by hue. Both halves are needed: the shader routes the red
  channel, so with the stock blue graph the glow renders near black. The middle level shares the effect's structure but has
  no palette; the high level is listed unreachable.
- Stays stock: **the blue swing arc itself**. Every route was built, served and tested on
  2026-09-25 and none moved it: a private child with a patched parent, the glow clouds' colour graph
  (`38 153 235` x10), vertex colour routing in the pixel shader, and a hue-shifted ramp texture. A
  sixth cloud (`fcd712f9`, VS-only billboard material `b8924303`) was found late and never tested.
  Parked, not blocked.

### Enemy sniper laser (`sniper`: enemy)

- **Targeting laser and shot**: `sniper_laser_sight`, `renegade_sniper_beam` and its `_outdoors`
  variant, mechanism B.
- **Scope and muzzle flash**: `FLASH_EFFECTS` (3 effects), mechanism A on a vector the stock material
  exposes, backed by `SNIPER_FLASH_REDIRECTS`.
- Coordinates with Redshift when it is installed (the sniper group label changes).
- No Rainbow mode: the colour is applied once at spawn, and the laser sight lives for a whole aim, so a
  rainbow would only change between aims. Removed from this source's options in 1.0.0.

## The techniques, by name

Each mechanism is a named combination of primitives. The primitives recur, so naming them makes it
obvious which ones a new effect needs.

| # | mechanism | techniques it applies |
|---|---|---|
| A | Direct material vector | **live vector write** to a variable the stock material already exposes |
| B | Renamed cloud + patched parent | **cloud rename** (murmur32 hash overwrite) + **scalar hijack** of `lighting_far_range` + **HSV packing** into one float + **stock-default gate** (must be exactly 1000.0) |
| C | Renamed cloud + native vector | **cloud rename** + **live vector write** to `lerp_color_a`, no shader payload |
| D | Added bundle record | **loose-path copy** of a boot-resident parent + **appended material record** + **material reference repoint** + **child privatisation** (a per-bundle copy of a shared child so re-parenting stays local) |
| E | Borrowed particle slot | **package borrowing** (an unused per-effect package) + **same-package binding** + **baked material palette** + **surface-effect swap** (destroy stock, create ours, re-attach two frames later) + **never-release pin** |
| F | Ailment shader patch | **shader patch** of the character material + **encoding into an existing vector** (`offset_time_duration.x`) + **zero-is-stock gate** |
| G | Appended particle record | **body colour edit** (unaligned 0-255 float triples, found by the `100xx` marker) + **appended particles record** + **murmur-preimage spawn** (no package lists it) + **hue palette** of copies |

Cross-cutting techniques, used by several mechanisms:

| technique | what it does |
|---|---|
| **chain redirect** | register any non-boot-resident link in a material's stub chain; the patched parent is delivered through it |
| **sha256 stock gate** | every redirect records the stock file's hash, so a game update disables it rather than serving a stale patch |
| **owner context** | `call_with_owner(player_category(unit), ...)` around a spawn entry point, so the tint picks mine/team/enemy |
| **gameplay gate** | no particle query until `enter GameplayStateRun`; queue instead, and freeze the retry deadline while shut |
| **reachability audit** | offline walk of every mapped effect's chains, cross-checked against live `AssetRedirect_Stats` |
| **baked hue** (`const_mask`) | for shaders that bind no cbuffer scalar at all: rewrite the three output-store operands so one existing per-pixel register feeds the channels the hue needs and a literal 0 feeds the rest. Operand rewrites render; every edit that INSERTS instructions into these shaders (`const_hsv`, `live_hsv` on `d087c368`) built cleanly and rendered as unpatched, for reasons never found. 7 hue corners, one parent per palette slot, never a drop-in for stock |
| **vertex colour routing** (`vcol_route`) | when the colour pixel shader multiplies a per-particle vertex colour (`COLOR0` -> `TEXCOORD16`), re-route which incoming channel feeds each output; also operand-only. Built and served for the greatsword arc, where it changed nothing because that cloud's vertex colour is grey |
| **sub-cloud addressing** | a multi-material cloud is addressable per material: one u32 name per material sits right after the packed material table, in table order. Address it by its murmur preimage; no rename needed |
| **baked palette on appended copies** | the Soulblaze recipe without borrowed packages: 12 particle copies appended to the effect's own bundle, each flame layer pointing at a stub served by a material generated at load with the hue baked in, chosen by name at spawn (the flamer burn) |

Techniques observed in RainbowBarrels and not yet used here:

| technique | why it is worth having |
|---|---|
| **custom shader export** | add a new scalar such as `rainbow_barrels_hue` instead of hijacking `lighting_far_range`; +24 bytes per child material, and each child needs its own reflection row because children do not inherit the parent's |
| **pre-spawn name swap** | set `_vfx_name_filled` / `_vfx_name_rim` on the liquid-area extension before it spawns, choosing a pre-baked variant, which sidesteps the missing owner entirely |
| **position and time owner match** | remember recent explosions (4 s, 9 m) and attribute an ownerless liquid area to the nearest one |
| **install-time bundle rebuild** | append records to stock bundles on disk with an installer, hash-pinned with backups and uninstall; bypasses boot residency completely, at the cost of breaking on every game patch |

## The seven mechanisms

### A. Direct material vector, no patch

The cloud's material already exposes a colour vector, so Lua writes it at spawn. Nothing is
redirected and no shader is touched.

- `World.set_particles_material_vector3(world, id, cloud, variable, Vector3(r, g, b))`
- Used by: las beams (`lasgun_beam` with `beam_color`, `lasgun_beam_crit` with `color_a`, both on
  the stock cloud name `beam`), and the enemy sniper's laser and scope flash.

### B. Renamed cloud plus patched parent shader

The workhorse: most flame and las colour works this way.

1. **Rename** the cloud inside the effect's `.particles` so Lua can address it. Cloud names are not
   shipped and the engine compares a 4-byte hash, so the payload overwrites that hash with
   `high32(murmur64a("polychromatic_jet_<n>"))`. Numbering must be contiguous from 1 within an
   effect, because the write loop stops at the first name that does not resolve.
2. **Patch** the parent material's colour pixel shaders so they read an existing scalar the stock
   shader ignores, `lighting_far_range`.
3. **Write** the encoded colour at spawn: `x = 1000 + S + (Hq * 16 + Vq) / 16384`, where S is
   saturation 0-15, Hq is hue 0-1023 and Vq is brightness 1-15 (8 = stock). Exactly 1000 is
   bit-exact stock, which is also the gate: every material under a patched parent must default to
   1000.0, or the patch is not safe to ship.

Used by: Inferno staff streams and wall impacts, flamer and servo-skull streams, las muzzles,
impacts and trails.

### C. Renamed cloud plus an unpatched parent that already takes a vector

Some parents cannot be patched because they are boot-resident, but already expose `lerp_color_a`.
The cloud is renamed as in B, then written with a vector instead of the scalar, so no shader payload
is needed at all.

- The muzzle core layers of every las weapon sit on one such parent, which drives 182 effects.
- In code this is `SPAWN_VECTOR_CLOUDS` plus `tint_mixed`: per effect, a map from cloud name to
  vector variable. Every other cloud of that effect still takes the scalar from B.

### D. Added bundle record, for boot-resident parents

The way past boot residency, and the newest mechanism.

1. Patch a **copy** of the boot-resident parent and ship it at an unused loose path: a material that
   no package the game loads carries, and that has no child materials of its own.
2. Add a **material record** to the effect's own bundle. The record is a 30-byte stub whose body is
   the literal `data/xx/<loose>` path, appended to both the entry table and the decompressed stream.
3. Repoint the cloud's material reference, a u64 in the particle body, at that record's name.

Used by: the red flare of every las muzzle, the krieg beam and crit-trail cores, and the muzzle
glow.

The glow needed one extra step. Its cloud references a **child** material that 25 game bundles
share, so re-parenting that child globally would have broken the glow wherever the mod does not
rebuild the bundle. Instead each rebuilt bundle carries a private copy of the child, stock bytes
with its parent pointing at the patched copy, and repoints its own cloud at that copy. The shared
child is left untouched.

### E. Borrowed particle slots, for Soulblaze flames

The Soulblaze flame exposes no cloud by name at all, so nothing can be written to it live. Instead
the mod swaps the whole particle for a recoloured copy.

- A **slot** is an unused per-effect package that carries both a particle and a material of its own.
  Both are redirected: the particle becomes a copy of the Soulblaze flame pointing at that
  package's own material, and the material becomes a copy of the flame material with a colour baked
  in. Particle and material must come from the same package, per the binding rule above.
- 12 slots give a 12-hue palette. The mod loads the slot packages when gameplay starts and **never
  releases them**: unloading a borrowed package while an effect made from it still exists crashes
  the engine.
- Saturation and brightness are baked into the 12 material files when the mod loads, taken from the
  staff profile, so changing those needs a restart. Hue is chosen per burn and switches live.
- On each new burn the mod creates the slot particle as a surface effect on the enemy, destroys the
  stock one, and stores the new id in the game's own table so the game still stops it when the burn
  ends. The swap is deferred two frames.

Borrowing costs a package per copy and only about 13 genuinely dead packages exist, which is why
mechanism G replaced this for the impacts. Soulblaze and the las muzzle glow still use it.

### F. Ailment shader patch, for the Soulblaze body glow

The burning body glow is not a particle: it is the enemy's own material sampling a gradient ramp.
Those shaders were patched to decode a colour from `offset_time_duration.x`, the burn timing vector
Lua already owns: `x = 4 * C + offset`, with `C = S * 4096 + Hq * 16 + Vq`, hue quantised to 256
steps here. C = 0 is bit-exact stock, which is the gate. Eight character parents are patched,
covering every breed except the daemonhost, whose materials reach no burn shader.

Gib caps are safe unpatched because they never read the timing value. Small body decals do read it
and are not patched yet, so they do not char during a coloured burn.

### G. Appended particle records, for colours baked into particle data

Some colours are not in a material at all. They sit in the `.particles` body as three consecutive
float32 in **0-255** space, at offsets that are not 4-byte aligned. The red glare at every las
impact is one: `255 50 22`. No material write, no shader patch and no baked material default
reaches them, only a byte edit does, so a palette needs one copy of the particle per hue.

Finding them: scan every byte offset for three floats that are whole numbers in 0..255, not all
equal. Genuine artist colours are preceded by a `100xx` marker float and followed by a zero;
structural runs such as `100 0 100` are not, and a triple that looks like a colour can also be an
intensity curve, so check that marker.

Making the copies: append a full `particles` record to a bundle the mod already rebuilds - header,
the source record's var header with the new body length, then the patched body - and add it to the
entry table. Name it something unused and spawn it by its murmur preimage. The engine serves it
even though no package lists it. Twelve copies of a 5 KB effect cost about 30 KB and no packages.

Used by: the impact glow for every las weapon (enemy hits, world hits, armour sparks, snow), 12
hues each. Copies inherit the rebuild, so their clouds still answer to the renamed names and the
live tint of mechanism B still applies on top.

**Pinning is mandatory.** Adding records to a bundle makes its package unsafe to unload: the engine
asserts every resource in the bundle has unloaded, and records in no package's list can fail that
assert. Swapping weapons unloads the las muzzle packages, and that crashed the game. The mod now
loads every extended package at gameplay start and never releases it, gated on the redirect being
served, which is about 3 MB held for 24 packages and does not grow with play.

**Known cost: a crash dump on exit.** Holding those packages crashes the game while it quits:
`Trying to unload resource #ID[69a81dd6d20df1ee] ... refcount: 1`, thrown from `_flush_unloads`
inside `destroy_global_managers`. That texture lives in the two pinned laspistol packages. Releasing
the pins on `exit StateGame` was tried and proven to run, and did not stop it, so the pins stay
unreleased and the exit crash is an open item. Gameplay is unaffected; it only fires during shutdown.

**A mid-level mod reload must re-sync the gate.** DMF only reports state transitions, so a mod
reloaded inside a level never sees `enter GameplayStateRun` and would stay shut until the next level.
On load the mod asks `Managers.ui:get_current_sub_state_name()` and, if already in
`GameplayStateRun`, opens the gate and redoes the per-level setup (pins, slots).

## Runtime rules that crash or silently no-op

**`World.has_particles_material` crashes on an effect with no cloud materials.** Not the write, the
QUERY. A mesh or beam effect whose `.particles` body has zero material references makes the engine
dereference a null array, an access violation reading `0x8`. `World.are_particles_playing` returns
true first and does not protect you. Five sessions died to this on 2026-09-24 via the power maul's
`arc_maul_looping_mesh`. Detect it offline: count `cloud_detect.material_refs` inside every
`.particles` entry; zero refs means never map it. Seven of 92 mapped effects were material-less and
had never tinted anything, so removing them cost no colour:

    cultist_flame_thrower_hit        renegade_flame_thrower_hit
    power_maul_activated             power_maul_activated_2hand
    power_maul_p2_weapon_special_01  arc_rifle_lightning
    arc_maul_looping_mesh

**Do not query the particle system before the level is live.** The mod holds off every query until
DMF reports `enter GameplayStateRun`, queueing instead. The real order per level load is
`StateLoading`, `GameplayStateInit`, `StateGameplay` (which fires in the middle, not first), about
twenty `GameplayInit*` steps, then `GameplayStateRun`; nothing fires during play, and it re-enters
on every level, so the gate cannot get stuck. The pending queue must not count its 30-frame
deadline while the gate is shut, or a tint queued during init expires before gameplay starts.

**Effects with no redirectable link anywhere** are skipped outright rather than retried
(`UNREACHABLE_EFFECTS`). Only `forcesword_2h_special_high` is listed.

**Particles created inside a particle group ignore live material writes.** Minion buff node effects
and liquid areas pass `buff_context.particle_group` to `World.create_particles`; 334 successful writes on
resolving, playing flame clouds changed nothing. Bake the colour into a material copy and substitute the
particle by name at spawn instead (the burn and Soulblaze).

**Other mods can make our work invisible.** `vfx_swapper` hooks `World.create_particles` and calls
`stop_spawning_particles` on a configurable blocklist that overlaps ours heavily: every lasgun
muzzle, `lasgun_crit_trail`, all three plasma charged explosions, the plasma muzzle and beam, the
force sword, and `fire_grenade_player_initial_blast`. Read its live settings before blaming our
payload. Realms Latency is another: with a latency set it marks the local player `remote = true` for
lag compensation, and any effect template that decides `is_local_unit = not player.remote` (the
servo skull's floor decal, for one) then sets itself up as remote and draws nothing; it now exposes
the real flag while a template starts.
## What decides "mine", "team" and "enemy"

Ownership is resolved by comparing units, never by `_is_local_unit`, because bots are local units on
a host. The local player's unit is "mine", any other player-owned unit is "team", anything else is
"enemy". Weapon effects carry an owner context set around the player fx extension and the three
impact entry points, so remote players' shots classify correctly. A Soulblaze burn takes the colour
of whoever set the enemy alight, fixed at the moment of ignition.

**`PlayerUnitFxExtension` is not the only spawn path.** Twenty-six scripts in
`extension_systems/visual_loadout/wieldable_slot_scripts/` call `World.create_particles`
directly, so the fx-extension hook never sees them and `_spawn_owner` stays nil, falling back to
"enemy". The consequences differed per source and hid the bug for weeks:

- `greatsword` declares only `mine`/`team`, so `profile_for` returned nil and **nothing
  was ever tinted**. It looked stock for reasons that had nothing to do with reachability.
- `flamer` and `plasma` declare `enemy`, so they tinted, with the **enemy** colour instead of the
  player's.

The fix is one choke point: `WieldableSlotScripts` is a plain module, hooked with `mod:hook_require`,
and its `update`, `fixed_update`, `post_update` and `update_unit_position` all carry the owning unit.
Wrapping those four in `call_with_owner(player_category(unit), ...)` covers all 26 scripts. The
remaining entry points (`wield`, `on_sweep_hit`, `on_action`, ...) take no unit; `wield` already
works because it routes through `spawn_particles_local`.

Liquid areas have the same shape of gap and no fix yet: `LiquidAreaExtension` spawns its filled, rim
and additional-unit particles with a bare `World.create_particles`, so a player's own burning pool
reads as "enemy".

## Hiding rather than colouring

Unticking "Show ... fire" stops the particle at spawn rather than recolouring it. For las weapons
that hides the whole shot, beam included.

## How payloads are delivered

Every rebuilt bundle is padded to exactly its stock size (zeros inside the last Kraken chunk). A
rebuilt bundle shorter than stock read fine here but crashed a Windows 10 machine in DirectStorage with
`E_DSTORAGE_END_OF_FILE` (1.0.0, 2026-09-26): the engine asked for the stock length and the
non-BypassIO path rejected the short read.

Every replacement file is a redirect registered with the Asset Redirect library, which records the
**stock** file's sha256. After a game update a changed stock file disables that redirect, so the
effect falls back to stock instead of serving a stale patch.

| suffix | what it is |
|---|---|
| `.pyro`, `.pyro2` | a rebuilt bundle: renamed clouds, repointed materials, appended records (palette copies, material stubs) |
| `.livehsv`, `.livehsv2` | a parent material with its colour shaders patched for the live `lighting_far_range` write (mechanism B) |
| `.arcpal` | a `const_mask` build of the greatsword glow parent, one per hue slot |
| `.plasmapal`, `.glowpal` | baked material copies behind the plasma linger and las glow palettes |
| `.burnhsv` | a character material with its burn shaders patched for mechanism F |
| `.soulslot`, `.glowslot` | a borrowed particle slot: a copy of the Soulblaze flame or the las glow |
| `.parentswap` | a copy of a child material whose parent points at a patched copy |
| `.template`, `.plasmatemplate`, `.glowtemplate`, `.impactglowtemplate`, `.surftemplate`, `.burntemplate` | stock child materials the generated files below are made from |
| `.soulmat`, `.glowmat`, `.impactglow`, `.burnmat` | colour materials generated at mod load from the settings (Soulblaze, las glow, las impact glow, flamer burn) |

## What stays stock, and why

| effect | why |
|---|---|
| Inferno staff floor decal | drawn inside the particle system with no Lua handle; its cloud spawns units rather than using a material |
| the light inside a las muzzle flash | a cloud with no material at all |
| `super_armor_lasgun` | its baked colours are not red-dominant, so they were left alone rather than guessed |
| daemonhost Soulblaze glow | its materials reach no burn shader |
| small body decals while burning | their burn shaders read the timing value but are not patched yet |
| force greatsword swing arc | see the greatsword section: every route built and served, none moved it; parked 2026-09-25 |
| 15 material chains across las, plasma, flamer, greatsword | they reach parents we never built a patched payload for; this, not reachability, is why those sources read "partial" |
| burn smoke and embers, and the top burn stack layer | five of the nine burn parents expose no `lighting_far_range` and `stack_lvl04` sits on a root material with no child to bake into |
| type-2 ColorGraph clouds | a cloud can carry its own baked RGB curve instead of referencing a material, so our material work never touches it; four RGB keys at a fixed offset, 352 in explosion light clouds and 480 in `fire_lingering` |

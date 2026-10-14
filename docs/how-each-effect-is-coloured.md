# Polychromatic: how each effect is coloured

Polychromatic recolours effects with a small set of techniques. This document describes each technique, then lists
every source by module with the techniques it uses, then the parts that stay stock. The base mod holds the shared
machinery (owner detection, settings, the loader and the package installer); each module supplies the effect copies,
patched files and data for its own sources, and the engines behind a technique run only when an installed module uses
them.

## Foundations

### Effect copies

The game's effects cannot be edited where they live, so the mod ships its own copies. Each copy is a full particle
effect plus the materials, parent materials and textures it needs, registered as a game package that loads at boot. Every package belongs to one module, and carries all it needs.
A copy draws exactly like the stock effect until one of the techniques below changes its colour. When the game is
about to spawn a stock effect that has copies, the mod substitutes the right copy by name at that moment. Where the
game sends an effect's name to other players, the stock name is sent and the copy is substituted only when the
particle is created locally.

A copy's materials must be able to find every parent and texture they reference, either inside the package or among
the assets the game always keeps loaded. A copy that misses either renders flat or not at all, so every package
carries what its materials need.

### Owner: mine, team, enemy

Every source has a setting per owner. The owner of a spawn is decided by unit, never by a "local unit" flag (bots
are local units on a host):

- **mine**: the local player's unit, or a companion it owns (the servo-skull).
- **team**: any other player's unit.
- **enemy**: anything else.

The owner comes from the code that spawns the effect: the player's effect extension, the projectile's owner, the
attacker of an impact, the slot script of a wielded weapon, or the minion that fires. Effects that spawn with no
owner are attributed by context. A burning or chem pool from a player's grenade takes its thrower where the game names
one, and otherwise the nearest blast of the same grenade from the last few seconds; pools from barrels and hazards have no
owner. A servo-skull charge-up or scope glint takes the owner of the nearest servo-skull within a few metres.

### Routing between sources

A few effects are shared by more than one source and are routed at spawn:

- **Force staff basic projectile and its impacts**: the same effect fires from the Surge, Trauma and Voidstrike
  staffs. It takes the colour of the staff in the owner's secondary slot.
- **The burst on a target and the targeting glow shared by blitzes**: teammates see the same burst for Brain Burst
  and Smite, and Brain Burst and Assail draw the same aim marker. It takes the colour of the blitz the caster is
  holding; with any other weapon in hand it stays stock.

The staff route lives in the base (`engines/staff_routing.lua`): its staff template names, effect paths and the
Trauma default are fixed there, and a module enables it by declaring the `staff_routing` engine. The blitz route reads
its weapon to source table from the Psyker module's `data/blitz_routing.lua`.

### Showing and hiding

Each owner setting has a "Show" toggle and a colour mode. Unticking Show leaves that source exactly as the game draws
it. The **Hidden** mode stops the effect at spawn instead of recolouring it; for las weapons that hides the whole shot.
Arc maul, Arc rifle, Assail, Brain Burst, Grenade: Fire, Smite and Staff: Surge offer no Hidden mode: their colour comes
from colour channels, mesh copies or hue copies, so their copy has to spawn. Grenade: Smoke and Telekine Shield offer none either: the
smoke cloud and the shield are units, not effects that can be stopped.

## Techniques

### 1. Live tint

Used for flame, las, plasma, force sword, staff and blitz effects.

- The copy's colour clouds are **renamed** so the mod can address them at runtime: cloud names are stored as hashes,
  so each colour cloud gets a known name in its copy.
- The parent material behind those clouds uses a **patched colour shader** that reads one material scalar the stock
  shader ignores, `lighting_far_range`, and tints its output by it.
- At spawn the mod writes the owner's colour into that scalar on each renamed cloud. Saturation, hue and brightness
  are packed into one float, and the exact value 1000.0 means stock. Every material under a patched parent defaults
  to 1000.0, so anything the mod does not write draws unchanged.

Colour, saturation and brightness follow the settings for every new spawn; Rainbow takes the hue of the moment.
Live writes do not reach a particle spawned inside a particle group, or a particle whose header marks it as
instanced; copies that rely on live tint have that marker cleared.

### 2. Material vector writes

Some stock materials already expose a colour vector. For those clouds the mod writes the vector at spawn and needs
no patched shader:

- the main las beam and its crit variant (`beam_color`, `color_a`);
- the core of every las muzzle flash and the servo-skull's charge-up (`lerp_color_a`, plus `lerp_color_b` where the
  material holds the colour in both);
- the enemy sniper's scope glint, muzzle flash and beam emitter.

### 3. Colour channels

Mesh effects (lightning bolts, ribbons, arcs) ignore runtime material writes, so their copies read the colour from
the renderer instead.

- The constant buffer every shader reads carries a number of render settings. Polychromatic owns nine of them as
  **colour channels**: four terrain tessellation and displacement distances, which Darktide does not use, and five
  debug overlay settings that the mod adds to the game's render settings at install (`occlusion_debug_far`,
  `occlusion_debug_near`, `occlusion_debug_opacity`, `occluder_debug_far`, `occluder_debug_opacity`).
- Each channel carries **three colour slots**, one per source and owner, packed into one float: 32 hues, 4
  saturation steps and 4 brightness steps per slot. A slot set to Base decodes as stock; a channel with every slot on
  Base holds the game's own value.
- A copy's material reads its slot and tints its output. The mod writes the channels whenever a setting changes and
  twice a second, so colour, saturation and brightness change live on effects already in the air, and Rainbow cycles
  smoothly. Every copy on one slot shares that slot's colour at any moment.
- Mesh particles alive together are drawn as one batch keyed by mesh and name, so each copy carries its own mesh
  tag; without distinct tags the first copy alive would set the colour for all of them.
- A channel on an added setting is written only when the added settings were loaded at this boot; otherwise its
  slots stay stock.

The slot table lives in the base (`channels.lua`) and is shared by all modules, so a module's slots never collide
with another's.

| Channel | Slots |
|---|---|
| `terrain_tesselation_min_distance` | Staff: Surge (mine), Staff: Surge (team), Arc rifle (mine) |
| `terrain_tesselation_max_distance` | Arc rifle (team), Arc maul (mine), Arc maul (team) |
| `terrain_displacement_min_distance` | Explosive barrels, Grenade: Fire (mine), Grenade: Fire (team) |
| `terrain_displacement_max_distance` | Plasma gun (mine), Plasma gun (team), Smite (mine) |
| `occlusion_debug_far` | Smite (team), Brain Burst (mine), Brain Burst (team) |

The other four added settings are free channels.

### 4. Hue copies

Where a colour cannot be written at runtime, the package holds one copy per hue (usually twelve) and the mod spawns
the copy nearest the owner's hue. The hue follows the setting at each spawn; saturation and brightness are fixed in
the copy unless noted. What carries the hue differs:

- **Colour keys in the particle data.** Some colours sit in the particle body itself as runs of 0-255 colour keys,
  such as the glare in every las impact, the glow a bolt casts on the floor and the Assail knife trails. Each hue
  copy has those keys
  rewritten to its hue, scaled to the stock key's brightness.
- **Baked materials.** Each hue copy points at a material with the hue baked into its shader, for materials no live
  route reaches.
- **Unit copies.** A mesh cloud that draws its own unit's material gets copies of that unit, each pointing at a
  baked-hue material.
- **Burn and Soulblaze palettes.** The burning and Soulblaze flames on enemies are hue copies whose materials are
  generated when the game starts from the source's saturation and brightness. The hue is chosen when the enemy
  catches fire, from whoever set it alight. Only the first surface effect binds to a skinned body, so the copy is
  chosen as the burn is added rather than swapped in afterwards.

### 5. Replacement lights

Lights inside particles cannot be recoloured, so the copy's own light is switched off and the mod places a real light
instead: a pooled scene light that replays the stock light's brightness curve and flicker over its life, coloured by
the owner's setting. Flamer, servo-skull and staff streams get a pair of lights that follow the stream while it
fires.

### 6. Weapon surface glow

Glows that belong to the weapon model are coloured on the weapon itself:

- an emissive colour vector on the weapon's materials;
- a glow colour vector on named attachment units of a held item, such as the Assail shards hovering at the Psyker's
  hand, in first and third person;
- the plasma gun's barrel fins, whose heat glow is a separate render target: their materials are swapped for copies
  that read a colour channel for both the cold colour and the heat glow, so the heat gauge stays stock.

Looping weapon effects keep the copy they started with, so any change to that weapon's source settings restarts its
loops.

### 7. Burn body glow

The charring glow on a burning enemy is the enemy's own material, not a particle. The character materials are
patched to decode a colour from the burn timing vector the game already writes, and the mod encodes the burn's colour
into it; zero means stock. Every breed except the daemonhost is covered.

### 8. Unit material swap

A unit's material slot is swapped for one of twelve baked-hue copies of its material, following the owner's hue. The
copies keep the stock material's inputs, so the game's own per-frame values (such as a shield's fade) still apply.
Saturation and brightness are fixed at full in the copies.

## Sources by module

Each module lists its sources by name. A source is present only while its module is installed.

### Staves module

#### Staff: Inferno (mine, team)

- Streams and wall impacts: **live tint**, written while the stream fires.
- The stream's light: **replacement lights** that follow the stream.
- Enemies set alight: **hue copies** (Soulblaze palette) and **burn body glow**, when "Soulblaze glow follows these
  settings" is on.

#### Staff: Surge (mine, team)

- The bolts, the jumps between targets and the strike on each: **colour channels**.
- The bolts' floor glow: **hue copies** (colour keys).
- The basic projectile and its impacts: **live tint**, routed here when fired from a Surge staff.

#### Staff: Trauma (mine, team)

- The basic projectile, its impacts, the charged explosion and the aiming indicators: **live tint**.
- The impact and explosion lights: **replacement lights**.
- The reticule's centre: **unit material swap**.

#### Staff: Voidstrike (mine, team)

- The basic projectile, its impacts, the charge-up, the charged blast and its cast: **live tint**.
- The charge sphere and the blast's mesh layers: **hue copies** (baked materials).
- The impact lights: **replacement lights**.

### Grenades module

#### Grenade: Chem (mine, team)

- The blast, the gas trail, the held grenade's wisps, the lingering pool and its edge: **live tint**. Layers whose
  materials carry baked colours stay stock. The pool takes the owner of the blast that made it.
- The pool's surface: **hue copies** (baked unit material), with live tint on top. Its distortion layers stay stock.

#### Grenade: Fire (mine, team)

- The blast and the burning pool, including its edge: **colour channels**. The pool takes the owner of the blast
  that made it.
- The blast's light: **replacement lights**.

#### Grenade: Flash (mine, team)

- The flash: **live tint**. Layers whose materials carry baked colours stay stock.

#### Grenade: Smoke (mine, team)

- The burst and the trail: **live tint**.
- The smoke cloud: **hue copies**. The cloud unit spawns its smoke effect itself, so each hue has a copy of the unit
  naming a copy of the effect with the hue baked into its material; the copy nearest the owner's hue is spawned in
  place of the stock unit on this machine only.

### Psyker module

#### Assail (mine, team)

- The knife trail and the critical trail: **hue copies** (colour keys), one set of twelve for your knives and your
  team's, picked at spawn from the thrower's hue at full saturation and brightness. The critical trail's two glow
  layers also draw children of live-patched roots with the hue baked in (baked materials).
- The hit flash on the target: **live tint**.
- The aim marker: **live tint**, routed by the caster's weapon (shared with Brain Burst).
- The shards hovering around the hand while Assail is held, first and third person: **weapon surface glow** (glow
  vector on the four shard units). Colour, saturation and brightness change live and Rainbow cycles; Base writes the
  stock cyan back.
- Hits on armour and walls and blood stay stock.

#### Brain Burst (mine, team)

- Hand charge-up, build-up and target marker sprites: **live tint**.
- Mesh and untintable parts of the same effects: **colour channels**.
- The charge-up's light: **hue copies** (colour keys).
- The burst teammates see on a target, and the targeting glow: **live tint**, routed by the caster's weapon.

#### Force greatsword (mine, team)

- Charge, activation, fingertip wisps, stage 2 and its loop, blocks, parries, the push and the sword impact:
  **live tint**.
- The arc thrown by the charged special, all three levels: **hue copies** (unit copies); the low level's glow clouds
  also carry re-hued colour keys.

#### Smite (mine, team)

- The lightning between hands and targets, the strike on each target, the hand and fingertip arcs: **colour
  channels**.
- Charge-up and target marker sprites: **live tint**.
- The lights in the charge-up and the attack: **hue copies** (colour keys).
- The burst teammates see on a target: **live tint**, routed by the caster's weapon.

#### Telekine Shield (mine, team)

- The wall and the dome: **unit material swap**, applied while the shield stands. With "Change colour when damaged" ticked for
  that owner, a shield below the owner's threshold takes the owner's damaged colour, read from the shield's synced
  health, whatever the colour mode.
- The start and fade bursts, the block flash and the placement preview stay stock.

### Guns module

#### Flamer (mine, team)

- Zealot flamer streams and wall impacts: **live tint**, written while the stream fires.
- The stream's light: **replacement lights** that follow the stream.
- Enemies set alight by a flamer: **hue copies** (burn palette) and **burn body glow**, when "Burning enemies follow
  these settings" is on.

#### Las weapons (mine, team)

- Beams, lingers, crit trails and most muzzle layers for lasguns, laspistols and the Helbore: **live tint**.
- The main beam and the muzzle cores: **material vector writes**.
- Impact glare on enemies, surfaces, armour and snow: **hue copies** (colour keys), with live tint on top.
- The heavy laspistol's muzzle glow: **hue copies** (baked materials).

#### Phosphor pistol (mine, team)

- Muzzle flash, hit impacts and the backblast on each enemy hit: **live tint**.
- Magazine glow: **weapon surface glow** (emissive vector).

#### Plasma gun (mine, team)

- Muzzles, charge, overcharge vents, valve, reload, penetration, beams, impacts and charged explosions: **live tint**.
- The beam linger: **hue copies** (colour keys), with live tint on top. Its saturation and brightness follow your own
  setting for every owner.
- The barrel fins, cold and hot: **weapon surface glow** on a **colour channel**.

### Skitarii module

#### Arc maul (mine, team)

- Idle arcs on the head and the special's lightning: **colour channels**.
- The special's floor glow: **hue copies** (colour keys).
- Coil glow: **weapon surface glow** (emissive vector).

#### Arc rifle (mine, team)

- Beam lightning, arc chains and their strikes, the impact: **colour channels**.
- The impact's floor glow: **hue copies** (colour keys).
- The beam and impact lights: **replacement lights**.
- The rifle's glow: **weapon surface glow** (emissive vector).

#### Servo-Skull flame (mine, team)

- The companion's flamer stream: **live tint**.
- The stream's light: **replacement lights** that follow the stream.
- Enemies it sets alight: **hue copies** (the skull's own burn palette, generated from the skull's saturation and
  brightness) and **burn body glow**, when "Burning enemies follow these settings" is on.

#### Servo-Skull las (mine, team)

- Beam, linger, impacts, armour sparks and scope glint: **live tint**.
- Muzzle core and the charge-up between shots: **material vector writes**.

### Hazards module

#### Enemy sniper laser (enemy)

- Targeting laser and shot: **live tint**.
- Scope glint, muzzle flash and beam emitter: **material vector writes**.
- No Rainbow: the laser lives for the whole aim and is coloured once at spawn. When Redshift is installed, Redshift
  owns the sniper laser and this source steps back.

#### Explosive barrels (enemy)

- The brightest flame layers: **colour channels**.
- The blast's light: **replacement lights**.

## What stays stock

| Effect | Why |
|---|---|
| Inferno staff floor decal | drawn inside the particle system with no handle to colour it |
| The light inside a las muzzle flash | a cloud with no material |
| `super_armor_lasgun` | its baked colours are left as the game draws them |
| Phosphor shot trail and burn | left as the game draws them |
| Explosive barrel smoke, sparks and one outer flame layer | their materials expose no colour input |
| Surge hand sparks | coloured by a shared texture |
| Brain Burst hand charge-up mesh | draws its own unit's material, which has no copy |
| Assail hits on armour and walls | shared with autoguns |
| Plasma heat gauge | kept stock on purpose |
| Enemy flamers, Scab gunner las and Scab plasma trooper effects | Flamer, Las weapons and Plasma gun have no enemy setting |
| Burn smoke, embers and the top burn stack layer | their materials expose no colour input |
| Daemonhost Soulblaze glow | its materials have no burn shader |
| Small body decals while burning | their burn shaders are not patched |
| Clouds with their own colour curve | a cloud can carry a baked colour curve instead of a material |

## Delivery and safety

- Packages and the added render settings are installed from the base plus every installed module, and load from the next game start. Adding or removing a module reinstalls them at the next start; with no module installed, the packages are removed. The one game file
  they change is backed up and restored on removal.
- Patched stock files (the parent shaders behind live tint and the character materials behind burn body glow) are
  served in place of the stock file only while the stock file matches the version the patch was made from; a changed
  stock file falls back to stock rather than serving a stale patch.
- Materials generated at load (burn and Soulblaze palettes, las glow and impact glow) are served only when the game's
  material format matches the one they were built for.

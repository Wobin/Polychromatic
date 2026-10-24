# Polychromatic

Recolours or hides weapon and Psyker effects in Darktide (flame, las, plasma, lightning and warp powers), separately for your own and your team's, plus the enemy sniper laser and exploding barrels.

Polychromatic is a base mod plus six optional modules. The base changes nothing on its own; each module you install adds the sources for one group of effects.

## Install

Pick one:

- **Everything:** download `Polychromatic.zip`. It holds the base and all six modules.
- **Base plus the modules you want:** download `Polychromatic_Empty.zip` (the base), then each module zip you want. Unzip them all into your `mods` folder, so that each module lands in `mods/Polychromatic/modules/<module>/`.

Either way you end with `mods/Polychromatic/Polychromatic.mod`. Add `Polychromatic` to `mod_load_order.txt` (or let your mod manager do it), after Redshift. Start the game; the effect packages load on that first start. Adding or removing a module takes effect after a mods reload (Ctrl+Shift+L) or the next start.

## Modules

| Module | Zip | Sources |
|---|---|---|
| Staves | `Polychromatic - Staves.zip` | Staff: Inferno, Staff: Surge, Staff: Trauma, Staff: Voidstrike |
| Grenades | `Polychromatic - Grenades.zip` | Grenade: Chem, Grenade: Fire, Grenade: Flash, Grenade: Smoke |
| Psyker | `Polychromatic - Psyker.zip` | Assail, Brain Burst, Force greatsword, Smite, Telekine Shield |
| Guns | `Polychromatic - Guns.zip` | Flamer, Las weapons, Phosphor pistol, Plasma gun |
| Skitarii | `Polychromatic - Skitarii.zip` | Arc maul, Arc rifle, Power sword, Servo-Skull flame, Servo-Skull las |
| Hazards | `Polychromatic - Hazards.zip` | Enemy sniper laser, Explosive barrels |

The options list the installed modules under General, and the **Source** dropdown holds only their sources. With no module installed the game is fully stock.

## Adding and removing modules

To add a module, unzip it into your `mods` folder. To remove one, delete its folder from `mods/Polychromatic/modules/`. The change applies after a mods reload (Ctrl+Shift+L) or the next start: the options list and the sources follow the installed modules, and a removed module's effects are stock from that point. A module replaced in place refreshes its effects at the next mission or hub load. Saved settings for a removed module are kept and return if the module is installed again. With every module removed the game is fully stock. A removed module's composed file stays in the local application data folder (`%LOCALAPPDATA%\asset-redirect\hosts`) until that host is composed again.

## Sources

Each source has its own settings, chosen from the **Source** dropdown in the mod options. For your own effects and your team's (the sniper laser and barrels are enemy-only) you pick a colour mode:

- **Base**: leave it exactly as the game draws it.
- **Set colour**: pick a colour and a brightness.
- **Rainbow**: the hue cycles over time.
- **Hidden**: the effect is not drawn.

### Staves

| Source | Covers |
|---|---|
| Staff: Inferno | Streams, wall impacts and the glow an impact leaves on the ground (nearest of 12 hues). Enemies you set alight glow and burn in that colour (Soulblaze). |
| Staff: Surge | The lightning bolts, the jumps between targets and the strike on each, plus the basic projectile and its impacts. The hand sparks stay stock. No Hidden. |
| Staff: Trauma | The basic projectile and its impacts, the charged explosion, its light and the aiming reticule. |
| Staff: Voidstrike | The basic projectile and its impacts, the charge-up sphere, the charged blast and its impact. |

### Grenades

| Source | Covers |
|---|---|
| Grenade: Chem | The Hive Scum chem grenade's blast, gas trail, the held grenade's wisps and the lingering pool with its edge. Layers with baked colours stay stock. |
| Grenade: Fire | The blast, its light and the burning pool it leaves. No Hidden. |
| Grenade: Flash | The Hive Scum flash grenade's flash. Layers with baked colours stay stock. |
| Grenade: Smoke | The burst, the trail and the smoke cloud; the cloud takes the nearest of 12 hues when it forms. No Hidden. |

### Psyker

| Source | Covers |
|---|---|
| Assail | The knife trail, the critical trail, the hit flash on the target, the aim marker and the shards hovering at the hand while Assail is held. The trails take the nearest of 12 hues; hits on armour and walls, blood and the knife itself stay stock. No Hidden. |
| Brain Burst | The Psyker hand charge-up, the build-up, the target marker and the burst on the target. No Hidden. |
| Force greatsword | Charge, activation, fingertip wisps, blocks, parries, the push, and the arc thrown by the charged special. |
| Smite | The Psyker lightning between hands and targets, the strike on each target, the hand and fingertip arcs, the charge-up and the target marker. No Hidden. |
| Telekine Shield | The wall and the dome, in the nearest of 12 hues. Optionally, for your shields and your team's separately, a shield below a set health percentage switches to a damaged colour, even in Base mode. The start, fade and block flashes stay stock. No Hidden. |

### Guns

| Source | Covers |
|---|---|
| Flamer | Zealot flamer streams and wall impacts. Enemies you set alight burn in that colour. |
| Las weapons | Beams, muzzle flashes and impacts for lasguns, laspistols and the Helbore. |
| Phosphor pistol | Muzzle flash, hit impacts, the backblast on each enemy hit and the magazine glow. The shot trail and the burn stay stock. Ticking "Weapon glow uses its own colour" gives the magazine glow a colour of its own. |
| Plasma gun | Muzzle, charge, overcharge vents, beams, impacts, charged explosions and the barrel fins, cold and hot. The heat gauge stays stock. Ticking "Weapon glow uses its own colour" gives the fins a colour of their own, the nearest of 12 hues. |

### Skitarii

| Source | Covers |
|---|---|
| Arc maul | The Skitarii arc maul's idle arcs, the special's lightning and the coil glow. No Hidden. |
| Arc rifle | The Skitarii arc rifle's beam lightning, arc chains and their strikes, the impact and its light, and the rifle's glow. No Hidden. Ticking "Weapon glow uses its own colour" gives the rifle's glow a colour of its own. |
| Power sword | The Skitarii power sword's blade power field and its crackles, the node glow, the activation sparks, the arcs while the special is active, the sparks at the energy node and the hit sparks with their light, in the nearest of 12 hues. The broad arcs thrown while the special is active stay stock. No Hidden. |
| Servo-Skull flame | The Skitarii companion's flamer. Enemies it sets alight burn in that colour. |
| Servo-Skull las | The Skitarii companion's las shots: muzzle flash, beam, linger, impacts and scope glint. |

### Hazards

| Source | Covers |
|---|---|
| Enemy sniper laser | The Scab sniper's targeting laser and shot. No Rainbow, since the laser lives for the whole aim. |
| Explosive barrels | The fire of exploding red barrels. The brightest flame layers recolour; the smoke, sparks and one outer flame layer stay stock. |

The basic staff projectile is the same effect on the Surge, Trauma and Voidstrike staffs; it takes the colour of the staff that fired it. The burst you see on a target when a teammate casts Brain Burst or Smite, and the aim marker shared by Brain Burst and Assail, follow the blitz the caster is holding.

## Notes

- **First start.** Most recolours come from extra effect copies. For each installed module the mod composes its copies into a replacement for one stock debug package that the game never loads, serves that replacement from `%LOCALAPPDATA%\asset-redirect\hosts\` while the game runs, and loads it as a game package while a level runs. The packages are in effect on the first start. A few spare graphics settings (the four terrain distances and `hdr_paper_white_nits`) colour the lightning live.
- **Effect packages setting.** The **Load effect packages** checkbox under General is on by default. Unticked, no package is composed or loaded and the sources that need packages stay stock.
- **Version 2.0 install.** The first start of this version removes a version 2.0 install from the game folder once and says so in chat; colours work in that same session.
- Polychromatic writes nothing to the game folder, so it needs no special handling alongside CustomAssets, Vortex or a game update.
- Colour, saturation and brightness change live for almost everything. The exceptions are burning enemies and Soulblaze: they take their hue at the moment they catch fire, and read saturation and brightness when the game starts, so changing those two needs a restart.
- Untick "Show ... fire" to leave a source exactly stock. To remove it, set the colour mode to Hidden.
- The mod also serves patched copies of a few of the game's own shader files through its own loader. After a game update, any patched file whose original has changed is disabled automatically and that effect falls back to stock until the mod is updated.
- **Antivirus note.** `bin/asset-redirect.dll` serves the patched files and the effect packages. It is an unsigned native library that hooks the game's own file-open calls inside the game process, and machine-learning scanners (Windows Defender's `Wacatac.C!ml` verdict among them) sometimes flag exactly that shape. The source is in this repository and the build is reproducible; each release lists the DLL's SHA-256 so you can check what you downloaded. If Defender quarantines it, restore it and add an exclusion for the mod folder, or report the file as a false positive to Microsoft.
- **Something not recoloured?** Type `/poly_check` in chat. It says whether the loader is running and how many patched files are being served, and writes a full report (loader state, every patched file, slot packages, the live colour channels, your settings, and which effects were seen and coloured) to the console log. For a crash, tick "Debug logging" at the bottom of the mod's options and restart the game first: the log then records the same report at launch and each patched effect as it loads. Attach that log to a bug report.
- Works alongside Redshift: when Redshift is installed it keeps the sniper laser and this mod steps back from it.

## How it works

The engineering write-up, mechanism by mechanism, is in [docs/how-each-effect-is-coloured.md](docs/how-each-effect-is-coloured.md).

## Requirements

- The Darktide Mod Framework.
- Load order: Polychromatic goes after Redshift.

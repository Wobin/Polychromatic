# Polychromatic

Recolours or hides fire and las effects in Darktide, separately for your own and your team's fire, plus the enemy sniper laser.

## Sources

Each source has its own settings, chosen from the **Source** dropdown in the mod options. For your own fire and your team's (the sniper laser is enemy-only) you pick a colour mode:

- **Base**: leave it exactly as the game draws it.
- **Set colour**: pick a colour and a brightness.
- **Rainbow**: the hue cycles over time (each new effect takes the hue of the moment it appears).
- **Hidden**: the effect is not drawn.

| Source | Covers |
|---|---|
| Inferno staff | Streams and wall impacts. Enemies you set alight with it glow and burn in that colour (Soulblaze). |
| Flamer | Zealot flamer streams and wall impacts. Enemies you set alight burn in that colour. |
| Servo-skull flamer | The Skitarii companion's flamer. Enemies it sets alight burn in that colour. |
| Las weapons | Beams, muzzle flashes and impacts for lasguns, laspistols and the Helbore. |
| Plasma gun | Muzzle, charge, overcharge vents, beams, impacts and charged explosions. |
| Force greatsword | Charge, activation, fingertip wisps, block, parry, push, and the glow of the wind slash. The blue arc of the slash itself stays stock. |
| Enemy sniper laser | The Scab sniper's targeting laser and shot. No rainbow for this one, since the laser lives for the whole aim. |

## Notes

- Burning enemies and Soulblaze take their hue at the moment they catch fire. Their saturation and brightness are read from your setting when the game starts, so changing those two needs a restart; changing the colour does not.
- Untick "Show ... fire" to leave that fire exactly stock. To remove it, set the colour mode to Hidden.
- The mod ships patched copies of a few of the game's effect files and serves them through its own loader. After a game update, any patched file whose original has changed is disabled automatically and that effect falls back to stock until the mod is updated.
- Works alongside Redshift: when Redshift is installed it keeps the sniper laser and this mod steps back from it.

## How it works

The engineering write-up, mechanism by mechanism, is in [docs/how-each-effect-is-coloured.md](docs/how-each-effect-is-coloured.md).

## Install

Unzip into your `mods` folder so that you have `mods/Polychromatic/Polychromatic.mod`, then add `Polychromatic` to `mod_load_order.txt` (or let your mod manager do it). Requires the Darktide Mod Framework.

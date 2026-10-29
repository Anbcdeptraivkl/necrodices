# Game text — edit here

Every word the player reads lives in this folder. Rules (numbers, prices, effects) stay in
`data/*.json`; these files only hold words, so editing them can never change the balance.
After editing, run `python tools/check_data.py` (it reports a missing id or a broken file) and
the game picks the text up on the next start.

## `ui/` — interface text, one file per screen

| File | What it holds |
|---|---|
| `common.json` | Buttons and labels used everywhere (NEW RUN, CLOSE, roles, elements, rarities, top bar tips) |
| `battle.json` | Battle screen: ROLL / REROLL / SUMMON / ATTACK!, pick tray, army line, banners, number pops, rule panel |
| `market.json` | Crypt Market: buttons, card captions, coffer kinds, sold / opened |
| `spoils.json` | The money lines after a won battle |
| `tooltips.json` | Tooltip lines: item kind (`Trinket\n%s` = "Trinket", then the rarity on the next line), price (`$%d`, its own line), unit kinds, face / squad text. One idea per line, never joined with dots |
| `codex.json` | Codex tabs, headers and "Summoned by …" sentences |
| `tutorial.json` | First-time coach marks and the four How to Play pages |
| `settings.json` | Settings overlay |
| `end_screen.json` | Victory / Game Over screen |

Each file is `"key": "text"`. Change the text, never the key. A key may appear in one file only.

## `content/` — names, effects and descriptions per id

| File | Fields |
|---|---|
| `units.json` | `name`, `lore` (Codex description) |
| `hunters.json` | `hunters`: `name`, `lore`; `rules`: `name`, `short` (battle / map panel), `effect` |
| `combos.json` | `name`, `pattern`, `lore` |
| `trinkets.json` | `name`, `effect` (tooltip, say WHEN it triggers: On Roll / On Summon / On Attack / After a won battle), `lore` |
| `potions.json`, `gems.json`, `gear.json` | `name`, `effect`, `lore` |
| `coffers.json` | `name`, `lore` |
| `runes.json` | `name`, `effect`, `lore` |

## Placeholders

Keep these exactly as they are; the game fills them in:

- `%s` text or a number, `%d` a whole number — keep how many there are and their order.
- `{counter}` (Overgrowth) and `{value}` (Side-eyed Grimoire) — live trinket numbers.
- `\n` — a line break.

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
| `tooltips.json` | Tooltip lines: item kind (`Trinket\n%s` = "Trinket", then the rarity on the next line), price (`$%d`, its own line), unit kinds, face / group text. One idea per line, never joined with dots |
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

## Writing rules

The designer's own voice; new and edited text follows it.

1. **Effects start with their moment**, then the change: `On Summon: +3 Count per scoring BONE dice.`
   Moments: On Roll / On Summon / On Attack / After battle. Conditions follow the moment
   (`On Summon, with at least 2 METAL dices scoring: +30 Power.`).
2. **Words, not symbols, for amounts and game nouns.** Write `3 or more`, never `3+`
   (combo patterns like `2+2` are notation and stay). The player summons **groups** of
   monsters, never "squads". One cube is a **dice** too, never "die" (`Bone Dice`, `1 random dice`).
3. **Lore is one short, dry line**: a mood or a joke, often a single sentence
   (`Oink in peace.`, `Attracts storms.`). It describes the item, not its rules.

Also: one idea per line in tooltips, never joined with dots (see `tooltips.json` above).

## Placeholders

Keep these exactly as they are; the game fills them in:

- `%s` text or a number, `%d` a whole number — keep how many there are and their order.
- `{counter}` (Overgrowth) and `{value}` (Side-eyed Grimoire) — live trinket numbers.
- `\n` — a line break.

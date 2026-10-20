# Action combat depth — checklist for a player-controlled fighter

For real-time, player-controlled combat (top-down or side view): an avatar, hero or
character the player steers and attacks with. Distilled from games known for combat players
master — *Zelda* (A Link to the Past, Minish Cap), *Enter the Gungeon*, *Hades*, *Diablo*,
*Hyper Light Drifter*, *Doom* (2016), *Mount & Blade*. Behaviour descriptions are from reviews,
developer talks and play; exact frame numbers are not claimed.

Depth = **the player reads a situation, chooses a response that costs something, and the
result shows whether the read was right.** Every item below protects one link of that chain.

## The checklist

| # | Question | Fails when | Seen in |
| --- | --- | --- | --- |
| 1 | **Does each threat ask a different question?** | Enemies differ in looks and numbers but every one is answered the same way | Zelda: shielded foes need a flank, projectiles need a shield or a reflect. Gungeon: each enemy has its own bullet pattern |
| 2 | **Do attacks commit?** Start-up, active, recovery; limited moving or cancelling while attacking | Attacks are free to spam while moving; nothing to time | Hades: attack strings root you, dash cancels; Diablo: each swing is a committed animation; M&B: hold to charge, release on time |
| 3 | **Does the defence cost something?** A window, a cooldown, a resource, a vulnerable end | A short-cooldown invulnerable dodge answers everything | Gungeon: the roll is invulnerable only in its first half, then lands vulnerable and cannot steer; blanks are a scarce panic button |
| 4 | **Is there a read-based defence**, not only an escape? | The only defence is leaving | M&B: block in the direction of the incoming swing; Zelda: shield faces the threat |
| 5 | **Does the economy reward engaging?** | Retreating and shooting from range is as safe and nearly as fast | Doom: health comes from glory kills ("push forward"); Hyper Light Drifter: gun ammo refills only by sword hits; Hades: the Cast must be picked up where it landed |
| 6 | **Is there no permanent safe distance?** | The player out-runs every enemy and nothing covers range | Ranged, leaping, charging enemies; arenas that close in; speed parity while attacking |
| 7 | **Does position matter?** | Where you stand changes nothing but who is near | Hades: wall slams for knockback damage; Diablo: fighting in doorways; M&B: speed bonus for charges, flanking |
| 8 | **Few verbs, many interactions?** | Many buttons, each with one use | Hades: Attack, Special, Cast, Dash — combined by upgrades |
| 9 | **Is every hit readable and felt?** | Hits land without a tell or without feedback; the steps of a combo share one shape, hit area and feedback, so a string of three feels like one hit repeated (bigger numbers alone are not felt) | Tells per enemy, hitstop, knockback, a short mercy invulnerability (Zelda, Hades) |
| 10 | **Does mastery show in results?** | A skilled and an average player finish the same fight in the same time with the same HP | Compare a "kiter", a "spammer" and an "engager" bot, then confirm with human play |

## Using it

1. Name the routine that currently wins (kite and nuke, spam, dodge on cooldown). One
   dominant routine is the symptom; find which row breaks the chain.
2. Fix by **pairs, not halves**: low HP is only fair with avoidable damage (rows 3, 9);
   a cheap dodge is only fine when damage requires being close (rows 3, 5, 6). Copying one
   half of a reference's pair is the most common failure.
3. Prefer one change per axis per experiment: economy (row 5), commitment (2), threats (1, 6),
   defence (3, 4). Test against bots for patterns, then a human for feel.
4. In a mass battle, the fighter's verbs should also act on the battle (knock enemies into
   allies, break a line for the army, use the field's corpses / objects); otherwise the
   fighter plays a duel beside the battle instead of inside it.

## Sources

- Enter the Gungeon dodge roll: https://enterthegungeon.wiki.gg/wiki/Dodge_Roll_(Move) ;
  interview with Dave Crooks: https://www.windowscentral.com/enter-gungeon-interview
- Doom (2016) combat philosophy, GDC 2018 (Loudy, Campbell):
  https://gdconf.com/news/speaker-qa-kurt-loudy-jake-campbell-break-combat-philosophy-doom ,
  https://www.gamedeveloper.com/design/video-the-combat-design-of-i-doom-i-
- Hades verbs and Cast: https://www.tomsguide.com/us/hades-early-access-review-supergiant,review-6046.html ,
  https://www.pcgamer.com/hades-review , https://blog.playstation.com/?p=351740
- Hyper Light Drifter ammo from melee: https://www.gameskinny.com/tips/hyper-light-drifter-weapons-guide/

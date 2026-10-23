#!/usr/bin/env python3
"""Validate content JSON under data/ against GAME_SPEC.md v2 (sections 4, 6 and 9).

Usage: python tools/check_data.py
Prints "DATA OK" or the list of problems (exit code 1).

Checks ids (shared with the art pipeline via tools/art_ids.py), the trinket DSL vocabulary,
cross references (rituals, gear prerequisites, boss rules) and the shape of tunables. Tunable
numbers (prices, HP, weights) are checked by range, never by value, so balance passes never
break this checker. The game repeats the vocabulary check at boot (core/rules_registry.gd).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_ids  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

ELEMENTS = ["BONE", "FIRE", "ICE", "LEAF", "VOLT", "METAL"]
COMBOS = ["RABBLE", "DUO_PACT", "TRIO", "RAINBOW", "FULL_MOON", "RITUAL", "QUARTET", "QUINTET"]
RUNES = {"SHARP", "SWARM", "WILD", "GLASS", "IRON", "TOMB", "GILDED", "LUCKY"}
UNIT_KINDS = {"T1", "HYBRID", "RITUAL", "ELITE", "LEGEND", "PARADE", "WISP"}
DISPLAY_OF = {"T1": "horde", "HYBRID": "horde", "WISP": "horde", "RITUAL": "single", "ELITE": "single",
              "PARADE": "single", "LEGEND": "legend"}
RARITIES = {"COMMON", "UNCOMMON", "RARE"}
TRIGGER_OPS = {
    "ROLL": {"ensure_face"},
    "DIE": {"add_power", "add_count", "mul_power", "mul_count"},
    "SQUAD": {"add_power", "add_count", "mul_power", "mul_count"},
    "RESOLVE": {"mul_damage", "add_damage"},
    "SUMMON": {"add_money"},
    "SPOILS": {"add_money"},
}
SOURCES = {"money", "rerolls_left", "summons_left", "squads_before", "bosses_defeated", "counter", "scored_dice"} | {
    f"{p}:{e}" for p in ("scored", "held") for e in ELEMENTS}
CONDS = {
    "always": set(), "die_element": {"element"}, "die_points_lte": {"n"}, "squad_combo": {"combo"},
    "squad_combo_in": {"combos"}, "squad_has_element": {"element"}, "squad_element_count_gte": {"element", "n"},
    "squad_all_points_gte": {"n"}, "squad_is_first": set(), "squad_is_last": set(), "squad_unit_repeated": set(),
    "battle_distinct_elements_gte": {"n"}, "squads_gte": {"n"},
}
DIE_CONDS = {"die_element", "die_points_lte"}
POTION_ACTIONS = {"element", "points", "rune", "mirror", "money_double"}
COFFER_KINDS = {"POTION", "GEM", "TRINKET", "BONE"}
COFFER_SIZES = {"NORMAL", "JUMBO", "MEGA"}
GEAR_EFFECTS = {"summons", "rerolls", "relic_slots", "consumable_slots", "shop_reroll_discount", "shop_card_slots",
                "interest_cap"}
GEAR_PAIRS = {"DEATH_KNELL": "GRAVE_BELL", "SECOND_CUP": "LOADED_CUP", "OSSUARY": "RELIQUARY",
              "BLACK_MARKET": "HAGGLER_LANTERN", "OVERFLOWING_CRYPT": "OVERSTOCK", "DRAGON_HOARD": "GRAVE_GOODS"}
BOSS_RULES = {"EXORCIST", "WITCH_HUNTER", "BELL_RINGER", "INQUISITOR", "ENRAGED"}
ECONOMY_INTS = ["start_money", "start_dice", "max_dice", "pick_min", "pick_max", "base_summons", "base_rerolls",
                "min_summons", "reward_mob", "reward_champion", "reward_boss", "reward_final", "unused_summon_bonus",
                "interest_per", "interest_amount", "interest_cap", "relic_slots", "consumable_slots", "shop_card_slots",
                "shop_coffer_slots", "shop_reroll_base", "shop_reroll_step", "sell_relic_divisor", "sell_consumable",
                "die_price", "die_rune_price", "former_bone_points", "max_points"]
FILES = ["elements", "combos", "units", "relics", "consumables", "coffers", "equipment", "enemies", "curve",
         "economy", "strings_en"]

problems: list[str] = []


def err(msg: str) -> None:
    problems.append(msg)


def load(name: str):
    path = os.path.join(DATA, f"{name}.json")
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        err(f"{name}.json: {e}")
        return None


def ids_match(what: str, rows: list, expected: list) -> None:
    ids = [r.get("id") for r in rows]
    if len(ids) != len(set(ids)):
        err(f"{what}: duplicate ids")
    if set(ids) != set(expected):
        err(f"{what}: ids differ from GAME_SPEC §6 (missing {sorted(set(expected) - set(ids))}, "
            f"extra {sorted(set(ids) - set(expected))})")


def check_units(d) -> set:
    rows = d.get("units", [])
    ids_match("units", rows, list(art_ids.UNITS))
    per_kind: dict[str, set] = {}
    for u in rows:
        kind = u.get("kind")
        if kind not in UNIT_KINDS:
            err(f"unit {u.get('id')}: kind {kind}")
            continue
        if u.get("display") != DISPLAY_OF[kind]:
            err(f"unit {u['id']}: display {u.get('display')} != {DISPLAY_OF[kind]}")
        if u.get("display") == "horde" and "mini" not in u:
            err(f"unit {u['id']}: horde unit needs a mini")
        if kind in ("T1", "ELITE", "LEGEND"):
            per_kind.setdefault(kind, set()).add(u["elements"][0])
    for kind in ("T1", "ELITE", "LEGEND"):
        if per_kind.get(kind) != set(ELEMENTS):
            err(f"units: every element needs one {kind}")
    return {u["id"] for u in rows}


def check_combos(d, unit_ids: set) -> None:
    rows = sorted(d.get("combos", []), key=lambda r: r.get("rank", 0))
    if [r.get("id") for r in rows] != COMBOS:
        err(f"combos: ids in rank order must be {COMBOS}")
    for r in rows:
        if not all(isinstance(r.get(k), (int, float)) and r[k] > 0 for k in ("base_p", "base_c", "lvl_p", "lvl_c")):
            err(f"combo {r.get('id')}: base / level numbers must be > 0")
    rituals = d.get("rituals", [])
    if len(rituals) != 4:
        err("combos: 4 rituals")
    for r in rituals:
        els = r.get("elements", [])
        if r.get("unit") not in unit_ids or len(set(els)) != 3 or r.get("core") not in els:
            err(f"ritual {r.get('unit')}: 3 distinct elements with the core among them")


def check_cond(where: str, c: dict, trigger: str) -> None:
    t = c.get("type")
    if t not in CONDS:
        err(f"{where}: condition {t}")
        return
    if set(c) - {"type"} != CONDS[t]:
        err(f"{where}: condition {t} params {sorted(set(c) - {'type'})}")
    if t in DIE_CONDS and trigger != "DIE":
        err(f"{where}: die condition {t} in {trigger}")
    if t.startswith("squad_") or t == "battle_distinct_elements_gte":
        if trigger in ("ROLL", "RESOLVE", "SPOILS"):
            err(f"{where}: squad condition {t} in {trigger}")
    if "element" in c and c["element"] not in ELEMENTS:
        err(f"{where}: element {c['element']}")
    for combo in [c.get("combo")] + list(c.get("combos", [])):
        if combo is not None and combo not in COMBOS:
            err(f"{where}: combo {combo}")


def check_value(where: str, v) -> None:
    if isinstance(v, (int, float)):
        return
    if not isinstance(v, dict) or v.get("per") not in SOURCES or set(v) != {"base", "per", "step"}:
        err(f"{where}: value {v}")


def check_relics(d) -> None:
    rows = d.get("relics", [])
    ids_match("relics", rows, art_ids.RELICS)
    for r in rows:
        where = f"trinket {r.get('id')}"
        if r.get("rarity") != art_ids.RELIC_RARITY.get(r.get("id")):
            err(f"{where}: rarity {r.get('rarity')}")
        if not isinstance(r.get("price"), int) or not 1 <= r["price"] <= 20:
            err(f"{where}: price out of range")
        blocks = r.get("blocks") or [{"trigger": r.get("trigger"), "cond": r.get("cond"), "effects": r.get("effects")}]
        if "counter" in r:
            if r["counter"].get("on") != "SUMMON":
                err(f"{where}: counter on SUMMON only")
            check_cond(where, r["counter"].get("cond", {}), "SUMMON")
        for b in blocks:
            trig = b.get("trigger")
            if trig not in TRIGGER_OPS:
                err(f"{where}: trigger {trig}")
                continue
            check_cond(where, b.get("cond") or {}, trig)
            for e in b.get("effects") or []:
                if e.get("op") not in TRIGGER_OPS[trig]:
                    err(f"{where}: op {e.get('op')} not legal in {trig}")
                if e.get("op") == "ensure_face" and e.get("element") not in ELEMENTS:
                    err(f"{where}: ensure_face element")
                check_value(where, e.get("value"))
        if not r.get("text"):
            err(f"{where}: text")


def check_consumables(d) -> None:
    rows = d.get("consumables", [])
    ids_match("consumables", rows, art_ids.CONSUMABLES)
    for c in rows:
        where = f"consumable {c.get('id')}"
        kind = c.get("kind")
        if kind == "GEM":
            if c.get("action") != "level" or c.get("combo") not in COMBOS:
                err(f"{where}: gems level a combo")
        elif kind == "POTION":
            act = c.get("action")
            if act not in POTION_ACTIONS:
                err(f"{where}: action {act}")
            if act == "element" and c.get("element") not in ELEMENTS:
                err(f"{where}: element")
            if act == "rune" and c.get("rune") not in RUNES:
                err(f"{where}: rune")
        else:
            err(f"{where}: kind {kind}")
        if not 0 <= c.get("min_targets", -1) <= c.get("max_targets", -1) <= 2:
            err(f"{where}: targets {c.get('min_targets')}..{c.get('max_targets')}")
        if not isinstance(c.get("price"), int) or c["price"] < 1:
            err(f"{where}: price")
    gems = {c.get("combo") for c in rows if c.get("kind") == "GEM"}
    if gems != set(COMBOS):
        err("consumables: one gem per combo")


def check_coffers(d) -> None:
    rows = d.get("coffers", [])
    ids_match("coffers", rows, art_ids.COFFERS)
    for k in rows:
        if k.get("kind") not in COFFER_KINDS or k.get("size") not in COFFER_SIZES:
            err(f"coffer {k.get('id')}: kind / size")
        if not 1 <= k.get("picks", 0) <= k.get("choices", 0):
            err(f"coffer {k.get('id')}: picks of choices")
    for key, allowed in (("kind_weights", COFFER_KINDS), ("size_weights", COFFER_SIZES)):
        w = d.get(key, {})
        if set(w) != allowed or any(v <= 0 for v in w.values()):
            err(f"coffers: {key} must weight every {sorted(allowed)}")
    if d.get("first_visit_kind") not in COFFER_KINDS:
        err("coffers: first_visit_kind")


def check_equipment(d) -> None:
    rows = d.get("equipment", [])
    ids_match("equipment", rows, art_ids.EQUIPMENT)
    for q in rows:
        if q.get("requires") != GEAR_PAIRS.get(q.get("id")):
            err(f"gear {q.get('id')}: requires {q.get('requires')} != {GEAR_PAIRS.get(q.get('id'))}")
        if not q.get("effect") or set(q["effect"]) - GEAR_EFFECTS:
            err(f"gear {q.get('id')}: effect keys")


def check_enemies(d) -> None:
    ids_match("enemies", d.get("enemies", []), list(art_ids.ENEMIES))
    rules = {r.get("id"): r for r in d.get("boss_rules", [])}
    if set(rules) != BOSS_RULES:
        err("enemies: boss rules")
    for r in rules.values():
        if not 0.3 <= r.get("hp_mult", 0) <= 4.0:
            err(f"boss rule {r.get('id')}: hp_mult out of range")
    sel = d.get("boss_selection", {})
    if not set(sel.get("night1_pool", [])) <= BOSS_RULES:
        err("enemies: night1_pool")


def check_curve(d) -> None:
    bases = d.get("night_base", [])
    if len(bases) != d.get("nights") or any(b2 <= b1 for b1, b2 in zip(bases, bases[1:])):
        err("curve: one rising base per night")
    mult = d.get("role_mult", {})
    if set(mult) != {"MOB", "CHAMPION", "BOSS"} or not (mult["MOB"] <= mult["CHAMPION"] <= mult["BOSS"]):
        err("curve: role_mult must cover MOB <= CHAMPION <= BOSS")


def check_economy(d) -> None:
    for k in ECONOMY_INTS:
        if not isinstance(d.get(k), int) or d[k] < 0:
            err(f"economy: {k} must be a whole number >= 0")
    if not 1 <= d.get("pick_min", 0) <= d.get("pick_max", 0) <= 5:
        err("economy: pick_min <= pick_max <= 5")
    if set(d.get("runes", {})) != RUNES:
        err("economy: one row per rune")
    if set(d.get("shop_card_weights", {})) != {"TRINKET", "POTION", "GEM", "DIE"}:
        err("economy: shop_card_weights")
    if set(d.get("relic_rarity_weights", {})) != RARITIES:
        err("economy: relic_rarity_weights")
    if set(d.get("die_rune_weights", {})) - RUNES:
        err("economy: die_rune_weights")


def main() -> int:
    data = {n: load(n) for n in FILES}
    if any(v is None for v in data.values()):
        for p in problems:
            print("PROBLEM:", p)
        return 1
    for n, d in data.items():
        if n != "strings_en" and d.get("version") != 2:
            err(f"{n}.json: version must be 2")
    unit_ids = check_units(data["units"])
    check_combos(data["combos"], unit_ids)
    check_relics(data["relics"])
    check_consumables(data["consumables"])
    check_coffers(data["coffers"])
    check_equipment(data["equipment"])
    check_enemies(data["enemies"])
    check_curve(data["curve"])
    check_economy(data["economy"])
    if not all(isinstance(v, str) for v in data["strings_en"].values()):
        err("strings_en: must be a flat key -> string map")
    if problems:
        for p in problems:
            print("PROBLEM:", p)
        return 1
    print("DATA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

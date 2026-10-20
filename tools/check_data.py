#!/usr/bin/env python3
"""Validate content JSON under data/ against GAME_SPEC.md (sections 6 and 9).

Usage: python tools/check_data.py
Prints "DATA OK" or the list of problems (exit code 1).
"""
import itertools
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

ELEMENTS = ["BONE", "FIRE", "ICE", "LEAF", "VOLT", "METAL"]
TIERS = {"T1", "T2", "T3", "WISP"}

# spec 9.1 DSL vocabulary
TRIGGERS = {"GROUP", "FINAL", "SUMMON", "FIGHT_END"}
OPS = {"add_power", "add_count", "mul_power", "mul_count", "add_money"}
SOURCES = {"money", "rerolls_left", "summons_left", "groups", "bosses_defeated", "counter"} | {
    f"essence:{e}" for e in ELEMENTS
}
CONDS = {
    "always": set(),
    "group_has_element": {"element"},
    "group_tier": {"tier"},
    "group_unit": {"unit"},
    "group_is_first": set(),
    "group_unit_repeated": set(),
    "essence_gte": {"element", "n"},
    "essence_eq": {"element", "n"},
    "distinct_elements_gte": {"n"},
    "all_elements_present": set(),
    "groups_gte": {"n"},
}

# Spec expectations (spec 6.3/spec 6.4 recipes, spec 6.5–spec 6.7 prices, spec 6.8 enemies, spec 6.9 rules)
EXPECTED_RECIPES = {
    "BONE+BONE": "SKELETON_WARRIOR", "FIRE+FIRE": "FIRE_IMP", "ICE+ICE": "FROST_BAT",
    "LEAF+LEAF": "PUMPKINLING", "VOLT+VOLT": "VOLT_GHOST", "METAL+METAL": "HAUNTED_ARMOR",
    "BONE+FIRE": "FLAME_SKULL", "BONE+LEAF": "SCARECROW", "BONE+METAL": "SHIELD_SKELETON",
    "FIRE+ICE": "STEAM_SLIME", "FIRE+LEAF": "JACK_O_LANTERN", "ICE+LEAF": "BOG_WITCH",
    "ICE+VOLT": "STORM_BANSHEE", "VOLT+METAL": "TESLA_SPIDER",
    "BONE+BONE+BONE": "LICH", "BONE+FIRE+LEAF": "HEADLESS_HORSEMAN",
    "BONE+VOLT+METAL": "STITCHED_GOLEM", "ICE+LEAF+VOLT": "WITCH_QUEEN",
}
EXPECTED_WISP = {"BONE+ICE", "BONE+VOLT", "FIRE+VOLT", "FIRE+METAL", "ICE+METAL", "LEAF+VOLT", "LEAF+METAL"}
RELIC_PRICE_BY_RARITY = {"COMMON": 4, "UNCOMMON": 6, "RARE": 8}
EXPECTED_RELICS = [
    "RATTLE_DRUM", "EMBER_JAR", "FROST_LANTERN", "MOSS_CHARM", "LIGHTNING_ROD", "IRON_NAIL",
    "GRAVEDIGGER_LAMP", "WISP_JAR", "GRAVE_ROBBER", "BONE_SAW", "DEEP_FREEZE", "COLD_HEARTH",
    "BONE_PILE", "GRAND_PROCESSION", "THRIFTY_GHOST", "HYBRID_VIGOR", "COPYCAT_COFFIN",
    "OVERGROWTH", "SPIRIT_BOARD", "PIGGY_COFFIN", "TACTICIAN_SKULL", "CROWN_OF_THE_LICH",
    "FULL_MOON", "BLACK_GRIMOIRE", "ELEMENTAL_CONVERGENCE",
]
CONSUMABLE_PRICE_BY_KIND = {"TOME": 3, "SIGIL": 3, "INK": 4, "DIE": 5}
CONSUMABLE_TARGETS_BY_KIND = {"TOME": 0, "SIGIL": 2, "INK": 1, "DIE": 0}
MODIFIERS = {"SHARP", "SWARM", "HEX", "GOLD", "WILD"}
EQUIPMENT_PRICE = 10
EXPECTED_EQUIPMENT = {
    "BONE_POUCH": None, "BONE_SATCHEL": "BONE_POUCH", "GRAVE_BELL": None, "LOADED_CUP": None,
    "SECOND_CUP": "LOADED_CUP", "RELIQUARY": None, "POCKET_CRYPT": None, "HAGGLER_LANTERN": None,
}
EXPECTED_RULE_HP = {"EXORCIST": 2.0, "WITCH_HUNTER": 2.0, "BELL_RINGER": 2.0, "INQUISITOR": 1.5, "ENRAGED": 2.0}
ROLES = {"MOB", "CHAMPION", "BOSS"}
ECONOMY_KEYS = {
    "start_money": 4, "reward_mob": 3, "reward_champion": 4, "reward_boss": 5,
    "unused_summon_bonus": 1, "interest_per": 5, "interest_cap": 5,
    "shop_reroll_base": 4, "shop_reroll_step": 1, "relic_slots": 5, "consumable_slots": 2,
    "max_dice": 8, "base_summons": 3, "base_rerolls": 2,
}
FILES = ["elements", "units", "relics", "consumables", "equipment", "enemies", "curve", "economy", "strings_en"]

problems: list[str] = []


def err(msg: str) -> None:
    problems.append(msg)


def load(name: str):
    path = os.path.join(DATA, name + ".json")
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:  # noqa: BLE001
        err(f"{name}.json: cannot load ({e})")
        return None


def key_of(elems) -> str:
    return "+".join(sorted(elems, key=ELEMENTS.index))


def check_version(name, d):
    if name != "strings_en" and d.get("version") != 1:
        err(f"{name}.json: missing \"version\": 1")


def check_elements(d):
    ids = [e.get("id") for e in d.get("elements", [])]
    if ids != ELEMENTS:
        err(f"elements: order {ids} != {ELEMENTS}")
    for i, e in enumerate(d.get("elements", [])):
        if e.get("index") != i:
            err(f"elements: {e.get('id')} index {e.get('index')} != {i}")


def check_units(d):
    units = d.get("units", [])
    if len(units) != 19:
        err(f"units: expected 19, got {len(units)}")
    recipes: dict[str, str] = {}
    ids = set()
    for u in units:
        uid = u.get("id")
        ids.add(uid)
        if u.get("tier") not in TIERS:
            err(f"units: {uid} bad tier {u.get('tier')}")
        for k in ("base_p", "base_c", "grow_p", "grow_c"):
            if not isinstance(u.get(k), (int, float)):
                err(f"units: {uid} missing numeric {k}")
        rec = u.get("recipe")
        if u.get("tier") == "WISP":
            if rec != [] or u.get("fallback") is not True or u.get("mini") != "wisp":
                err(f"units: WISP must have recipe [], fallback true, mini 'wisp'")
            continue
        if not isinstance(rec, list) or any(e not in ELEMENTS for e in rec):
            err(f"units: {uid} bad recipe {rec}")
            continue
        if rec != sorted(rec, key=ELEMENTS.index):
            err(f"units: {uid} recipe not in canonical order")
        if u.get("mini") != rec[0].lower():
            err(f"units: {uid} mini {u.get('mini')} != {rec[0].lower()}")
        k = key_of(rec)
        if k in recipes:
            err(f"units: duplicate recipe {k}")
        recipes[k] = uid
        size = len(rec)
        if (u["tier"] == "T3") != (size == 3):
            err(f"units: {uid} tier {u['tier']} vs recipe size {size}")
    if [u.get("id") for u in units if u.get("tier") == "WISP"] != ["WISP"]:
        err("units: exactly one WISP unit required")
    same = [k for k in recipes if k.count("+") == 1 and len(set(k.split("+"))) == 1]
    hybrid = [k for k in recipes if k.count("+") == 1 and len(set(k.split("+"))) == 2]
    triples = [k for k in recipes if k.count("+") == 2]
    if (len(same), len(hybrid), len(triples)) != (6, 8, 4):
        err(f"units: same/hybrid/triple = {len(same)}/{len(hybrid)}/{len(triples)}, expected 6/8/4")
    if recipes != EXPECTED_RECIPES:
        err(f"units: recipe table mismatch vs spec spec 6.3/spec 6.4: {set(recipes.items()) ^ set(EXPECTED_RECIPES.items())}")
    wisp = set(d.get("wisp_keys", []))
    if wisp != EXPECTED_WISP or len(d.get("wisp_keys", [])) != 7:
        err(f"units: wisp_keys {sorted(wisp)} != spec")
    for k in wisp:
        if k in recipes:
            err(f"units: wisp key {k} also has a recipe")
    for a, b in itertools.combinations_with_replacement(ELEMENTS, 2):
        k = key_of([a, b])
        if k not in recipes and k not in wisp:
            err(f"units: pair {k} does not resolve")
    return ids


def check_cond(where, c, unit_ids):
    if not isinstance(c, dict) or c.get("type") not in CONDS:
        err(f"{where}: illegal cond {c}")
        return
    need = CONDS[c["type"]]
    extra = set(c) - {"type"} - need
    if set(need) - set(c) or extra:
        err(f"{where}: cond {c['type']} params {sorted(set(c) - {'type'})} != {sorted(need)}")
    if "element" in c and c["element"] not in ELEMENTS:
        err(f"{where}: unknown element {c['element']}")
    if "tier" in c and c["tier"] not in TIERS:
        err(f"{where}: unknown tier {c['tier']}")
    if "unit" in c and c["unit"] not in unit_ids:
        err(f"{where}: unknown unit {c['unit']}")
    if "n" in c and not isinstance(c["n"], (int, float)):
        err(f"{where}: n must be numeric")


def check_effects(where, effs, has_counter):
    if not isinstance(effs, list) or not effs:
        err(f"{where}: effects must be non-empty list")
        return
    for e in effs:
        if e.get("op") not in OPS:
            err(f"{where}: illegal op {e.get('op')}")
        v = e.get("value")
        if isinstance(v, dict):
            if set(v) != {"base", "per", "step"}:
                err(f"{where}: value object keys {sorted(v)}")
            if v.get("per") not in SOURCES:
                err(f"{where}: illegal source {v.get('per')}")
            if v.get("per") == "counter" and not has_counter:
                err(f"{where}: uses counter source without counter")
        elif not isinstance(v, (int, float)) or isinstance(v, bool):
            err(f"{where}: bad value {v}")


def check_block(where, b, unit_ids, has_counter):
    if b.get("trigger") not in TRIGGERS:
        err(f"{where}: illegal trigger {b.get('trigger')}")
    check_cond(where, b.get("cond"), unit_ids)
    check_effects(where, b.get("effects"), has_counter)


def check_relics(d, unit_ids):
    relics = d.get("relics", [])
    ids = [r.get("id") for r in relics]
    if len(relics) != 25:
        err(f"relics: expected 25, got {len(relics)}")
    if ids != EXPECTED_RELICS:
        err("relics: ids/order differ from spec 6.5")
    for r in relics:
        rid = r.get("id")
        for k in ("name", "rarity", "price", "text"):
            if k not in r:
                err(f"relics: {rid} missing {k}")
        if RELIC_PRICE_BY_RARITY.get(r.get("rarity")) != r.get("price"):
            err(f"relics: {rid} price {r.get('price')} / rarity {r.get('rarity')} mismatch")
        has_counter = "counter" in r
        if has_counter:
            c = r["counter"]
            if c.get("on") not in TRIGGERS or not isinstance(c.get("inc"), (int, float)):
                err(f"relics: {rid} bad counter {c}")
            check_cond(f"relics:{rid}.counter", c.get("cond"), unit_ids)
        if "blocks" in r:
            if any(k in r for k in ("trigger", "cond", "effects")):
                err(f"relics: {rid} mixes blocks with flat form")
            for i, b in enumerate(r["blocks"]):
                check_block(f"relics:{rid}.blocks[{i}]", b, unit_ids, has_counter)
        else:
            check_block(f"relics:{rid}", r, unit_ids, has_counter)


def check_consumables(d):
    cons = d.get("consumables", [])
    if len(cons) != 18:
        err(f"consumables: expected 18, got {len(cons)}")
    seen_mods = set()
    for c in cons:
        cid, kind = c.get("id"), c.get("kind")
        if kind not in CONSUMABLE_PRICE_BY_KIND:
            err(f"consumables: {cid} bad kind {kind}")
            continue
        if c.get("price") != CONSUMABLE_PRICE_BY_KIND[kind]:
            err(f"consumables: {cid} price {c.get('price')}")
        if c.get("max_targets") != CONSUMABLE_TARGETS_BY_KIND[kind]:
            err(f"consumables: {cid} max_targets {c.get('max_targets')}")
        if kind in ("TOME", "SIGIL"):
            if c.get("element") not in ELEMENTS or cid != f"{kind}_{c.get('element')}":
                err(f"consumables: {cid} element {c.get('element')}")
        if kind == "INK":
            if c.get("modifier") not in MODIFIERS or cid != f"INK_{c.get('modifier')}":
                err(f"consumables: {cid} modifier {c.get('modifier')}")
            seen_mods.add(c.get("modifier"))
    kinds = [c.get("kind") for c in cons]
    if (kinds.count("TOME"), kinds.count("SIGIL"), kinds.count("INK"), kinds.count("DIE")) != (6, 6, 5, 1):
        err("consumables: kind counts != 6/6/5/1")
    if seen_mods != MODIFIERS:
        err(f"consumables: ink modifiers {seen_mods}")


def check_equipment(d):
    eq = d.get("equipment", [])
    if len(eq) != 8:
        err(f"equipment: expected 8, got {len(eq)}")
    ids = {e.get("id") for e in eq}
    for e in eq:
        eid = e.get("id")
        if e.get("price") != EQUIPMENT_PRICE:
            err(f"equipment: {eid} price {e.get('price')}")
        req = e.get("requires")
        if req is not None and (req not in ids or req == eid):
            err(f"equipment: {eid} invalid requires {req}")
        if EXPECTED_EQUIPMENT.get(eid, "?") != req:
            err(f"equipment: {eid} requires {req} differs from spec")
        if not isinstance(e.get("effect"), dict) or len(e["effect"]) != 1:
            err(f"equipment: {eid} effect must be single-key object")
    if ids != set(EXPECTED_EQUIPMENT):
        err("equipment: ids differ from spec 6.7")


def check_enemies(d):
    en = d.get("enemies", [])
    if len(en) != 9:
        err(f"enemies: expected 9, got {len(en)}")
    rules = {r.get("id"): r for r in d.get("boss_rules", [])}
    if {k: r.get("hp_mult") for k, r in rules.items()} != EXPECTED_RULE_HP:
        err("enemies: boss_rules ids/hp_mult differ from spec 6.9")
    ids = {e.get("id") for e in en}
    roles = [e.get("role") for e in en]
    if (roles.count("MOB"), roles.count("CHAMPION"), roles.count("BOSS")) != (3, 2, 4):
        err("enemies: role counts != 3/2/4")
    for e in en:
        if e.get("role") not in ROLES:
            err(f"enemies: {e.get('id')} bad role")
        rule = e.get("rule")
        if e.get("role") == "BOSS":
            if rule not in rules or rule == "ENRAGED" or rules[rule].get("boss") != e.get("id"):
                err(f"enemies: {e.get('id')} invalid rule {rule}")
        elif rule is not None:
            err(f"enemies: non-boss {e.get('id')} has rule {rule}")
    for rid, r in rules.items():
        b = r.get("boss")
        if rid == "ENRAGED":
            if b is not None:
                err("enemies: ENRAGED boss must be null")
        elif b not in ids:
            err(f"enemies: rule {rid} boss {b} unknown")
        if not r.get("text"):
            err(f"enemies: rule {rid} missing text")
    sel = d.get("boss_selection", {})
    if set(sel.get("night1_pool", [])) - set(rules) or sel.get("enraged_rule_count") != 2:
        err("enemies: boss_selection invalid")


def check_curve(d):
    if d.get("nights") != 8 or d.get("night_base") != [600, 1500, 3500, 8000, 16000, 30000, 55000, 90000]:
        err("curve: night_base differs from spec 6.10")
    if d.get("role_mult") != {"MOB": 1.0, "CHAMPION": 1.5, "BOSS": 2.0}:
        err("curve: role_mult differs from spec 6.10")


def check_economy(d):
    for k, v in ECONOMY_KEYS.items():
        if d.get(k) != v:
            err(f"economy: {k} = {d.get(k)} != {v}")
    if d.get("shop_category_weights") != {"RELIC": 40, "TOME": 25, "SIGIL": 20, "INK": 10, "DIE": 5}:
        err("economy: shop_category_weights differ from spec 4.6")
    if d.get("relic_rarity_weights") != {"COMMON": 70, "UNCOMMON": 25, "RARE": 5}:
        err("economy: relic_rarity_weights differ from spec 4.6")
    mods = d.get("modifiers", {})
    exp = {"SHARP": ("add_power", 10), "SWARM": ("add_count", 2), "HEX": ("mul_count", 1.5), "GOLD": ("add_money", 2)}
    for m, (op, v) in exp.items():
        if (mods.get(m, {}).get("op"), mods.get(m, {}).get("value")) != (op, v):
            err(f"economy: modifier {m} != {op} {v}")


def check_strings(d):
    if not isinstance(d, dict) or not all(isinstance(v, str) for v in d.values()):
        err("strings_en: must be flat key->string map")


def main() -> int:
    data = {n: load(n) for n in FILES}
    for n, d in data.items():
        if d is not None:
            check_version(n, d)
    unit_ids = set()
    if data["elements"]: check_elements(data["elements"])
    if data["units"]: unit_ids = check_units(data["units"])
    if data["relics"]: check_relics(data["relics"], unit_ids)
    if data["consumables"]: check_consumables(data["consumables"])
    if data["equipment"]: check_equipment(data["equipment"])
    if data["enemies"]: check_enemies(data["enemies"])
    if data["curve"]: check_curve(data["curve"])
    if data["economy"]: check_economy(data["economy"])
    if data["strings_en"] is not None: check_strings(data["strings_en"])
    if problems:
        for p in problems:
            print("PROBLEM:", p)
        return 1
    print("DATA OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Content IDs and art hints shared by build_manifest.py / gen_placeholders.py / validate_art.py.

IDs come from GAME_SPEC §6. When `data/<file>.json` exists, its IDs are read and must agree
with the fallback lists below (same set) — a mismatch raises, so spec, data and art stay in sync.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"

ELEMENTS = ["BONE", "FIRE", "ICE", "LEAF", "VOLT", "METAL"]

# --- GAME_SPEC §6.2 — id -> unit elements (v2: units are picked by combo, not by recipe) --------
UNITS: dict[str, list[str]] = {
    "SKELETON_WARRIOR": ["BONE"], "FIRE_IMP": ["FIRE"], "FROST_BAT": ["ICE"],
    "PUMPKINLING": ["LEAF"], "VOLT_GHOST": ["VOLT"], "HAUNTED_ARMOR": ["METAL"],
    "FLAME_SKULL": ["BONE", "FIRE"], "SCARECROW": ["BONE", "LEAF"], "SHIELD_SKELETON": ["BONE", "METAL"],
    "STEAM_SLIME": ["FIRE", "ICE"], "JACK_O_LANTERN": ["FIRE", "LEAF"], "BOG_WITCH": ["ICE", "LEAF"],
    "STORM_BANSHEE": ["ICE", "VOLT"], "TESLA_SPIDER": ["VOLT", "METAL"],
    "WISP": [],
    "HEADLESS_HORSEMAN": ["BONE", "FIRE", "LEAF"], "STITCHED_GOLEM": ["BONE", "VOLT", "METAL"],
    "WITCH_QUEEN": ["ICE", "LEAF", "VOLT"], "CLOCKWORK_KRAKEN": ["FIRE", "ICE", "METAL"],
    "LICH": ["BONE"], "HELLHOUND": ["FIRE"], "FROST_WRAITH": ["ICE"], "MANDRAKE_BRUTE": ["LEAF"],
    "THUNDER_GHOUL": ["VOLT"], "GARGOYLE": ["METAL"],
    "BONE_DRAGON": ["BONE"], "EMBER_COLOSSUS": ["FIRE"], "FROST_WYRM": ["ICE"], "ELDER_HOLLOW": ["LEAF"],
    "STORM_TITAN": ["VOLT"], "IRON_JUGGERNAUT": ["METAL"],
    "PHANTOM_PARADE": [],
}
# Quintet legends: 32x32 sheets (category "legend", feet on row 31).
LEGEND_UNITS = frozenset({"BONE_DRAGON", "EMBER_COLOSSUS", "FROST_WYRM", "ELDER_HOLLOW", "STORM_TITAN",
                          "IRON_JUGGERNAUT"})

# Units that hover (ART_SPEC §4.2 concepts): drawn above an N0 shadow row at y=15.
FLOATING_UNITS = frozenset({"FROST_BAT", "VOLT_GHOST", "FLAME_SKULL", "WISP", "STORM_BANSHEE",
                            "FROST_WRAITH", "PHANTOM_PARADE"})

# Units drawn from a mask (§4.3) instead of Hallow32.
MASK_UNITS = {"WISP": "wisp_mask"}

# Art ramp hints (ART_SPEC §4.2 table): (primary ramp, accent). Accent is an element or a palette key.
UNIT_ART: dict[str, tuple[str, str | None]] = {
    "SKELETON_WARRIOR": ("BONE", "M2"), "FIRE_IMP": ("FIRE", None), "FROST_BAT": ("ICE", None),
    "PUMPKINLING": ("LEAF", "F1"), "VOLT_GHOST": ("VOLT", "N7"), "HAUNTED_ARMOR": ("METAL", "V2"),
    "FLAME_SKULL": ("BONE", "FIRE"), "SCARECROW": ("BONE", "LEAF"), "SHIELD_SKELETON": ("BONE", "METAL"),
    "STEAM_SLIME": ("FIRE", "ICE"), "JACK_O_LANTERN": ("FIRE", "LEAF"), "BOG_WITCH": ("ICE", "LEAF"),
    "STORM_BANSHEE": ("ICE", "VOLT"), "TESLA_SPIDER": ("METAL", "VOLT"), "WISP": ("MASK", None),
    "HEADLESS_HORSEMAN": ("BONE", "FIRE"), "STITCHED_GOLEM": ("METAL", "VOLT"), "WITCH_QUEEN": ("ICE", "LEAF"),
    "CLOCKWORK_KRAKEN": ("METAL", "ICE"),
    "LICH": ("BONE", "N4"), "HELLHOUND": ("FIRE", "N1"), "FROST_WRAITH": ("ICE", "N7"),
    "MANDRAKE_BRUTE": ("LEAF", "S0"), "THUNDER_GHOUL": ("VOLT", "N4"), "GARGOYLE": ("METAL", "N3"),
    "BONE_DRAGON": ("BONE", "R1"), "EMBER_COLOSSUS": ("FIRE", "N1"), "FROST_WYRM": ("ICE", "N7"),
    "ELDER_HOLLOW": ("LEAF", "B0"), "STORM_TITAN": ("VOLT", "I1"), "IRON_JUGGERNAUT": ("METAL", "R1"),
    "PHANTOM_PARADE": ("N6", "G1"),
}

# --- GAME_SPEC §6.4 trinkets (code name: relics) -------------------------------------------------
RELIC_RARITY: dict[str, str] = {
    **{r: "COMMON" for r in ["RATTLE_DRUM", "EMBER_JAR", "FROST_LANTERN", "MOSS_CHARM", "LIGHTNING_ROD",
                             "IRON_NAIL", "GRAVEDIGGER_LAMP", "TRIO_TOTEM", "MOON_CHARM", "BONE_SAW",
                             "WISP_JAR", "GRAVE_ROBBER", "DEEP_FREEZE"]},
    **{r: "UNCOMMON" for r in ["LOADED_BONE", "THRIFTY_GHOST", "HYBRID_VIGOR", "COPYCAT_COFFIN", "OVERGROWTH",
                               "SPIRIT_BOARD", "PIGGY_COFFIN", "GILDED_TOOTH", "BONE_PILE", "COLD_HEARTH",
                               "GRAND_PROCESSION"]},
    **{r: "RARE" for r in ["TACTICIAN_SKULL", "CROWN_OF_THE_LICH", "LAST_RITES", "ELEMENTAL_CONVERGENCE",
                           "BLOOD_MOON", "BLACK_GRIMOIRE"]},
}
RELICS = list(RELIC_RARITY)

# --- GAME_SPEC §6.6 potions + §6.7 gems (code name: consumables) ---------------------------------
POTIONS = ([f"ELIXIR_{e}" for e in ELEMENTS]
           + ["STRENGTH_TONIC", "WHETSTONE_OIL", "SWARM_BREW", "WILD_SPIRITS", "GLASS_DRAUGHT", "IRON_DRAUGHT",
              "GRAVE_DUST", "LIQUID_GOLD", "LUCKY_CLOVER", "MIRROR_DRAUGHT", "HERMIT_BREW"])
GEMS = ["OPAL", "GARNET", "AMBER", "PRISM", "MOONSTONE", "OBSIDIAN", "EMERALD", "BLOODSTONE"]
CONSUMABLES = POTIONS + GEMS

# --- GAME_SPEC §6.9 coffers ------------------------------------------------------------------------
COFFER_KINDS = ["POTION", "GEM", "TRINKET", "BONE"]
COFFERS = [f"COFFER_{k}{s}" for k in COFFER_KINDS for s in ("", "_JUMBO", "_MEGA")]

# --- GAME_SPEC §6.8 gear (code name: equipment) ------------------------------------------------------
EQUIPMENT = [
    "GRAVE_BELL", "DEATH_KNELL", "LOADED_CUP", "SECOND_CUP", "RELIQUARY", "OSSUARY", "HAGGLER_LANTERN",
    "BLACK_MARKET", "OVERSTOCK", "OVERFLOWING_CRYPT", "GRAVE_GOODS", "DRAGON_HOARD", "POCKET_CRYPT",
]

# --- GAME_SPEC §4.6 runes: die body (20x20) + face tile (16x16) per rune ------------------------------
RUNES = {"sharp": "R1", "swarm": "L1", "wild": "N6", "glass": "I2", "iron": "M1", "tomb": "N5",
         "gilded": "G1", "lucky": "L2"}

# --- GAME_SPEC §6.8 + ART_SPEC §4.5 accents -----------------------------------------------------
ENEMIES: dict[str, tuple[str, str | None]] = {
    "MOB_TORCH_VILLAGER": ("FIRE", None),
    "MOB_PITCHFORK_FARMER": ("METAL", None),
    "MOB_LANTERN_WATCHMAN": ("G1", None),
    "CHAMP_GUARD_CAPTAIN": ("METAL", "R1"),
    "CHAMP_MONSTER_HUNTER": ("B0", "R1"),
    "BOSS_EXORCIST": ("I2", "G1"),
    "BOSS_WITCH_HUNTER": ("R1", "M2"),
    "BOSS_BELL_RINGER": ("G0", "G1"),
    "BOSS_INQUISITOR": ("R0", "R1"),
}
SHOPKEEPER = ("SHOPKEEPER_UNDERTAKER", ("N4", "G1"))

# --- ART_SPEC non-content asset names -------------------------------------------------------------
MINIS = ["bone", "fire", "ice", "leaf", "volt", "metal"]  # + mini_wisp_mask
STAT_ICONS = {
    "coin": "G1", "power": "I1", "count": "R1", "reroll": "M1", "summon": "F2",
    "hp": "R1", "lock": "M1", "info": "I1", "book": "B1", "gear": "M1",
}
UI_FILES = [
    # (name, w, h, nine-slice margin or None)
    ("btn_primary_normal", 24, 24, 6), ("btn_primary_pressed", 24, 24, 6),
    ("btn_primary_disabled", 24, 24, 6), ("btn_primary_hover", 24, 24, 6),
    ("btn_secondary_normal", 24, 24, 6), ("btn_secondary_pressed", 24, 24, 6),
    ("btn_secondary_disabled", 24, 24, 6), ("btn_secondary_hover", 24, 24, 6),
    ("panel_dark", 24, 24, 6), ("panel_card", 24, 24, 6), ("panel_tooltip", 16, 16, 4),
    ("chip", 16, 12, 4), ("slot", 20, 20, None), ("slot_selected", 20, 20, None),
    ("hp_frame", 16, 7, 3), ("hp_fill", 1, 5, None), ("hp_preview", 1, 5, None),
    ("power_box", 16, 14, 4), ("count_box", 16, 14, 4),
    ("rarity_stripe_common", 4, 4, None), ("rarity_stripe_uncommon", 4, 4, None),
    ("rarity_stripe_rare", 4, 4, None),
    ("stamp_defeated", 64, 20, None), ("divider", 8, 1, None),
]
assert len(UI_FILES) == 24
# Drawn at the largest canvas (ART_SPEC §2, 640x300) and centred; the 480x270 centre is the
# safe area every screen size shows.
BACKGROUNDS = [("bg_title", 640, 300), ("bg_map", 640, 300), ("bg_battle", 640, 300),
               ("shop_decor", 120, 182)]   # shop: dark screen + a decorated right corner (D-R12)
VFX = [  # (name, sheet w, h, frame_w)
    ("spark", 4, 4, 4), ("puff", 32, 8, 8), ("slash", 48, 16, 16), ("coin", 24, 6, 6),
    ("soul", 12, 6, 6), ("impact_ring", 48, 16, 16), ("aura", 160, 40, 40),
    ("flame", 128, 32, 32),
]


# --- data/*.json cross-check --------------------------------------------------------------------
def _rows_from_json(path: Path, key: str) -> list[dict]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(raw, list):
        return [r for r in raw if isinstance(r, dict)]
    if isinstance(raw, dict):
        # {"<key>": [...]} (preferred) / single list value / {"ID": {...}, ...}
        if isinstance(raw.get(key), list):
            return [r for r in raw[key] if isinstance(r, dict)]
        lists = [v for v in raw.values() if isinstance(v, list)]
        if len(lists) == 1:
            return [r for r in lists[0] if isinstance(r, dict)]
        if raw and all(isinstance(v, dict) for v in raw.values()):
            return [{"id": k, **v} for k, v in raw.items()]
    raise ValueError(f"{path}: cannot find the '{key}' row list")


def _checked(name: str, fallback: list[str]) -> tuple[list[str], str]:
    """Return (ids, source). IDs from data/<name>.json if present, asserted equal (as a set) to fallback."""
    path = DATA_DIR / f"{name}.json"
    if not path.exists():
        return list(fallback), "art_ids.py (fallback)"
    rows = _rows_from_json(path, name)
    ids = [str(r["id"]) for r in rows if "id" in r]
    missing = sorted(set(fallback) - set(ids))
    extra = sorted(set(ids) - set(fallback))
    if missing or extra or len(ids) != len(set(ids)):
        raise AssertionError(
            f"data/{name}.json disagrees with GAME_SPEC §6 lists in tools/art_ids.py: "
            f"missing={missing} extra={extra} duplicates={len(ids) - len(set(ids))}"
        )
    # Art-relevant attributes must agree too (unit recipe -> ramps, relic rarity -> stripe).
    for r in rows:
        if name == "units" and list(r.get("elements", [])) != UNITS[r["id"]]:
            raise AssertionError(f"data/units.json {r['id']} elements {r.get('elements')} != {UNITS[r['id']]}")
        if name == "relics" and r.get("rarity") and r["rarity"] != RELIC_RARITY[r["id"]]:
            raise AssertionError(f"data/relics.json {r['id']} rarity {r['rarity']} != {RELIC_RARITY[r['id']]}")
    return ids, f"data/{name}.json"


def load_ids() -> dict[str, tuple[list[str], str]]:
    """Return {kind: (ids, source)} for units/relics/consumables/equipment/coffers/enemies."""
    return {
        "units": _checked("units", list(UNITS)),
        "relics": _checked("relics", RELICS),
        "consumables": _checked("consumables", CONSUMABLES),
        "equipment": _checked("equipment", EQUIPMENT),
        "coffers": _checked("coffers", COFFERS),
        "enemies": _checked("enemies", list(ENEMIES)),
    }

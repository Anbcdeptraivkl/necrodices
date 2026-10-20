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

# --- GAME_SPEC §6.2 — id -> recipe elements (WISP: fallback, no fixed recipe) ---------------
UNITS: dict[str, list[str]] = {
    "SKELETON_WARRIOR": ["BONE", "BONE"],
    "FIRE_IMP": ["FIRE", "FIRE"],
    "FROST_BAT": ["ICE", "ICE"],
    "PUMPKINLING": ["LEAF", "LEAF"],
    "VOLT_GHOST": ["VOLT", "VOLT"],
    "HAUNTED_ARMOR": ["METAL", "METAL"],
    "FLAME_SKULL": ["BONE", "FIRE"],
    "SCARECROW": ["BONE", "LEAF"],
    "SHIELD_SKELETON": ["BONE", "METAL"],
    "STEAM_SLIME": ["FIRE", "ICE"],
    "JACK_O_LANTERN": ["FIRE", "LEAF"],
    "BOG_WITCH": ["ICE", "LEAF"],
    "STORM_BANSHEE": ["ICE", "VOLT"],
    "TESLA_SPIDER": ["VOLT", "METAL"],
    "WISP": [],
    "LICH": ["BONE", "BONE", "BONE"],
    "HEADLESS_HORSEMAN": ["BONE", "FIRE", "LEAF"],
    "STITCHED_GOLEM": ["BONE", "VOLT", "METAL"],
    "WITCH_QUEEN": ["ICE", "LEAF", "VOLT"],
}
T3_UNITS = {"LICH", "HEADLESS_HORSEMAN", "STITCHED_GOLEM", "WITCH_QUEEN"}

# Units that hover (ART_SPEC §4.2 concepts): drawn above an N0 shadow row at y=15.
FLOATING_UNITS = frozenset({"FROST_BAT", "VOLT_GHOST", "FLAME_SKULL", "WISP", "STORM_BANSHEE"})

# Units drawn from a mask (§4.3) instead of Hallow32.
MASK_UNITS = {"WISP": "wisp_mask"}

# Art ramp hints (ART_SPEC §4.2 table): (primary ramp, accent). Accent is an element or a palette key.
UNIT_ART: dict[str, tuple[str, str | None]] = {
    "SKELETON_WARRIOR": ("BONE", "M2"),
    "FIRE_IMP": ("FIRE", None),
    "FROST_BAT": ("ICE", None),
    "PUMPKINLING": ("LEAF", "F1"),
    "VOLT_GHOST": ("VOLT", "N7"),
    "HAUNTED_ARMOR": ("METAL", "V2"),
    "FLAME_SKULL": ("BONE", "FIRE"),
    "SCARECROW": ("BONE", "LEAF"),
    "SHIELD_SKELETON": ("BONE", "METAL"),
    "STEAM_SLIME": ("FIRE", "ICE"),
    "JACK_O_LANTERN": ("FIRE", "LEAF"),
    "BOG_WITCH": ("ICE", "LEAF"),
    "STORM_BANSHEE": ("ICE", "VOLT"),
    "TESLA_SPIDER": ("METAL", "VOLT"),
    "WISP": ("MASK", None),
    "LICH": ("BONE", "N4"),
    "HEADLESS_HORSEMAN": ("BONE", "FIRE"),
    "STITCHED_GOLEM": ("METAL", "VOLT"),
    "WITCH_QUEEN": ("ICE", "LEAF"),
}

# --- GAME_SPEC §6.5 ------------------------------------------------------------------------
RELICS = [
    "RATTLE_DRUM", "EMBER_JAR", "FROST_LANTERN", "MOSS_CHARM", "LIGHTNING_ROD", "IRON_NAIL",
    "GRAVEDIGGER_LAMP", "WISP_JAR", "GRAVE_ROBBER", "BONE_SAW", "DEEP_FREEZE", "COLD_HEARTH",
    "BONE_PILE", "GRAND_PROCESSION", "THRIFTY_GHOST", "HYBRID_VIGOR", "COPYCAT_COFFIN",
    "OVERGROWTH", "SPIRIT_BOARD", "PIGGY_COFFIN", "TACTICIAN_SKULL", "CROWN_OF_THE_LICH",
    "FULL_MOON", "BLACK_GRIMOIRE", "ELEMENTAL_CONVERGENCE",
]
RELIC_RARITY = {r: "COMMON" for r in RELICS[:10]}
RELIC_RARITY.update({r: "UNCOMMON" for r in RELICS[10:20]})
RELIC_RARITY.update({r: "RARE" for r in RELICS[20:]})

# --- GAME_SPEC §6.6 ------------------------------------------------------------------------
CONSUMABLES = (
    [f"TOME_{e}" for e in ELEMENTS]
    + [f"SIGIL_{e}" for e in ELEMENTS]
    + ["INK_WILD", "INK_SHARP", "INK_SWARM", "INK_HEX", "INK_GOLD", "SPARE_DIE"]
)

# --- GAME_SPEC §6.7 ------------------------------------------------------------------------
EQUIPMENT = [
    "BONE_POUCH", "BONE_SATCHEL", "GRAVE_BELL", "LOADED_CUP", "SECOND_CUP", "RELIQUARY",
    "POCKET_CRYPT", "HAGGLER_LANTERN",
]

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
MODIFIERS = {"sharp": "R1", "swarm": "L2", "hex": "N5", "gold": "G1"}
STAT_ICONS = {
    "coin": "G1", "power": "I1", "count": "R1", "reroll": "M1", "summon": "F2",
    "hp": "R1", "lock": "M1", "info": "I1", "book": "B1",
}
UI_FILES = [
    # (name, w, h, nine-slice margin or None)
    ("btn_primary_normal", 24, 24, 6), ("btn_primary_pressed", 24, 24, 6),
    ("btn_primary_disabled", 24, 24, 6),
    ("btn_secondary_normal", 24, 24, 6), ("btn_secondary_pressed", 24, 24, 6),
    ("btn_secondary_disabled", 24, 24, 6),
    ("panel_dark", 24, 24, 6), ("panel_card", 24, 24, 6), ("panel_tooltip", 16, 16, 4),
    ("chip", 16, 12, 4), ("slot", 20, 20, None), ("slot_selected", 20, 20, None),
    ("hp_frame", 16, 7, 3), ("hp_fill", 1, 5, None), ("hp_preview", 1, 5, None),
    ("power_box", 16, 14, 4), ("count_box", 16, 14, 4),
    ("rarity_stripe_common", 4, 4, None), ("rarity_stripe_uncommon", 4, 4, None),
    ("rarity_stripe_rare", 4, 4, None),
    ("stamp_defeated", 64, 20, None), ("divider", 8, 1, None),
]
assert len(UI_FILES) == 22
# Drawn at the largest canvas (ART_SPEC §2, 640x300) and centred; the 480x270 centre is the
# safe area every screen size shows.
BACKGROUNDS = [("bg_title", 640, 300), ("bg_map", 640, 300), ("bg_battle", 640, 300),
               ("bg_shop", 640, 300)]
VFX = [  # (name, sheet w, h, frame_w)
    ("spark", 4, 4, 4), ("puff", 32, 8, 8), ("slash", 48, 16, 16), ("coin", 24, 6, 6),
    ("soul", 12, 6, 6), ("impact_ring", 48, 16, 16), ("aura", 160, 40, 40),
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
        if name == "units" and r.get("recipe") and list(r["recipe"]) != UNITS[r["id"]]:
            raise AssertionError(f"data/units.json {r['id']} recipe {r['recipe']} != {UNITS[r['id']]}")
        if name == "relics" and r.get("rarity") and r["rarity"] != RELIC_RARITY[r["id"]]:
            raise AssertionError(f"data/relics.json {r['id']} rarity {r['rarity']} != {RELIC_RARITY[r['id']]}")
    return ids, f"data/{name}.json"


def load_ids() -> dict[str, tuple[list[str], str]]:
    """Return {kind: (ids, source)} for units/relics/consumables/equipment/enemies."""
    return {
        "units": _checked("units", list(UNITS)),
        "relics": _checked("relics", RELICS),
        "consumables": _checked("consumables", CONSUMABLES),
        "equipment": _checked("equipment", EQUIPMENT),
        "enemies": _checked("enemies", list(ENEMIES)),
    }

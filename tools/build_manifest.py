"""Build assets/manifest.json — one entry per art file in ART_SPEC §11.

    python tools/build_manifest.py

Entry fields: id, path (relative to project root), w, h, frame_w, frames, category,
flags (subset of: mask, floating, tint), tag (2-3 letter placeholder label),
ramp / accent (colour hints: element name or Hallow32/mask key), margin (9-slice margin, UI only).
"""

from __future__ import annotations

import json
import sys

import art_ids as ids
from art_ids import ROOT

MANIFEST = ROOT / "assets" / "manifest.json"

SKIP_WORDS = {"OF", "THE", "O", "MOB", "CHAMP", "BOSS"}


def _tag_candidates(name: str) -> list[str]:
    words = [w for w in name.upper().split("_") if w and w not in SKIP_WORDS] or [name.upper()]
    cands: list[str] = []
    if len(words) >= 2:
        cands.append("".join(w[0] for w in words)[:3])
        cands.append((words[0][:2] + words[1][0]))
        cands.append((words[0][0] + words[1][:2]))
        cands.append((words[0][0] + words[-1][:2]))
    else:
        w = words[0]
        cands.append(w[:3] if len(w) >= 3 else w)
        cands.append(w[0] + w[-2:])
        cands += [w[0] + w[i] + w[-1] for i in range(1, len(w) - 1)]
    out = []
    for c in cands:
        c = "".join(ch for ch in c if ch.isalnum())[:3]
        if len(c) < 2:
            c = (c + name.upper().replace("_", ""))[:2]
        if c not in out:
            out.append(c)
    return out


class Tagger:
    """Assigns tags unique within a category."""

    # Max tag length per category: a 16x16 unit body has a 10 px interior (3x5 font: 2 letters).
    MAX_LEN = {"unit": 2}

    def __init__(self) -> None:
        self.used: dict[str, set[str]] = {}

    def __call__(self, category: str, name: str) -> str:
        used = self.used.setdefault(category, set())
        n = self.MAX_LEN.get(category, 3)
        flat = [w[0] for w in name.upper().split("_") if w]
        for c in [c[:n] for c in _tag_candidates(name)] + [flat[0] + ch for ch in name.upper()[1:] if ch.isalpha()]:
            if c not in used:
                used.add(c)
                return c
        for i in range(10):
            c = name.upper()[:2] + str(i)
            if c not in used:
                used.add(c)
                return c
        raise RuntimeError(f"cannot tag {name}")


def build() -> tuple[list[dict], dict[str, str]]:
    sources = {k: src for k, (_, src) in ids.load_ids().items()}
    tag = Tagger()
    entries: list[dict] = []

    def add(path: str, w: int, h: int, category: str, *, frame_w: int | None = None,
            name: str | None = None, flags: list[str] | None = None, ramp: str | None = None,
            accent: str | None = None, tag_text: str | None = None, margin: int | None = None) -> None:
        fid = path.rsplit("/", 1)[-1].removesuffix(".png")
        fw = frame_w or w
        e = {
            "id": fid, "path": path, "w": w, "h": h, "frame_w": fw, "frames": w // fw,
            "category": category, "flags": sorted(flags or []),
            "tag": tag_text or tag(category, name or fid), "ramp": ramp, "accent": accent,
        }
        if margin is not None:
            e["margin"] = margin
        entries.append(e)

    S = "assets/sprites"
    # Units (19) — WISP -> wisp_mask
    for uid in ids.UNITS:
        fname = ids.MASK_UNITS.get(uid, uid.lower())
        flags = []
        if uid in ids.MASK_UNITS:
            flags.append("mask")
        if uid in ids.FLOATING_UNITS:
            flags.append("floating")
        r, a = ids.UNIT_ART[uid]
        add(f"{S}/units/{fname}.png", 32, 16, "unit", frame_w=16, name=uid, flags=flags, ramp=r, accent=a)
    add(f"{S}/units/legion_banner.png", 16, 16, "legion", ramp="N3", accent="N5", tag_text="LG")
    # Crowd minis (7)
    for el in ids.MINIS:
        add(f"{S}/minis/mini_{el}.png", 16, 8, "mini", frame_w=8, ramp=el.upper(),
            tag_text=el[0].upper() + el[1].upper())
    add(f"{S}/minis/mini_wisp_mask.png", 16, 8, "mini", frame_w=8, flags=["mask"], ramp="MASK", tag_text="WI")
    # Enemies (9) + shopkeeper
    for eid, (r, a) in ids.ENEMIES.items():
        add(f"{S}/enemies/{eid.lower()}.png", 96, 32, "enemy", frame_w=32, name=eid, ramp=r, accent=a)
    sk, (r, a) = ids.SHOPKEEPER
    add(f"{S}/enemies/{sk.lower()}.png", 64, 32, "shopkeeper", frame_w=32, name="UNDERTAKER", ramp=r, accent=a)
    # Dice
    D = f"{S}/dice"
    add(f"{D}/die_body.png", 20, 20, "dice", ramp="BONE", tag_text="DI")
    add(f"{D}/die_roll.png", 80, 20, "dice", frame_w=20, ramp="BONE", tag_text="RL")
    for el in ids.ELEMENTS + ["WILD"]:
        r = "WILD" if el == "WILD" else el
        add(f"{D}/glyph_{el.lower()}.png", 12, 12, "glyph", ramp=r, tag_text=el[:2])
    for el in ids.ELEMENTS + ["WILD"]:
        r = "WILD" if el == "WILD" else el
        add(f"{D}/glyph8_{el.lower()}.png", 8, 8, "glyph8", ramp=r, tag_text=el[:2])
    for el in ids.ELEMENTS:
        add(f"{D}/pip_{el.lower()}.png", 6, 6, "pip", ramp=el, tag_text=el[:2])
    for mod, col in ids.MODIFIERS.items():
        add(f"{D}/mod_{mod}.png", 5, 5, "mod", ramp=col, tag_text=mod[:2].upper())
    add(f"{D}/die_select.png", 22, 22, "dice_overlay", ramp="G1", tag_text="SE")
    add(f"{D}/die_bound.png", 22, 22, "dice_overlay", flags=["tint"], ramp="WHITE", tag_text="BN")
    add(f"{D}/die_shackle.png", 20, 20, "dice_overlay", ramp="METAL", accent="N0", tag_text="SH")
    add(f"{D}/face_tile.png", 16, 16, "dice_overlay", ramp="BONE", tag_text="FT")
    # Icons
    for rid in ids.RELICS:
        add(f"assets/icons/relics/{rid.lower()}.png", 16, 16, "relic_icon", name=rid,
            ramp="N4", accent=ids.RELIC_RARITY[rid])
    add("assets/icons/bases/tome_base.png", 16, 16, "consumable_base", ramp="N3", tag_text="TB")
    add("assets/icons/bases/sigil_base.png", 16, 16, "consumable_base", ramp="N4", tag_text="SG")
    for cid in ids.CONSUMABLES:
        kind, _, rest = cid.partition("_")
        accent = rest if rest in ids.ELEMENTS else None
        ramp = {"TOME": "N3", "SIGIL": "N4"}.get(kind, "N4")
        add(f"assets/icons/consumables/{cid.lower()}.png", 16, 16, "consumable_icon", name=cid,
            ramp=ramp, accent=accent)
    for qid in ids.EQUIPMENT:
        add(f"assets/icons/equipment/{qid.lower()}.png", 16, 16, "equipment_icon", name=qid, ramp="N4")
    for st, col in ids.STAT_ICONS.items():
        add(f"assets/icons/stats/{st}.png", 8, 8, "stat_icon", ramp=col, tag_text=st[:2].upper())
    # UI (22) + logo + howto
    for name, w, h, margin in ids.UI_FILES:
        add(f"assets/ui/{name}.png", w, h, "ui", name=name, margin=margin)
    add("assets/ui/logo.png", 160, 48, "logo", ramp="F1", tag_text="RR")
    for i in range(1, 5):
        add(f"assets/ui/howto_{i}.png", 200, 120, "howto", ramp="N1", tag_text=f"H{i}")
    # Backgrounds
    for name, w, h in ids.BACKGROUNDS:
        add(f"assets/bg/{name}.png", w, h, "bg", name=name, ramp="N1", accent="N2")
    # VFX
    for name, w, h, fw in ids.VFX:
        flags = ["tint"] if name == "spark" else []
        add(f"assets/vfx/{name}.png", w, h, "vfx", frame_w=fw, name=name, flags=flags)
    # App icon
    add("assets/icon/app_icon_32.png", 32, 32, "app_icon", ramp="BONE", tag_text="RR")

    paths = [e["path"] for e in entries]
    assert len(paths) == len(set(paths)), "duplicate manifest paths"
    for e in entries:
        assert e["w"] % e["frame_w"] == 0, e["path"]
        assert e["path"] == e["path"].lower(), e["path"]
    return entries, sources


def main() -> int:
    try:
        entries, sources = build()
    except AssertionError as exc:
        print(f"MANIFEST ERROR: {exc}")
        return 1
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    doc = {"generated_by": "tools/build_manifest.py", "spec": "ART_SPEC §11", "count": len(entries),
           "files": entries}
    MANIFEST.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8", newline="\n")
    counts: dict[str, int] = {}
    for e in entries:
        counts[e["category"]] = counts.get(e["category"], 0) + 1
    print(f"wrote {MANIFEST.relative_to(ROOT).as_posix()}: {len(entries)} files")
    print("  " + ", ".join(f"{k} {v}" for k, v in counts.items()))
    print("  id sources: " + ", ".join(f"{k}={v}" for k, v in sources.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())

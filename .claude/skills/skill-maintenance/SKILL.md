---
name: skill-maintenance
description: How to create, edit, split, rename or delete an agent skill in this repo, and decide whether new knowledge belongs in a skill or in project docs. Use when adding or changing anything under .claude/skills, when a task taught a reusable trap or pattern worth recording, when no skill matched a recurring task type, or when a skill turned out to be wrong or out of date.
---

# Skill Maintenance

Skills are the agent's reusable know-how. They are only useful if they are **selected
reliably** (good descriptions, a current index) and **trusted** (never stale, never
project-specific). This skill is the procedure for keeping both true.

## Skill or doc? Decide first

| The knowledge is… | It goes in |
| --- | --- |
| True for any Godot game of this kind (a pattern, an engine trap, a workflow) | a **skill** |
| True only for this project (a path, a number, a decision, a unit size, a class name) | `docs/` — the skill says *"the project doc names X"* |
| A one-off fact about the current task | nowhere (the commit message / conversation) |
| History ("we used to…", "in build N…") | git history; a skill states the current rule |

Test: *copy the skill into another Godot project of the same genre — is every sentence still
true?* If not, move the project-specific part to `docs/`.

## When to create a new skill

Create one when at least one holds, **and** no existing skill is the natural owner:

- the same kind of task has come up twice and needed the same non-obvious steps;
- a trap cost real time (roughly 30+ minutes) and will be hit again;
- a rule must be followed every time a certain file type or system is touched.

Prefer extending an existing skill (a new section or a new `references/` file) over a new
skill. Split a skill when its `SKILL.md` passes the line limit or it answers two unrelated
*Use when* questions.

## Anatomy

```
.claude/skills/<kebab-name>/
  SKILL.md            required — front matter + the rules and routing (≤ 300 lines)
  references/*.md     optional — detail loaded only when SKILL.md routes to it
  scripts/            optional — helpers the skill tells the agent to run
```

`SKILL.md` front matter — exactly these two keys:

```yaml
---
name: <kebab-name, equal to the folder name>
description: <What it covers, one sentence>. Use when <concrete triggers: files, systems, task kinds, symptoms>.
---
```

The **description is the selector**. It is what the agent sees before deciding to load the
skill, and the text after `Use when` becomes the index row. Write triggers an agent can match
against a task: file types (`.tscn`, `.cs`), systems (save, formation, pathfinding),
activities (debugging, profiling, adding art), and symptoms (blurry sprites, stale class
cache). Max 1024 characters.

Body shape that works (see [the template](references/skill-template.md)):
1. One paragraph: what problem this skill owns.
2. **Rules** — short, imperative, each with its *why* when not obvious.
3. **Procedure / checklist** for the common task.
4. **Routing** — "for X read `references/x.md`".
5. **Traps** already hit, as a table: trap · symptom · fix.

## Procedures

**Create:** decide skill-vs-doc → copy the template → write the description last, after the
body is clear → `python tools/skills_index.py --write` → mention the new skill in the reply.

**Edit:** change the rule where it lives; delete the old statement rather than adding "update:"
notes. If the description changes, regenerate the index.

**Rename / split / merge:** move the folder, fix `name`, fix every link to it
(`grep -r "<old-name>" .claude AGENTS.md docs`), regenerate the index.

**Delete:** only when the knowledge is obsolete or fully absorbed elsewhere; say where it went.
Regenerate the index.

**Always finish with** `python tools/skills_index.py` — it must print `Skills OK`.

## Quality bar

- Imperative and specific: "Run `--import` once per session", not "consider re-importing".
- Every rule answers *why* in a clause, or it will be "optimised" away.
- No invented facts: engine behaviour you have not verified is marked *(unverified)* or left out.
  Numbers (budgets, sizes) are either measured or labelled as a starting guess.
- No file paths of a specific project, except as a clearly marked example.
- Keep `SKILL.md` a router, not an encyclopedia; push tables and long lists to `references/`.

# Skill template

Copy into `.claude/skills/<name>/SKILL.md` and replace every `<…>`.

```markdown
---
name: <kebab-name>
description: <What this skill covers in one sentence>. Use when <files / systems / activities / symptoms that should trigger it>.
---

# <Title>

<One paragraph: the problem this skill owns, and what it deliberately does not cover
(name the skill that does).>

## Rules

1. **<Rule>.** <Why, in one clause.>
2. …

## Procedure

1. <Step>
2. …

## Routing

- <Sub-task> → [references/<file>.md](references/<file>.md)

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| <name> | <what you see> | <what to do> |
```

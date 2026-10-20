# Debt register and ratchet

How a project keeps architecture rules as a gate rather than a hope.

## The register — `docs/architecture_audit.md`

A **register, not a refactor plan**. Snapshot date and branch at the top, then one entry per
known smell in this project:

```markdown
### <ID> · <High|Medium|Low> · <Smell name>  [<scanner section>]
<Where it is (files, functions), what it does wrong, which bug it produced or will produce.>
**Replace with:** <pattern> — <now | when touched>.
```

- Severity is bug risk: **High** = already produced a bug or silently wrong; **Medium** =
  makes the next bug likely or hard to find; **Low** = friction.
- Closing an item: mark it `— closed <date>` with one paragraph of what the code now does
  and which test holds it. Keep closed items until the next snapshot, then drop them.
- A *"What is already right — keep doing it"* section is worth as much as the smells.
- Only High items that are live bug sources get scheduled; the rest are *fix when touched*.

## The ratchet — `tools/arch_check.py` (build it when the codebase has ~20+ scripts)

1. A scanner measures each rule per file: file logic lines, function logic lines, branches
   per function, repeated identical guards, UI built/placed/coloured in code, animations
   outside presentation states, comments narrating history.
2. `--all` prints the whole-repo table (rule · violations · where mostly).
3. Pre-commit mode compares each staged file's counts with the same file at `HEAD`:
   - **new file** → must pass every rule outright;
   - **count went up** → block the commit;
   - **count unchanged** → warn only (existing debt);
   - **count went down** → pass, and say so.
4. Install as a git hook in the repo (`.githooks/pre-commit`, activated with
   `git config core.hooksPath .githooks` — ask the user before changing git config).
5. Re-run `--all` whenever a register item closes and update the baseline table in the register.

Never bypass the hook to land a change; fix the count or ask the user.

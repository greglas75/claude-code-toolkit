# Skill Management Rules (Always Active)

When creating or modifying skills (slash commands), follow this structure.

## Directory Layout

```
~/.claude/skills/{name}/SKILL.md    ← source of truth (edit HERE)
~/.claude/commands/{name}.md        ← symlink → skills/{name}/SKILL.md
~/.gemini/antigravity/skills/{name} ← symlink → ~/.claude/skills/{name}
```

One file, three systems: Claude Code (skills), Claude Code (commands), Antigravity.

## SKILL.md Format

Every skill MUST have YAML frontmatter:

```yaml
---
name: skill-name
description: "What this skill does and when to use it."
disable-model-invocation: true
---

# /skill-name — Short Title

[markdown content with $ARGUMENTS placeholder]
```

- `disable-model-invocation: true` for user-invoked workflows (/review, /refactor, /backlog)
- Omit it for background knowledge skills the agent should auto-load

## Creating a New Skill

1. Create directory + SKILL.md:
   ```bash
   mkdir -p ~/.claude/skills/{name}
   # Write SKILL.md with frontmatter + content
   ```

2. Create symlinks:
   ```bash
   # Claude Code commands (backward compat)
   ln -s ~/.claude/skills/{name}/SKILL.md ~/.claude/commands/{name}.md

   # Antigravity
   ln -sfn ~/.claude/skills/{name} ~/.gemini/antigravity/skills/{name}
   ```

3. Verify:
   ```bash
   ls -la ~/.claude/commands/{name}.md
   ls -la ~/.gemini/antigravity/skills/{name}
   ```

## Updating an Existing Skill

Just edit `~/.claude/skills/{name}/SKILL.md`. Symlinks propagate automatically.

## Deleting a Skill

```bash
rm ~/.claude/commands/{name}.md
rm ~/.gemini/antigravity/skills/{name}
rm -rf ~/.claude/skills/{name}
```

## Supporting Files

Skills can include additional files (scripts, templates, references):

```
~/.claude/skills/{name}/
├── SKILL.md           # Main instructions (required)
├── templates/         # Templates for the skill
├── examples/          # Example outputs
└── scripts/           # Helper scripts
```

Reference them from SKILL.md so the agent knows what they contain.

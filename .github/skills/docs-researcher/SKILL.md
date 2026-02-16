---
name: docs-researcher
description: Use Playwright MCP to crawl Godot 4.6 and GitHub Copilot official documentation when the agent lacks 2026-specific context about APIs, features, or configuration.
---

# Docs Researcher Skill

Use this skill whenever you encounter an unknown or uncertain Godot 4.6 API, node, method, shader built-in, or GitHub Copilot feature (skills, hooks, agents, instructions). Do NOT guess — verify against live documentation first.

## When to Activate

- A Godot 4.6 class, method, or property is mentioned that you are not confident about
- A GDScript language feature may have changed in 4.6
- A Copilot configuration feature (skills, hooks, agents, instructions) needs verification
- You are writing code that depends on exact API signatures or parameter types
- You need to check if a feature is deprecated or replaced in 4.6

## Research Process

### For Godot 4.6 Questions

1. Use `playwright/browser_navigate` to go to `https://docs.godotengine.org/en/stable/`
2. Use the search functionality or navigate directly to the class reference at `https://docs.godotengine.org/en/stable/classes/class_<classname>.html` (lowercase)
3. Find the exact method signature, property type, or enum values
4. Check "New in version" or "Changed in version" notes
5. Extract the relevant information and cite the source URL

**Common search targets:**

- Class reference: `https://docs.godotengine.org/en/stable/classes/`
- GDScript reference: `https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html`
- Shader reference: `https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/`
- 2D tutorials: `https://docs.godotengine.org/en/stable/tutorials/2d/`
- Migration guide: `https://docs.godotengine.org/en/stable/tutorials/migrating/`

### For GitHub Copilot Questions

1. Use `playwright/browser_navigate` to go to `https://docs.github.com/en/copilot/`
2. Navigate to the relevant section:
   - Custom instructions: `https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions`
   - Custom agents: `https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-custom-agents`
   - Agent skills: `https://docs.github.com/en/copilot/concepts/agents/about-agent-skills`
   - Hooks: `https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/use-hooks`
   - Hooks reference: `https://docs.github.com/en/copilot/reference/hooks-configuration`
   - Agents reference: `https://docs.github.com/en/copilot/reference/custom-agents-configuration`
3. Extract the current configuration format, supported properties, or behavior
4. Cite the source URL

## Output Format

After researching, report:

- **Source**: The URL where the information was found
- **Finding**: The exact API signature, configuration format, or feature behavior
- **Relevance to Voidrift**: How this applies to the current task

## Important

- Always prefer official documentation over community forums, Stack Overflow, or blog posts
- Godot and Copilot features evolve rapidly — do not rely solely on training data
- If documentation is ambiguous or contradictory, note the ambiguity and present both interpretations

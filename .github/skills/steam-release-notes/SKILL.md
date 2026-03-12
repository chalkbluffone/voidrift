---
name: steam-release-notes
description: Step-by-step procedure for generating player-facing release notes, updating release state, and posting Discord deploy notifications during a Super Cool Space Game Steam deploy.
---

# Steam Release Notes Skill

Use this skill when asked to: generate or update release notes, configure Discord deploy notifications, bump the release version, review what changed since the last deploy, or troubleshoot the release notes pipeline.

## When to Activate

- Setting up or configuring Discord deploy notifications
- Bumping version for a named release before deploying
- Reviewing player-facing changes since the last deploy
- Troubleshooting missing notes, empty Discord posts, or webhook errors
- Running `push_release_notes.ps1` manually after a deploy

## Key Files

| File                           | Purpose                                                               |
| ------------------------------ | --------------------------------------------------------------------- |
| `.env`                         | Discord webhook URL secret — never committed, gitignored              |
| `tools/release_state.json`     | Version, summary, last-deployed commit SHA — edit before each release |
| `build/release_notes.md`       | Agent-written player-facing notes — read by the push script           |
| `tools/push_release_notes.ps1` | Reads `build/release_notes.md` and posts to Discord                   |
| `tools/deploy.ps1`             | Steam upload only — no notes logic                                    |

## Full Deploy + Notes Workflow

This is handled automatically by the **release-ops** agent when you say "build and deploy":

```
1. tools/build.ps1              → build all platforms
2. tools/deploy.ps1             → upload to Steam
3. Agent writes build/release_notes.md with polished player-facing notes
4. tools/push_release_notes.ps1 → reads notes file + posts to Discord  (success only)
```

The agent reviews git commits since the last deploy, writes player-relevant notes to `build/release_notes.md`, then the script posts that file's content to Discord.

To run just the notes step manually after a deploy:

```powershell
# Preview without posting:
& "C:\git\voidrift\tools\push_release_notes.ps1" -DryRun

# Post to Discord:
& "C:\git\voidrift\tools\push_release_notes.ps1"

# Use a different notes file:
& "C:\git\voidrift\tools\push_release_notes.ps1" -NotesFile "build\release_notes_v0.2.0.md"
```

## Step 1 — Configure Discord Webhook (First-Time Setup)

1. In your Discord server: right-click target channel → **Edit Channel**
2. **Integrations** → **Webhooks** → **New Webhook**
3. Name it, set an optional avatar, click **Copy Webhook URL**
4. Open `.env` at the project root and set:
   ```
   DISCORD_DEPLOY_WEBHOOK=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN
   ```
5. **Never commit `.env`** — it is gitignored and contains a credential

## Step 2 — Bump Version (Before a Named Release)

Edit `tools/release_state.json` — only `version` and `summary`:

```json
{
  "version": "0.2.0",
  "summary": "Enemy overhaul and weapon balance pass",
  "last_deployed_commit": "abc1234...",
  "last_build_id": "22270000",
  "last_deploy_time": "2026-03-12 18:51"
}
```

Leave the `last_*` fields alone — they are auto-updated after each successful notes post.

## Step 3 — Preview Pending Commits

Preview which commits will appear in the next post:

```powershell
$sha = (Get-Content tools/release_state.json | ConvertFrom-Json).last_deployed_commit
if ($sha) { git log "${sha}..HEAD" --oneline } else { git log -30 --oneline }
```

## Step 4 — Write Release Notes

The release-ops agent writes `build/release_notes.md` with polished, player-facing content. The file should:

- Start with a `# Title` line (the script strips this and uses it as the embed title)
- Use Discord markdown: `**bold**`, emoji shortcodes (`:new:`, `:scales:`, `:bug:`, `:sparkles:`, `:zap:`)
- Organize into sections: New Features, Balance Changes, Bug Fixes, Quality of Life, Performance & Stability
- Skip internal/repo-maintenance commits (instruction files, TODO updates, tooling changes)
- Keep bullet points concise and player-relevant

## Step 5 — Run Push Script

```powershell
# Preview:
& "C:\git\voidrift\tools\push_release_notes.ps1" -DryRun

# Post to Discord:
& "C:\git\voidrift\tools\push_release_notes.ps1"
```

The script will:

1. Load webhook URL from `.env`
2. Load version/summary from `tools/release_state.json`
3. Read `build/release_notes.md` content
4. Wrap in a Discord embed and post to the configured channel
5. Update `tools/release_state.json` with the current HEAD SHA

## Step 6 — Post Steam Community Patch Notes (Manual)

SteamCMD cannot publish Community Hub announcements automatically:

1. Open `build/release_notes.md`
2. Go to the game's Steam Community Hub → **Post Announcement**
3. Paste the content and publish

## Output Format

**Console output:**

```
=== Release Notes — v0.2.0 ===
Reading from: C:\git\voidrift\build\release_notes.md

(file contents printed)

=== Posting to Discord ===
Posted successfully (HTTP 204)

State updated. Next run will cover commits since: def5678
```

**Discord embed:** Title from version, file content as description, summary field, purple accent.

## Troubleshooting

| Symptom                       | Cause                                       | Fix                                                                         |
| ----------------------------- | ------------------------------------------- | --------------------------------------------------------------------------- |
| `.env` missing error          | File not found or key not set               | Create `.env` at project root with `DISCORD_DEPLOY_WEBHOOK=`                |
| Discord: failed after 3 tries | Invalid/deleted webhook URL                 | Regenerate webhook in Discord channel settings, update `.env`               |
| Notes file not found          | Agent didn't write `build/release_notes.md` | Write the file before running the script                                    |
| Notes file too short          | File exists but has minimal content         | Rewrite with more complete player-facing notes                              |
| State JSON not updating       | Script exited before save step              | Fix the error, then re-run — state saves only after successful Discord post |

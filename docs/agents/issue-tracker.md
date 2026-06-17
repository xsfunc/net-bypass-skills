# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

## Repo inference

`gh` infers the repo from `git remote -v` when run inside a clone. The remote uses an SSH alias (`xsunfc:xsfunc/net-bypass-skills.git`); if `gh` doesn't resolve the alias to `owner/repo`, pass `-R xsfunc/net-bypass-skills` explicitly on each command.

## Scope note

These commands run on your local dev machine (the `gh` CLI), not on the router. The router-side `jq` ban in `AGENTS.md` §2/§11 does not apply here — `gh`'s `--jq` flag is local tooling.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

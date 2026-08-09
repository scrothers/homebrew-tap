# scrothers/homebrew-tap

A personal Homebrew tap. Steven is the only contributor; it is not open to outside
contributions. Formulae are hand-maintained and bottled to GHCR by CI.

> **Adding or updating a formula? Read [AGENTS.md](AGENTS.md) first.** It is the full
> walkthrough: scaffold, build recipe per upstream build system, dependencies, livecheck,
> test block, local verification, PR, bottling and publishing. This file covers only what
> that document does not — repository-level facts and infrastructure conventions.

## Layout

```
Formula/            formulae live here, one .rb per package
scripts/            gen-readme.rb (README table), new-formula.rb (scaffolder)
.github/workflows/  tests.yml, publish.yml, autobump.yml, autopublish.yml
Makefile            the local interface — always prefer a make target over raw brew
AGENTS.md           how to prepare a build; the formula-authoring guide
```

## Local environment

`brew` is installed natively at `/home/linuxbrew/.linuxbrew` and is not on `PATH` by
default. A fresh install falls back to system Ruby and dies with
`cannot load such file -- bundler`; `brew vendor-install ruby` fixes it once.

Run `make tap` once per checkout. It symlinks this working tree into
`$(brew --repository)/Library/Taps/` so `brew` operates on the files being edited rather
than a separate clone, and refuses to touch that path if it is a real directory.

`make all` is the pre-push gate. `make help` lists every target.

## Working on the tooling itself

These apply when editing `scripts/`, the `Makefile` or the workflows — not when writing a
formula.

- **`brew style` lints more than Ruby.** It runs actionlint and shellcheck over
  `.github/workflows/` too, so `make style` and `make syntax` already cover the workflows.
  `make lint` is only zizmor, which Homebrew does not run. A tap-level
  `.github/actionlint.yaml` would be honoured if one is ever needed.
- **A tap-level `.rubocop.yml` is ignored.** `brew style` passes `--config` pointing at
  Homebrew's own, which overrides RuboCop's directory discovery. Make the source comply, or
  use an inline `rubocop:disable` with the clarifying comment on the **preceding** line —
  `Cop/DisableComment` requires it there, not trailing.
- **Ruby in `scripts/` must be module-namespaced.** On macOS the tap is analysed with
  Homebrew's own Library in RuboCop's scope, so top-level constants and `Object`-level
  methods trip `Lint/ConstantReassignment` and `Lint/DuplicateMethods` against brew's
  source. The Linux leg does not reproduce this, so local green is not proof.
- **zizmor audits the whole repo**, including `.github/dependabot.yml`, not just
  `workflows/`. `make lint` points at `.` to match CI.

## CI chain

`autobump.yml` (cron, PAT) opens a bump PR → `tests.yml` builds bottles → `autopublish.yml`
sees the green run and dispatches `publish.yml` → `brew pr-pull` pushes bottles to
`ghcr.io/v2/scrothers/tap`, commits the `bottle do` block, fast-forwards `main`.

Two consequences worth remembering:

- The bump PR must be opened with the **PAT** (`secrets.HOMEBREW_BUMP_TOKEN`), not
  `GITHUB_TOKEN`. GitHub does not trigger workflows from `GITHUB_TOKEN` events, so a
  default-token PR would never get CI and never get bottles. `autopublish.yml` may use
  `GITHUB_TOKEN` because `workflow_dispatch` is a documented exception to that rule.
- `main` must **not** require pull requests. `brew pr-pull` fast-forwards `main` directly
  via `git-try-push`; a PR requirement deadlocks publishing. The ruleset blocks force
  pushes and deletions only.

In CI the tap name comes from the `setup-homebrew` step's `tap-name` output
(`scrothers/tap`), which is not `$GITHUB_REPOSITORY` (`scrothers/homebrew-tap`). See the
orientation table in [AGENTS.md](AGENTS.md).

## Action pinning

`actions/*` and the lint actions are SHA-pinned with a version comment, and Dependabot
keeps them fresh on a 7-day cooldown. `Homebrew/actions/*` are also SHA-pinned — matching
upstream's own templates — but Dependabot does not track them, so refresh manually:

```bash
gh api repos/Homebrew/actions/releases/latest --jq .tag_name
```

Never reference `Homebrew/actions/...@master`; every action runs a deprecation shim on it.

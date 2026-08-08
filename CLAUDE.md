# scrothers/homebrew-tap

A personal Homebrew tap. Steven is the only contributor; it is not open to outside
contributions. Formulae are hand-maintained and bottled to GHCR by CI.

## Layout

```
Formula/            formulae live here, one .rb per package
scripts/            gen-readme.rb (README table), new-formula.rb (scaffolder)
.github/workflows/  tests.yml, publish.yml, autobump.yml, autopublish.yml
Makefile            the local interface — always prefer a make target over raw brew
```

## Naming, and the two tap names

Homebrew strips the `homebrew-` prefix, so this one repo has two names and they are not
interchangeable:

| Form | Value | Used by |
| --- | --- | --- |
| Tap name | `scrothers/tap` | `brew bump --tap=`, `brew audit --tap=`, `brew style`, `brew install` |
| Repo name | `scrothers/homebrew-tap` | `brew pr-pull --tap=`, `$GITHUB_REPOSITORY` |

Getting these backwards is the single easiest mistake to make in this repo. In CI, the
tap name comes from the `setup-homebrew` step's `tap-name` output.

## Local workflow

`brew` is installed natively at `/home/linuxbrew/.linuxbrew`. Run `make tap` once per
checkout — it symlinks this working tree into `$(brew --repository)/Library/Taps/` so
`brew` operates on the files you are editing rather than a separate clone.

```bash
make tap                              # one-time wiring
make new-formula NAME=foo REPO=o/r    # scaffold
make style fix                        # rubocop via brew
make audit                            # --strict --online
make test F=foo                       # brew test
make readme                           # regenerate the README table
make all                              # everything CI runs, locally
```

`make all` is the pre-push gate. If it is green, CI's syntax and lint jobs will be green.

Worth knowing: `brew style` runs **actionlint and shellcheck over `.github/workflows/`**
as well as RuboCop over Ruby, so `make style` / `make syntax` already lint the workflows.
`make lint` is only zizmor, which Homebrew does not run. A tap-level
`.github/actionlint.yaml` would be picked up automatically if one is ever needed.

`brew style` ignores a tap-level `.rubocop.yml` — it passes `--config` pointing at
Homebrew's own, which overrides RuboCop's directory discovery. Do not add one expecting
it to work; make the source comply instead, or use an inline `rubocop:disable` with a
clarifying comment on the **preceding** line (Homebrew's `Cop/DisableComment` requires
it there, not trailing).

## House rules for formulae

1. **Every formula must have a `livecheck` block.** Without one it is invisible to
   `brew bump` and the autobump workflow silently skips it forever. `brew audit` does
   *not* catch this. If a formula genuinely should not auto-bump, say so explicitly with
   `livecheck do skip "reason" end`. `no_autobump!` is **not** available — it raises
   outside official Homebrew taps.
2. **Every formula must have a meaningful `test do`.** Not `assert_predicate bin/"x", :exist?`.
   Run the thing and assert on its output.
3. `desc` — no leading article, no trailing period, sentence case. `brew audit --strict`
   enforces this but the scaffolder gets it right up front.
4. `license` is always set, using an SPDX identifier.
5. Prefer a `head` spec where upstream has a sensible default branch.

## CI chain

`autobump.yml` (cron, PAT) opens a bump PR → `tests.yml` builds bottles → `autopublish.yml`
sees the green run and dispatches `publish.yml` → `brew pr-pull` pushes bottles to
`ghcr.io/v2/scrothers/tap`, commits the `bottle do` block, fast-forwards `main`.

Two consequences worth remembering:

- The bump PR must be opened with the **PAT** (`secrets.HOMEBREW_BUMP_TOKEN`), not
  `GITHUB_TOKEN`. GitHub does not trigger workflows from `GITHUB_TOKEN` events, so a
  default-token PR would never get CI and never get bottles.
- `main` must **not** require pull requests. `brew pr-pull` fast-forwards `main` directly
  via `git-try-push`; a PR requirement deadlocks publishing. The ruleset blocks force
  pushes and deletions only.

## Action pinning

`actions/*` and the lint actions are SHA-pinned with a version comment, and Dependabot
keeps them fresh. `Homebrew/actions/*` are also SHA-pinned — matching upstream's own
templates — but Dependabot does not track them, so refresh manually:

```bash
gh api repos/Homebrew/actions/releases/latest --jq .tag_name
```

Never reference `Homebrew/actions/...@master`; every action runs a deprecation shim on it.

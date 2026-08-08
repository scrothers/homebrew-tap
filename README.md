<div align="center">

# scrothers/tap

**Personal Homebrew formulae.** Built for the tools I ship, the scripts I keep, and the software that is not yet (or never will be) in core.

[![Homebrew](https://img.shields.io/badge/Homebrew-scrothers%2Ftap-FBB040?style=for-the-badge&logo=homebrew&logoColor=black)](https://brew.sh)
[![CI](https://img.shields.io/github/actions/workflow/status/scrothers/homebrew-tap/tests.yml?branch=main&style=for-the-badge&logo=github&label=CI)](https://github.com/scrothers/homebrew-tap/actions/workflows/tests.yml)
[![Autobump](https://img.shields.io/github/actions/workflow/status/scrothers/homebrew-tap/autobump.yml?style=for-the-badge&logo=github&label=autobump)](https://github.com/scrothers/homebrew-tap/actions/workflows/autobump.yml)
[![License](https://img.shields.io/badge/license-BSD--2--Clause-111111?style=for-the-badge)](LICENSE)

```text
brew tap scrothers/tap
```

</div>

---

## Quick start

One-shot install (taps automatically):

```bash
brew install scrothers/tap/<formula>
```

Or tap once, then install by short name:

```bash
brew tap scrothers/tap
brew install <formula>
```

`Brewfile`:

```ruby
tap "scrothers/tap"
brew "<formula>"
```

Bottles are published to [GitHub Packages](https://github.com/scrothers?tab=packages&repo_name=homebrew-tap), so installs are a download rather than a build on `macos-26` and `ubuntu-latest`. Anything else compiles from source.

## Formulae

<!-- FORMULAE:START -->
| Formula | Description | Version | License |
| ------- | ----------- | ------- | ------- |
| _Coming soon_ | Formulae land here as they are added. | — | — |
<!-- FORMULAE:END -->

<sub>This table is generated from `Formula/*.rb` by `make readme`. Do not edit it by hand.</sub>

List everything in the tap:

```bash
brew search scrothers/tap/
```

## About

This is a personal tap, and it is **closed to contributions**. Issues and pull requests
are disabled. That is a scope decision, not a judgement — a tap that accepts formulae
becomes a distribution, and I do not want to run a distribution.

Found a bug in one of these tools? File it against the upstream project. Found a bug in
the *packaging* — wrong checksum, broken test, missing dependency — email me and I will
fix it. See [CONTRIBUTING.md](CONTRIBUTING.md).

Want the same setup for yourself? `brew tap-new <user>/<repo> --github-packages` gets you
most of what is here.

## How it works

Formulae are hand-written, tested on macOS and Linux, bottled by CI, and kept current
automatically.

```
 cron ──▶ autobump.yml ──▶ opens a version-bump PR
                                    │
                                    ▼
                              tests.yml ──▶ builds and uploads bottles
                                    │
                                    ▼
                          autopublish.yml ──▶ dispatches publish.yml on green
                                    │
                                    ▼
                              publish.yml ──▶ bottles to ghcr.io, fast-forwards main
```

| Workflow | Trigger | Purpose |
| -------- | ------- | ------- |
| `tests.yml` | push to `main`, pull request | `brew test-bot` syntax, audit, install and test; builds bottles; lints workflows |
| `publish.yml` | manual dispatch | `brew pr-pull` — uploads bottles to `ghcr.io/v2/scrothers/tap` and merges the PR |
| `autobump.yml` | daily cron | `brew bump` — opens a PR for every formula whose upstream moved |
| `autopublish.yml` | `tests.yml` completing | Dispatches `publish.yml` for green, owner-authored bump PRs |

Every formula carries a [`livecheck`](https://docs.brew.sh/Brew-Livecheck) block. Without
one, `brew bump` cannot see new upstream releases and the formula would quietly stop
being updated.

## Development

Homebrew must be installed. Wire this checkout into it once:

```bash
make tap
```

Then:

```bash
make new-formula NAME=foo REPO=owner/repo   # scaffold a formula from a GitHub repo
make style fix                              # RuboCop, via brew
make audit                                  # brew audit --strict --online
make test F=foo                             # run one formula's test block
make livecheck                              # what does upstream have that we do not?
make readme                                 # regenerate the table above
make lint                                   # zizmor security audit of the workflows
make all                                    # everything CI checks
```

`brew style` already runs actionlint and shellcheck over `.github/workflows/`, so
`make style` covers those; `make lint` adds the part Homebrew does not do.

`make all` is the pre-push gate. `make help` lists every target.

## Documentation

- [Homebrew docs](https://docs.brew.sh)
- [`brew help`](https://docs.brew.sh/Manpage) / `man brew`
- [How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [`brew livecheck`](https://docs.brew.sh/Brew-Livecheck)

## License

[BSD 2-Clause](LICENSE). The packaged software is under its own licence, listed per
formula in the table above.

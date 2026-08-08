<div align="center">

# scrothers/tap

**Personal Homebrew formulae.** Built for the tools I ship, the scripts I keep, and the software that is not yet (or never will be) in core.

[![Homebrew](https://img.shields.io/badge/Homebrew-scrothers%2Ftap-FBB040?style=for-the-badge&logo=homebrew&logoColor=black)](https://brew.sh)
[![CI](https://img.shields.io/github/actions/workflow/status/scrothers/homebrew-tap/tests.yml?branch=main&style=for-the-badge&logo=github&label=CI)](https://github.com/scrothers/homebrew-tap/actions/workflows/tests.yml)
[![Tap](https://img.shields.io/badge/tap-scrothers%2Ftap-111111?style=for-the-badge)](https://github.com/scrothers/homebrew-tap)

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

## Formulae

| Formula | Description |
| ------- | ----------- |
| _Coming soon_ | Formulae land here as they are added. |

List everything in the tap:

```bash
brew search scrothers/tap/
```

## Development

This tap uses Homebrew's standard test-bot and bottle workflow.

| Workflow | Purpose |
| -------- | ------- |
| `tests.yml` | Syntax checks and formula tests on push/PR |
| `publish.yml` | Bottle publish when a PR is labeled `pr-pull` |

Local checks:

```bash
brew test-bot --only-tap-syntax
brew audit --strict --online scrothers/tap/<formula>
brew test scrothers/tap/<formula>
```

## Documentation

- [Homebrew docs](https://docs.brew.sh)
- [`brew help`](https://docs.brew.sh/Manpage) / `man brew`
- [How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)

# Preparing a build for scrothers/tap

Instructions for a coding agent adding or updating a formula in this tap. Read it start
to finish before writing any Ruby — several steps here fail in ways that only surface two
stages later.

This tap is maintained by one person and is closed to outside contributions. You are
working on Steven's behalf; do not add contribution scaffolding, issue templates, or
"how to contribute" prose.

> **About the examples.** Only section 3a shows a complete formula. Everything after it is
> a fragment shown at the left margin — in a real formula those stanzas are indented one
> level inside the `class` body, and `system` calls belong inside `def install`. The
> fragments are written this way because `brew style` lints the Ruby in this file.

---

## 0. Orientation

**One repo, two names, not interchangeable.** Getting these backwards is the most common
mistake in this repo:

| Form | Value | Used by |
| --- | --- | --- |
| Tap name | `scrothers/tap` | `brew bump`, `audit`, `style`, `livecheck`, `install`, `test` |
| Repo name | `scrothers/homebrew-tap` | `brew pr-pull`, `$GITHUB_REPOSITORY` |

**Wire up the checkout once.** Homebrew resolves `scrothers/tap` through its own Taps
directory, not your working copy, so without this you will edit one file and lint another:

```bash
make tap
```

`make help` lists every target. `make all` is the pre-push gate and runs what CI runs.

---

## 1. Scaffold

```bash
make new-formula NAME=lazygit REPO=jesseduffield/lazygit
```

This writes `Formula/lazygit.rb` with `desc`, `homepage`, `url`, `sha256`, `license`,
`head` and a `livecheck` block already filled in from the GitHub API, and leaves the
install block as a `raise`. It deliberately omits an explicit `version` — Homebrew derives
that from the tag URL, and an explicit one would need hand-syncing on every bump.

If upstream is not on GitHub, or has no releases, write the file by hand from the same
shape. The class name must match Homebrew's `Formulary.class_s`: `foo-bar` → `FooBar`,
`foo@1.2` → `FooAT12`, `c++` → `Cxx`.

---

## 2. Identify the build system

Read upstream's repository root before writing anything. Do not guess from the language
badge on the README.

| Upstream has | Build system | Section |
| --- | --- | --- |
| `go.mod` | Go | [3a](#3a-go) |
| `Cargo.toml` | Rust | [3b](#3b-rust) |
| `CMakeLists.txt` | CMake | [3c](#3c-cmake-make-and-autotools) |
| `configure.ac` / `Makefile.am` | Autotools | [3c](#3c-cmake-make-and-autotools) |
| plain `Makefile` | Make | [3c](#3c-cmake-make-and-autotools) |
| `meson.build` | Meson | `std_meson_args` |
| release assets per OS/arch, no practical source build | Prebuilt binary | [3d](#3d-prebuilt-binary) |

Prefer building from source. Reach for a prebuilt binary only when the source build is
genuinely impractical — a huge toolchain, a vendored SDK, or upstream shipping only
binaries.

---

## 3. Write the install block

Homebrew provides `std_*_args` helpers that set install prefixes, strip flags and
reproducibility flags correctly. **Use them instead of hand-writing flags.** All are
defined in `Library/Homebrew/formula.rb`; read the definition if you need the exact
keyword arguments.

### 3a. Go

The one complete example. Note the stanza order — `brew style --fix` will reorder it for
you if you get it wrong, and `livecheck` goes above `depends_on`.

```ruby
class Lazygit < Formula
  desc "Simple terminal UI for git commands"
  homepage "https://github.com/jesseduffield/lazygit"
  url "https://github.com/jesseduffield/lazygit/archive/refs/tags/v0.44.1.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/jesseduffield/lazygit.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ldflags = "-X main.version=#{version} -X main.buildSource=homebrew"
    system "go", "build", *std_go_args(ldflags:)
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lazygit --version")
  end
end
```

`std_go_args(output: bin/name, ldflags: nil, gcflags: nil, tags: nil)` already adds
`-trimpath`, `-o`, and `-s -w`. **Do not pass `-s -w` yourself** — it is redundant, and
Homebrew suppresses it automatically when building with debug symbols.

If upstream releases with GoReleaser and reads the standard `main.version` /
`main.commit` / `main.date` / `main.builtBy` variables, use the shorthand:

```ruby
system "go", "build", *std_go_args(ldflags: :goreleaser)
```

Multiple binaries, or a `cmd/` layout:

```ruby
system "go", "build", *std_go_args(output: bin/"foo"), "./cmd/foo"
system "go", "build", *std_go_args(output: bin/"foo-agent"), "./cmd/agent"
```

### 3b. Rust

```ruby
depends_on "rust" => :build
```

```ruby
system "cargo", "install", *std_cargo_args
```

`std_cargo_args(root: prefix, path: ".", features: nil)` supplies `--locked`, the job
count, and the install root. For a workspace member, pass the path:

```ruby
system "cargo", "install", *std_cargo_args(path: "crates/cli")
system "cargo", "install", *std_cargo_args(features: ["jemalloc"])
```

`--locked` means the build honours `Cargo.lock`. If upstream does not commit one, the
build will fail; that is upstream's bug to fix, not something to paper over.

### 3c. CMake, Make and autotools

CMake — `depends_on "cmake" => :build`, then:

```ruby
system "cmake", "-S", ".", "-B", "build", *std_cmake_args
system "cmake", "--build", "build"
system "cmake", "--install", "build"
```

Autotools:

```ruby
system "./configure", *std_configure_args
system "make", "install"
```

A release tarball usually ships a generated `configure`. A git checkout usually does not,
so a `head` spec needs the autotools chain declared:

```ruby
head do
  url "https://github.com/owner/repo.git", branch: "main"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
end
```

and bootstrapped before configure runs:

```ruby
system "autoreconf", "--force", "--install", "--verbose" if build.head?
system "./configure", *std_configure_args
system "make", "install"
```

Plain Make — most such projects need `PREFIX` passed explicitly, and many ignore
`DESTDIR`:

```ruby
system "make", "install", "PREFIX=#{prefix}"
```

### 3d. Prebuilt binary

Use `on_macos` / `on_linux` and `on_arm` / `on_intel` to select the asset. Because the URL
differs per platform, an explicit `version` **is** required here — there is no single URL
for Homebrew to derive it from.

`livecheck` must still come **before** the `on_macos` / `on_linux` stanzas; `brew style`
enforces that ordering.

```ruby
version "1.4.2"
license "Apache-2.0"
```

```ruby
on_macos do
  on_arm do
    url "https://github.com/owner/repo/releases/download/v1.4.2/foo_darwin_arm64.tar.gz"
    sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  end
  on_intel do
    url "https://github.com/owner/repo/releases/download/v1.4.2/foo_darwin_amd64.tar.gz"
    sha256 "1111111111111111111111111111111111111111111111111111111111111111"
  end
end

on_linux do
  on_arm do
    url "https://github.com/owner/repo/releases/download/v1.4.2/foo_linux_arm64.tar.gz"
    sha256 "2222222222222222222222222222222222222222222222222222222222222222"
  end
  on_intel do
    url "https://github.com/owner/repo/releases/download/v1.4.2/foo_linux_amd64.tar.gz"
    sha256 "3333333333333333333333333333333333333333333333333333333333333333"
  end
end
```

The install block is usually just moving the extracted binary into place:

```ruby
bin.install "foo"
```

`url :stable` still works in `livecheck` here: the `github_latest` strategy only needs
`github.com/<owner>/<repo>` out of the URL, which a release-download URL provides.

For a single value that differs by architecture, `on_arch_conditional` is tidier than two
blocks:

```ruby
sha256 on_arch_conditional(arm: "aaaa", intel: "bbbb")
```

Prebuilt binaries still get bottled. That is intentional — the bottle pins the exact
artefact and makes installs a single GHCR pull.

### 3e. Versioned formulae

To keep an old series installable alongside the current one, add `Formula/<name>@<major>.rb`.
Pin the **major**, matching `node@22` and `openssl@3`, unless upstream breaks compatibility
on minors the way Python does — otherwise every minor needs its own file.

The class name must match `Formulary.class_s`, which is not obvious here:
`pmmcp@1` → `PmmcpAT1`, `pmmcp@1.0` → `PmmcpAT10`.

Three things a versioned formula needs that the main one does not:

```ruby
keg_only :versioned_formula
```

No `head` spec — a versioned formula pins a series, and the default branch is not in it.

And a livecheck scoped to the series. **Do not use `github_latest` here.** That strategy
only ever inspects the single newest release, so the moment upstream ships 2.0 it stops
matching and the formula silently stops being bumped — the exact failure mode the
`livecheck` rule exists to prevent. Enumerate releases instead:

```ruby
livecheck do
  url :stable
  regex(/^v?(1(?:\.\d+)+)$/i)
  strategy :github_releases do |json, regex|
    json.map do |release|
      next if release["draft"] || release["prerelease"]

      match = release["tag_name"]&.match(regex)
      next if match.blank?

      match[1]
    end
  end
end
```

Check the regex rejects what it should before committing — `1(?:\.\d+)+` matches `v1.10.3`
and correctly refuses `v2.0.0` and `v11.0.0`.

Every retained version costs a full bottle build on every CI run, so add one when you
actually need to hold a series back, not speculatively.

---

## 4. Dependencies

Declare what upstream actually needs. Every dependency you add is one more thing that can
break a bottle build.

```ruby
depends_on "cmake" => :build          # needed to compile, not at runtime
depends_on "pkgconf" => :build
depends_on "openssl@3"                # needed at runtime
depends_on "git" => :test             # only for the test block
depends_on :macos                     # platform restriction
uses_from_macos "curl"                # macOS ships it; Linux needs the formula
uses_from_macos "zlib", since: :catalina
```

Rules of thumb:

- Compilers and build tools are always `=> :build`. A stray runtime dep on `go` or `rust`
  bloats every install.
- `uses_from_macos` is for things macOS provides in the SDK. Using plain `depends_on` for
  those makes the macOS bottle carry a dependency it does not need.
- Do not declare a dependency on something already in Homebrew's default build environment
  (a C compiler, `make`).

---

## 5. livecheck is mandatory

**Every formula in this tap must have a `livecheck` block.** Without one, `brew bump`
cannot see new upstream versions, and the daily autobump workflow skips the formula
silently, forever. `brew audit` does not catch this. It is the single easiest way to
quietly break the automation.

GitHub releases — the default, and what the scaffolder emits:

```ruby
livecheck do
  url :stable
  regex(/^v?(\d+(?:\.\d+)+)$/i)
  strategy :github_latest
end
```

Git tags, when upstream tags without publishing releases:

```ruby
livecheck do
  url :stable
  regex(/^v?(\d+(?:\.\d+)+)$/i)
  strategy :git
end
```

Opting out — this is the **only** supported way. `no_autobump!` raises outside official
Homebrew taps:

```ruby
livecheck do
  skip "Tracks a rolling snapshot; bumped by hand"
end
```

Throttling a noisy upstream so only every tenth release opens a PR:

```ruby
livecheck do
  url :stable
  regex(/^v?(\d+(?:\.\d+)+)$/i)
  throttle 10
end
```

Verify before moving on. It should print the current and latest versions, not an error:

```bash
make livecheck
```

---

## 6. The test block

`brew test` runs against the **installed** formula, in a sandboxed temporary directory.
The house rule: run the thing and assert on real output.

```ruby
test do
  assert_match version.to_s, shell_output("#{bin}/foo --version")
end
```

Not acceptable — this passes even if the binary is a corrupt zero-byte file:

```ruby
test do
  assert_predicate bin/"foo", :exist?
end
```

Exercise real behaviour where you can. `testpath` is the sandboxed working directory:

```ruby
test do
  (testpath/"input.json").write('{"name": "test"}')
  output = shell_output("#{bin}/foo convert input.json")
  assert_match 'name = "test"', output
end
```

Asserting on a non-zero exit — `shell_output` takes the expected status as a second
argument and raises if it does not match:

```ruby
shell_output("#{bin}/foo --nonexistent-flag 2>&1", 1)
```

If the tool needs network to do anything useful, test the parts that do not. Bottle builds
run with network restrictions, and a network-dependent test will fail in CI while passing
on your machine.

---

## 7. Verify locally

Work through these in order. Each catches a different class of problem, and a later one
passing does not imply an earlier one would.

```bash
make style fix                    # RuboCop via brew; --fix handles most of it
brew install --build-from-source scrothers/tap/foo
make test F=foo                   # runs the test block against the install
make audit                        # --strict --online
make readme                       # regenerate the formula table
make all                          # everything CI runs
```

`brew install --build-from-source` is the step that actually proves the install block. Do
not skip it and let CI find out.

For a formula that has never been committed, add the new-formula audit — it applies checks
that only run the first time:

```bash
brew audit --strict --online --new scrothers/tap/foo
```

Reinstalling repeatedly while iterating:

```bash
brew uninstall foo && brew install --build-from-source scrothers/tap/foo
```

---

## 8. Open the pull request

Never commit to `main` directly, even for a one-line version change.

```bash
git checkout -b add-foo
git add Formula/foo.rb README.md
git commit
git push -u origin add-foo
gh pr create
```

`tests.yml` then runs on `macos-26` and `ubuntu-latest`, executing
`brew test-bot --only-formulae`: it installs the formula, runs the test block, audits it,
runs livecheck, builds bottles and uploads them as artifacts.

---

## 9. Publish the bottles

Bottles exist only as CI artifacts until `publish.yml` pulls them. It is dispatch-driven:

```bash
gh workflow run publish.yml -f pull_request=<PR-number> -f head_sha=<sha>
```

`brew pr-pull` downloads the artifacts, uploads bottles to `ghcr.io/v2/scrothers/tap`,
rewrites the formula's `bottle do` block with the real checksums, and fast-forwards `main`.
The PR closes itself. There is no separate merge step — **do not merge the PR by hand**,
or `pr-pull` will have nothing to fast-forward and the bottles will be orphaned.

For a version bump opened by the autobump workflow, none of this is manual:
`autopublish.yml` dispatches `publish.yml` as soon as test-bot goes green.

**One-time per formula:** after the first successful publish, the GHCR package is private
by default and `brew install` will 404. Set its visibility to public under the repository's
Packages settings. This cannot be automated.

---

## 10. Confirm it works

```bash
brew uninstall foo
brew update
brew install scrothers/tap/foo    # should pour a bottle, not compile
```

If it compiles, the bottle is missing, the GHCR package is still private, or the
`bottle do` block never landed on `main`.

---

## Failure reference

| Symptom | Cause |
| --- | --- |
| `Error: cannot load such file -- bundler` | Homebrew fell back to system Ruby. `brew vendor-install ruby`. |
| `brew style` clean locally, fails on macOS CI | Cross-file RuboCop cops see brew's own Library. Usually a top-level constant or method in `scripts/`; namespace it in a module. |
| A tap `.rubocop.yml` has no effect | Expected. `brew style` passes `--config` pointing at Homebrew's own, which overrides directory discovery. Fix the source instead. |
| `Cop/DisableComment` | The clarifying comment must be on the line *immediately before* `# rubocop:disable`, not trailing it. |
| Formula never appears in bump PRs | Missing `livecheck` block. |
| `no_autobump!` raises `ArgumentError` | Only valid in official Homebrew taps. Use `livecheck do skip end`. |
| `brew install` 404s after publishing | GHCR package still private. |
| Bump PR opens but no CI runs | `HOMEBREW_BUMP_TOKEN` missing or expired. GitHub does not trigger workflows from `GITHUB_TOKEN` events. |
| `ComponentsOrder` audit failure | Stanza order is fixed. `brew style --fix` reorders it for you. |
| Description rejected by audit | No leading article, no trailing full stop, 80 characters max. |

## Things that will not work the way you expect

- **`brew style` lints this file too.** Homebrew loads the `rubocop-md` plugin, which
  concatenates every Ruby-tagged fence in a Markdown file into one virtual source and runs
  the formula cops over it. That is why the examples above are fragments at the left
  margin rather than indented class bodies.
- **`brew style` also lints workflows.** It runs actionlint and shellcheck over
  `.github/workflows/`. There is no separate actionlint step, and none is needed.
- **`main` deliberately does not require pull requests.** `brew pr-pull` fast-forwards it
  directly; a PR requirement would deadlock publishing. The ruleset blocks force pushes and
  deletions only. Do not "harden" this.
- **Local green is not proof.** The Linux container leg and the macOS leg fail differently.
  Both must pass.
- **Homebrew's own source is the best documentation.** `Library/Homebrew/formula.rb` has
  every `std_*_args` helper with its real signature. Read it rather than recalling flags.

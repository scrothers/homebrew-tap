# typed: false
# frozen_string_literal: true

class PmmcpAT1 < Formula
  desc "Agent-native process supervisor with an MCP control plane"
  homepage "https://github.com/scrothers/pmmcp"
  url "https://github.com/scrothers/pmmcp/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "80cb6dd2c7cdca9b5418af348fd9a07c2c1ad69553f972ddc5030d6fdc1e3d09"
  license "Apache-2.0"

  # Deliberately scoped to the 1.x series, and deliberately not `github_latest`: that
  # strategy only ever inspects the newest release, so once upstream ships 2.0 it would
  # stop matching and this formula would silently stop being bumped. `github_releases`
  # enumerates releases, so the newest 1.x is still found.
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

  # No `head` spec: a versioned formula pins a series, and upstream's default branch is
  # not in it.

  keg_only :versioned_formula

  depends_on "go" => :build

  def install
    # Kept deliberately identical to Formula/pmmcp.rb; see the comments there for why
    # the ldflags are written out by hand and why Commit is left alone.
    ENV["CGO_ENABLED"] = "0"

    ldflags = %W[
      -X github.com/scrothers/pmmcp/internal/version.Version=#{version}
      -X github.com/scrothers/pmmcp/internal/version.BuildDate=#{time.iso8601}
    ]

    system "go", "build", *std_go_args(output: bin/"pmmcp", ldflags:), "./cmd/pmmcp"
    system "go", "build", *std_go_args(output: bin/"pmmcpd", ldflags:), "./cmd/pmmcpd"

    generate_completions_from_executable(bin/"pmmcp", "completion")
    generate_completions_from_executable(bin/"pmmcpd", "completion")
  end

  def caveats
    <<~EOS
      This formula is keg-only, so it is not symlinked into #{HOMEBREW_PREFIX}.
      Run it by full path, or link it explicitly:
        #{opt_bin}/pmmcp

      pmmcpd is not started automatically. To install the user-level service:
        #{opt_bin}/pmmcp install-service
    EOS
  end

  test do
    assert_match "pmmcp #{version}", shell_output("#{bin}/pmmcp --version")
    assert_match "pmmcpd #{version}", shell_output("#{bin}/pmmcpd version")
    assert_match "__pmmcp_debug", shell_output("#{bin}/pmmcp completion bash")
  end
end

# typed: false
# frozen_string_literal: true

class Pmmcp < Formula
  desc "Agent-native process supervisor with an MCP control plane"
  homepage "https://github.com/scrothers/pmmcp"
  url "https://github.com/scrothers/pmmcp/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "80cb6dd2c7cdca9b5418af348fd9a07c2c1ad69553f972ddc5030d6fdc1e3d09"
  license "Apache-2.0"
  head "https://github.com/scrothers/pmmcp.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    # Upstream builds with cgo off (see .goreleaser.yaml); match it so the bottle has
    # no libc linkage it does not need.
    ENV["CGO_ENABLED"] = "0"

    # Upstream puts its version vars in internal/version, not the `main.*` names
    # `std_go_args(ldflags: :goreleaser)` assumes, so they are set explicitly.
    # Commit and BuildDate are deliberately left at their "unknown" defaults: there is
    # no git metadata in a release tarball, and stamping a timestamp would make the
    # bottle unreproducible.
    ldflags = "-X github.com/scrothers/pmmcp/internal/version.Version=#{version}"

    system "go", "build", *std_go_args(output: bin/"pmmcp", ldflags:), "./cmd/pmmcp"
    system "go", "build", *std_go_args(output: bin/"pmmcpd", ldflags:), "./cmd/pmmcpd"

    generate_completions_from_executable(bin/"pmmcp", "completion")
    generate_completions_from_executable(bin/"pmmcpd", "completion")
  end

  # No `service` block on purpose. pmmcpd ships its own user-level service installer
  # (`pmmcp install-service`), which writes the systemd user unit or launchd agent
  # upstream expects. A Homebrew service would be a second, competing supervisor for
  # the same daemon.
  def caveats
    <<~EOS
      pmmcpd is not started automatically. To install the user-level service:
        pmmcp install-service

      Then check the daemon and configuration with:
        pmmcp doctor
    EOS
  end

  test do
    assert_match "pmmcp #{version}", shell_output("#{bin}/pmmcp --version")
    assert_match "pmmcpd #{version}", shell_output("#{bin}/pmmcpd version")

    # No daemon is running under `brew test`, so exercise what works offline. Cobra
    # emits this marker into every bash completion script it generates.
    assert_match "__pmmcp_debug", shell_output("#{bin}/pmmcp completion bash")
  end
end

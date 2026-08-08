#!/usr/bin/env ruby
# frozen_string_literal: true

# Scaffolds Formula/<name>.rb from a GitHub repository.
#
#   ruby scripts/new-formula.rb --name lazygit --repo jesseduffield/lazygit
#
# Pulls description, homepage, licence and the latest release tarball via `gh api`,
# computes the sha256, and writes a stub with `livecheck` and `test do` already present.
# The install block is left as a TODO — that part cannot be guessed.

require "digest"
require "json"
require "open3"
require "optparse"
# Redundant only on Ruby 4.0+, which auto-requires Pathname. Kept so the script also runs
# on older system Rubies.
# rubocop:disable Lint/RedundantRequireStatement
require "pathname"
# rubocop:enable Lint/RedundantRequireStatement

ROOT      = Pathname.new(__dir__).parent.freeze
FORMULA_D = (ROOT / "Formula").freeze
REPO_RE   = %r{\A[\w.-]+/[\w.-]+\z}

options = {}
OptionParser.new do |parser|
  parser.banner = "usage: ruby scripts/new-formula.rb --name <formula> --repo <owner/repo>"
  parser.on("--name NAME", "Formula name, e.g. lazygit") { |v| options[:name] = v }
  parser.on("--repo REPO", "GitHub repo, e.g. jesseduffield/lazygit") { |v| options[:repo] = v }
  parser.on("--force", "Overwrite an existing formula file") { options[:force] = true }
end.parse!

abort "both --name and --repo are required" if options[:name].nil? || options[:repo].nil?

name = options[:name]
repo = options[:repo]
abort "--repo must look like owner/repo, got #{repo.inspect}" unless repo.match?(REPO_RE)

target = FORMULA_D / "#{name}.rb"
if target.exist? && !options[:force]
  abort "#{target.relative_path_from(ROOT)} already exists (pass --force to overwrite)"
end

def sh(*cmd)
  out, err, status = Open3.capture3(*cmd)
  abort "#{cmd.first} failed: #{err.strip}" unless status.success?
  out
end

# Same, but returns nil instead of aborting — for calls that are allowed to fail.
def sh_or_nil(*cmd)
  out, _err, status = Open3.capture3(*cmd)
  status.success? ? out : nil
end

# Homebrew's Formulary.class_s — the class name must match or `brew` cannot load it.
def class_name(name)
  klass = name.capitalize
  klass = klass.gsub(/[-_.\s]([a-zA-Z0-9])/) { Regexp.last_match(1).upcase }
  klass = klass.tr("+", "x")
  klass.sub(/(.)@(\d)/, '\1AT\2')
end

# `brew audit --strict` rejects a leading article and a trailing full stop, and caps the
# description length. GitHub descriptions routinely violate all three.
def clean_desc(raw)
  desc = raw.to_s.strip
  desc = desc.sub(/\A(?:A|An|The)\s+/i, "")
  desc = desc.sub(/[.．]+\z/, "")
  desc = desc.gsub(/\s+/, " ")
  desc[0] = desc[0].upcase unless desc.empty?
  desc
end

puts "fetching #{repo} ..."
meta = JSON.parse(sh("gh", "api", "repos/#{repo}"))

release_json = sh_or_nil("gh", "api", "repos/#{repo}/releases/latest")
warn "no published release found for #{repo}; leaving url/sha256 as TODO" unless release_json
release = release_json && JSON.parse(release_json)

homepage = meta["homepage"].to_s.empty? ? meta["html_url"] : meta["homepage"]
desc     = clean_desc(meta["description"])
license  = meta.dig("license", "spdx_id").to_s
license  = "" if %w[NOASSERTION NONE].include?(license)
branch   = meta["default_branch"]

warn "WARNING: description is #{desc.length} chars; audit caps it at 80" if desc.length > 80
warn "WARNING: no SPDX licence detected; fill in `license` by hand" if license.empty?

# No explicit `version` is emitted: Homebrew derives it from a GitHub tag URL, and an
# explicit one would have to be kept in sync by hand on every bump.
stable_block = if release
  tag = release["tag_name"]
  url = "https://github.com/#{repo}/archive/refs/tags/#{tag}.tar.gz"
  puts "latest release: #{tag}"
  puts "hashing #{url} ..."
  digest = Digest::SHA256.hexdigest(sh("curl", "-fsSL", url))

  <<~RUBY.chomp
    url "#{url}"
      sha256 "#{digest}"
  RUBY
else
  <<~RUBY.chomp
    # TODO: no GitHub release found. Point this at a tarball and add its sha256.
      url "https://github.com/#{repo}/archive/refs/tags/vX.Y.Z.tar.gz"
      sha256 ""
  RUBY
end

contents = <<~RUBY
  # typed: false
  # frozen_string_literal: true

  class #{class_name(name)} < Formula
    desc "#{desc}"
    homepage "#{homepage}"
    #{stable_block}
    license "#{license}"
    head "https://github.com/#{repo}.git", branch: "#{branch}"

    # Required by house rules: without this, `brew bump` cannot see new releases and the
    # autobump workflow skips this formula silently. See CLAUDE.md.
    livecheck do
      url :stable
      regex(/^v?(\\d+(?:\\.\\d+)+)$/i)
      strategy :github_latest
    end

    # TODO: declare build and runtime dependencies with depends_on.

    def install
      # TODO: replace with the real build.
      #
      #   Go:    system "go", "build", *std_go_args(ldflags: "-s -w")
      #   Rust:  system "cargo", "install", *std_cargo_args
      #   Make:  system "make", "install", "PREFIX=\#{prefix}"
      #   CMake: system "cmake", "-S", ".", "-B", "build", *std_cmake_args
      #          system "cmake", "--build", "build"
      #          system "cmake", "--install", "build"
      raise "install block not implemented for #{name}"
    end

    test do
      # TODO: run the thing and assert on real output. An existence check is not a test.
      assert_match version.to_s, shell_output("\#{bin}/#{name} --version")
    end
  end
RUBY

FORMULA_D.mkpath
target.write(contents)

puts
puts "wrote #{target.relative_path_from(ROOT)}"
puts
puts "next:"
puts "  1. fill in the install block and the dependencies"
puts "  2. make style fix"
puts "  3. make audit"
puts "  4. make test F=#{name}"
puts "  5. make readme"

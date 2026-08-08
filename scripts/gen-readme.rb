#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates the formula table in README.md from the files in Formula/.
#
# Deliberately does NOT shell out to `brew`. This runs in the CI lint job, which is a
# plain Ubuntu runner with no Homebrew, and it needs to stay fast. Instead it evaluates
# each formula against a stub Formula class that records the DSL calls it cares about
# and swallows everything else.
#
#   ruby scripts/gen-readme.rb            rewrite the table in place
#   ruby scripts/gen-readme.rb --check    exit 1 if the table is stale, write nothing
#
# Everything lives under one module on purpose. `brew style` runs RuboCop with Homebrew's
# own Library in scope, so a top-level constant or an Object-level method here collides
# with brew's source and trips Lint/ConstantReassignment or Lint/DuplicateMethods.

# Homebrew's RuboCop targets Ruby 4.0, where Pathname is auto-required, so it calls this
# redundant. The CI lint job runs on the GitHub runner's system Ruby, which is older and
# still needs the explicit require.
# rubocop:disable Lint/RedundantRequireStatement
require "pathname"
# rubocop:enable Lint/RedundantRequireStatement

module TapReadme
  ROOT       = Pathname.new(__dir__).parent.freeze
  README     = (ROOT / "README.md").freeze
  FORMULA_D  = (ROOT / "Formula").freeze
  START_MARK = "<!-- FORMULAE:START -->"
  END_MARK   = "<!-- FORMULAE:END -->"
  REGION_RE  = /#{Regexp.escape(START_MARK)}\n.*?#{Regexp.escape(END_MARK)}/m
  ARCHIVE_RE = /\.(?:tar\.(?:gz|bz2|xz|zst)|tgz|tbz|zip|gem|jar)\z/
  VERSION_RE = /(\d+(?:\.\d+)+(?:[.-][A-Za-z0-9]+)*)\z/

  Info = Struct.new(:name, :desc, :homepage, :version, :license, keyword_init: true)

  # The base class every formula file subclasses during parsing. Records the handful of
  # top-level DSL calls we render and ignores the rest. Blocks (`bottle do`, `test do`,
  # `livecheck do`, ...) are swallowed unevaluated, so nothing in a formula can run.
  class Formula
    def self.descendants
      @descendants ||= []
    end

    def self.inherited(subclass)
      super
      Formula.descendants << subclass
    end

    def self.captured
      @captured ||= {}
    end

    def self.method_missing(name, *args, **kwargs, &_block)
      return if args.empty? && kwargs.empty?

      captured[name] ||= { args: args, kwargs: kwargs }
      nil
    end

    def self.respond_to_missing?(_name, _include_private = false)
      true
    end

    def self.const_missing(name)
      name
    end

    # Homebrew DSL names that collide with real methods inherited from Kernel/Object.
    # `test do ... end` is the live example: Kernel#test is the file-test operator, so it
    # answers the call and raises ArgumentError before method_missing is ever consulted.
    # Undefining them on the singleton routes them back to method_missing.
    DSL = [
      :desc, :homepage, :url, :mirror, :sha256, :version, :revision, :version_scheme,
      :license, :head, :stable, :bottle, :resource, :patch, :depends_on, :uses_from_macos,
      :conflicts_with, :keg_only, :option, :deprecated_option, :skip_clean, :pour_bottle?,
      :livecheck, :test, :service, :on_macos, :on_linux, :on_arm, :on_intel, :on_system,
      :deprecate!, :disable!, :link_overwrite, :fails_with, :needs, :go_resource,
      :allow_network_access!, :deny_network_access!
    ].freeze

    class << self
      DSL.each do |dsl_method|
        inherited_real_method = method_defined?(dsl_method) || private_method_defined?(dsl_method)
        undef_method(dsl_method) if inherited_real_method
      end
    end
  end

  # Best-effort version extraction, in descending order of trustworthiness: an explicit
  # `version`, then a git `tag:`, then the tail of the download URL.
  def self.derive_version(captured)
    explicit = captured.dig(:version, :args, 0)
    return explicit.to_s if explicit

    tag = captured.dig(:url, :kwargs, :tag)
    return tag.to_s.delete_prefix("v") if tag

    url = captured.dig(:url, :args, 0).to_s
    return "" if url.empty?

    stem  = url.split("/").last.to_s.sub(ARCHIVE_RE, "")
    match = stem.match(VERSION_RE)
    match ? match[1] : ""
  end

  def self.load_formula(path)
    before = Formula.descendants.dup
    # Evaluated in this module's scope so `class Foo < Formula` resolves to the stub
    # above and the resulting class is namespaced here rather than at top level.
    module_eval(path.read, path.to_s)
    klass = (Formula.descendants - before).last
    return if klass.nil?

    captured = klass.captured
    Info.new(
      name:     path.basename(".rb").to_s,
      desc:     captured.dig(:desc, :args, 0).to_s,
      homepage: captured.dig(:homepage, :args, 0).to_s,
      version:  derive_version(captured),
      license:  captured.dig(:license, :args, 0).to_s,
    )
  rescue StandardError, SyntaxError => e
    warn "#{path.basename}: could not parse (#{e.class}: #{e.message})"
    Info.new(name: path.basename(".rb").to_s, desc: "", homepage: "", version: "", license: "")
  end

  def self.render_table(infos)
    rows = if infos.empty?
      ["| _Coming soon_ | Formulae land here as they are added. | — | — |"]
    else
      infos.sort_by(&:name).map do |f|
        name    = f.homepage.empty? ? "`#{f.name}`" : "[`#{f.name}`](#{f.homepage})"
        desc    = f.desc.empty? ? "—" : f.desc
        version = f.version.empty? ? "—" : "`#{f.version}`"
        license = f.license.empty? ? "—" : f.license
        "| #{name} | #{desc} | #{version} | #{license} |"
      end
    end

    <<~TABLE.chomp
      | Formula | Description | Version | License |
      | ------- | ----------- | ------- | ------- |
      #{rows.join("\n")}
    TABLE
  end

  def self.splice(readme, table)
    abort "README.md is missing the #{START_MARK} / #{END_MARK} markers" unless readme.match?(REGION_RE)

    readme.sub(REGION_RE, "#{START_MARK}\n#{table}\n#{END_MARK}")
  end

  def self.run(argv)
    check_only = argv.include?("--check")

    infos   = FORMULA_D.glob("*.rb").sort.filter_map { |p| load_formula(p) }
    current = README.read
    updated = splice(current, render_table(infos))
    count   = "#{infos.size} formula#{"e" if infos.size != 1}"

    if current == updated
      puts "README formula table is up to date (#{count})"
      return 0
    end

    if check_only
      warn "README formula table is stale. Run `make readme` and commit the result."
      return 1
    end

    README.write(updated)
    puts "README formula table regenerated (#{count})"
    0
  end
end

exit TapReadme.run(ARGV) if $PROGRAM_NAME == __FILE__

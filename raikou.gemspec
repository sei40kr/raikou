# typed: strict
# frozen_string_literal: true

require_relative "lib/raikou/version"

Gem::Specification.new do |spec|
  spec.name = "raikou"
  spec.version = Raikou::VERSION
  spec.authors = ["sei40kr"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Seek-based pagination for ActiveRecord with Sorbet type safety"
  spec.description = "A cursor-based (seek method) pagination library for ActiveRecord with strong Sorbet typing"
  spec.homepage = "https://github.com/sei40kr/raikou"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob(%w[
    lib/**/*.rb
    sorbet/**/*.rbi
    README.md
    LICENSE
    CHANGELOG.md
  ])
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "activerecord", ">= 6.0"
  spec.add_dependency "sorbet-runtime", "~> 0.5"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "sorbet", "~> 0.5"
  spec.add_development_dependency "tapioca", "~> 0.11"
  spec.add_development_dependency "sqlite3", "~> 1.4"
end

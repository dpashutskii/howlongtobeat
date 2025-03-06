require_relative 'lib/howlongtobeat/version'

Gem::Specification.new do |spec|
  spec.name          = "howlongtobeat"
  spec.version       = HowLongToBeat::VERSION
  spec.authors       = ["Dmitrii Pashutskii"]
  spec.email         = ["dpashutskii@gmail.com"]

  spec.summary       = "Ruby client for HowLongToBeat.com"
  spec.description   = "A simple Ruby gem to fetch game completion times from HowLongToBeat.com"
  spec.homepage      = "https://github.com/dpashutskii/howlongtobeat"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  spec.files         = Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md", "CODE_OF_CONDUCT.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", "~> 1.15.0"
  spec.add_dependency "ostruct", "~> 0.6.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"
end

# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in howlongtobeat.gemspec
gemspec

gem "rake", "~> 13.0"

# public_suffix 7 needs Ruby >= 3.2, but CI also tests Ruby 3.1 (addressable pulls it in via webmock).
gem "public_suffix", "< 7"

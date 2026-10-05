require 'bundler/setup'
require 'webmock/rspec'
require 'howlongtobeat'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Live specs talk to howlongtobeat.com. HLTB rate-limits bursts (429 on
  # /api/search/site/init since late September 2026), so each live example
  # waits a few seconds first, the same fix upstream used (0be480b).
  config.around(:each, :live) do |example|
    WebMock.allow_net_connect!
    sleep(rand(3.0..6.0))
    begin
      example.run
    ensure
      WebMock.disable_net_connect!
    end
  end
end

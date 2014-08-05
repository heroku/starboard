ENV["RACK_ENV"] = "test"
require "minitest/autorun"
require "rack/test"
require "webmock/minitest"
require "dotenv"
Dotenv.load(".env.test")

require_relative "../app"

module Scrolls
  def self.log(*args)
    yield
  end
end

def fixture_zip
  File.open(File.expand_path(File.join(File.dirname(__FILE__), "fixtures/test.zip")))
end

class Cache
  def initialize
    @internal_cache = {}
  end

  def set(key, value, ttl = 0)
    @internal_cache[key] = value
  end

  def get(key)
    @internal_cache[key]
  end
end


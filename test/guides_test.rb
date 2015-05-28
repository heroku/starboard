require_relative "test_helper"

class HttpClient
  def self.get(*args)
    @@args = args
    Struct.new(:body).new(fixture_zip.read)
  end

  def self.args
    @@args
  end
end

class GuidesTest < MiniTest::Unit::TestCase

  def test_refresh
    guides = Guides.new(cache)
    guides.guides_file = fixture_zip
    guides.refresh
    onboarding = cache.get("onboarding.md")
    refute_nil onboarding
    assert_includes onboarding, "list_name"
  end

  def test_refresh_call_github
    guides = Guides.new(cache)
    guides.http_client = HttpClient
    guides.refresh
    assert_equal HttpClient.args.first, "https://api.github.com/repos/ys/markdown/zipball/master"
    assert_equal HttpClient.args.last[:headers]["Authorization"], "token github_token"
  end

  def cache
    @cache ||= Cache.new
  end
end

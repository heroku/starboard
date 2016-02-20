require_relative "test_helper"

class AppTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    App
  end

  def cache
    @cache ||= Cache.new
  end

  def setup
    app.settings.cache = cache
    stub_request(:get, /.*api.github.com.*/)
      .to_return(:body => fixture_zip, :status => 200)
  end

  def test_refresh_guides_without_token_unauthorized
    post("/guides")
    assert_equal last_response.status, 401
  end

  def test_refresh_guides_with_token
    post("/guides", t: ENV["HOOK_TOKEN"])
    assert_equal last_response.status, 200
  end

  def test_refresh_guides_saves_in_cache
    assert_nil cache.get("onboarding.md")
    post("/guides", t: ENV["HOOK_TOKEN"])
    assert_includes cache.get("onboarding.md"), "list_name"
  end

  def test_get_a_guide
    guides = Guides.new(cache)
    guides.guides_file = fixture_zip
    guides.refresh
    get("/guides/onboarding.md")
    assert_includes last_response.body, "list_name"
  end

  def test_get_a_non_existing_guide
    get("/guides/onboarding.md")
    assert_equal last_response.status, 404
  end
end

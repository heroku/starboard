source "https://rubygems.org"
ruby "2.6.6"

gem "sinatra", "~>2.0.2"
gem "sinatra-contrib"
gem "puma"
gem "dalli"
gem "rubyzip"
gem "excon"
gem "sinatra-asset-pipeline"
gem "scrolls"
gem "heroku-bouncer"
gem "git_hub_integration", "0.1.4", source: "https://packagecloud.io/heroku/gemgate/"
gem "redis"
gem "octokit", ">= 4.6.2"

gem "rack-ssl"

group "development", "test" do
  gem "dotenv"
  gem "pry-byebug"
end

group "test" do
  gem "minitest"
  gem "rack-test"
  gem "webmock", ">= 3.4.2"
end

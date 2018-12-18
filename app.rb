require "rubygems"
require "bundler"

Bundler.require
require "sinatra/asset_pipeline"

require "securerandom"
require_relative "app/guides"

class App < Sinatra::Base
  register Sinatra::AssetPipeline

  set :ssl, lambda { !(development? || test?) }
  use Rack::SSL, exclude: -> (env) { !ssl? }

  configure :development do
    require "dotenv"
    Dotenv.load
  end

  configure :production do
    ENV["MEMCACHE_SERVERS"] = ENV["MEMCACHIER_SERVERS"] if ENV["MEMCACHIER_SERVERS"]
    ENV["MEMCACHE_USERNAME"] = ENV["MEMCACHIER_USERNAME"] if ENV["MEMCACHIER_USERNAME"]
    ENV["MEMCACHE_PASSWORD"] = ENV["MEMCACHIER_PASSWORD"] if ENV["MEMCACHIER_PASSWORD"]
  end

  set :cache, Dalli::Client.new
  set :assets_precompile, %w(app.js screen.css)
  enable :sessions
  set :session_secret, ENV["SESSION_SECRET"]

  configure do
    # Setup Sprockets
    sprockets.append_path File.join(root, "assets", "stylesheets")
    sprockets.append_path File.join(root, "assets", "javascripts")
  end

  configure :production, :development do
    use ::Heroku::Bouncer,
        oauth: {id: ENV["HEROKU_OAUTH_ID"], secret: ENV["HEROKU_OAUTH_SECRET"]},
        secret: ENV["HEROKU_BOUNCER_SECRET"],
        herokai_only: true,
        skip: -> (env) { ENV["HEROKAI_ONLY"] != "true" || env["PATH_INFO"] == "/guides" }
  end

  Excon.defaults[:middlewares] << Excon::Middleware::RedirectFollower

  post "/guides" do
    error 401 unless [ENV["HOOK_TOKEN"], token].include? params[:t]
    json refresh_guides
  end

  get "/" do
    erb :index, locals: {organization: organization, token: token}
  end

  get "/guides/*" do
    guides.get(params[:splat].first) || error(404)
  end

  get "/setup" do
    erb :setup
  end

  def refresh_guides
    guides.refresh
  end

  def guides
    @guides ||= Guides.new(settings.cache)
  end

  def organization
    ENV["TRELLO_ORGANIZATION"] ||
      raise("config var for TRELLO_ORGANIZATION is missing")
  end

  def token
    settings.cache.get("frontend_hook_token") || SecureRandom.hex.tap do |token|
      settings.cache.set("frontend_hook_token", token, 60)
    end
  end
end

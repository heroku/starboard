require "zip"
require "excon"
require "scrolls"

class Guides

  attr_accessor :guides_file
  attr_accessor :http_client
  attr_reader :cache

  def initialize(cache)
    @http_client = Excon
    @cache = cache
  end

  def get(name)
    cache.get(name)
  end

  def refresh
    Scrolls.log(app: "starboard", action: "refresh")  do
      refreshed_guides = { guides: [] }
      Zip::File.open(guides_file.path) do |io|
        io.each do |entry|
          filename = entry.name.split('/')[1..-1].join('/')
          next if entry.directory?
          refreshed_guides[:guides] << filename
          cache.set(filename, entry.get_input_stream.read)
        end
      end
      refreshed_guides
    end
  end

  private

  def guides_file
    unless @guides_file
      f = Tempfile.new('zip')
      f << zip_response.body
      f.flush
      f.close
      @guides_file = f
    end
    @guides_file
  end

  def zip_response
    branch = ENV['GITHUB_BRANCH'] || 'master'
    http_client.get("https://:#{ENV['GITHUB_TOKEN']}@api.github.com/repos/#{ENV['GITHUB_REPO']}/zipball/#{branch}")
  end
end

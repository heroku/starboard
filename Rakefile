require 'sinatra/asset_pipeline/task'
require 'rake/testtask'
require './app'

Sinatra::AssetPipeline::Task.define! App

Rake::TestTask.new do |t|
    t.pattern = 'test/*_test.rb'
end

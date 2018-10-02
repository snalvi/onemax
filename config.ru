# config.ru

# require File.expand_path '../main.rb', __FILE__

require "./app"
require "./authentication"

$stdout.sync = true
# run App

run Rack::URLMap.new({  "/" => App,
"/protected" => AuthenticatedReviews
})

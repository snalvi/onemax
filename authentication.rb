require 'sinatra/base'

class AuthenticatedReviews < Sinatra::Base

  use Rack::Auth::Basic, "Protected Area" do |username, password|
    username == 'onemax' && password == 'OneMax2018!'

    get '/' do
    	"authenticated endpoint"
  	end
  end

  get '/' do
  	"protected endpoint"
  end

end

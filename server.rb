require 'open-uri'
require_relative 'models/books'


class BookShelf < Sinatra::Base

  use Rack::Session::Cookie, secret: (ENV['SESSION_SECRET'] || 'some-secret')
  use OmniAuth::Builder do
    provider :goodreads, ENV['GOODREADS_KEY'], ENV['GOODREADS_SECRET']
  end

  configure do
    Mongoid.load!("config/mongoid.yml")
    register Sinatra::StaticAssets

    Goodreads.configure(
      :api_key => ENV['GOODREADS_KEY'],
      :api_secret => ENV['GOODREADS_SECRET']
    )

    ASIN::Configuration.configure do |config|
      config.secret        = ENV['AMAZON_SECRET']
      config.key           = ENV['AMAZON_KEY']
      config.associate_tag = 'your-tag'
    end
  end

  configure :development do
    Mongoid.logger.level = Logger::DEBUG
    Moped.logger.level = Logger::DEBUG

    register Sinatra::Reloader
    also_reload './models/*'
    set :protection, except: :path_traversal
  end

  get '/auth/:provider/callback' do
    auth = request.env['omniauth.auth']
    session[:user_id] = auth[:extra][:raw_info][:id]
    session[:credentials] = auth[:credentials]
    redirect "/"
  end

  # get %r{/img/(.*)} do |img_path|
  #   URI.parse(img_path).read
  # end

  get "/logout" do
    session.clear
    env['rack.session'].clear
    redirect "/auth/goodreads"
  end

  get "/:id" do |id|
    user = User.find_or_create_by(user_id: id)
    credentials = session[:credentials]
    if credentials
      consumer = OAuth::Consumer.new(ENV['GOODREADS_KEY'], ENV['GOODREADS_SECRET'], {site: 'http://www.goodreads.com'})
      access_token = OAuth::AccessToken.new(consumer, credentials['token'], credentials['secret'])
      user.access_token = access_token
    end
    @books = user.load_books(!!params[:force])
    erb :index
  end

  get "/" do
    if session[:user_id]
      redirect "/#{session[:user_id]}"
    else
      redirect "/auth/goodreads"
    end
  end

end

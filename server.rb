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
  end

  get '/auth/:provider/callback' do
    auth = request.env['omniauth.auth']
    session[:user_id] = auth[:extra][:raw_info][:id]
    redirect "/#{session[:user_id]}"
  end

  get "/:id" do |id|
    user = User.where(user_id: id).first
    if user && user.books && user.books.size > 0
      @books = user.books.map {|book| Book.new(book)}
      return erb :index
    end

    client = Goodreads.new
    user_info = client.user(id)
    user_id = user_info[:id]
    shelves = user_info[:user_shelves]
    @books = []
    page = 1
    shelves.each do |shelf_data|
      while true
        shelf = client.shelf(user_id, shelf_data[:id], page: page)
        break if shelf.books.size == 0
        shelf.books.each do |shelf_book|
          @books << Book.new(goodreads_data: shelf_book.book)
        end
        page += 1
      end
    end

    @books = @books.sort_by { |b| [b.author_last_name, b.pub_date, b.title] }

    user = User.find_or_create_by(user_id: id)
    user.books = @books.map(&:to_hash)
    user.last_updated = DateTime.now
    user.upsert
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

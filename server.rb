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
    client = Goodreads.new
    user_info = client.user(id)
    user_id = user_info[:id]
    shelves = user_info[:user_shelves]
    all_books = []
    page = 1
    shelves.each do |shelf_data|
      while true
        shelf = client.shelf(user_id, shelf_data[:id], page: page)
        break if shelf.books.size == 0
        shelf.books.each do |shelf_book|
          all_books << shelf_book.book
        end
        page += 1
      end
    end

    asin_client = ASIN::Client.instance
    @books = all_books.map do |b|
      if b[:image_url] =~ /nocover/
        puts "No cover for #{b[:title]}"
        asin = b[:asin] || b[:isbn]
        if not asin
          puts "No asin for #{b[:title]}"
          extended_book_data = client.book(b[:id]) rescue client.book(b[:id])
          asin = extended_book_data[:asin] || extended_book_data[:isbn]
        end
        item = asin_client.lookup(asin)
        if item.size == 0
          puts "Not found on amazon, trying text search"
          item = asin_client.search_keywords("#{b[:title].gsub(/\(.*\)/, '').strip} #{b[:authors][:author][:name].strip}")
        end
        if item.size > 0
          b[:image_url] = item[0].raw.LargeImage.URL
          puts "Image found for #{b[:title]} - #{b[:image_url]}"
        end
        puts "\n\n\n"
      end

      Book.new(b)
    end
    @books = @books.sort_by { |b| [b.author_last_name, b.title] }
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

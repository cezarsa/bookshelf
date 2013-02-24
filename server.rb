['models'].each do |path|
  Dir["#{path}/*.rb"].each do |file|
    require_relative file
  end
end

class BookshelfConfig

  def initialize
    begin
      @config = YAML.load_file('config.yml')
    rescue SyntaxError
      @config = {}
    end
    @config['amazon'] ||= {}
    @config['amazon'].merge!({
      'secret' => ENV['AMAZON_SECRET'],
      'key' => ENV['AMAZON_KEY'],
      'email' => ENV['AMAZON_EMAIL'],
      'password' => ENV['AMAZON_PASSWORD']
    }) { |k, v1, v2| v2 ? v2 : v1 }

    if @config['amazon'].any? { |k, v| v.nil? }
      error!
    end
  end

  def error!
    puts <<-END
You have to create a config.yml file with:

amazon:
  key: <your aws api key>
  secret: <your aws api secret>
  email: <your email>
  password: <your password>

    END
    exit -1
  end

  def method_missing(method_id, *args)
    method_id.to_s.split('_').inject(@config) { |acc, p| acc[p] }
  end
end

$bookshelf_config = BookshelfConfig.new

class BookShelf < Sinatra::Base

  configure do
    register Sinatra::StaticAssets

    ASIN::Configuration.configure do |config|
      config.secret        = $bookshelf_config.amazon_secret
      config.key           = $bookshelf_config.amazon_key
      config.associate_tag = 'something'
    end
  end

  configure :development do
    register Sinatra::Reloader
    also_reload './models/*'
  end


  get "/" do
    @books = Books.new($bookshelf_config.amazon_email, $bookshelf_config.amazon_password).all
    @books.delete_if { |b| b.order_data['title'][/dictionary/i] }
    @books.sort_by! { |b| [b.author_last_name, b.title] }

    erb :index
  end
end

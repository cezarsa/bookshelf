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
    rescue
    end
    @config ||= {}
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
    Mongoid.load!("config/mongoid.yml")
    register Sinatra::StaticAssets

    ASIN::Configuration.configure do |config|
      config.secret        = $bookshelf_config.amazon_secret
      config.key           = $bookshelf_config.amazon_key
      config.associate_tag = 'something'
    end
  end

  configure :development do
    Mongoid.logger.level = Logger::DEBUG
    Moped.logger.level = Logger::DEBUG

    register Sinatra::Reloader
    also_reload './models/*'
  end

  def filter_books(books)
    books.delete_if { |b| b.order_data['title'][/dictionary/i] }
    books.sort_by! { |b| [b.author_last_name, b.title] }
  end

  get "/import" do
    erb :import
  end

  post "/import" do

    uuid = UUID.generate
    u = User.new(uuid: uuid, amazon_data: params[:amazondata], last_updated: DateTime.now)

    if u.save
      redirect url("/#{uuid}")
    else
      @errors = u.errors
      erb :import
    end
  end

  get "/:uuid" do |uuid|
    u = User.where(uuid: uuid).first
    data = u.amazon_data.gsub(/\r?\n/m, '').gsub(/(,|{)(\w+?):/, '\1"\2":')

    @books = Books.new(data).all
    filter_books(@books)

    erb :index
  end

  get "/" do
    @books = Books.new(nil, $bookshelf_config.amazon_email, $bookshelf_config.amazon_password).all
    filter_books(@books)

    erb :index
  end

end

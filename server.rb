['models'].each do |path|
  Dir["#{path}/*.rb"].each do |file|
    require_relative file
  end
end

begin
  $bookshelf_config = YAML.load_file('config.yml')
rescue SyntaxError
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

class BookShelf < Sinatra::Base

  configure do
    register Sinatra::StaticAssets

    ASIN::Configuration.configure do |config|
      config.secret        = $bookshelf_config['amazon']['secret']
      config.key           = $bookshelf_config['amazon']['key']
      config.associate_tag = 'something'
    end
  end

  configure :development do
    register Sinatra::Reloader
    also_reload './models/*'
  end


  get "/" do
    @books = Books.new($bookshelf_config['amazon']['email'], $bookshelf_config['amazon']['password']).all
    @books.delete_if { |b| b.order_data['title'][/dictionary/i] }
    @books.sort_by! { |b| [b.author_last_name, b.title] }

    erb :index
  end
end

require 'mechanize'
require 'json'

class Books
  AMAZON_URL = "http://www.amazon.com/"
  KINDLE_BOOKS_URL = "https://www.amazon.com/gp/digital/fiona/manage/features/order-history/ajax/queryOwnership_refactored2.html?offset=0&count=100"
  CACHE_MAX_AGE = 24 * 60 * 60

  def initialize(email, password)
    @email = email
    @password = password

    books = fetch_from_cache
    if books
      @books = books.map { |b| Book.from_cache(b) }
    else
      raise "password required" if password.nil?
      @books = fetch_from_amazon
      update_cache(@books)
    end
  end

  def fetch_from_amazon
    agent = Mechanize.new do |agent|
      agent.user_agent_alias = 'Mac Safari'
      agent.follow_meta_refresh = true
      agent.redirect_ok = true
    end

    page = agent.get(AMAZON_URL)
    page = page.link_with(:id => 'nav-your-account').click

    form = page.form_with(:name => 'signIn')
    form.email = @email
    form.password = @password
    form.radiobutton_with(:name => 'create', :value => '0').check
    page = form.submit

    page = agent.get(KINDLE_BOOKS_URL)
    books_data = JSON.parse(page.content)
    
    books = books_data['data']['items']

    client = ASIN::Client.instance

    all_results = []
    books.each_slice(10) do |books_slice|
      all_results += client.lookup(books_slice.map {|b| b['asin'] })
    end
    books_data = {}
    all_results.each { |b| books_data[b.asin] = b }

    books.map do |order_data|
      order_data['author'] = CGI.unescapeHTML(order_data['author'])
      order_data['title'] = CGI.unescapeHTML(order_data['title'])
      book_data = books_data[order_data['asin']]
      error_count = 5
      sleep_on_error = 0.5

      unless book_data
        begin
          title = order_data['title'].match(/(.*?)(\(|$)/)[1].strip
          book_data = client.search({:SearchIndex => :Books, :Author => order_data['author'], :Title => title, :ResponseGroup => :Medium})
          if book_data.size > 0
            book_data = book_data.min_by do |b|
              Text::Levenshtein.distance(order_data['title'], b.title)
            end
          else
            book_data = nil
          end
        rescue
          sleep(sleep_on_error)
          sleep_on_error *= 2
          error_count -= 1
          raise if error_count == 0
          retry
        end
      end
      
      if book_data
        Book.from_amazon(book_data, order_data)
      end
    end.compact
  end

  def cache_file_name
    "#{@email}-books.json"
  end

  def fetch_from_cache
    return nil unless File.exist? cache_file_name

    File.open(cache_file_name) do |f|
      return nil if Time.now.to_i > f.stat.mtime.to_i + CACHE_MAX_AGE
      return JSON.parse(f.read())
    end
  end

  def update_cache(books)
    File.open(cache_file_name, 'w') do |f|
      f.write(JSON.dump(books.map { |b| b.to_hash }))
    end
  end

  def all
    @books
  end

end

class Book
  attr_accessor :book_data, :order_data

  def self.from_amazon(book_data, order_data)
    Book.new({
      'order_data' => order_data,
      'book_data' => book_data.nil? ? {} : book_data.raw
    })
  end

  def self.from_cache(book_data)
    Book.new book_data
  end
    
  def asin
    book_data['ASIN']
  end

  def author
    author = book_data['Author'] ? book_data['Author'] : book_data['ItemAttributes']['Author']
    author || order_data['author'].split(',').map(&:strip).reverse.join(' ') || ''
  end

  def title
    order_data['title']
  end

  def image
    order_data['image'].gsub('._SX105_', '')
  end

  def order_date
    order_data['orderDateEpoch']
  end

  def author_last_name
    base_author = author
    if base_author.kind_of? Enumerable
      base_author = author[0]
    end
    base_author.split[-1] || ''
  end

  def initialize(args)
    @order_data = args['order_data']
    @book_data = args['book_data']
  end

  def to_hash
    {
      :book_data => @book_data,
      :order_data => @order_data
    }
  end
end

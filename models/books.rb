require 'mechanize'
require 'json'
require 'set'


class User
  include Mongoid::Document

  field :user_id, type: String
  field :books, type: Array
  field :last_updated, type: DateTime

  attr_accessor :access_token

  def each_goodreads_books
    wanted_shelves = Set['read', 'currently-reading']
    client = Goodreads.new(oauth_token: access_token)
    page = 1
    while true
      shelf = client.shelf(user_id, nil, page: page, per_page: 200)
      break if shelf.nil? || shelf.books.nil? || shelf.books.size == 0
      shelf.books.each do |shelf_book|
        shelf = shelf_book.shelves.shelf
        unless shelf.kind_of? Array
          shelf = [shelf]
        end
        shelf_names = Set.new(shelf.map(&:name))
        if (shelf_names & wanted_shelves).size > 0
          yield shelf_book.book
        end
      end
      page += 1
    end
  end

  def load_books(force_update)
    if self.books && self.books.size > 0 && !force_update
      existing_books = self.books.map { |book| Book.new(book) }
      self.check_new(existing_books)
    else
      self.update_books!
    end
  end

  def check_new(existing_books)
    new_books = []
    existing_ids = Set.new(existing_books.map { |book| book.id })

    self.each_goodreads_books do |goodreads_data|
      next if existing_ids.include?(goodreads_data['id'])
      new_books << Book.new(goodreads_data: goodreads_data)
    end

    return self.save_new_books(existing_books + new_books)
  end

  def update_books!
    books = []
    self.each_goodreads_books do |goodreads_data|
      books << Book.new(goodreads_data: goodreads_data)
    end

    self.save_new_books(books)
  end

  def save_new_books(books)
    books = books.sort_by { |b| [b.author_last_name, b.pub_date, b.title] }

    self.books = books.map(&:to_hash)
    self.last_updated = DateTime.now
    self.upsert
    books
  end
end

def pipeline_first(*blks)
  last_val = nil
  blks.each do |b|
    last_val = b.call
    break if last_val
  end
  last_val
end

BOOK_ATTRS = [:goodreads_data, :goodreads_ext_data, :amazon_data]
MAX_RETRIES = 5

class Book

  attr_accessor *BOOK_ATTRS

  def initialize(data)
    BOOK_ATTRS.each do |var|
      self.instance_variable_set("@#{var}".to_sym, data[var] || data[var.to_s])
    end
    if data[:prevent_best_book]
      @prevent_best_book = true
    end
    update_cover
    update_pub_date
    clean_data
  end

  def clean_data
    if @goodreads_data
      @goodreads_data.delete('similar_books')
      @goodreads_data.delete('reviews_widget')
    end
    @goodreads_ext_data = nil
    @amazon_data = nil
  end

  def with_retries
    retries = MAX_RETRIES
    while retries > 0
      retries -= 1

      begin
        yield
        break
      rescue Exception => e
        to_sleep = 2**(MAX_RETRIES - retries)
        puts "Request error #{e}, retrying in #{to_sleep}s"
        sleep(to_sleep)
        raise if retries == 0
      end
    end
  end

  def goodreads_ext_data
    return @goodreads_ext_data if @goodreads_ext_data
    puts "Fetching goodreads_ext_data for #{self.title}"

    with_retries do
      client = Goodreads.new
      @goodreads_ext_data = client.book(goodreads_data['id'])
    end
    @goodreads_ext_data
  end

  def amazon_data
    return @amazon_data if @amazon_data
    puts "Fetching amazon_data for #{self.title} - #{self.id}"

    item = []
    source = :asin
    asin_client = ASIN::Client.instance
    with_retries do
      asin = goodreads_data['asin'] || goodreads_data['isbn'] || goodreads_ext_data['asin'] || goodreads_ext_data['isbn']
      item = asin_client.lookup(asin)
    end
    if item.size == 0
      source = :text
      with_retries do
        keywords = "#{self.title.gsub(/\(.*\)/, '').strip} #{self.author}"
        puts "Trying amazon text search for #{keywords}"
        item = asin_client.search_keywords(keywords)
      end
    end
    if item.size > 0
      @amazon_data = {data: item[0], source: source}
    end
    @amazon_data
  end

  def valid_cover?
    goodreads_data['image_url'] && !(goodreads_data['image_url'] =~ /nocover|nophoto/)
  end

  def best_book
    return @best_book if @best_book
    return nil if @prevent_best_book
    best_book_id = goodreads_data['work'] && goodreads_data['work']['best_book_id']
    unless best_book_id
      best_book_id = goodreads_ext_data['work'] && goodreads_ext_data['work']['best_book_id']
    end
    puts "Fetching best book from #{self.title}: #{best_book_id}"
    return nil unless best_book_id
    client = Goodreads.new
    best_data = client.book(best_book_id)
    @best_book = Book.new(goodreads_data: best_data, prevent_best_book: true)
  end

  def update_cover
    return if self.valid_cover?

    amazon_data = self.amazon_data
    new_cover = pipeline_first(
      lambda {
        break unless amazon_data && amazon_data[:source] == :asin
        data = amazon_data[:data]
        data && data['LargeImage'] && data['LargeImage']['URL']
      },
      lambda {
        bb = self.best_book
        bb.image if bb
      },
      lambda {
        break unless amazon_data
        data = amazon_data[:data]
        data && data['LargeImage'] && data['LargeImage']['URL']
      }
    )

    if new_cover
      goodreads_data['image_url'] = new_cover
    end
  end

  def update_pub_date
    return if goodreads_data['publication_year']

    bb = self.best_book
    if bb && bb.goodreads_data["publication_year"]
      goodreads_data["publication_year"],
      goodreads_data["publication_month"],
      goodreads_data["publication_day"] =
        bb.goodreads_data["publication_year"],
        bb.goodreads_data["publication_month"],
        bb.goodreads_data["publication_day"]
      return
    end

    data = self.amazon_data
    pub_date = data && data['ItemAttributes'] && data['ItemAttributes']['PublicationDate']

    if pub_date
      goodreads_data["publication_year"], goodreads_data["publication_month"], goodreads_data["publication_day"] = pub_date.split('-')
    end
  end

  def id
    goodreads_data['id']
  end

  def author
    goodreads_data['authors']['author']['name'].strip
  end

  def title
    goodreads_data['title']
  end

  def image
    (goodreads_data['image_url'] || '').gsub(/books\/(.+)m\//, "books/\\1l/")
  end

  def pub_date
    "%04d-%02d-%02d" % [goodreads_data["publication_year"].to_i, goodreads_data["publication_month"].to_i, goodreads_data["publication_day"].to_i]
  end

  def author_last_name
    author.split[-1] || ''
  end

  def to_hash
    {
      :goodreads_data => @goodreads_data
    }
  end

end

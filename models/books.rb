require 'mechanize'
require 'json'


class User
  include Mongoid::Document

  field :user_id, type: String
  field :books, type: Array
  field :last_updated, type: DateTime

  attr_accessible :user_id, :books, :last_updated
end


BOOK_ATTRS = [:goodreads_data, :goodreads_ext_data, :amazon_data]
MAX_RETRIES = 5

class Book

  attr_accessor *BOOK_ATTRS

  def initialize(data)
    BOOK_ATTRS.each do |var|
      self.instance_variable_set("@#{var}".to_sym, data[var] || data[var.to_s])
    end
    try_cover
    try_pub_date
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
    return @goodreads_ext_data unless @goodreads_ext_data.nil?
    puts "Fetching goodreads_ext_data for #{self.title}"

    with_retries do
      client = Goodreads.new
      @goodreads_ext_data = client.book(goodreads_data['id'])
    end

    @goodreads_ext_data = false unless @goodreads_ext_data
    @goodreads_ext_data
  end

  def amazon_data
    return @amazon_data unless @amazon_data.nil?
    puts "Fetching amazon_data for #{self.title}"

    with_retries do
      asin_client = ASIN::Client.instance
      asin = goodreads_data['asin'] || goodreads_data['isbn'] || goodreads_ext_data['asin'] || goodreads_ext_data['isbn']
      item = asin_client.lookup(asin)
      if item.size == 0
        keywords = "#{self.title.gsub(/\(.*\)/, '').strip} #{self.author}"
        puts "Trying amazon text search for #{keywords}"
        item = asin_client.search_keywords(keywords)
      end
      if item.size > 0
        @amazon_data = item[0].raw
      end
    end

    @amazon_data = false unless @amazon_data
    @amazon_data
  end

  def try_cover
    return if goodreads_data['image_url'] && !(goodreads_data['image_url'] =~ /nocover/)

    data = self.amazon_data
    if data
      goodreads_data['image_url'] = data['LargeImage']['URL']
    end
  end

  def try_pub_date
    return if goodreads_data['publication_year']

    data = self.amazon_data
    if data
      pub_date = data['ItemAttributes']['PublicationDate'].split('-')
      goodreads_data["publication_year"], goodreads_data["publication_month"], goodreads_data["publication_day"] = pub_date
    end
  end

  def author
    goodreads_data['authors']['author']['name'].strip
  end

  def title
    goodreads_data['title']
  end

  def image
    goodreads_data['image_url'].gsub(/books\/(.+)m\//, "books/\\1l/")
  end

  def pub_date
    "%04d-%02d-%02d" % [goodreads_data["publication_year"].to_i, goodreads_data["publication_month"].to_i, goodreads_data["publication_day"].to_i]
  end

  def author_last_name
    author.split[-1] || ''
  end

  def to_hash
    BOOK_ATTRS.reduce({}) { |res, item| res[item] = send(item); res }
  end

end

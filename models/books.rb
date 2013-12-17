require 'mechanize'
require 'json'


class User
  include Mongoid::Document

  field :uuid, type: String
  field :amazon_data, type: String
  field :last_updated, type: DateTime
end

class BookList
  def initialize(amazondata)
    books = JSON.parse(amazondata)
    @books = books['data']['items'].map do |order_data|
      if order_data['firstOrderDate'] == 0
        puts "Ignoring - #{order_data['title']}"
      else
        Book.new(order_data)
      end
    end.compact

  end

  def all
    @books
  end
end

class Book

  attr_accessor :author, :title, :image

  def initialize(data)
    @author = data[:authors][:author][:name]
    @title = data[:title]
    @image = data[:image_url].gsub(/books\/(.+)m\//, "books/\\1l/")
  end

  def author_last_name
    author.split[-1] || ''
  end

end

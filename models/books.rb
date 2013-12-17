require 'mechanize'
require 'json'


class User
  include Mongoid::Document

  field :user_id, type: String
  field :books, type: Array
  field :last_updated, type: DateTime

  attr_accessible :user_id, :books, :last_updated
end

class Book

  attr_accessor :author, :title, :image

  def initialize(data)
    @author = data[:author] || data['author']
    @title = data[:title] || data['title']
    @image = data[:image] || data['image']
  end

  def author_last_name
    author.split[-1] || ''
  end

  def to_hash
    {
      author: author,
      title: title,
      image: image
    }
  end

end

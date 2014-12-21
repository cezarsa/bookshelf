source 'https://rubygems.org'
ruby '1.9.3', :engine => 'jruby', :engine_version => '1.7.16.1'

gem 'mechanize'
gem 'sinatra', :require => "sinatra/base"
gem 'sinatra-contrib', :require => false
gem 'sinatra-static-assets'
gem 'httpclient'
gem 'text'
gem 'mongoid', github: 'mongoid/mongoid'
gem 'uuid'
gem 'multi_xml'
gem 'goodreads', github: 'cezarsa/goodreads'
gem 'omniauth'
gem 'omniauth-oauth'
gem 'omniauth-goodreads'
gem 'bson'
gem 'puma'
gem 'asin', '~> 2.0'
gem 'rubyntlm', '~> 0.3.2'

platforms :ruby do
  gem 'bson_ext'
  group :development do
    gem 'byebug'
  end
end

platforms :jruby do
  # gem 'pacer-orient', '~> 2.3.3.pre'
  group :development do
    gem 'ruby-debug'
  end
end

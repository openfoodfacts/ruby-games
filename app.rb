require 'sinatra'
require 'sinatra/reloader' if development?

require_relative './app_static'
require_relative './app_processing'

require 'sinatra'

# Static

set :public_folder, Proc.new { File.join(root, 'public') }
set :static, true

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

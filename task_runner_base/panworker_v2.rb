require 'active_record'
require 'faraday'

ActiveRecord::Base.establish_connection(ENV["DB_CONNECT_STR"])

def run_code(code,model)
  open("#{model}.rb","w") {|f| f.write(code) }
  load "./#{model}.rb"
  File.delete("./#{model}.rb")
end

def http_get(url)
  body = ""
  begin
      body = Faraday.new(url).get.body  # use default proxy
  rescue
      body = Faraday.new(url, proxy:"http://127.0.0.1:1087").get.body  # use local proxy for last try
  end
  return body
end

## load data model from github
models = ["application_record","task"]
models.each do |model| 
  url = "https://raw.githubusercontent.com/adam429/panscan/main/panscan/app/models/#{model}.rb"
  body = http_get(url)
  run_code(body,model)
end

puts "==start run_loop=="
Task.run_loop(ENV["WORKER_NAME"])

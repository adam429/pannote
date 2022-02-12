# 初始化
require 'active_record'
require 'faraday'
require 'histogram/array' 
require 'parallel'
require 'vega'

ActiveRecord::Base.establish_connection(ENV["DB_CONNECT_STR"])

def run_code(code,model)
  open("#{model}.rb","w") {|f| f.write(code) }
  load "./#{model}.rb"
end

## load data model from github
models = ["application_record","address","cache","block","epoch","epoch_detail","event","transfer","tx","task"]
models.each do |model| 
  url = "https://raw.githubusercontent.com/adam429/panscan/main/panscan/app/models/#{model}.rb"
  body = Faraday.get(url).body
  run_code(body,model)
end

## read-only for models
code = """
  class ApplicationRecord < ActiveRecord::Base
    after_initialize :readonly!
    def delete
      raise ActiveRecord::ReadOnlyRecord
    end
  end
"""
run_code(code,"readonly")


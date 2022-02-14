# 初始化
require 'active_record'
require 'ethereum.rb'
require 'eth'
require 'faraday'
require 'histogram/array' 
require 'parallel'
require 'resolv-replace'
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
    def delete
      raise ActiveRecord::ReadOnlyRecord
    end
    before_create { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }
    before_save {
      if self.class==Address and self.changed_attributes.filter {|k,v| k!='tag'}=={} then
      else 
        raise ActiveRecord::ReadOnlyRecord 
      end
    }
  end
"""
run_code(code,"readonly") if not $data_import


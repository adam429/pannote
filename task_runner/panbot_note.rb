# 初始化
require 'active_record'
require 'ethereum.rb'
require 'eth'
require 'faraday'
require 'histogram/array' 
require 'parallel'
require 'resolv-replace'
require 'vega'


contract_name = "PancakePredictionV2"
contract_addr = "0x18B2A687610328590Bc8F2e5fEdDe3b582A49cdA".downcase
bscscan_apikey = "HIFNPQFV6MY755QMVPFIAY7F25RUTHI26Z"


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



$client = Ethereum::HttpClient.new(ENV["HTTP_ENDPOINT"])

api_url = "https://api.bscscan.com/api?module=contract&action=getabi&address=#{contract_addr}&apikey=#{bscscan_apikey}"
abi = JSON.parse(JSON.parse(response = Faraday.get(api_url).body)["result"])

$contract = Ethereum::Contract.create(
        client: $client, 
        name: contract_name, 
        address: contract_addr, 
        abi: abi)



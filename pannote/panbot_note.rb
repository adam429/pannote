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
models = ["application_record","address","cache","block","epoch","epoch_detail","event","transfer","log","tx","task"]
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


def address_graph_expand(addr,exclude)
  addr_list = addr.map {|x| x.to_a[0][1]}.uniq

  expend_all_addr = Transfer.where(from:addr_list).map {|x| x.to} + Transfer.where(to:addr_list).map {|x| x.from} + addr_list
  expend_addr = expend_all_addr.uniq.filter { |x| not exclude[x]}
  ret = expend_addr.map {|x| [["(input)",x]].to_h }
      
  return ret
end


def auto_tag_name(addr,name)
    puts name
    addr_list = addr.map {|x| x.to_a[0][1]}.uniq

    bet_transfer_ratio = Address.where(addr:addr_list).map {|x|
        call_method_count = Tx.where('"to"=? or "from"=?',x.addr,x.addr).where("method_name=? or method_name=?","betBear","betBull").count; 
        transfer_count = Transfer.where('"to"=? or "from"=?',x.addr,x.addr).where(method_name:"Transfer").count; 
        [x.addr, call_method_count ,transfer_count ]
    }
    .map {|x| [x[0],x[1].to_f/x[2],x[1],x[2]]}
    .sort {|x,y| x[1]<=>y[1]}

    panbot_account_list = bet_transfer_ratio.filter {|x| not( x[1]<=0.05 ) }.map {|x| x[0]}
    money_account_list = bet_transfer_ratio.filter {|x| x[1]<=0.05  }.map {|x| x[0]}

    puts "panbot_account_list.count = #{panbot_account_list.count}"
    puts "money_account_list.count = #{money_account_list.count}"

    panbot_account_list.each_with_index {|x,i| addr=Address.find_by_addr(x);addr.tag="#{name} bot #{i}"; addr.save}
    money_account_list.each_with_index {|x,i| addr=Address.find_by_addr(x);addr.tag="#{name} money #{i}"; addr.save}
    
end

def auto_tag(tagspace,addr)
  used_tag = Address.where('tag is not null').filter {|x| tagspace.include?(x.tag.split(" ")[0]) }.map {|x| x.tag.split(" ")[0]}.uniq
  open_tag = tagspace-used_tag

  auto_tag_name(addr,open_tag.pop)
end

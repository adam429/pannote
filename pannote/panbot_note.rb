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

def to_graph(addr,min_amount=0, max_connect=100)
  addr_list = addr.map {|x| x.to_a[0][1]}.uniq

  exclude_addr = addr_list.map { |addr|
      [addr, Transfer.where(from:addr).count, Transfer.where(to:addr).count, Transfer.where(from:addr).sum(:amount)/1e18, Transfer.where(to:addr).sum(:amount)/1e18]
  }.filter{ |x| x[2]>max_connect and x[1]>max_connect}

  addr_list = addr_list.filter {|x| not exclude_addr.map{|x| x[0]}.include?(x) }

  graph = "digraph {\n" +  
    exclude_addr.map {|addr| 
      x=Address.find_by_addr(addr[0]);  
      %Q( "#{x.tag ? x.tag + ' @'+x.addr[-4,4] : x.addr }" [shape=doubleoctagon style=filled] ) + ";\n" + 
      %Q( "group @#{x.addr[-4,4]} trans #{addr[1]+addr[2]}"[style=filled] ) + ";\n" +
      %Q( "#{x.tag ? x.tag + ' @'+x.addr[-4,4] : x.addr }" -> "group @#{x.addr[-4,4]} trans #{addr[1]+addr[2]}" [label=#{addr[3].round(2)}] ) + ";\n" +
      %Q( "group @#{x.addr[-4,4]} trans #{addr[1]+addr[2]}" -> "#{x.tag ? x.tag + ' @'+x.addr[-4,4] : x.addr }" [label=#{addr[4].round(2)}] ) + ";\n"
    }.join("") + 
    Transfer.where(from:addr_list).where(to:addr_list).where("amount > ?",min_amount * 1e18).map {|x|
      %Q( "#{x.ar_from.tag ? x.ar_from.tag + ' @'+x.from[-4,4] : x.from }" -> "#{ x.ar_to.tag ? x.ar_to.tag + ' @'+x.to[-4,4] : x.to}" [label=#{(x.amount/1e18).round(2)}] )
    }.join(";\n") + "\n}"
  url = "https://quickchart.io/graphviz?graph=#{graph.gsub(/\n/,"")}"
  body = Faraday.get(url).body
  IRuby.html body
end


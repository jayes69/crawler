require 'nokogiri'
require 'open-uri'
require 'openssl'
require 'open_uri_redirections'
require 'mechanize'
require 'mail'
require 'diffy'
require 'http-cookie'
require_relative 'lib/eventbus.rb'

def get_id
  puts "Get Page Table"
  page = Nokogiri::HTML(open("https://www.wikifolio.com/de/de/w/wf00esi893"))
  puts "Get wikifolioId"
  match = page.css('script')
  match.each do |m|
    if !(id = /wikifolioId: "(.*?)"/.match(m.to_s)).nil?
      id = id[1]
      puts "ID: #{id}"
      return id
    end
  end
end

def get_xml(agent)
  id = get_id
  time = Time.now().to_i*1000
  page = agent.get("http://wikifolio.com/api/wikifolio/#{id}/tradehistory?page=0&pageSize=10&_=#{time}")
  html = agent.current_page.body
  xml = Nokogiri::XML(html)
  return xml
end

def build_body(event)
  return if !event.is_a?(Hash)
  type = translate_type(event['type'])

  body = "Name: #{event['name']}"                    if !event['name'].nil?
  body << " #{event['isin']}"                        if !event['isin'].nil?
  body << ", Typ: #{type}"                           if !event['type'].nil?
  body << ", Ausgeführt: #{event['date']}"           if !event['date'].nil?
  body << ", Kurs: #{event['price']}"                if !event['price'].nil?
  body << ", Gewichtung: #{event['weightage']}%"     if !event['weightage'].nil?
  body << ", Performance: #{event['performance']}%"  if !event['performance'].nil?
  return body
end

def translate_type(type)
  return if type.nil?
  case type
    when 'Buy'
      type = "Quote Kauf"
    when 'BuyLimit'
      type = "Limit Kauf"
    when 'BuyStopLimit'
      type = "Stop-Limit Kauf"
    when 'Sell'
      type = "Quote Verkauf"
    when 'SellLimit'
      type = "Limit Verkauf"
    when 'SellStopLimit'
      type = 'Stop-Limit Verkauf'
    else
      type = type + ' (nicht übersetzt)'
    end
  return type
end

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = nil

eventbus = Eventbus.new

eventbus.subscribe do |event|
  puts "Subscribe event: #{event}"
  puts "Set Mail options"
  options = { 
    :address              => "mail.medicomit.de",
    :port                 => 25,
    :domain               => 'medicomit.de',
    :user_name            => 'test@medicomit.de',
    :password             => 'te123st',
    :authentication       => 'plain',
    :enable_starttls_auto => false,
    :openssl_verify_mode  => 'none'
  }
  puts "Set Mail defaults"
  Mail.defaults do
    delivery_method :smtp, options
  end
  puts "Create new mail"
  if !event['type'].nil?
    type = translate_type(event['type']) 
  else
    type = ""
  end
  mail = Mail.deliver do
    from    "test@medicomit.de"
    to      "tobias.schneider@net-up.de" #"js@net-up.de"
    subject "Börsenbriefempfehlungen nutzen: " + type
    body    build_body(event)
  end
  puts "Send mail"
  mail.deliver!
end

agent = Mechanize.new
agent.user_agent_alias = 'Windows Chrome'

time = Time.now().to_i*1000

agent.get("https://www.wikifolio.com/dynamic/de/de/login/login?ReturnUrl=/de/de/home-e&_=#{time}") do |page|
  puts "Go to Login"
  folio_form = page.form
  puts "Setting email"
  folio_form.Username = 'support@net-up.de'
  puts "Setting password"
  folio_form.Password = 'Kj23d9MwcQ7rg'
  puts "Login"
  agent.submit(folio_form)

  #first time only
  #xml = get_xml(agent)
  #File.open('old.xml', "w") do |f|
  #  f.write(xml)
  #end

  xml = get_xml(agent)
  File.open('new.xml', "w") do |f|
    f.write(xml)
  end

  diff = Diffy::Diff.new('./old.xml', './new.xml', :source => 'files')
  diff_s = diff.to_s(:html)
  diff_a = diff.to_a

  #write down diff
  File.open('diff.xml', "w") do |f|
    f.write(diff_s)
  end

  if (diff_s == '<div class="diff"></div>')
    puts "NO NEW INFO " + Time.now.to_s
  else
    
    info_hash = {}

    diff_a.each do |line|
      if line.start_with?('+') #new entries
        puts line
        if !(type = /OrderType>(.*?)</.match(line.to_s)).nil?
          type = type[1]
          info_hash['type'] = type
        elsif !(name = /Name>(.*?)</.match(line.to_s)).nil?
          name = name[1]
          info_hash['name'] = name
        elsif !(isin = /Isin>(.*?)</.match(line.to_s)).nil?
          isin = isin[1]
          info_hash['isin'] = isin
        elsif !(date = /ExecutionDate>(.*?)</.match(line.to_s)).nil?
          date = date[1]
          date = DateTime.parse(date)
          date = date.strftime("%d.%m.%Y %H:%M")
          info_hash['date'] = date
        elsif !(price = /ExecutionPrice>(.*?)</.match(line.to_s)).nil?
          price = price[1]
          info_hash['price'] = price
        elsif !(weightage = /Weightage>(.*?)</.match(line.to_s)).nil?
          weightage = weightage[1]
          info_hash['weightage'] = (weightage.to_f*100).round(2)
        elsif !(performance = /Performance>(.*?)</.match(line.to_s)).nil?
          performance = performance[1]
          info_hash['performance'] = (performance.to_f*100).round(2)
        end
      end
    end

    eventbus.publish(info_hash) #send Email

    #new data is saved as old for comparison
    File.open('old.xml', "w") do |f|
      f.write(xml)
    end

    puts "NEW INFO " + Time.now.to_s
  end
end

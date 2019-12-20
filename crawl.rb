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
    when 'BuyStopLimit'
      type = "Stop-Limit Verkauf"
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
  type = translate_type(event['type'])
  mail = Mail.deliver do
    from    "test@medicomit.de"
    to      "tobias.schneider@net-up.de"
    subject "Börsenbriefempfehlungen nutzen: " + type
    body    build_body(event)
  end
  puts "Send mail"
  mail.deliver!
end

agent = Mechanize.new
agent.user_agent_alias = 'Windows Chrome'

agent.get('https://www.wikifolio.com/de/de/home-e') do |page|
  agent.cookies.each do |cookie|
    puts cookie.to_s
  end
  puts "Go to Login"
  agent.click('//html/body/div[2]/div[1]/div/span/div/div/div/div[2]/div/div/div/div/div[3]/div')
  agent.click('//html/body/div[2]/header/div[2]/div/div/nav/div[3]/a[1]/span')
  folio_form = page.form
  puts "Setting email"
  folio_form.Email = 'support@net-up.de'
  puts "Setting password"
  folio_form.Password = 'Kj23d9MwcQ7rg'
  puts "Login"
  agent.submit(folio_form)
  page = agent.get("https://www.wikifolio.com/de/de/w/wf00esi893")
  sleep(10)
  page = agent.get("https://www.wikifolio.com/de/de/w/wf00esi893")
  sleep(5)
  agent.cookies.each do |cookie|
    puts cookie.to_s
  end
  cookie = Mechanize::Cookie.new(name: 'theAuthCookie', value: 'E306D781579ECE947B236A601DEA3A76C67E6EE02C9948A1F86DD93FB905BB51B3DF218E0A53F319436CE62DE82834ECC25A9F94E5ED6E2236DAAFC7EC4002D661CAB9B9CBC100CCB729E1542243D794FEB666134C307B0D35166EE69850E5E35489BEEA654E31C11BBCA30CD95BF30DF78BAC869556DA2D9BB64F213C9206B2E6E79B0645E5BA0A9359F813DC7109B541D5E3AAD5783E7A9B4CAFD535246333F1790E37FD51ED3CE5E633E42D6516BB3EFD1F3C72FBF936E9ABD5076325B54F5C9508AFFF106156BCF179BB532B7075E5EC131D982DC697F426EE14A94ECF22C2B3D756F4224B584B04EA08D27F1E53395551C1410399D4B7BAB80359E36AB31E25D540D945055AF025489D52A28EE7FC01706458005DB76DE752D0240E637DB32E4DD46C5913753251567E792252545E821E6A347AA01AE5C99BCD6DA4C19DE64E8C34790717F818792708DEAE136B9633FBFF3D133228C7C028A3F2C7F4DE7A0C1D2CBE7CE7537B536FE2BE7025AA69C6B65F9D383D75C4E41ECF1323C23604A301F76D87DEC6C58C4534B34C6E04C0103F301DD38120081E78C573F1FD8426E7CB582BADA0A300C966B8E89B9CD8AF0303B9DAC3B48B0CD7A8339361DB6C2FBCB601CCC86DA95938C0B165CF4FFA90DAB97B944E2D0066B64AABE2B1D0A5AB9F79666ADF9F2BFBD9760DD8982018F0F4A69DE8414BC9678E87DDF4C98C304734FDB90E31B3FD6AB88881EF31CDDBC2DDF9E702FC95C0C057194D284A4166CD08A9863D38E910BC003EA08D200A068E922897BB8772B8A7E3BC9CA536B247F13FFFBD')
  cookie.domain = "www.wikifolio.com"
  cookie.path = "/"
  agent.cookie_jar.add(agent.history.last.uri, cookie)
  agent.cookie_jar.save("cookies.yaml", session: true)

  #first time only?
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
          info_hash['weightage'] = weightage
        elsif !(performance = /Performance>(.*?)</.match(line.to_s)).nil?
          performance = performance[1]
          info_hash['performance'] = performance
        end
      end
    end

    eventbus.publish(info_hash) #send Email

    #new data is saved as old for comparison
    File.open('old.xml', "w") do |f|
      f.write(xml)
    end

    #delete diff
    #File.open('diff.xml', 'w') {|file| file.truncate(0) }

    puts "NEW INFO " + Time.now.to_s
  end
end

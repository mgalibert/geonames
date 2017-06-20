def cache_folder(country)
  "#{CACHE_ROOT_FOLDER}/#{country}"
end

def cache_file(country, cache_key)
  "#{cache_folder(country)}/#{cache_key}"
end

def create_cache(country)
  FileUtils::mkdir_p(cache_folder(country))
end

def in_cache?(country, cache_key)
  File.exist?(cache_file(country, cache_key))
end

def write_to_cache(country, cache_key, content)
  create_cache(country)
  File.open(cache_file(country, cache_key), 'w') { |f| f.puts(content) }
end

def read_from_cache(country, cache_key)
  File.read(cache_file(country, cache_key))
end

def search_geonames(name, country)
  cache_key = name.gsub(' ','_').gsub('/','_')

  if in_cache?(country, cache_key)
    if VERBOSE
      puts "Cache HIT for #{country}/#{name}".green
    else
      print '.'.yellow
    end
  else
    if VERBOSE
      puts "Calling API to search for #{country}/#{name}".yellow
    else
      print 'x'.green
    end

    response_body = search_geonames_http_request(name, country)
    write_to_cache(country, cache_key, response_body)
  end

  read_from_cache(country, cache_key)
end

def search_geonames_http_request(name, country)
  begin
    uri = URI.parse(geonames_query(name, country))
    response = Net::HTTP.get_response(uri)
    sleep 0.4
    raise if response.code != "200"
    response.body
  rescue
    puts "Downloading error for #{country}/#{name}".red
    sleep 2
    retry
  end
end

def geonames_query(name, country)
  username = USERNAMES.sample(1)[0]
  url = "http://api.geonames.org/search?name_equals=#{name}&country=#{country}&featureClass=P&type=rdf&orderby=population&maxRows=1&username=#{username}"
  URI.encode(url)
end


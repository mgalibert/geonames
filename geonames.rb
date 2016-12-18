require "csv"
require 'net/http'
require 'nokogiri'
require 'set'
require 'stringex'

CSV_PARAMS = {
          :col_sep => ';',
          :headers => true,
          :header_converters => :symbol,
        }

LOCALES = { 
  "fr" => "FR",
  "en" => "GB",
  "da" => "DK",
  "de" => "DE",
  "it" => "IT",
  "cs" => "CZ",
  "es" => "ES",
  "hu" => "HU",
  "ja" => "JA",
  "ko" => "KO",
  "nl" => "NL",
  "pl" => "PL",
  "pt" => "PT",
  "ru" => "RU",
  "sv" => "SE",
  "tr" => "TR",
  "zh" => "ZH"
}

USERNAMES = [
  "capitainetrain",
  "michelgalibert",
  "michelgalibert2",
  "michelgalibert3"
]

NAMES_NOT_FOUND = Set.new
NAMES_WITHOUT_TRANSLATIONS = Set.new
WORDS_TO_REMOVE = Set.new

CSV.foreach("names_not_found.csv", CSV_PARAMS) do |row|
  NAMES_NOT_FOUND << row[:name]
end

CSV.foreach("names_without_translations.csv", CSV_PARAMS) do |row|
  NAMES_WITHOUT_TRANSLATIONS << row[:name]
end

CSV.foreach("words_to_remove.csv", CSV_PARAMS) do |row|
  WORDS_TO_REMOVE << row[:word]
end

def clean_name(row)
  cleaned_name = row[:name].dup

  WORDS_TO_REMOVE.each do |word|
    cleaned_name.gsub!(/ #{word}$/, "")
    cleaned_name.gsub!(/ #{word.capitalize}$/, "")
    cleaned_name.gsub!(/ #{word.downcase}$/, "")
    cleaned_name.gsub!(/ #{word.upcase}$/, "")
  end

  cleaned_name.gsub!(/ \(.+\)/, "")

  if row[:country] == "FR"
    cleaned_name.gsub!("St-", "Saint-")
    cleaned_name.gsub!("Ste-", "Sainte-")
    cleaned_name.gsub!(/ Lycée.+$/, "")
  end

  cleaned_name
end

def geonames_query(name, country)
  username = USERNAMES.sample(1)[0]
  url = "http://api.geonames.org/search?name_equals=#{name}&country=#{country}&featureClass=P&type=rdf&orderby=population&maxRows=1&username=#{username}"
  URI.encode(url)
end

def valid_name(name)
  !NAMES_NOT_FOUND.include?(name) &&
  !NAMES_WITHOUT_TRANSLATIONS.include?(name) &&
  name !~ /[0-9]/
end

def clean_translations(raw_translations)
  translations = {}
  raw_translations.each do |raw_translation|
    language = raw_translation[:"xml:lang"]
    translations[language] = raw_translation.inner_html
  end
  translations
end

def slugify(name)
  name.gsub(/[\/\.]/,"-").to_ascii.to_url
end

def is_valid_city(original_name, searched_name, result_name)
  [slugify(original_name), slugify(searched_name)].include?(slugify(result_name))
end

def is_valid_translation(searched_name, row, language, translation)                                
  !LOCALES[language].nil? &&                        # Check if the language is supported
  LOCALES[language] != row[:country] &&             # Do not add a translation for the station country
  (if ["ru", "ko", "zh", "ja"].include?(language)   # Check if translation is different than the station name
    translation !~ /[a-zA-Z]/
  else
    slugify(translation)    !~ /(^|-)(l|d)?(#{slugify(searched_name)}|#{slugify(row[:name])})s?(-|$)/ &&
    slugify(searched_name)  !~ /(^|-)(l|d)?#{slugify(translation)}s?(-|$)/ &&
    slugify(row[:name])     !~ /(^|-)(l|d)?#{slugify(translation)}s?(-|$)/
  end)
end

CSV.open('stations2.csv', 'w', CSV_PARAMS) do |csv|

  CSV.open('names_not_found.csv', 'a', CSV_PARAMS) do |names_not_found_csv|

    CSV.open('names_without_translations.csv', 'a', CSV_PARAMS) do |names_without_translations_csv|

      # Copy headers from original file
      headers = CSV.foreach("../stations/stations.csv", {:col_sep => ";"}).first
      csv << headers

      # Importing rows from original file
      CSV.foreach("../stations/stations.csv", CSV_PARAMS) do |row|

        original_name = row[:name]
        searched_name = clean_name(row)
        if valid_name(searched_name)
          begin
            #puts "Downloading XML for #{searched_name} (#{row[:name]} #{row[:id]})"
            uri = URI.parse(geonames_query(searched_name, row[:country]))
            response = Net::HTTP.get_response(uri)
            sleep 0.4
            if response.code != "200"
              raise
            end
          rescue
            puts "Connection error for #{row[:name]}"
            sleep 2
            retry
          end
          begin
            response_xml = Nokogiri::XML(response.body)
            city = response_xml.at_xpath("//gn:Feature")
          rescue
            puts "There is a problem with Nokogiri. Retrying"
            sleep 2
            retry
          end
          if !city.nil?
            result_name  = city.xpath("//gn:name").inner_html
            translations = clean_translations(city.xpath("//gn:alternateName"))
            if translations.any? && 
              is_valid_city(original_name, searched_name, result_name) &&
              translations.any? {|language, translation| is_valid_translation(searched_name, row, language, translation) }
                translations.each do |language, translation|
                  if is_valid_translation(searched_name, row, language, translation) && row[:"info#{language}"].nil?               
                    row[:"info#{language}"] = translation
                    if !["ru", "ko", "zh", "ja"].include?(language)
                      p "Translation found for #{searched_name} (#{row[:name]} #{row[:id]})"
                      p "#{language}: #{translation}"
                    end
                  end
                end
            else
              NAMES_WITHOUT_TRANSLATIONS << searched_name
              names_without_translations_csv << [searched_name]
            end
          else
            NAMES_NOT_FOUND << searched_name
            names_not_found_csv << [searched_name]
          end
        end
      csv << row
      end
    end
  end
end

require "csv"
require 'net/http'
require 'nokogiri'
require 'set'

csv_params = {
          :col_sep => ';',
          :headers => true,
          :header_converters => :symbol,
        }

LOCALES = [ "fr",
            "en",
            "da",
            "de",
            "it",
            "cs",
            "es",
            "hu",
            "ja",
            "ko",
            "nl",
            "pl",
            "pt",
            "ru",
            "sv",
            "tr",
            "zh"
         ]

NAMES_NOT_FOUND = Set.new
NAMES_WITHOUT_TRANSLATIONS = Set.new
WORDS_TO_REMOVE = Set.new

CSV.foreach("geonames/names_not_found.csv", csv_params) do |row|
  NAMES_NOT_FOUND << row[:name]
end

CSV.foreach("geonames/names_without_translations.csv", csv_params) do |row|
  NAMES_WITHOUT_TRANSLATIONS << row[:name]
end

CSV.foreach("geonames/words_to_remove.csv", csv_params) do |row|
  WORDS_TO_REMOVE << row[:word]
end

def clean_name(row)
  cleaned_name = row[:name].dup

  WORDS_TO_REMOVE.each do |word|
    cleaned_name.gsub!(/ #{word}$/, "")
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
  url = "http://api.geonames.org/search?name_equals=#{name}&country=#{country}&featureClass=P&type=rdf&orderby=population&username=capitainetrain"
  URI.encode(url)
end

def valid_name(name)
  !NAMES_NOT_FOUND.include?(name) &&
  !NAMES_WITHOUT_TRANSLATIONS.include?(name) &&
  (name =~ /\d/).nil?
end

def clean_translations(raw_translations)
  translations = {}
  raw_translations.each do |raw_translation|
    language = raw_translation[:"xml:lang"]
    translations[language] = raw_translation.inner_html
  end
  translations
end


def valid_translation(searched_name, row, language, translation)

  # Check if the translation country is supported
  #LOCALES.include?(language) &&
  ["da", "sv"].include?(language) &&

  # Do not add a translation for the station country
  language != row[:country].downcase &&

  # Do not replace an existing translation
  row[:"info#{language}"].nil? &&

  # Make sure the translation is different than the searched name
  searched_name != translation &&

  # Make sure the translation is different than the original name
  row[:name] != translation
end


CSV.open('stations2.csv', 'w', csv_params) do |csv|

  CSV.open('names_not_found.csv', 'a', csv_params) do |names_not_found_csv|

    CSV.open('names_without_translations.csv', 'a', csv_params) do |names_without_translations_csv|

      # Copy headers from original file
      headers = CSV.foreach("stations.csv", {:col_sep => ";"}).first
      csv << headers

      # Importing rows from original file
      CSV.foreach("stations.csv", csv_params) do |row|

        # Search translation for suggestable row only
        if row[:is_suggestable] == "t" && row[:country] == "DK"
          searched_name = clean_name(row)

          if valid_name(searched_name)
            begin
              puts "Downloading XML for #{searched_name} (#{row[:name]})"
              uri = URI.parse(geonames_query(searched_name, row[:country]))
              response = Net::HTTP.get_response(uri)
              sleep 2
              if response.code != "200"
                raise
              end

            rescue
              puts "Connection error for #{row[:name]}"
              sleep 5
              retry
            end

            begin
              response_xml = Nokogiri::XML(response.body)
              city = response_xml.at_xpath("//gn:Feature")
            rescue
              puts "There is a problem with Nokogiri. Retrying"
              sleep 5
              retry
            end

            if !city.nil?
              translations = clean_translations(city.xpath("//gn:alternateName"))
              if !translations.empty?
                if translations.values.include?(searched_name)
                  translations.each do |language, translation|
                    if valid_translation(searched_name, row, language, translation)
                      row[:"info#{language}"] = translation
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
        end
      csv << row
      end
    end
  end
end

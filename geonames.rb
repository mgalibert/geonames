require "csv"
require 'net/http'
require 'nokogiri'
require 'set'
require 'stringex'
require 'colorize'
require 'fileutils'

require_relative './lib/constants'
require_relative './lib/utils'
require_relative './lib/geonames_api'

NAMES_NOT_FOUND            = load_set_from_csv(NAMES_NOT_FOUND_FILE, :name)
NAMES_WITHOUT_TRANSLATIONS = load_set_from_csv(NAMES_WITHOUT_TRANSLATIONS_FILE, :name)
WORDS_TO_REMOVE            = load_set_from_csv(WORDS_TO_REMOVE_FILE, :word)

VERBOSE = false

def clean_name(name, country)
  cleaned_name = name.dup

  WORDS_TO_REMOVE.each do |word|
    cleaned_name.gsub!(/ #{word}$/, "")
    cleaned_name.gsub!(/ #{word.capitalize}$/, "")
    cleaned_name.gsub!(/ #{word.downcase}$/, "")
    cleaned_name.gsub!(/ #{word.upcase}$/, "")
  end

  cleaned_name.gsub!(/ \(.+\)/, "")

  if country == "FR"
    cleaned_name.gsub!("St-", "Saint-")
    cleaned_name.gsub!("Ste-", "Sainte-")
    cleaned_name.gsub!(/ Lycée.+$/, "")
  end

  cleaned_name
end

def valid_name?(name)
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

CSV.open(MODIFIED_STATIONS_FILE, 'w', CSV_PARAMS) do |out_csv|
  CSV.open(NAMES_NOT_FOUND_FILE, 'a', CSV_PARAMS) do |names_not_found_csv|
    CSV.open(NAMES_WITHOUT_TRANSLATIONS_FILE, 'a', CSV_PARAMS) do |names_without_translations_csv|

      # Copy headers from original file
      headers = CSV.foreach(ORIGINAL_STATIONS_FILE, {:col_sep => ";"}).first
      out_csv << headers

      # Reading rows from original file
      CSV.foreach(ORIGINAL_STATIONS_FILE, CSV_PARAMS) do |row|
        original_name = row[:name]
        country       = row[:country]
        searched_name = clean_name(original_name, country)
        if valid_name?(searched_name)
          response_body = search_geonames(searched_name, country)

          begin
            response_xml = Nokogiri::XML(response_body)
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
                  if is_valid_translation(searched_name, row, language, translation) && row[:"info#{language}"] !=  translation
                    if !["ru", "ko", "zh", "ja"].include?(language)
                      puts "Translation found for #{searched_name} (#{row[:name]} #{row[:id]}) -> #{language}: #{translation}".green
                    end
                    if row[:"info#{language}"].nil?
                      row[:"info#{language}"] = translation
                    else
                      puts "Preventing #{language} update because there is already a comment: #{row[:"info#{language}"]} (fresh: #{translation})".yellow
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

        out_csv << row
      end
    end
  end
end

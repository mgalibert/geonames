require "csv"

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

STATIONS = CSV.read("stations2.csv", CSV_PARAMS)
STATIONS_BY_ID = STATIONS.inject({}) { |hash, station| hash[station[:id]] = station; hash }

CSV.open('stations3.csv', 'w', CSV_PARAMS) do |csv|
  # Copy headers from original file
  headers = CSV.foreach("stations2.csv", {:col_sep => ";"}).first
  csv << headers

  # Importing rows from original file
  STATIONS.each do |row|
    parent = STATIONS_BY_ID[row[:parent_station_id]]
    if !parent.nil? && 
      row[:is_suggestable] == "t" &&
      parent[:is_suggestable] == "t"
      LOCALES.keys.each do |locale|
        if row[:"info#{locale}"].nil? && !parent[:"info#{locale}"].nil?
          row[:"info#{locale}"] = parent[:"info#{locale}"]
          puts "Station #{row[:name]} (#{row[:id]}) has a new localized info in “#{locale}”: #{row[:"info#{locale}"]}"
        end
      end
    end

    csv << row
  end
end
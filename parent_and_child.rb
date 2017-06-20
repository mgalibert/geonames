require "csv"
require "colorize"

require_relative './lib/constants'
require_relative './lib/utils'

STATIONS = load_csv("stations2.csv")
STATIONS_BY_ID = STATIONS.inject({}) { |hash, station| hash[station[:id]] = station; hash }

CSV.open(POLISHED_STATIONS_FILE, 'w', CSV_PARAMS) do |csv|
  # Copy headers from original file
  headers = CSV.foreach(MODIFIED_STATIONS_FILE, {:col_sep => ";"}).first
  csv << headers

  # Importing rows from original file
  STATIONS.each do |row|
    parent = STATIONS_BY_ID[row[:parent_station_id]]

    if !parent.nil? && row[:is_suggestable] == "t" && parent[:is_suggestable] == "t"
      LOCALES.keys.each do |locale|
        if row[:"info#{locale}"].nil? && !parent[:"info#{locale}"].nil?
          row[:"info#{locale}"] = parent[:"info#{locale}"]
          puts "Station #{row[:name]} (#{row[:id]}) has a new localized info in “#{locale}”: #{row[:"info#{locale}"]}".green
        end
      end
    else
      print '.'.yellow
    end

    csv << row
  end
end

puts "Done"

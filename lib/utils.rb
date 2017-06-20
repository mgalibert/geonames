
CSV_PARAMS = {
  :headers   => true,
  :col_sep   => ';',
  :encoding => 'UTF-8',
  :header_converters => :symbol
}

def load_set_from_csv(file_name, key)
  print "Loading #{file_name}... "
  set = Set.new
  CSV.foreach(file_name, CSV_PARAMS) do |row|
    set << row[key]
  end
  puts "Done"

  set
end

def load_csv(file_name)
  print "Loading #{file_name}... "
  content = CSV.read(file_name, CSV_PARAMS)
  puts "Done"

  content
end

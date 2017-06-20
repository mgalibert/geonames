.PHONY: install run polish sync

install:
	bundle install

run:
	ruby geonames.rb

polish:
	ruby parent_and_child.rb

sync:
	cp stations3.csv ../stations/stations.csv



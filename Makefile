### CEBS Linked Data Makefile
#
# James A. Overton <james@overton.ca>
#
# This file is used to build CEBS Linked Data ontology from source.
# Usually you want to run:
#
#     make clean all
#
# Requirements:
#
# - GNU Make
# - ROBOT <http://github.com/ontodev/robot>


### Configuration
#
# These are standard options to make Make sane:
# <http://clarkgrubb.com/makefile-style-guide#toc2>

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:
.SECONDARY:

OBO = http://purl.obolibrary.org/obo
LIB = lib
ROBOT := java -jar build/robot.jar


### Set Up

build:
	mkdir -p $@

ontology:
	mkdir -p $@


### ROBOT
#
# We use the official development version of ROBOT for most things.

build/robot.jar: | build
	curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.5.0/robot.jar



### ROBOT Validation

NTP/%.tsv: NTP/%.xlsx
	xlsx2csv -i -d tab -n Terms $^ $@

NTP/%.csv: convert.py NTP/%.tsv
	python3 $^ $@

NTP/%_report.xlsx: NTP/%.csv cebs.owl | build/robot.jar
	java -jar build/robot.jar validate --csv $< --owl cebs.owl --output $@



### Ontology Source Tables

SHEET := 15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk
tables = imports value_specifications endpoints
source_files = $(foreach o,$(tables),ontology/$(o).tsv)
templates = $(foreach i,$(source_files),--template $(i))

### Tables
#
# These tables are stored in Google Sheets, and downloaded as TSV files.

build/cebs.xlsx: | build
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/$(SHEET)/export?format=xlsx"

ontology/%.tsv: build/cebs.xlsx
	xlsx2csv -d tab -n $* $< $@

build/endpoints.tsv: ontology/endpoints.tsv
	sed '/LABEL/d' $< > $@

build/validation.owl: ontology/imports.tsv ontology/value_specifications.tsv | build/robot.jar
	$(ROBOT) template \
	--prefix "CEBS: http://example.com/CEBS_" \
	$(foreach t,$^,--template $t) \
	--output $@

build/endpoints_report.%: build/validation.owl build/endpoints.tsv
	$(ROBOT) validate \
	--input $< \
	--table $(word 2,$^) \
	--standalone true \
	--output $@

.PHONY: update-tsv
update-tsv: ontology/imports.tsv ontology/endpoints.tsv




# TODO: Fix CEBS prefix
cebs.owl: $(source_files) | build/robot.jar
	$(ROBOT) template \
	--prefix "CEBS: http://example.com/CEBS_" \
	$(templates) \
	--output $@

.PHONY: tidy
tidy:
	rm -f $(source_files) build/cebs.xlsx build/endpoints* build/validation.owl

.PHONY: clean
clean: tidy
	rm -rf build
	rm -f cebs.owl

.PHONY: all
all: build/endpoints_report.txt build/endpoints_report.html cebs.owl

.PHONY: update
update: tidy update-tsv all

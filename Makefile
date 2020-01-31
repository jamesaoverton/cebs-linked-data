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

# VIEW Endpoints: The validated endpoints table
ENDPOINTS := build/endpoints.html build/endpoints.xlsx
build/endpoints.%: build/validation.owl build/endpoints.tsv
	$(ROBOT) validate \
	--input $< \
	--table $(word 2,$^) \
	--standalone true \
	--output $@

# VIEW Tree View: The complete ontology
TREES := build/cebs.html cebs.owl
build/cebs.html: cebs.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@
	mv $@ $@.tmp
	sed "s/params.get('text')/params.get('text') || 'assay'/" $@.tmp > $@
	rm $@.tmp

VIEWS := $(ENDPOINTS) $(TREES)

# ACTION Fetch the latest data, validate it, and rebuild
update:
	make tidy $(VIEWS)





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

build/robot-tree.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/tree-view/lastSuccessfulBuild/artifact/bin/robot.jar


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

# TODO: Fix CEBS prefix
cebs.owl: $(source_files) | build/robot.jar
	$(ROBOT) template \
	--prefix "CEBS: http://example.com/CEBS_" \
	$(templates) \
	--output $@

.PHONY: tidy
tidy:
	rm -f $(source_files) $(VIEWS)

.PHONY: clean
clean: tidy
	rm -rf build
	rm -f cebs.owl

.PHONY: all
all: cebs.owl

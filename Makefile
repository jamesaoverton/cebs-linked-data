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

### Workflow
#
# 1. Edit the [Google Sheet](https://docs.google.com/spreadsheets/d/15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk)
# 2. Run [Update](update) to fetch the latest data, validate it, and rebuild
# 3. View the validation results:
#     - [Clinpath](build/clinpath.html) The validated clinpath table ([clinpath.xlsx](build/clinpath.xlsx))
#     - [Organ weight](build/organ_weight.html) The validated organ weight table ([organ_weight.xlsx](build/organ_weight.xlsx))
# 4. If the tables were valid, then [view the tree](./tree.sh) ([alternative tree](build/cebs.html), [cebs.owl](cebs.owl))
#
# Run `make all`

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

ROBOT := java -jar build/robot.jar

ENDPOINTS := clinpath organ_weight
ENDPOINT_FILES := $(foreach e,$(ENDPOINTS),build/$(e).html build/$(e).xlsx)

build/%.html: cebs.owl build/%.tsv | build/robot.jar
	$(ROBOT) validate \
	--input $< \
	--table $(word 2,$^) \
	--format html \
	--standalone true \
	--output-dir $(dir $@)

build/%.xlsx: cebs.owl build/%.tsv | build/robot.jar
	$(ROBOT) validate \
	--input $< \
	--table $(word 2,$^) \
	--format xlsx \
	--standalone true \
	--output-dir $(dir $@)

TREES := build/cebs.html cebs.owl
build/cebs.html: cebs.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@
	mv $@ $@.tmp
	sed "s/params.get('text')/params.get('text') || 'assay'/" $@.tmp > $@
	rm $@.tmp

VIEWS := $(ENDPOINT_FILES) $(TREES)

.PHONY: update
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
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/validate/lastSuccessfulBuild/artifact/bin/robot.jar

build/robot-tree.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/tree-view/lastSuccessfulBuild/artifact/bin/robot.jar


### ROBOT Validation

NTP/%.tsv: NTP/%.xlsx
	xlsx2csv -i -d tab -n Terms $^ $@

NTP/%.csv: convert.py NTP/%.tsv
	python3 $^ $@

NTP/%_report.xlsx: NTP/%.csv cebs.owl | build/robot.jar
	java -jar build/robot.jar validate --csv $< --owl cebs.owl --output $@


### RDFTab

UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
	RDFTAB_URL := https://github.com/ontodev/rdftab.rs/releases/download/v0.1.1/rdftab-x86_64-apple-darwin
else
	RDFTAB_URL := https://github.com/ontodev/rdftab.rs/releases/download/v0.1.1/rdftab-x86_64-unknown-linux-musl
endif

build/rdftab: | build
	curl -L -o $@ $(RDFTAB_URL)
	chmod +x $@

build/cebs.db: prefixes.sql cebs.owl | build/rdftab
	rm -f $@
	sqlite3 $@ < $<
	./build/rdftab $@ < $(word 2,$^)

.PHONY: tree.sh
tree.sh: build/cebs.db


### Ontology Source Tables

SHEET := 15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk
TABLES = imports value_specifications units $(ENDPOINTS)
SOURCE_TABLES = $(foreach o,$(TABLES),ontology/$(o).tsv)
BUILD_TABLES = $(foreach o,$(TABLES),build/$(o).tsv)

### Tables
#
# These tables are stored in Google Sheets, and downloaded as TSV files.

build/cebs.xlsx: | build
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/$(SHEET)/export?format=xlsx"

ontology/%.tsv: build/cebs.xlsx
	xlsx2csv -d tab -n $* $< $@

build/%.tsv: ontology/%.tsv
	sed '/ID	LABEL/d' $< > $@

# TODO: Fix CEBS prefix
cebs.owl: $(SOURCE_TABLES) | build/robot.jar
	$(ROBOT) template \
	--prefix "CEBS: http://example.com/CEBS_" \
	$(foreach t,$^,--template $t) \
	--output $@

.PHONY: tidy
tidy:
	rm -f build/cebs.xlsx $(SOURCE_TABLES) $(BUILD_TABLES) $(VIEWS)

.PHONY: clean
clean: tidy
	rm -rf build
	rm -f cebs.owl

.PHONY: all
all: cebs.owl

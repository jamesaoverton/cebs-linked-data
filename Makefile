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
	curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.4.1/robot.jar


### Ontology Source Tables

tables = imports analyte-assays
source_files = $(foreach o,$(tables),ontology/$(o).tsv)
templates = $(foreach i,$(source_files),--template $(i))

### Tables
#
# These tables are stored in Google Sheets, and downloaded as TSV files.

ontology/imports.tsv: | ontology
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk/export?format=tsv&id=15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk&gid=909296649"

ontology/analyte-assays.tsv: | ontology
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk/export?format=tsv&id=15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk&gid=0"

.PHONY: update-tsv
update-tsv: ontology/imports.tsv ontology/analyte-assays.tsv


# TODO: Fix CEBS prefix
cebs.owl: $(source_files) | build/robot.jar
	$(ROBOT) template \
		--prefix "CEBS: http://example.com/CEBS_" \
	$(templates) \
	--output $@


.PHONY: clean
clean:
	rm -rf build
	rm -f cebs.owl

.PHONY: clobber
clobber: clean
	rm -f ontology/imports.tsv ontology/analyte-assays.tsv

.PHONY: all
all: cebs.owl


# CEBS Linked Data

This initial prototype of the next version of the CEBS Linked Data ontology is driven by the [CEBS Linked Data Terms](https://docs.google.com/spreadsheets/d/15TG1MDtDT0qB5fi7zNJp979iTYPYfOrdq_FHuNyYsTk) Google Sheet. Each sheet is downloaded to the [`ontology/`](ontology/) directory. The [`Makefile`](Makefile) uses [ROBOT](http://robot.obolibrary.org) to build [`cebs.owl`](cebs.owl) from those sheets.

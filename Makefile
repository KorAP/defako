SHELL := /bin/bash
ifneq (,$(filter test,$(MAKECMDGOALS)))
SRC_DIR = test/resources/dnf/p5
YEARS= 00 03 08 09 11 12 14 15 19
else
SRC_DIR ?= ./p5
#YEARS ?= $(shell seq -w 2012 2024 | sed 's/^.*\([0-9][0-9]\)/\1/')
YEARS ?= $(shell seq -w 2000 2020 | sed 's/^.*\([0-9][0-9]\)/\1/')
endif

BUILD_DIR ?= build
TARGET_DIR ?= target
MAX_THREADS ?= $(shell nproc)
MAKE ?= make -j $(shell nproc)
SLACK ?= $(if $(shell command -v slack 2>/dev/null),slack,echo)
XMLLINT ?= xmllint
KORAPXMLTOOL_BIN ?= bin/korapxmltool
KORAPXMLTOOL_URL ?= https://github.com/KorAP/korapxmltool/releases/latest/download/korapxmltool
KORAPXMLTOOL ?= $(KORAPXMLTOOL_BIN)
MARMOTMALTOOL ?= $(KORAPXMLTOOL_BIN)
SPACYXMLTOOL ?= $(KORAPXMLTOOL_BIN)
KORAPXMLTOOL_MODELS_PATH ?= models
KRILL_INDEXER_HEAP ?= 500g
KRILL_INDEXER_JAR ?= lib/Krill-Indexer.jar
KRILL_INDEXER_URL ?= https://github.com/KorAP/Krill/releases/latest/download/Krill-Indexer.jar
SAXON_VERSION ?= 12.9
SAXON_ZIP_VERSION ?= 12-9
XMLRESOLVER_VERSION ?= 5.3.3
export KORAPXMLTOOL_MODELS_PATH

SAXON_ZIP ?= lib/SaxonEE$(SAXON_ZIP_VERSION)J.zip
SAXON_STAMP ?= lib/.saxon-$(SAXON_VERSION).stamp
SAXON_JAR ?= lib/saxon-ee-$(SAXON_VERSION).jar
XMLRESOLVER_JAR ?= lib/xmlresolver-$(XMLRESOLVER_VERSION).jar
XMLRESOLVER_DATA_JAR ?= lib/xmlresolver-$(XMLRESOLVER_VERSION)-data.jar
SAXON_URL ?= https://downloads.saxonica.com/SaxonJ/EE/12/SaxonEE$(SAXON_ZIP_VERSION)J.zip
SAXON_LICENSE_FILE ?= lib/saxon-license.lic
SAXON_CP ?= $(SAXON_JAR):$(XMLRESOLVER_JAR):lib/textclassifier.jar:$(XMLRESOLVER_DATA_JAR)
SAXON ?= java -Djava.util.logging.config.file=/logging.properties -cp $(SAXON_CP) net.sf.saxon.Transform -expand:off -catalog:"lib/dtds/xhtml11/xhtmlcatalog.xml;lib/dtds/xhtml/dtd/xhtmlcatalog.xml"
KORAPXMLTOOL_PREREQ := $(if $(filter $(KORAPXMLTOOL_BIN),$(KORAPXMLTOOL) $(MARMOTMALTOOL) $(SPACYXMLTOOL)),$(KORAPXMLTOOL_BIN))
P5_DIR ?= $(SRC_DIR)


.DELETE_ON_ERROR:

.PHONY: all clean distclean test i5 i5valid krill malt index check-saxon-license check-xmllint


.PRECIOUS: $(TARGET_DIR)/%.i5.xml $(TARGET_DIR)/dnf%.pre.i5.xml $(TARGET_DIR)/.i5-individual.stamp %.zip %.tree_tagger.zip %.ud.zip %.marmot-malt.zip %.spacy.zip %.i5.xml %.tar

all: index

krill: $(foreach year,$(YEARS),$(TARGET_DIR)/dnf$(year).krill.tar)

index: $(TARGET_DIR)/dnf.index

# Do NOT expand the TEI sources into Make prerequisite lists: with the full
# corpus (>100K files) that causes Make to segfault while constructing the
# dependency graph.  Individual .i5.xml files are built via a single sub-make
# (serialised by the stamp file below).

check-saxon-license: $(SAXON_STAMP)
	@test -r "$(SAXON_LICENSE_FILE)" || { echo "ERROR: Saxon EE license not found or not readable: $(SAXON_LICENSE_FILE)"; echo "Copy your Saxon license to lib/saxon-license.lic before building .i5.xml files."; exit 1; }

check-xmllint:
	@command -v "$(XMLLINT)" >/dev/null || { echo "ERROR: xmllint not found. Install libxml2 tools before running XML validation."; exit 1; }

$(TARGET_DIR)/dnf%.i5.xml: $(TARGET_DIR)/dnf%.pre.i5.xml  xslt/pass2.xsl xslt/pass3.xsl models/dereko_domains_s.classifier | check-saxon-license
	$(SAXON) -xsl:xslt/pass2.xsl $< | $(SAXON) -xsl:xslt/pass3.xsl - > $@

# Single sub-make builds all individual tei→i5.xml files once.
# Using a stamp file (not a phony target) ensures Make only runs this once even
# when multiple dnf%.pre.i5.xml targets are built in parallel — each waits for
# the same stamp and never races on the same target/ files.
$(TARGET_DIR)/.i5-individual.stamp: xslt/p5toi5.xsl xslt/idsCorpus-template.xml | check-saxon-license
	mkdir -p $(TARGET_DIR)
	find -L $(SRC_DIR) -type f -name '*.tei.xml' | sort -u | \
		sed 's|.*/\(.*\)\.tei\.xml|$(TARGET_DIR)/\1.i5.xml|' | \
		xargs --no-run-if-empty -d '\n' $(MAKE) BUILD_DIR=$(BUILD_DIR) TARGET_DIR=$(TARGET_DIR) SRC_DIR=$(SRC_DIR)
	touch $@

$(TARGET_DIR)/dnf%.pre.i5.xml: xslt/idsCorpus-template.xml $(TARGET_DIR)/.i5-individual.stamp
	rm -f $(TARGET_DIR)/filelist$*.txt
	head -n -1 xslt/idsCorpus-template.xml | sed -e 's/{YY}/$*/' > $@
	@find -L $(SRC_DIR) -type f -name '*.tei.xml' | sort -u | while read src; do \
		f=$(TARGET_DIR)/$$(basename $${src%.tei.xml}).i5.xml; \
		[ -r "$$f" ] || { echo "WARN: missing $$f"; continue; }; \
		if ! grep -sq "$$f" $(TARGET_DIR)/filelist$*.txt && head -500 "$$f" | grep -Eq '<pubDate type="year">..$*'; then \
			echo $$f >> $(TARGET_DIR)/filelist$*.txt; \
			cat "$$f" | grep -Ev 'xml version' >> $@; \
		fi; \
	done
	tail -n 1 xslt/idsCorpus-template.xml  >> $@


test: models/dereko_domains_s.classifier i5valid test/test-xml.sh
	bash test/test-xml.sh

i5: $(foreach year,$(YEARS),$(TARGET_DIR)/dnf$(year).i5.xml)

i5valid: i5 check-xmllint
	$(XMLLINT) --noout $(foreach year,$(YEARS),$(TARGET_DIR)/dnf$(year).i5.xml)
	$(XMLLINT) --noout --valid $(foreach year,$(YEARS),$(TARGET_DIR)/dnf$(year).i5.xml) || true


$(TARGET_DIR)/%.i5.xml: $(P5_DIR)/%.tei.xml xslt/p5toi5.xsl xslt/idsCorpus-template.xml | check-saxon-license
	mkdir -p $(TARGET_DIR)
	echo "Converting $< to $@"
	$(SAXON) -xsl:xslt/p5toi5.xsl $< debug=1 | $(XMLLINT) -encode utf-8 -format - > $@

%.zip: %.i5.xml
	docker run --rm -i -e KORAPXMLTEI_TOKENIZER_HEAP_SIZE=32G korap/tei2korapxml:latest -l warn -s -tk - < $< > $@ 2> >(tee $(@:.zip=.log) >&2)
	printf "%s\t%s\n" "$$(grep -c '<idsText ' $<)" "$$(unzip -l $@ | grep data.xml | wc -l)"

%.tree_tagger.zip: %.zip | $(KORAPXMLTOOL_PREREQ)
	$(KORAPXMLTOOL) -j 2 -T treetagger -t zip -f -D $(TARGET_DIR) $<

%.spacy.zip: %.zip | $(KORAPXMLTOOL_PREREQ)
	KORAPXMLTOOL_XMX=100G $(KORAPXMLTOOL) -j 16 -P spacy -t zip --force -D $(TARGET_DIR) $<

models/de.marmot:
	mkdir -p models
	curl -sL -o $@ https://cistern.cis.lmu.de/marmot/models/CURRENT/spmrl/de.marmot

models/german.mco:
	mkdir -p models
	curl -sL -o $@  https://corpora.ids-mannheim.de/tools/$@

models/dereko_domains_s.classifier:
	mkdir -p models
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

$(KORAPXMLTOOL_BIN):
	mkdir -p $(dir $@)
	curl -fL -o $@.tmp $(KORAPXMLTOOL_URL)
	chmod a+x $@.tmp
	mv $@.tmp $@

$(KRILL_INDEXER_JAR):
	mkdir -p $(dir $@)
	curl -fL -o $@.tmp $(KRILL_INDEXER_URL)
	mv $@.tmp $@

$(SAXON_ZIP):
	mkdir -p $(dir $@)
	curl -fL -o $@.tmp $(SAXON_URL)
	mv $@.tmp $@

$(SAXON_STAMP): $(SAXON_ZIP)
	unzip -q -j -o $(SAXON_ZIP) saxon-ee-$(SAXON_VERSION).jar lib/xmlresolver-$(XMLRESOLVER_VERSION).jar lib/xmlresolver-$(XMLRESOLVER_VERSION)-data.jar -d lib
	touch $@

$(SAXON_JAR) $(XMLRESOLVER_JAR) $(XMLRESOLVER_DATA_JAR): $(SAXON_STAMP)
	@test -r "$@" || { echo "ERROR: expected Saxon artifact was not extracted: $@"; exit 1; }

%.marmot-malt.zip: %.zip models/de.marmot models/german.mco | $(KORAPXMLTOOL_PREREQ)
	$(MARMOTMALTOOL) -T marmot -P malt -t zip -f -D $(TARGET_DIR) $<

malt: $(foreach year,$(YEARS),$(TARGET_DIR)/dnf$(year).marmot-malt.zip)

%.ud.zip: %.zip | $(KORAPXMLTOOL_PREREQ)
	$(KORAPXMLTOOL) $< | pv | ./scripts/udpipe2 | conllu2korapxml > $@

# Old korapxml2krill recipe kept as fallback (requires KorAP-XML-Krill from CPAN):
#	mkdir -p ${BUILD_DIR}/krill/$(basename $@)
#	mkdir -p $(basename $@)
#	K2K_TRANSLATOR_TEXT=1 korapxml2krill archive --quiet -w -z -cfg krill-korap4dnb.cfg -c ${BUILD_DIR}/krill/$(basename $@)/korapxml2krill.cache -j $(MAX_THREADS) -te ${BUILD_DIR}/krill/$(basename $@) --non-word-tokens --meta I5 -i $< -i $(word 2,$^) -i $(word 3,$^) -o $(basename $@)
%.krill.tar: %.zip %.marmot-malt.zip %.tree_tagger.zip %.spacy.zip | $(KORAPXMLTOOL_PREREQ)
	K2K_PUBLISHER_STRING=1 K2K_TRANSLATOR_TEXT=1 $(KORAPXMLTOOL) -j 6 --non-word-tokens -linfo -f -t krill -D $(TARGET_DIR) $^
	$(SLACK) "$(basename $@) krill archive created"

%.json: %.krill.tar
	rm -rf $@
	mkdir -p $@
	for f in $<; do tar -C $@ -xf $$f; done




$(TARGET_DIR)/dnf.index.tar.xz: $(TARGET_DIR)/dnf.index
	tar -I 'xz -T0' -C $(dir $<) -cf $@ $(notdir $<)

clean:
	@read -p "Really delete $(BUILD_DIR)/ and $(TARGET_DIR)/? [y/N] " ans; \
	[[ "$$ans" =~ ^[yY] ]] && rm -rf $(BUILD_DIR) $(TARGET_DIR) || echo "Aborted."

distclean: clean
	@read -p "Also delete downloaded tools (bin/, models/, extracted libs)? [y/N] " ans; \
	[[ "$$ans" =~ ^[yY] ]] && rm -rf bin models \
		$(KRILL_INDEXER_JAR) $(SAXON_STAMP) $(SAXON_JAR) $(XMLRESOLVER_JAR) $(XMLRESOLVER_DATA_JAR) \
		|| echo "Aborted."

$(TARGET_DIR)/dnf.index: $(foreach year,$(YEARS),$(TARGET_DIR)/dnf$(year).krill.tar) $(KRILL_INDEXER_JAR)
	@test ! -e "$@" -a ! -L "$@" || echo "NOTE: $@ already exists; Krill-Indexer will update the existing index in place."
	java -Xmx$(KRILL_INDEXER_HEAP) -jar $(KRILL_INDEXER_JAR) --progress -c lib/krill.conf -i $(subst " ",;,$(filter %.krill.tar,$^)) -o $@

#!/usr/bin/env bash
TESTDIR=$(dirname $0)
ASSERTSH=${TESTDIR}/assert.sh
# set -e
. ${ASSERTSH}
ERRORS=0
PASSED=0
TEXTS=2
I5_FILE=target/dnf15.i5.xml
if [ ! -f "$I5_FILE" ]; then
  log_failure "File $I5_FILE does not exist"
  exit 1
fi


observed=$(xmlstarlet  sel --net -t -v "count(//idsText)"  $I5_FILE)
assert_eq "$observed" "$TEXTS" "$I5_FILE contains $TEXTS idsText elements"

observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc/sourceDesc/biblStruct/monogr/h.author[normalize-space(.)])"  $I5_FILE)
assert_eq "$observed" "$TEXTS" "$I5_FILE contains $TEXTS non-empty h.author elements"

observed=$(xmlstarlet sel --net -t -v "/idsCorpus/idsHeader/fileDesc/titleStmt/c.title" target/dnf12.i5.xml)
assert_eq "$observed" "Deutsche Nationalbibliothek: Fachliteratur 2012 (DeFaKo@DNB)" "c.title contains year and DeFaKo@DNB"

observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc/sourceDesc/biblStruct/monogr/h.author[contains(., '[')])"  target/dnf12.i5.xml)
assert_eq "$observed" "0" "authors do not contain []"

observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/profileDesc/textDesc/textType[contains(., 'Dissertation')])"  $I5_FILE)
assert_gt "$observed" "0" "at least one textType contains 'Dissertation'"

observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/profileDesc/textDesc/textType[normalize-space(.)=''])"  $I5_FILE)
assert_eq "$observed" "0" "no empty textType elements"

observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/profileDesc/textDesc/textTypeRef[normalize-space(.)=''])"  $I5_FILE)
assert_eq "$observed" "0" "no empty textTypeRef elements"

min_expected=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText)"  $I5_FILE)
observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc/publicationStmt/idno)"  $I5_FILE)
assert_gt "$observed" "$min_expected" "exvery text has more than one idno element"

observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc/publicationStmt/idno[@type='URN'])"  $I5_FILE)
assert_eq "$observed" "$min_expected" "exvery text has one idno element of type URN"

observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc/publicationStmt/idno[@type='URL' and starts-with(@rend, 'URN;urn:nbn:de:')])"  $I5_FILE)
assert_eq "$observed" "$min_expected" "for every idno element of type URN, there is also an URL element with @rend starting with 'URN;urn:nbn:de:'"

#observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc/publicationStmt/idno[@type='IDN' and .='8999999999'])"  $I5_FILE)
#assert_eq "$observed" "1" "epub 8... id and without API metadata is transformed"

#observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc[publicationStmt/idno[@type='IDN' and .='8999999999']]/sourceDesc//h.title[.='Herzblut'])"  $I5_FILE)
#assert_eq "$observed" "1" "static metadata for epub with 8... id is correctly retrieved"

xmllint -noout xslt/static_metadata.xml
assert_eq "$?" "0" "static_metadata.xml is well-formed"

#observed=$(xmlstarlet sel --net -t -v "count(/idsCorpus/idsDoc/idsText/idsHeader/fileDesc[publicationStmt/idno[@type='IDN' and .='8000000009']]/sourceDesc//h.title[.='Ein Hund kam in die Küche'])"  target/dnb23.i5.xml)
#assert_eq "$observed" "1" "static metadata is also used as fallback by ISBN and via symbolic link"


exit_with_test_summary



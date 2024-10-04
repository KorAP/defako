<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:ids="http://www.ids-mannheim.de/ids"
                xmlns:hlu="http://www.ids-mannheim.de/hlu"
                xmlns:saxon="http://saxon.sf.net/"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:srw="http://www.loc.gov/zing/srw/"
                xmlns:oai="http://www.openarchives.org/OAI/2.0/oai_dc/"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                exclude-result-prefixes="xs opf dc ids hlu map saxon xhtml xsi srw oai">

    <xsl:output method="xml" indent="yes" omit-xml-declaration="yes" saxon:line-length="1000"/>
    <xsl:strip-space elements="*"/>

    <xsl:param name="debug" select="1"/>

    <xsl:variable name="ev"/>
    <xsl:variable name="x"/>
    
    <xsl:variable name="idno" as="xs:string" select="replace(base-uri(), '.*/([0-9]{9,13}X?).*' , '$1')"/>

    <xsl:variable name="idno_type">
        <xsl:choose>
            <xsl:when test="starts-with($idno,'1')">
                <xsl:value-of select="'IDN'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'ISBN'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:param name="buchpreis"/>
    
    <xsl:variable name="dnbBookdataQuery" as="xs:string">
        <xsl:value-of disable-output-escaping="yes" select="concat('https://services.dnb.de/sru/dnb?version=1.1&amp;operation=searchRetrieve&amp;query=', $idno_type, '%3D', $idno, '&amp;recordSchema=oai_dc')"/>
    </xsl:variable>
    <xsl:variable name="dnbBookdata">
      <xsl:if test="$debug">
        <xsl:message select="concat('debug message dnbBookdataQuery: ', $dnbBookdataQuery)"/>
        <xsl:message select="concat('debug message idno: ', $idno)"/>
        <xsl:message select="concat('debug message original title from static metadata: ', if(starts-with($idno, '8')) then doc('static_metadata.xml')//oai:dc[dc:identifier=$idno]//dc:title else '')"/>
      </xsl:if>
      <xsl:variable name="tmp" select="if(starts-with($idno, '8')) then doc('static_metadata.xml')//oai:dc[dc:identifier=$idno] else doc($dnbBookdataQuery)"/>
      <xsl:copy-of select="if($tmp//dc:title) then $tmp else doc('static_metadata.xml')//oai:dc[replace(dc:identifier[@xsi:type='tel:ISBN'][1], '-',  '')=$idno]"/>
    </xsl:variable>

    <xsl:variable name="autor"
        select="replace(string-join($dnbBookdata//dc:creator[not(contains(., '[')) or matches(., '\[Verfasser\]')], ' ; '), ' *\[[^\]]*\]', '')"/>
        <xsl:variable name="straight_autor" select="normalize-space(replace(hlu:reversedAuthors($autor), ',', ''))"/>
    <xsl:variable name="translator"
        select="replace(string-join($dnbBookdata//dc:creator[matches(., '\[Übersetzer\]')], ' ; '), ' *\[[^\]]*\]', '')"/>
        <xsl:variable name="straight_translator" select="normalize-space(replace(hlu:reversedAuthors($translator), ',', ''))"/>

    <xsl:variable name="herausgeber"
        select="replace(string-join($dnbBookdata//dc:creator[matches(., '\[(Herausgeber|Hrsg.)\]')], ' ; '), ' *\[[^\]]*\]', '')"/>
        <xsl:variable name="straight_herausgeber" select="normalize-space(replace(hlu:reversedAuthors($herausgeber), ',', ''))"/>

    <xsl:variable name="ina"/>
    <xsl:variable name="_corpus"/>
    <xsl:variable name="ent_known"/>


    <!-- added HLU 2012-02-09: -->
    <xsl:variable name="ent">
        <xsl:choose>
            <xsl:when test="$ent_known">
                <xsl:value-of select="$ent_known"/>
            </xsl:when>
            <xsl:when test="$ev">
                <xsl:value-of select="$ev"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$j"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="titel">
        <xsl:variable name="title-with-subtitles">
           <xsl:if test="$debug">
                <xsl:message select="concat('title: ', ($dnbBookdata//dc:title)[1])"/>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="contains(($dnbBookdata//dc:title)[1],':')">
                    <xsl:choose>
                        <xsl:when test="matches(($dnbBookdata//dc:title)[1], '.*/.*:.*/')">
                            <xsl:value-of select="normalize-space(substring-before(($dnbBookdata//dc:title)[1], ':'))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="normalize-space(substring-before(substring-before(($dnbBookdata//dc:title)[1], '/'), ':'))"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                 <xsl:when test="contains(($dnbBookdata//dc:title)[1],'/')">
                    <xsl:value-of select="normalize-space(substring-before(($dnbBookdata//dc:title)[1], '/'))"/>
                 </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="normalize-space(($dnbBookdata//dc:title)[1])"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="tmptitle" select="normalize-space(replace($title-with-subtitles, '\|.*', ''))"/>
        <xsl:value-of select="if ($tmptitle) then $tmptitle else ($dnbBookdata//dc:title)[1]"/>
    </xsl:variable>

    <xsl:variable name="erscheinungsort">
        <xsl:choose>
            <xsl:when test="contains(($dnbBookdata//dc:publisher)[1], ':')">
                <xsl:value-of select="normalize-space(substring-before(($dnbBookdata//dc:publisher)[1], ':'))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="normalize-space(($dnbBookdata//dc:publisher)[1])"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="erscheinungsland" select="ids:country-city($erscheinungsort)"/>

    <xsl:variable name="texttype" select="replace(($dnbBookdata//dc:subject[matches(., '^[A-Z] ')])[1], '^[A-Z] (.*)', '$1')"/>

  <xsl:variable name="genretable">
    <genres>
      <genre keyRegex="Diss" genre="Fachliteratur: Dissertation"/>
      <genre keyRegex="." genre="Fachliteratur"/>
    </genres>
  </xsl:variable>

  <xsl:variable name="textFullGenre" select="$genretable/genres/genre[matches($dnbBookdata, ./@keyRegex, 'i')][1]/@genre"/>
    <xsl:variable name="verlag">
        <xsl:choose>
            <xsl:when test="contains(($dnbBookdata//dc:publisher)[1], ':')">
                <xsl:value-of select="normalize-space(substring-after(($dnbBookdata//dc:publisher)[1], ':'))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="normalize-space(($dnbBookdata//dc:publisher)[1])"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="erscheinungsjahr">
        <xsl:value-of select="replace(($dnbBookdata//dc:date)[1], '.*?((19|20)[0-9][0-9]).*', '$1')"/>
    </xsl:variable>

    <xsl:variable name="untertitel"
        select="normalize-space(substring-after(substring-before(($dnbBookdata//dc:title)[1], '/'), ':'))"/>

    <xsl:variable name="j" select="$erscheinungsjahr"/>

    <!-- for BOT+s: -->
    <xsl:variable name="seiten" select="replace($dnbBookdata//dc:format,'S\.','')"/>

    <!-- fuer BOT+b: -->
    <xsl:variable name="_b">
        <xsl:variable name="regexp1" select="'(Band|Bd\.)\s*([0-9]?[0-9]?[0-9])'"/>
        <xsl:choose>
            <xsl:when test="matches($dnbBookdata, $regexp1)">
                <xsl:analyze-string select="$dnbBookdata//dc:title" regex="{$regexp1}">
                    <xsl:matching-substring>
                        <xsl:value-of select="."/>
                    </xsl:matching-substring>
                </xsl:analyze-string>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'.'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <!-- for BOT+x: -->
    <xsl:variable name="txtart">
        <xsl:choose>
            <xsl:when test="$x">
                <xsl:value-of select="concat('[', $x, ']')"/>
            </xsl:when>
            <xsl:when
                test="matches($untertitel, '([Rr]oman|[Ee]rzählung(en)?|[Aa]nthologie|[Gg]eschichte(n)?|[Nn]ovelle)')">
                <xsl:value-of
                    select="concat('[', replace(replace($untertitel, '.*?(((^|\P{L})\p{L}+)?([Rr]oman|[Ee]rzählung(en)?|[Aa]nthologie|[Gg]eschichte(n)?|[Nn]ovelle)).*', '$1'), '\P{L}*(.+)', '$1'), ']')"
                    />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of>Roman</xsl:value-of>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>



    <!-- fuer BOTd: -->
    <xsl:variable name="dok"
        select="concat((if(string-length($autor) &gt; 0) then concat($straight_autor, ': ') else ''), $titel, ', ', $txtart, ', (', $j, ')')"/>

    <!-- END variables derived from sru request to dnb archive -->


    <xsl:variable name="corpus_sigle" select="concat('DNF', substring($erscheinungsjahr, 3, 2))"/>

    <!-- for BOTD: -->
    <!-- Dokumentsigle muss zusammen mit Korpussigle (z.B DIV fuer loz-div und loz-div-pub) eindeutig sein -->
    <xsl:variable name="doc_sigle">
        <xsl:variable name="firstContentWordTitleInitial">
            <xsl:variable name="helper">
                <xsl:analyze-string select="$titel" regex="\w+">
                    <xsl:matching-substring>
                        <xsl:choose>
                            <xsl:when
                                test="matches(.,'^[A-Z]') and not(matches(.,'^(Der|Die|Das|Des|Ein|Eine|Eines|Einmal|Von|Mit|Zu|Zur)$'))">
                                <!-- TODO: Fktnswoerter nachtragen -->
                                <xsl:sequence select="."/>
                            </xsl:when>
                            <xsl:otherwise/>
                        </xsl:choose>
                    </xsl:matching-substring>
                </xsl:analyze-string>
            </xsl:variable>
            <xsl:value-of
                select="upper-case(substring(normalize-space(replace($helper,'\s+.+$','')),1,3))"/>
            <!-- longest match of .+  -->
        </xsl:variable>
        <xsl:variable name="authorInitials">
            <xsl:choose>
                <xsl:when test="contains($autor,';')">
                    <xsl:variable name="lastname_aut1"
                        select="upper-case(substring(normalize-space($autor),1,1))"/>
                    <xsl:variable name="lastname_aut2"
                        select="replace($autor, '.*?;.*?([A-Z]).*', '$1')"/>
                    <xsl:value-of select="concat($lastname_aut1,  $lastname_aut2)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="lastname_aut1"
                        select="upper-case(substring(normalize-space(substring-before($autor,',')),1,1))"/>
                    <xsl:variable name="firstname_aut1"
                        select="upper-case(substring(normalize-space(substring-after($autor,',')),1,1))"/>
                    <xsl:value-of select="concat($lastname_aut1, $firstname_aut1)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="substring(replace(normalize-unicode(concat($authorInitials,$firstContentWordTitleInitial), 'NFKD'),'[^A-Z]',''),1,3)"/>
    </xsl:variable>


    <xsl:variable name="text_sigle" select="replace($idno, '.*([0-9]{5})[0-9X]$', '$1')"/>
    <xsl:variable name="sigle" select="concat($corpus_sigle, '/', $doc_sigle, '.', $text_sigle)"/>

    <!-- fuer BOT+xy: (?) -->
    <xsl:variable name="xyref">
        <xsl:value-of select="base-uri(.)"/>
        <xsl:text>; </xsl:text>
        <xsl:text>IDNO:</xsl:text>
        <xsl:value-of select="$idno"/>
        <xsl:text>; </xsl:text>
        <xsl:value-of select="string-join($dnbBookdata//dc:identifier)"/>
    </xsl:variable>

    <xsl:variable name="long-reference"
        select="concat($sigle, ' ', $autor, ': ', $titel, '. ', $erscheinungsort, ': ', $verlag, ', ', $erscheinungsjahr)"/>

    <xsl:variable name="short-reference"
        select="concat($straight_autor, ': ', $titel, ' (',  $erscheinungsjahr, ')')"/>

    <xsl:template match="/">
        <!-- for debugging purposes 
        <xsl:message select="concat('uri: ', base-uri())"/>
        <xsl:message select="concat('idno: ', $idno)"/>

        <xsl:message>
            dnbBookdataQuery: <xsl:value-of select="$dnbBookdataQuery"/>
        </xsl:message>

        <xsl:message>
            <xsl:copy-of select="$dnbBookdata"/>
        </xsl:message>
        -->
        <xsl:if  test="not($dnbBookdata//oai:dc)">
            <xsl:message terminate="yes" default-mode="text">ERROR: No metadata found for IDNO: <xsl:value-of select="$idno"/>
            <xsl:text>&#10;Query was: </xsl:text>
            <xsl:value-of disable-output-escaping="yes" select="replace($dnbBookdataQuery, '&amp;', '%38')"/>
           <xsl:text>&#10;Retrieved response: </xsl:text>
             <xsl:copy-of select="$dnbBookdata"/>
            </xsl:message>
        </xsl:if>

        <xsl:if test="not($j)">
            <xsl:message terminate="yes">ERROR: No dc:date found for IDNO: <xsl:value-of select="$idno"/></xsl:message>
        </xsl:if>

        <xsl:if test="not(normalize-space($titel))">
            <xsl:message terminate="yes">ERROR: No title found for IDNO: <xsl:value-of select="$idno"/></xsl:message>
        </xsl:if>

        <xsl:if test="not(normalize-space($autor))">
            <xsl:message terminate="yes">ERROR: No author found for IDNO: <xsl:value-of select="$idno"/></xsl:message>
        </xsl:if>

        <xsl:if test="not(matches($sigle, '^[A-Z]{2,3}[0-9]{2}/[A-Z]{2,3}\.[0-9]{5}$'))">
            <xsl:message terminate="yes">ERROR: Invalid sigle »<xsl:value-of select="$sigle"/>« for IDNO: <xsl:value-of select="$idno"/></xsl:message>
        </xsl:if>

        <idsDoc TEIform="TEI.2" type="text" version="1.0">
            <idsHeader TEIform="teiHeader" pattern="text" status="new" type="document" version="1.1">
                <fileDesc>
                    <titleStmt>
                        <dokumentSigle><xsl:value-of select="string-join(($corpus_sigle, $doc_sigle), '/')"/></dokumentSigle>
                        <d.title><xsl:value-of select="$short-reference"/></d.title>
                    </titleStmt>
                    <publicationStmt>
                        <distributor/>
                        <pubAddress/>
                        <availability region="world" status="unknown">QAO-NC</availability>
                        <pubDate/>
                    </publicationStmt>
                    <sourceDesc>
                        <biblStruct>
                            <monogr>
                                <h.title type="main"/>
                                <imprint/>
                            </monogr>
                        </biblStruct>
                    </sourceDesc>
                </fileDesc>
            </idsHeader>
            <idsText version="1.0">
                <idsHeader TEIform="teiHeader" pattern="text" status="new" type="text" version="1.1">
                    <fileDesc>
                        <titleStmt>
                            <textSigle><xsl:sequence select="$sigle"/></textSigle>
                            <t.title assemblage="regular"><xsl:value-of select="$long-reference"/></t.title>
                        </titleStmt>
                        <publicationStmt>
                            <distributor/>
                            <pubAddress/>
                            <xsl:for-each select="$dnbBookdata//dc:identifier">
                                <xsl:variable name="type" select="substring-after(@xsi:type, ':')"/>
                                <xsl:choose>
                                    <xsl:when test="@xsi:type='tel:ISBN'">
                                        <xsl:if test="matches(.,'(^([0-9]|-)+X?).*')">
                                            <idno type="{$type}"><xsl:value-of select="replace(., '(([0-9]|-)+X?).*', '$1')"/></idno>
                                        </xsl:if>
                                    </xsl:when>
                                    <xsl:when test="$type='URL' and contains(., '/urn:nbn:de')">
                                        <idno rend="URN;{tokenize(., '/')[last()]}" type="URL"><xsl:value-of select="."/></idno>
                                    </xsl:when>
                                    <xsl:otherwise><idno type="{$type}"><xsl:value-of select="."/></idno></xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each>
                            <availability region="world" status="unknown">QAO-NC</availability>
                            <pubDate/>
                        </publicationStmt>
                        <sourceDesc>
                            <biblStruct>
                                <monogr>
                                    <h.title type="main"><xsl:value-of select="$titel"/></h.title>
                                    <h.title type="sub"><xsl:value-of select="$untertitel"/></h.title>
                                    <h.author><xsl:value-of select="$autor"/></h.author>
                                    <xsl:if test="$translator">
                                        <editor role="translator"><xsl:value-of select="$translator"/></editor>
                                    </xsl:if>
                                    <xsl:if test="$herausgeber">
                                        <editor role="editor"><xsl:value-of select="$herausgeber"/></editor>
                                    </xsl:if>
                                    <edition>
                                        <further/>
                                        <kind>E-Book-Ausgabe</kind>
                                        <appearance>EPUB-Datei</appearance>
                                    </edition>
                                    <imprint>
                                        <publisher><xsl:value-of select="$verlag"/></publisher>
                                        <pubDate type="year"><xsl:value-of select="$j"/></pubDate>
                                        <pubDate type="month"/>
                                        <pubDate type="day"/>
                                        <pubPlace key="{$erscheinungsland}"><xsl:value-of select="$erscheinungsort"/></pubPlace>
                                    </imprint>
                                    <biblScope type="subsume"/>
                                    <biblScope type="pp"/>
                                    <biblScope type="vol"/>
                                    <biblScope type="volume-title"/>
                                </monogr>
                            </biblStruct>
                            <reference assemblage="regular" type="complete"><xsl:value-of select="concat($sigle, ' ', $autor, ': ', $titel, '. ', $erscheinungsort, ': ', $verlag, ', ', $erscheinungsjahr)"/></reference>
                        </sourceDesc>
                    </fileDesc>
                    <profileDesc>
                        <creation>
                            <creatDate><xsl:value-of select="$j"/></creatDate>
                        </creation>
                        <textClass/>
                        <textDesc>
                            <textType><xsl:value-of select="$textFullGenre"/></textType>
                            <textTypeRef><xsl:value-of select="replace($textFullGenre, '.*: *', '')"/></textTypeRef>
                            <textDomain/>
                        </textDesc>
                    </profileDesc>
                </idsHeader>
                <text>
                   <body>
                        <!-- Call the template for each idref the spine -->
                        <xsl:apply-templates select="//tei:body/*"/>
                    </body>
                </text>
            </idsText>
        </idsDoc>
    </xsl:template>

    <xsl:function name="ids:reversedAuthors">
        <xsl:param name="s" />
        <xsl:value-of
            select="
                if (matches($s, ';')) then
                    concat(ids:reversedAuthors(substring-before($s, ' ; ')), ' ; ', ids:reversedAuthors(substring-after($s, ' ; ')))
                else
                    replace($s, '(.+) (.+)', '$2, $1')"
            />
    </xsl:function>

    <xsl:function name="hlu:reversedAuthors">
        <xsl:param name="s"/>
        <xsl:value-of
            select="if (matches($s, ';')) then concat(ids:reversedAuthors(substring-before($s, ' ; ')), ' ; ', ids:reversedAuthors(substring-after($s, ' ; '))) else replace($s, '(.+),(.+)', '$2, $1')"
            />
    </xsl:function>

  <xsl:variable name="city-country-map" as="map(xs:string, xs:string)">
    <xsl:map>
      <xsl:map-entry key="'Axams'" select="'AT'"/>
      <xsl:map-entry key="'Vienna'" select="'AT'"/>
      <xsl:map-entry key="'Klagenfurt'" select="'AT'"/>
      <xsl:map-entry key="'Graz'" select="'AT'"/>
      <xsl:map-entry key="'Innsbruck'" select="'AT'"/>
      <xsl:map-entry key="'Salzburg'" select="'AT'"/>
      <xsl:map-entry key="'Bern'" select="'CH'"/>
      <xsl:map-entry key="'Biel/Bienne'" select="'CH'"/>
      <xsl:map-entry key="'Zurich'" select="'CH'"/>
      <xsl:map-entry key="'Basel'" select="'CH'"/>
      <xsl:map-entry key="'Geneva'" select="'CH'"/>
      <xsl:map-entry key="'Lucerne'" select="'CH'"/>
      <xsl:map-entry key="'Lausanne'" select="'CH'"/>
      <xsl:map-entry key="'Winterthur'" select="'CH'"/>
      <xsl:map-entry key="'St. Gallen'" select="'CH'"/>
      <xsl:map-entry key="'Interlaken'" select="'CH'"/>
      <xsl:map-entry key="'Brussels'" select="'BE'"/>
      <xsl:map-entry key="'Antwerp'" select="'BE'"/>
      <xsl:map-entry key="'Ghent'" select="'BE'"/>
      <xsl:map-entry key="'Bruges'" select="'BE'"/>
      <xsl:map-entry key="'Leuven'" select="'BE'"/>
      <xsl:map-entry key="'Liege'" select="'BE'"/>
      <xsl:map-entry key="'Charleroi'" select="'BE'"/>
      <xsl:map-entry key="'Namur'" select="'BE'"/>
      <xsl:map-entry key="'Mons'" select="'BE'"/>
      <xsl:map-entry key="'Bangkok'" select="'TH'"/>
      <xsl:map-entry key="'Copenhagen'" select="'DK'"/>
      <xsl:map-entry key="'colatina'" select="'BR'"/>
      <xsl:map-entry key="'Oakland Park'" select="'US'"/>
      <xsl:map-entry key="'Istanbul'" select="'TR'"/>
      <xsl:map-entry key="'Luxemburg'" select="'LU'"/>
      <xsl:map-entry key="'Palma de Mallorca'" select="'ES'"/>
      <xsl:map-entry key="'Swakopmund'" select="'NA'"/>
      <xsl:map-entry key="'Victoria'" select="'CA'"/>
      <xsl:map-entry key="'Wien'" select="'AT'"/>
      <xsl:map-entry key="'Windhoek'" select="'NA'"/>
      <xsl:map-entry key="'Zuerich'" select="'CH'"/>
      <xsl:map-entry key="'Zürich'" select="'CH'"/>
      <xsl:map-entry key="'Zug'" select="'CH'"/>
      <xsl:map-entry key="'ZÜRICH'" select="'CH'"/>
    </xsl:map>

  </xsl:variable>

  <xsl:template match="tei:note"/>
  <xsl:template match="tei:figure"/>
  
   <!-- Template to match and copy elements without namespaces -->
  <xsl:template match="*">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="node()|@*"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="@tei:lang"/>

  <!-- Template to copy attributes (attributes don't have namespaces) -->
  <xsl:template match="@*">
    <xsl:attribute name="{local-name()}">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <!-- Template to copy text nodes -->
  <xsl:template match="text()|comment()|processing-instruction()">
    <xsl:copy/>
  </xsl:template>

  <!-- Define the function -->
  <xsl:function name="ids:country-city" as="xs:string">
    <xsl:param name="city" as="xs:string"/>
    <xsl:sequence select="if (map:contains($city-country-map, $city)) then map:get($city-country-map, $city) else 'DE'"/>
  </xsl:function>
</xsl:stylesheet>

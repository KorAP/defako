<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:saxon="http://saxon.sf.net/"
                exclude-result-prefixes="saxon">
    
    <xsl:output method="xml" indent="yes" saxon:line-length="1000"
                doctype-public="-//IDS//DTD IDS-I5 1.0//EN"
                doctype-system="http://corpora.ids-mannheim.de/I5/DTD/i5.dtd"
        />
    
    <xsl:mode on-no-match="shallow-copy"/> 
    
    <xsl:template match="idsDoc[not(normalize-space(.//body))]"/>
    
    <xsl:template match="idsText[not(normalize-space(.//body))]"/>
    <xsl:template match="hi[parent::div]" priority="0.6">
        <p>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    
    <xsl:template match="(ref|emph|hi|text())[parent::div]" priority="0.9">
        <p>
            <xsl:apply-templates/>
        </p>
    </xsl:template>

    <xsl:template match="hi[local-name(preceding-sibling::*[1]) = 'hi' and @rend = preceding-sibling::hi[1]/@rend]"/>

    <xsl:template match="hi[following-sibling::hi and not(preceding-sibling::hi)]">
        <xsl:variable name="rend" select="@rend"/>
        <hi rend="{$rend}">
            <xsl:for-each-group select="self|following-sibling::hi" group-adjacent="@rend=$rend">
                <xsl:value-of select="current-group()"/>
            </xsl:for-each-group>
        </hi>
    </xsl:template>
</xsl:stylesheet>

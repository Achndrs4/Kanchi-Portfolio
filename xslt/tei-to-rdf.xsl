<?xml version="1.0" encoding="UTF-8"?>
<!--
    TEI -> RDF (Turtle), aligned to CIDOC-CRM.

    Modelling notes, because the choices here are not obvious and are the ones a
    reviewer should be able to challenge:

    * Texts are modelled as crm:E33_Linguistic_Object rather than as documents.
      The Halasya Mahatmya is a work transmitted by many physical carriers; the
      carriers are separate E18 objects that "carry" the work. Collapsing the two
      is the most common modelling error in text-corpus RDF and makes witness
      statements incoherent.

    * Witnesses become crm:E18_Physical_Thing linked by crm:P128_carries. A
      manuscript and a printed edition are both physical carriers, so they take
      the same class and are distinguished by their type, not by separate
      hierarchies.

    * Named-entity references become crm:P67_refers_to from the verse to the
      authority entity. The verse, not the whole text, is the referring subject,
      because that is the granularity at which the corpus is citable.

    * External alignment uses owl:sameAs only where the external record denotes
      the same thing, and is never used to assert identity where none exists
      (see the Sundareshvara-as-epithet-of-Shiva case in the authority file and
      docs/adr/0005). A weaker predicate is emitted instead where that applies,
      and the reason is carried through as an rdfs:comment. Asserting sameAs
      between a deity and a temple, or inventing a second deity entity for what
      is really a place-specific epithet, would both let a reasoner draw
      nonsense conclusions.

    @author Ani Chandrashekhar
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="tei xs">

  <xsl:output method="text" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:param name="base" as="xs:string" select="'https://kanchi.example.org/id/'"/>
  <xsl:param name="authority-doc" as="xs:string" select="'../data/authority/authority.xml'"/>

  <xsl:variable name="nl" select="'&#10;'"/>

  <!-- Escape a string for a Turtle literal. -->
  <xsl:function name="tei:lit" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="'&quot;' ||
        replace(replace(normalize-space($s), '\\', '\\\\'), '&quot;', '\\&quot;') ||
        '&quot;'"/>
  </xsl:function>

  <xsl:template match="/">
    <xsl:text>@prefix crm:  &lt;http://www.cidoc-crm.org/cidoc-crm/&gt; .&#10;</xsl:text>
    <xsl:text>@prefix dct:  &lt;http://purl.org/dc/terms/&gt; .&#10;</xsl:text>
    <xsl:text>@prefix rdfs: &lt;http://www.w3.org/2000/01/rdf-schema#&gt; .&#10;</xsl:text>
    <xsl:text>@prefix owl:  &lt;http://www.w3.org/2002/07/owl#&gt; .&#10;</xsl:text>
    <xsl:text>@prefix skos: &lt;http://www.w3.org/2004/02/skos/core#&gt; .&#10;</xsl:text>
    <xsl:text>@prefix geo:  &lt;http://www.w3.org/2003/01/geo/wgs84_pos#&gt; .&#10;</xsl:text>
    <xsl:text>@prefix kanchi: &lt;</xsl:text>
    <xsl:value-of select="$base"/>
    <xsl:text>&gt; .&#10;&#10;</xsl:text>

    <xsl:apply-templates select="//tei:TEI"/>
    <xsl:call-template name="authority-entities"/>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- The work and its carriers                                     -->
  <!-- ============================================================ -->

  <xsl:template match="tei:TEI">
    <xsl:variable name="id" select="@xml:id"/>
    <xsl:text># === Work: </xsl:text>
    <xsl:value-of select="$id"/>
    <xsl:text> ===&#10;</xsl:text>

    <xsl:text>kanchi:</xsl:text>
    <xsl:value-of select="$id"/>
    <xsl:text> a crm:E33_Linguistic_Object ;&#10;</xsl:text>
    <xsl:text>    rdfs:label </xsl:text>
    <xsl:value-of select="tei:lit(normalize-space((.//tei:titleStmt/tei:title[@type='main'])[1]))"/>
    <xsl:text> ;&#10;</xsl:text>
    <xsl:text>    dct:language </xsl:text>
    <xsl:value-of select="tei:lit(@xml:lang)"/>
    <xsl:text> ;&#10;</xsl:text>
    <xsl:text>    crm:P72_has_language </xsl:text>
    <xsl:value-of select="tei:lit(@xml:lang)"/>
    <xsl:text> .&#10;&#10;</xsl:text>

    <!-- Physical carriers -->
    <xsl:for-each select=".//tei:listWit/tei:witness">
      <xsl:variable name="wid" select="concat($id, '-wit-', @xml:id)"/>
      <xsl:text>kanchi:</xsl:text>
      <xsl:value-of select="$wid"/>
      <xsl:text> a crm:E18_Physical_Thing ;&#10;</xsl:text>
      <xsl:text>    rdfs:label </xsl:text>
      <xsl:value-of select="tei:lit(concat('Witness ', normalize-space(tei:abbr)))"/>
      <xsl:text> ;&#10;</xsl:text>
      <xsl:if test="tei:msDesc//tei:scriptNote">
        <xsl:text>    rdfs:comment </xsl:text>
        <xsl:value-of select="tei:lit(normalize-space(tei:msDesc//tei:scriptNote))"/>
        <xsl:text> ;&#10;</xsl:text>
      </xsl:if>
      <xsl:text>    crm:P128_carries kanchi:</xsl:text>
      <xsl:value-of select="$id"/>
      <xsl:text> .&#10;</xsl:text>
    </xsl:for-each>
    <xsl:text>&#10;</xsl:text>

    <!-- Verses as parts of the work -->
    <xsl:for-each select=".//tei:lg[@type='verse']">
      <xsl:text>kanchi:</xsl:text>
      <xsl:value-of select="@xml:id"/>
      <xsl:text> a crm:E33_Linguistic_Object ;&#10;</xsl:text>
      <xsl:text>    crm:P148i_is_component_of kanchi:</xsl:text>
      <xsl:value-of select="$id"/>
      <xsl:text> ;&#10;</xsl:text>

      <!-- entity references at verse granularity -->
      <xsl:for-each select=".//(tei:placeName | tei:persName)[@ref]">
        <xsl:text>    crm:P67_refers_to kanchi:</xsl:text>
        <xsl:value-of select="substring-after(@ref, ':')"/>
        <xsl:text> ;&#10;</xsl:text>
      </xsl:for-each>

      <!-- cross-language alignment -->
      <xsl:for-each select="tokenize(normalize-space(@corresp), '\s+')[. ne '']">
        <xsl:text>    crm:P130_shows_features_of kanchi:</xsl:text>
        <xsl:value-of select="substring(., 2)"/>
        <xsl:text> ;&#10;</xsl:text>
      </xsl:for-each>

      <xsl:text>    rdfs:label </xsl:text>
      <xsl:value-of select="tei:lit(concat('Verse ', @n))"/>
      <xsl:text> .&#10;</xsl:text>
    </xsl:for-each>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Authority entities and external alignment                     -->
  <!-- ============================================================ -->

  <xsl:template name="authority-entities">
    <xsl:variable name="auth" select="doc($authority-doc)"/>
    <xsl:text># === Authority entities ===&#10;</xsl:text>

    <xsl:for-each select="$auth//tei:place">
      <xsl:text>kanchi:</xsl:text>
      <xsl:value-of select="@xml:id"/>
      <xsl:text> a </xsl:text>
      <xsl:value-of select="if (@type = 'temple')
                            then 'crm:E22_Human-Made_Object'
                            else 'crm:E53_Place'"/>
      <xsl:text> ;&#10;</xsl:text>
      <xsl:for-each select="tei:placeName">
        <xsl:text>    skos:prefLabel </xsl:text>
        <xsl:value-of select="tei:lit(normalize-space(.))"/>
        <xsl:if test="@xml:lang">
          <xsl:text>@</xsl:text>
          <xsl:value-of select="replace(@xml:lang, '_', '-')"/>
        </xsl:if>
        <xsl:text> ;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:for-each select="tei:location/tei:geo">
        <xsl:text>    geo:lat </xsl:text>
        <xsl:value-of select="tokenize(normalize-space(.), '\s+')[1]"/>
        <xsl:text> ;&#10;    geo:long </xsl:text>
        <xsl:value-of select="tokenize(normalize-space(.), '\s+')[2]"/>
        <xsl:text> ;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:call-template name="external-ids"/>
      <xsl:text>    rdfs:isDefinedBy kanchi:</xsl:text>
      <xsl:value-of select="@xml:id"/>
      <xsl:text> .&#10;&#10;</xsl:text>
    </xsl:for-each>

    <xsl:for-each select="$auth//tei:person">
      <xsl:text>kanchi:</xsl:text>
      <xsl:value-of select="@xml:id"/>
      <!-- A deity is not an E21_Person. E28_Conceptual_Object is the honest
           class for a divine figure appearing in narrative. -->
      <xsl:text> a crm:E28_Conceptual_Object ;&#10;</xsl:text>
      <xsl:for-each select="tei:persName">
        <xsl:text>    skos:prefLabel </xsl:text>
        <xsl:value-of select="tei:lit(normalize-space(.))"/>
        <xsl:if test="@xml:lang">
          <xsl:text>@</xsl:text>
          <xsl:value-of select="replace(@xml:lang, '_', '-')"/>
        </xsl:if>
        <xsl:text> ;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:for-each select="tei:note[@type='alignment-gap']">
        <xsl:text>    rdfs:comment </xsl:text>
        <xsl:value-of select="tei:lit(normalize-space(.))"/>
        <xsl:text> ;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:call-template name="external-ids"/>
      <xsl:text>    rdfs:isDefinedBy kanchi:</xsl:text>
      <xsl:value-of select="@xml:id"/>
      <xsl:text> .&#10;&#10;</xsl:text>
    </xsl:for-each>

    <!-- Relations declared in listRelation -->
    <xsl:for-each select="$auth//tei:listRelation/tei:relation">
      <xsl:text>kanchi:</xsl:text>
      <xsl:value-of select="substring(@active, 2)"/>
      <xsl:text> </xsl:text>
      <xsl:value-of select="if (@name = 'located-in')
                            then 'crm:P53_has_former_or_current_location'
                            else 'crm:P129i_is_subject_of'"/>
      <xsl:text> kanchi:</xsl:text>
      <xsl:value-of select="substring(@passive, 2)"/>
      <xsl:text> .&#10;</xsl:text>
    </xsl:for-each>
  </xsl:template>

  <!--
      owl:sameAs is emitted only for authorities that denote the same kind of
      thing as the local entity. Everything else is skos:relatedMatch, which
      records the link without licensing identity inference.
  -->
  <xsl:template name="external-ids">
    <xsl:for-each select="tei:idno">
      <xsl:choose>
        <xsl:when test="@type = ('wikidata', 'gnd', 'geonames')">
          <xsl:text>    owl:sameAs &lt;</xsl:text>
          <xsl:value-of select="normalize-space(.)"/>
          <xsl:text>&gt; ;&#10;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>    skos:relatedMatch &lt;</xsl:text>
          <xsl:value-of select="normalize-space(.)"/>
          <xsl:text>&gt; ;&#10;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>

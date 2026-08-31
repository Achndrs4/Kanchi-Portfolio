<?xml version="1.0" encoding="UTF-8"?>
<!--
    TEI -> HTML5 for the reading view.

    The transformation renders the editorially chosen reading text inline and
    moves variants into a numbered apparatus beneath each verse, which is how a
    printed critical edition is laid out and what readers of such editions
    expect. Variants are also emitted as data- attributes so that the client-side
    script can reveal them in place without a second request.

    Written for XSLT 3.0 (Saxon), but deliberately avoiding streaming and
    higher-order functions so the same stylesheet runs unchanged inside eXist,
    which ships Saxon-HE in XSLT 3.0 mode.

    @author Ani Chandrashekhar
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="tei xs">

  <xsl:output method="xhtml" indent="yes" encoding="UTF-8"
              omit-xml-declaration="yes"/>

  <xsl:param name="show-apparatus" as="xs:boolean" select="true()"/>
  <xsl:param name="css-href" as="xs:string" select="'resources/css/kanchi.css'"/>

  <!-- ============================================================ -->
  <!-- Root                                                          -->
  <!-- ============================================================ -->

  <xsl:template match="/tei:TEI">
    <html lang="{substring(@xml:lang, 1, 2)}">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>
          <xsl:value-of select="normalize-space((//tei:titleStmt/tei:title)[1])"/>
        </title>
        <link rel="stylesheet" href="{$css-href}"/>
      </head>
      <body>
        <main class="edition" lang="{@xml:lang}">
          <xsl:call-template name="header-block"/>
          <xsl:apply-templates select="tei:text/tei:body"/>
          <xsl:call-template name="witness-list"/>
        </main>
        <script src="resources/js/apparatus.js"/>
      </body>
    </html>
  </xsl:template>

  <xsl:template name="header-block">
    <header class="edition-header">
      <h1>
        <xsl:value-of select="normalize-space((//tei:titleStmt/tei:title[@type='main'])[1])"/>
      </h1>
      <xsl:if test="//tei:titleStmt/tei:title[@type='sub']">
        <p class="subtitle">
          <xsl:value-of select="normalize-space(//tei:titleStmt/tei:title[@type='sub'])"/>
        </p>
      </xsl:if>
      <!-- The provenance warning is surfaced in the rendered output, not buried
           in the header. A caveat nobody reads is not a caveat. -->
      <xsl:for-each select="//tei:notesStmt/tei:note[@type='provenance-warning']">
        <div class="warning" role="note">
          <xsl:apply-templates select="tei:p"/>
        </div>
      </xsl:for-each>
    </header>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Structure                                                     -->
  <!-- ============================================================ -->

  <xsl:template match="tei:body">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="tei:div[@type='chapter']">
    <section class="chapter" id="{@xml:id}">
      <xsl:apply-templates/>
    </section>
  </xsl:template>

  <xsl:template match="tei:head">
    <h2 class="chapter-head"><xsl:apply-templates/></h2>
  </xsl:template>

  <xsl:template match="tei:lg[@type='verse']">
    <article class="verse" id="{@xml:id}">
      <div class="verse-number"><xsl:value-of select="@n"/></div>
      <div class="verse-text">
        <xsl:apply-templates select="tei:l"/>
      </div>
      <xsl:if test="$show-apparatus and .//tei:app">
        <xsl:call-template name="apparatus"/>
      </xsl:if>
      <xsl:if test="@corresp">
        <div class="alignment">
          <span class="label">aligned with</span>
          <xsl:for-each select="tokenize(normalize-space(@corresp), '\s+')">
            <a class="align-link" href="{.}"><xsl:value-of select="substring(., 2)"/></a>
          </xsl:for-each>
        </div>
      </xsl:if>
    </article>
  </xsl:template>

  <xsl:template match="tei:l">
    <div class="line" data-n="{@n}">
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Apparatus                                                     -->
  <!-- ============================================================ -->

  <!--
      Inline: only the lemma is rendered as running text. Each lemma is tagged
      with the index of its apparatus entry so the note below can be linked to
      it in both directions.
  -->
  <xsl:template match="tei:app">
    <xsl:variable name="idx">
      <xsl:number count="tei:app" level="any" from="tei:lg"/>
    </xsl:variable>
    <span class="lemma"
          id="lem-{ancestor::tei:lg/@xml:id}-{$idx}"
          data-app="{$idx}"
          data-variants="{string-join(tei:rdg ! normalize-space(.), ' | ')}">
      <xsl:apply-templates select="tei:lem/node()"/>
      <sup class="app-marker">
        <a href="#app-{ancestor::tei:lg/@xml:id}-{$idx}">
          <xsl:value-of select="$idx"/>
        </a>
      </sup>
    </span>
  </xsl:template>

  <xsl:template name="apparatus">
    <aside class="apparatus" aria-label="Apparatus criticus">
      <ol class="app-entries">
        <xsl:for-each select=".//tei:app">
          <xsl:variable name="idx">
            <xsl:number count="tei:app" level="any" from="tei:lg"/>
          </xsl:variable>
          <li id="app-{ancestor::tei:lg/@xml:id}-{$idx}" class="app-entry">
            <span class="app-lemma">
              <xsl:value-of select="normalize-space(tei:lem)"/>
            </span>
            <span class="app-wit">
              <xsl:call-template name="sigla">
                <xsl:with-param name="wit" select="tei:lem/@wit"/>
              </xsl:call-template>
            </span>
            <span class="app-sep">]</span>
            <xsl:for-each select="tei:rdg">
              <span class="app-reading">
                <xsl:value-of select="normalize-space(.)"/>
                <xsl:text> </xsl:text>
                <span class="app-wit">
                  <xsl:call-template name="sigla">
                    <xsl:with-param name="wit" select="@wit"/>
                  </xsl:call-template>
                </span>
                <xsl:if test="@type">
                  <span class="app-type">(<xsl:value-of select="@type"/>)</span>
                </xsl:if>
              </span>
              <xsl:if test="position() != last()">
                <span class="app-sep">,</span>
              </xsl:if>
            </xsl:for-each>
            <xsl:for-each select="tei:witDetail">
              <span class="app-note"><xsl:value-of select="normalize-space(.)"/></span>
            </xsl:for-each>
          </li>
        </xsl:for-each>
      </ol>
    </aside>
  </xsl:template>

  <!-- Render "#E1 #M1" as "E1 M1". -->
  <xsl:template name="sigla">
    <xsl:param name="wit" as="attribute()?"/>
    <xsl:value-of select="string-join(
        for $w in tokenize(normalize-space($wit), '\s+')[. ne '']
        return substring($w, 2), ' ')"/>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Named entities                                                -->
  <!-- ============================================================ -->

  <xsl:template match="tei:placeName | tei:persName">
    <span class="entity entity-{local-name()}"
          data-ref="{@ref}">
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Witness list                                                  -->
  <!-- ============================================================ -->

  <xsl:template name="witness-list">
    <footer class="witnesses">
      <h2>Witnesses</h2>
      <dl>
        <xsl:for-each select="//tei:listWit/tei:witness">
          <dt class="siglum"><xsl:value-of select="normalize-space(tei:abbr)"/></dt>
          <dd>
            <xsl:choose>
              <xsl:when test="tei:msDesc">
                <xsl:value-of select="normalize-space(
                    string-join(tei:msDesc/tei:msIdentifier/* ! normalize-space(.), ', '))"/>
                <xsl:if test="tei:msDesc//tei:scriptNote">
                  <span class="script-note">
                    <xsl:value-of select="normalize-space(tei:msDesc//tei:scriptNote)"/>
                  </span>
                </xsl:if>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="normalize-space(tei:desc)"/>
              </xsl:otherwise>
            </xsl:choose>
          </dd>
        </xsl:for-each>
      </dl>
    </footer>
  </xsl:template>

  <!-- Suppress the header from the body flow; it is handled explicitly. -->
  <xsl:template match="tei:teiHeader"/>
  <xsl:template match="tei:facsimile"/>

  <xsl:template match="tei:p">
    <p><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="tei:emph">
    <em><xsl:apply-templates/></em>
  </xsl:template>

  <xsl:template match="tei:ref">
    <a href="{@target}"><xsl:apply-templates/></a>
  </xsl:template>

  <xsl:template match="tei:mentioned">
    <code><xsl:apply-templates/></code>
  </xsl:template>

</xsl:stylesheet>

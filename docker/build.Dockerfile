# Tooling image for scripts/*.sh and the Python test suite.
#
# Pinned tool *versions* (Saxon, Jing, TEI Stylesheets) still come from
# scripts/bootstrap.sh, exactly as they do outside Docker; this image only
# supplies the runtimes those scripts expect (Java, Python, xmllint,
# zip/unzip, curl), so bootstrap/build-schema/validate/build-xar/pytest run
# the same way whether or not the host has a JDK installed.
FROM eclipse-temurin:21-jdk

RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        python3 python3-pip libxml2-utils unzip zip curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY services/flask/requirements.txt /tmp/flask-requirements.txt
RUN pip3 install --no-cache-dir pytest rdflib -r /tmp/flask-requirements.txt 2>/dev/null || \
    pip3 install --no-cache-dir --break-system-packages pytest rdflib -r /tmp/flask-requirements.txt

WORKDIR /workspace

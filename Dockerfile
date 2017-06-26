FROM openjdk:8u131-jre-alpine

RUN apk add --no-cache bash curl lsof wget

ARG SOLR_USER=solr
ARG SOLR_UID=8983
ARG SOLR_VERSION=6.5.1

RUN addgroup -S -g $SOLR_UID $SOLR_USER && \
  adduser -S -u $SOLR_UID -G $SOLR_USER -g $SOLR_USER $SOLR_USER

RUN mkdir -p /tmp/solr /opt \
    && cd /tmp/solr \
    && wget -q zenpip.zenoss.eng/packages/solr-$SOLR_VERSION.tgz \
    && tar -xf solr-$SOLR_VERSION.tgz solr-$SOLR_VERSION/bin/install_solr_service.sh --strip-components=2 \
    && bash install_solr_service.sh solr-$SOLR_VERSION.tgz -n \
    && echo -e "\n>> Note: preceding \"update-rc.d command not found\" error is benign\n" \
    && chmod +x /opt/solr/server/scripts/cloud-scripts/zkcli.sh \
    && rm -rf /tmp/solr

COPY ./init-solr.sh /usr/local/bin
COPY ./core-site.xml /opt/solr/server/etc/hadoop/

HEALTHCHECK CMD "curl -A Healthcheck -sI localhost:8983/solr/admin/cores | grep 'HTTP/1.1 200 OK'"

ENV PATH /opt/solr/bin:$PATH
WORKDIR /opt/solr
USER $SOLR_USER


FROM checkmarx/kics:v2.1.20-debian AS kics

FROM summerwind/actions-runner:latest

USER root

ENV KICS_QUERIES_PATH=/opt/kics/assets/queries
ENV KICS_LIBRARIES_PATH=/opt/kics/assets/libraries

COPY --from=kics /app/bin/kics /usr/local/bin/kics

COPY --from=kics \
  /app/bin/assets/queries \
  /opt/kics/assets/queries

COPY --from=kics \
  /app/bin/assets/libraries \
  /opt/kics/assets/libraries

RUN chmod +x /usr/local/bin/kics

USER runner
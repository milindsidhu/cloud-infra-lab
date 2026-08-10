# ------------------------------------------------------------------------------
# Custom GitHub Actions Runner Image with KICS
# ------------------------------------------------------------------------------
#
# This image extends the official Summerwind GitHub Actions runner image and
# bundles KICS (Keeping Infrastructure as Code Secure) into the runner.
#
# Purpose:
# - Provide a self-contained GitHub Actions runner with KICS pre-installed.
# - Avoid installing/downloading KICS during every workflow execution.
# - Enable Infrastructure as Code (IaC) security scanning directly from CI jobs.
#
# Base Image:
# - summerwind/actions-runner:latest
#
# Additional Tooling:
# - KICS v2.1.20
# - KICS query rules
# - KICS libraries
#
# Usage:
# Intended for personal CI/CD workflows requiring KICS scanning.
# Replace with summerwind/actions-runner:latest if KICS is not required.
#
# ------------------------------------------------------------------------------

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
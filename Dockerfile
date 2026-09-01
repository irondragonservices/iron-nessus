# Nessus is proprietary and licensed per activation. This image is built
# locally, by whoever holds the licence, and is not published. See the README.
#
#   docker build --secret id=nessus_code,env=NESSUS_ACTIVATION_CODE -t iron-nessus .
#
FROM debian:13.6-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

# The Tenable download to fetch. Their download IDs pin both the version and the
# distribution, so this changes when either does.
ARG NESSUS_PACKAGE=Nessus-latest-debian10_amd64.deb
ARG NESSUS_URL=https://www.tenable.com/downloads/api/v2/pages/nessus/files/${NESSUS_PACKAGE}

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl libcap2-bin tzdata \
    && useradd --shell /usr/sbin/nologin --uid 1000 --home-dir /opt/nessus --user-group app \
    && curl -fsSL -o /tmp/nessus.deb "${NESSUS_URL}" \
    && dpkg -i /tmp/nessus.deb \
    && rm /tmp/nessus.deb \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# nessusd needs to raise its own resource limits and to send raw packets; it
# gets those as file capabilities rather than by running as root.
#
# Upstream set these twice, the first pair immediately overwritten by the
# second — setcap replaces the whole capability set rather than adding to it.
RUN setcap "cap_net_admin,cap_net_raw,cap_sys_resource+eip" /opt/nessus/sbin/nessusd \
    && setcap "cap_net_admin,cap_net_raw,cap_sys_resource+eip" /opt/nessus/sbin/nessus-service

# Register and fetch the plugin feed.
#
# The activation code arrives as a build secret, not as a build ARG. An ARG
# used in a RUN is recorded in the image history and readable with
# `docker history`, so upstream's NESSUS_SERIAL was baked into every image
# built from it — which is also why that image could never be published.
RUN --mount=type=secret,id=nessus_code,required=true \
    /opt/nessus/sbin/nessuscli fetch --register "$(cat /run/secrets/nessus_code)" \
    && /opt/nessus/sbin/nessusd -R

RUN chown -R app:app /opt/nessus \
    && chmod u=rx,g=,o= /opt/nessus/sbin/*

WORKDIR /opt/nessus
EXPOSE 8834
USER app
VOLUME [ "/opt/nessus" ]
ENTRYPOINT [ "/opt/nessus/sbin/nessusd", "--no-root" ]

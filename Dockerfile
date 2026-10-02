# --------------------------------------------------------------------------------
# Docker configuration for a native Ubuntu Perforce Helix P4D server
# --------------------------------------------------------------------------------
#
# This image runs the official Perforce Helix P4D package (helix-p4d) installed
# directly on Ubuntu via the official Perforce APT repository. No pinned build
# numbers are used: the server version tracked by the repository is what ships.

FROM ubuntu:noble

# Install package management tools and editors
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget gnupg2 ca-certificates nano vim-tiny && \
    rm -rf /var/lib/apt/lists/*

# Import Perforce package signing key
RUN wget -qO - https://package.perforce.com/perforce.pubkey | \
    gpg --dearmor -o /usr/share/keyrings/perforce.gpg

# Add the official Perforce repository for Ubuntu 24.04 (noble)
RUN echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] http://package.perforce.com/apt/ubuntu noble release" | \
    tee /etc/apt/sources.list.d/perforce.list

# --------------------------------------------------------------------------------
# Docker BUILD
# --------------------------------------------------------------------------------

# Create the Perforce service user and group, install the Perforce Server, and
# add the helper scripts. The helix-p4d and helix-swarm-triggers packages are
# resolved to whatever the official repository currently provides (latest).
RUN apt-get update && \
    apt-get install -y --no-install-recommends helix-p4d helix-swarm-triggers && \
    rm -rf /var/lib/apt/lists/*

# Ensure server directories exist and are owned by the perforce service user
# (the perforce user and group are created automatically by the helix-p4d package).
RUN mkdir -p /opt/perforce/p4/home/root/etc \
    /opt/perforce/p4/home/depots \
    /opt/perforce/p4/home/checkpoints \
    /opt/perforce/p4/home/root/logs \
    /opt/perforce/p4/home/root/journal && \
    chown -R perforce:perforce /opt/perforce

# Add helper scripts
COPY files/init.sh /usr/local/bin/init.sh
COPY files/setup.sh /usr/local/bin/setup.sh
COPY files/restore.sh /usr/local/bin/restore.sh
COPY files/latest_checkpoint.sh /usr/local/bin/latest_checkpoint.sh
COPY files/configure.sh /usr/local/bin/configure.sh
COPY files/ssl.sh /usr/local/bin/ssl.sh

RUN \
    chmod +x /usr/local/bin/init.sh \
             /usr/local/bin/setup.sh \
             /usr/local/bin/restore.sh \
             /usr/local/bin/latest_checkpoint.sh \
             /usr/local/bin/configure.sh \
             /usr/local/bin/ssl.sh

# --------------------------------------------------------------------------------
# Docker ENVIRONMENT
# --------------------------------------------------------------------------------

# Default Environment
ARG NAME=perforce-server
ARG P4NAME=master
ARG P4TCP=1666
ARG P4USER=admin
ARG P4PASSWD=pass12349ers
ARG P4CASE=-C0
ARG P4CHARSET=utf8

# Dynamic Environment
ENV NAME=$NAME \
    P4NAME=$P4NAME \
    P4TCP=$P4TCP \
    P4PORT=$P4TCP \
    P4USER=$P4USER \
    P4PASSWD=$P4PASSWD \
    P4CASE=$P4CASE \
    P4CHARSET=$P4CHARSET \
    JNL_PREFIX=perforce-server

# Base Environment
ENV P4HOME=/opt/perforce/p4/home

# Derived Environment
ENV P4ROOT=$P4HOME/root \
    P4DEPOTS=$P4HOME/depots \
    P4CKP=$P4HOME/checkpoints \
    P4LOG=$P4HOME/root/logs \
    P4JOURNAL=$P4HOME/root/journal

# Editor Environment
ENV P4EDITOR=nano \
    EDITOR=nano

# Base service user
ENV P4USER_NAME=perforce

# Expose Perforce; TCP port and volumes
EXPOSE $P4TCP
VOLUME ["/opt/perforce/p4/home/root", "/opt/perforce/p4/home/checkpoints", "/opt/perforce/p4/home/depots"]

# --------------------------------------------------------------------------------
# Docker RUN
# --------------------------------------------------------------------------------

ENTRYPOINT ["/usr/local/bin/init.sh"]

HEALTHCHECK \
  --interval=2m \
  --timeout=10s \
  CMD p4 info -s > /dev/null || exit 1

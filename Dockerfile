# Use a Linux base image that supports ARM64 incase installing on an M1 Mac
# chose debian bullseye because its lightweight but an official distribution
FROM debian:bullseye

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive
#ENV RBENV_ROOT="/home/brew/.rbenv"
#ENV PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

# Install the required prerequisites software and some that aren't specified
# on the ESO page but are still needed (like git) and vim (because.)
# x11-apps, libgtk and libcanberra are to enable x11 forwarding.
RUN apt-get update && apt-get install -y \
    vim \
    x11-apps \
    libgtk2.0-0 \
    libcanberra-gtk-module \
    g++ \
    zlib1g-dev \
    libcurl4-openssl-dev \
    make \
    gzip \
    bzip2 \
    tar \
    perl \
    gawk \
    sed \
    grep \
    coreutils \
    pkg-config \
    curl \
    git \
    gfortran \
    python3-matplotlib \
    python3-wxgtk4.0 \
    python3-astropy \
    python3-numpy \
    python3-sklearn \
    openjdk-11-jre \
    default-jdk \
    libffi-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# set up the installation directory and download the installation script. NOTE!
# need to use tbar updated installation script on tans github which only
# downloads the MUSE pipeline.
# set an alias so can just type $esoreflex to begin the program

RUN INSTALL_DIR=${HOME}/pipelines/reflex/$(date +%Y-%m-%d) && \
    mkdir -pv ${INSTALL_DIR} \
    && cd ${INSTALL_DIR} \
    && curl -O https://raw.githubusercontent.com/tansb/muse_esoreflex_docker/refs/heads/main/install_esoreflex_muse_only.sh \
    && chmod u+x install_esoreflex_muse_only.sh \
    && bash install_esoreflex_muse_only.sh \
    && echo '#' >> ~/.bashrc \
    && echo '# tbar: add an alias so can just type $esoreflex to begin the program'  >> ~/.bashrc \
    && echo 'alias esoreflex="/root/pipelines/reflex/*/install/bin/esoreflex"' >> ~/.bashrc

# Set the default shell to bash
CMD ["/bin/bash"]
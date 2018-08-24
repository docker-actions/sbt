FROM ubuntu:bionic as build

ARG REQUIRED_PACKAGES="sed grep rsync"

ARG SBT_VERSION=1.1.6
ARG SHA256_SUM=f545b530884e3abbca026df08df33d5a15892e6d98da5b8c2297413d1c7b68c1

ENV ROOTFS /build/rootfs
ENV BUILD_DEBS /build/debs
ENV DEBIAN_FRONTEND=noninteractive

# Build pre-requisites
RUN bash -c 'mkdir -p ${BUILD_DEBS} ${ROOTFS}/{usr/local/bin,opt}'

# Fix permissions
RUN chown -Rv 100:root $BUILD_DEBS

# Install pre-requisites
RUN apt-get update \
        && apt-get -y install apt-utils curl

# Unpack required packges to rootfs
RUN cd ${BUILD_DEBS} \
  && for pkg in $REQUIRED_PACKAGES; do \
       apt-get download $pkg \
         && apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends -i $pkg | grep '^[a-zA-Z0-9]' | xargs apt-get download ; \
     done
RUN if [ "x$(ls ${BUILD_DEBS}/)" = "x" ]; then \
      echo No required packages specified; \
    else \
      for pkg in ${BUILD_DEBS}/*.deb; do \
        echo Unpacking $pkg; \
        dpkg -x $pkg ${ROOTFS}; \
      done; \
    fi

# sbt
RUN cd ${ROOTFS}/opt \
  && curl -L -o sbt.tar.gz https://piccolo.link/sbt-${SBT_VERSION}.tgz \
  && echo "$SHA256_SUM sbt.tar.gz" | sha256sum -c - \
  && tar -xzf sbt.tar.gz \
  && rm -f sbt.tar.gz \
  && ln -s /opt/sbt/bin/sbt ${ROOTFS}/usr/bin/sbt

COPY entrypoint.sh ${ROOTFS}/usr/local/bin/entrypoint.sh
RUN chmod +x ${ROOTFS}/usr/local/bin/entrypoint.sh

FROM actions/java:8u181-jdk-4
LABEL maintainer = "ilja+docker@bobkevic.com"

ARG ROOTFS=/build/rootfs

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY --from=build ${ROOTFS} /

# Get scala
RUN /usr/bin/sbt about

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

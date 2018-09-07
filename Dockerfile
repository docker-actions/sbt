FROM ubuntu:bionic as build

ARG REQUIRED_PACKAGES="sed grep rsync"

ARG SBT_VERSION=1.2.1
ARG SHA256_SUM=469c899d9d878ee5ed3f0e6fdc4095da2bf4a104d4ed72bd59a817b8354ad7df

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

# Move /sbin out of the way
RUN mv ${ROOTFS}/sbin ${ROOTFS}/sbin.orig \
      && mkdir -p ${ROOTFS}/sbin \
      && for b in ${ROOTFS}/sbin.orig/*; do \
           echo 'cmd=$(basename ${BASH_SOURCE[0]}); exec /sbin.orig/$cmd "$@"' > ${ROOTFS}/sbin/$(basename $b); \
           chmod +x ${ROOTFS}/sbin/$(basename $b); \
         done

COPY entrypoint.sh ${ROOTFS}/usr/local/bin/entrypoint.sh
RUN chmod +x ${ROOTFS}/usr/local/bin/entrypoint.sh

FROM actions/java:8u181-jdk-6
LABEL maintainer = "ilja+docker@bobkevic.com"

ARG ROOTFS=/build/rootfs

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY --from=build ${ROOTFS} /

# Get scala
RUN /usr/bin/sbt about

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

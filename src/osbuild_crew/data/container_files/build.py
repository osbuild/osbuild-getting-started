osbuild = r"""
FROM registry.fedoraproject.org/fedora-minimal:37

RUN \
    microdnf install -y \
        git \
        python-docutils \
        make \
        pkg-config \
        rpm-build \
        python3-setuptools \
        python3-devel \
        selinux-policy \
        selinux-policy-devel \
        systemd && \
        microdnf clean all

RUN \
    mkdir /build

ADD ./repo /build

WORKDIR \
    /build
"""

osbuild_composer = r"""
FROM registry.fedoraproject.org/fedora:37

RUN \
    dnf install -y \
        git \
        openssl \
        python-docutils \
        make \
        pkg-config \
        rpm-build \
        python3-setuptools \
        python3-devel \
        selinux-policy \
        selinux-policy-devel \
        systemd \
        golang \
        go-compilers-golang-compiler \
        krb5-devel \
        dnf-plugins-core && \
        dnf clean all

RUN \
    mkdir /build

WORKDIR \
    /build

ENV \
    GOFLAGS=-mod=vendor

RUN \
    dnf builddep -y osbuild-composer.spec && \
    dnf clean all
"""

weldr_client = r"""
FROM registry.fedoraproject.org/fedora:37

RUN \
    dnf install -y \
        git \
        make \
        rpm-build \
        dnf-plugins-core && \
        dnf clean all

RUN \
    mkdir /build


WORKDIR \
    /build

ADD ./repo /build

ENV \
    GOFLAGS=-mod=vendor

# XXX fix up from makefile!
RUN \
    make weldr-client.spec && \
    dnf builddep -y --spec -D 'with 1' weldr-client.spec && \
    dnf clean all
"""

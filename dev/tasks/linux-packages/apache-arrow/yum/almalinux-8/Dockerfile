# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

ARG FROM=almalinux:8
FROM ${FROM}

ARG DEBUG

RUN \
  quiet=$([ "${DEBUG}" = "yes" ] || echo "--quiet") && \
  dnf install -y ${quiet} epel-release && \
  dnf install --enablerepo=powertools -y ${quiet} \
    bison \
    boost-devel \
    brotli-devel \
    bzip2-devel \
    c-ares-devel \
    ccache \
    clang \
    cmake \
    curl-devel \
    flex \
    gcc-c++ \
    gflags-devel \
    git \
    glog-devel \
    gobject-introspection-devel \
    json-devel \
    libarchive \
    libxml2-devel \
    libzstd-devel \
    llvm-devel \
    llvm-static \
    lz4-devel \
    make \
    ncurses-devel \
    ninja-build \
    openssl-devel \
    pkg-config \
    python39 \
    python39-pip \
    re2-devel \
    # rapidjson-devel \
    rpmdevtools \
    snappy-devel \
    tar \
    thrift-devel \
    # utf8proc-devel \
    vala \
    which \
    zlib-devel && \
  dnf clean ${quiet} all && \
  ln -s pip3.9 /usr/bin/pip3

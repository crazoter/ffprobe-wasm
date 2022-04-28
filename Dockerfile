FROM emscripten/emsdk:3.1.8 as build

# Warning, FFMPEG 5 is not supported yet; will throw compilation errors.
# See https://github.com/opencv/opencv/issues/21711
ARG FFMPEG_VERSION=4.4.2
# Specify the commit SHA to be fetched from https://code.videolan.org/videolan/x264
ARG X264_COMMIT_SHA=5db6aa6cab1b146e07b60cc1736a01f21da01154

ARG PREFIX=/opt/ffmpeg
ARG MAKEFLAGS="-j4"

RUN apt-get update && apt-get install -y autoconf libtool build-essential git

# libx264
# https://stackoverflow.com/questions/3489173/how-to-clone-git-repository-with-specific-revision-changeset
RUN mkdir /tmp/x264-stable && \
  cd /tmp/x264-stable && \
  git init && git remote add origin https://code.videolan.org/videolan/x264.git && \
  git fetch origin ${X264_COMMIT_SHA} --depth=1 && \
  git reset --hard FETCH_HEAD

RUN cd /tmp/x264-stable && \
  emconfigure ./configure \
  --prefix=${PREFIX} \
  --host=i686-gnu \
  --enable-static \
  --disable-cli \
  --disable-asm \
  --extra-cflags="-s USE_PTHREADS=1"

RUN cd /tmp/x264-stable && \
  emmake make && emmake make install 

# Get ffmpeg source.
RUN cd /tmp/ && \
  wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz && \
  tar zxf ffmpeg-${FFMPEG_VERSION}.tar.gz && rm ffmpeg-${FFMPEG_VERSION}.tar.gz

ARG CFLAGS="-s USE_PTHREADS=1 -O3 -I${PREFIX}/include"
ARG LDFLAGS="$CFLAGS -L${PREFIX}/lib -s INITIAL_MEMORY=33554432"

# Compile ffmpeg.
RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
  emconfigure ./configure \
  --prefix=${PREFIX} \
  --target-os=none \
  --arch=x86_32 \
  --enable-cross-compile \
  --disable-debug \
  --disable-x86asm \
  --disable-inline-asm \
  --disable-stripping \
  --disable-doc \
  --enable-gpl \
  --enable-libx264 \
  --extra-cflags="$CFLAGS" \
  --extra-cxxflags="$CFLAGS" \
  --extra-ldflags="$LDFLAGS" \
  --nm="llvm-nm -g" \
  --ar=emar \
  --as=llvm-as \
  --ranlib=llvm-ranlib \
  --cc=emcc \
  --cxx=em++ \
  --objcc=emcc \
  --dep-cc=emcc

RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
  emmake make -j4 && \
  emmake make install

# COPY ./src/ffprobe-wasm-wrapper.cpp /build/src/ffprobe-wasm-wrapper.cpp
COPY ./Makefile /build/Makefile

WORKDIR /build

RUN make
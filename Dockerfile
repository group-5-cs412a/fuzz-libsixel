FROM aflplusplus/aflplusplus:latest

ENV AFL_USE_ASAN=1
ENV ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:symbolize=0

# Build dependencies
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    libtool \
    make \
    pkg-config \
    libjpeg-dev \
    libpng-dev \
    libgd-dev \
    gdb \
    strace \
    && rm -rf /var/lib/apt/lists/*

# Clone the tagged libsixel release
WORKDIR /src
RUN git clone --branch v1.8.7 --depth 1 https://github.com/saitoha/libsixel.git

# Configure and build libsixel
WORKDIR /src/libsixel
RUN CC=afl-clang-lto CXX=afl-clang-lto++ CFLAGS="-g -O2" CXXFLAGS="-g -O2" ./configure \
    --prefix=/usr/local \
    --disable-shared \
    --enable-static \
    --with-libcurl=no \
    --with-gdk-pixbuf2=no \
    --with-gd \
    --with-jpeg \
    --with-png \
    --disable-python

RUN make -j"$(nproc)" install

# Use --whole-archive as in handout thingy 
COPY harness.c /src/harness.c
RUN afl-clang-lto /src/harness.c -o /usr/local/bin/sixel-harness \
    -I/usr/local/include \
    -L/usr/local/lib -L/usr/local/lib/x86_64-linux-gnu -L/usr/local/lib64 \
    -Wl,--whole-archive -lsixel -Wl,--no-whole-archive \
    -ljpeg -lpng -lgd -lm

# Build vanilla libsixel and harness for QEMU mode (no instrumentation, no ASan)
WORKDIR /src/libsixel
RUN make clean && CC=gcc CXX=g++ ./configure \
    --prefix=/usr/local/vanilla \
    --disable-shared \
    --enable-static \
    --with-libcurl=no \
    --with-gdk-pixbuf2=no \
    --with-gd \
    --with-jpeg \
    --with-png \
    --disable-python
RUN make -j"$(nproc)" install

RUN gcc /src/harness.c -o /usr/local/bin/sixel-harness-qemu \
    -I/usr/local/vanilla/include \
    -L/usr/local/vanilla/lib \
    -Wl,--whole-archive -lsixel -Wl,--no-whole-archive \
    -ljpeg -lpng -lgd -lm

# Check if harness is instrumented (main one should be, qemu one should NOT be)
RUN nm /usr/local/bin/sixel-harness | grep -q "__afl_area_ptr" || (echo "Error: Main harness not instrumented" && exit 1)
RUN if nm /usr/local/bin/sixel-harness-qemu | grep -q "__afl_area_ptr"; then \
        echo "Error: QEMU harness should not be instrumented"; \
        exit 1; \
    fi

# Setup fuzzing workspace
WORKDIR /fuzzing
RUN mkdir -p seeds seeds_extended outputs sixel_crashes scripts
COPY corpus/wrapped_gif/*.gif /fuzzing/seeds/
COPY corpus/wrapped_gif_extended/*.gif /fuzzing/seeds_extended/
COPY sixel_crashes/ /fuzzing/sixel_crashes/
COPY scripts/*.sh /fuzzing/scripts/

# Use 755 for non-root user compatibility
RUN chmod +x /fuzzing/scripts/*.sh && chmod 755 /fuzzing /fuzzing/scripts

CMD ["/bin/bash"]

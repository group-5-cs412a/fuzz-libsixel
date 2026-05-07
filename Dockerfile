FROM aflplusplus/aflplusplus:latest

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
RUN CC=afl-clang-lto CXX=afl-clang-lto++ ./configure \
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

# Check if harness is instrumented
RUN nm /usr/local/bin/sixel-harness | grep -q "__afl_area_ptr" || (echo "Error: Harness not instrumented" && exit 1)

# Setup fuzzing workspace
WORKDIR /fuzzing
RUN mkdir -p seeds outputs sixel_crashes
COPY sixel_crashes/ /fuzzing/sixel_crashes/
COPY test_target.sh /fuzzing/test_target.sh
COPY launch_fuzzer.sh /fuzzing/launch_fuzzer.sh
RUN chmod +x /fuzzing/*.sh

# Copy images from the repo that are 200 bytes or smaller,
# Larger ones really slow down the fuzzing (50 execs / second)
RUN find /src/libsixel/images -type f -size -201c -exec cp {} /fuzzing/seeds/ \;

CMD ["/bin/bash"]

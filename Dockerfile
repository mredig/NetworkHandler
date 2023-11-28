# ================================
# Build image
# ================================
FROM swift:5.9.1-jammy as build

# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y\
    && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

ARG CONFIG
ENV CONFIG=${CONFIG}

# Build everything, with optimizations
RUN --mount=type=cache,target=/build/.build \
    swift \
    build \
    -c $CONFIG \
    --target NetworkHandler \
    --static-swift-stdlib

# Switch to the staging area
WORKDIR /staging

# # # Copy main executable to staging area
# RUN --mount=type=cache,target=/build/.build cp "$(swift build --package-path /build -c $CONFIG --show-bin-path)/Server" ./

# # Copy resources bundled by SPM to staging area
# RUN --mount=type=cache,target=/build/.build find -L "$(swift build --package-path /build -c $CONFIG --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# # Copy any resources from the public directory and views directory if the directories exist
# # Ensure that by default, neither the directory nor any of its contents are writable.
# RUN --mount=type=cache,target=/build/.build [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
# RUN --mount=type=cache,target=/build/.build [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

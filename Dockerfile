# Base Image: Ubuntu 22.04 (GLIBC 2.35 - Good compatibility, supports Tauri v2/Soup3)
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install System Dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    build-essential \
    libwebkit2gtk-4.1-dev \
    libssl-dev \
    libgtk-3-dev \
    libglib2.0-dev \
    libayatana-appindicator3-dev \
    libsoup-3.0-dev \
    librsvg2-dev \
    pkg-config \
    squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (Stable)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Node.js 20 (LTS) - Better compatibility with modern Vite
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Install AppImage Tools (LinuxDeploy)
RUN mkdir -p /build_tools
RUN wget -O /build_tools/linuxdeploy-x86_64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && \
    chmod +x /build_tools/linuxdeploy-x86_64.AppImage
RUN wget -O /build_tools/linuxdeploy-plugin-gtk.sh https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh && \
    chmod +x /build_tools/linuxdeploy-plugin-gtk.sh
# We use a legacy compatible appimagetool if possible, or standard. Standard is usually fine if built on 20.04.
RUN wget -O /build_tools/appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage && \
    chmod +x /build_tools/appimagetool-x86_64.AppImage

WORKDIR /app

# The build script will be passed via volume or command
CMD ["/bin/bash"]

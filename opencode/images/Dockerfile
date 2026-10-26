ARG FEDORA_VERSION=latest
FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION}

# Install Node.js and NPM from yum repositories
# Install Python 3 and development tools
RUN dnf install -y \
	 golang \
	 nodejs \
	 npm \
	 make \
	 python3 \
	 python3-pip \
	 python3-devel \
	 git \
	 gh \
	 libnotify \
	 jq \
	 podman \
	 skopeo \
	 rust \
	 cargo \
	 which \
	 ripgrep \
    && dnf clean all

# Install opencode CLI globally
RUN npm config set ignore-scripts false
RUN npm install -g @opencode/cli@latest --no-fund

# Install common Python tools
RUN pip3 install --no-cache-dir \
    pytest \
    requests \
    pyyaml

# Install rtk (Rust Token Killer) for token-optimized CLI output
RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
    && mv /root/.local/bin/rtk /usr/local/bin/rtk

# Generate the plugin bundled with this RTK version. Keep it outside HOME,
# which is replaced by a tmpfs and host config mounts at runtime.
RUN rtk init -g --opencode --hook-only --no-patch --no-trust-filters </dev/null \
    && install -D -m 644 /root/.config/opencode/plugins/rtk.ts \
        /usr/share/opencode/plugins/rtk/index.ts

# Container-wide opencode config (EnMaaS providers, updates off). Merged with
# the user's ~/.config/opencode/opencode.json mounted at runtime.
COPY ./opencode.json /usr/share/opencode/opencode.json
ENV OPENCODE_CONFIG=/usr/share/opencode/opencode.json

# Create opencode user
RUN useradd -m -u 1000 -s /bin/bash opencode

# Create workspace directory
RUN mkdir -p /workspace && chown -R opencode:opencode /workspace
WORKDIR /workspace

# Switch to opencode user
USER opencode

# Set opencode as the default command
ENTRYPOINT ["opencode"]

# Default to showing help
CMD ["--help"]

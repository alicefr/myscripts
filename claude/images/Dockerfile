ARG FEDORA_VERSION=latest
FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION}

# Install Node.js and NPM from yum repositories
# Install Python 3 and development tools
RUN dnf install -y \
	 golang\
	 nodejs \
	 npm \
	 make \
    python3 \
    python3-pip \
    python3-devel \
	 git \
	 golang \
	 libnotify \
	 jq \
	 podman \
	 rust \
	 cargo \
	 which \
    && dnf clean all

# Install Claude Code CLI globally
RUN npm config set ignore-scripts false
RUN npm install -g @anthropic-ai/claude-code --no-fund


# Install common Python tools
RUN pip3 install --no-cache-dir \
    pytest \
    requests \
    pyyaml

# Create claude user
RUN useradd -m -u 1000 -s /bin/bash claude


# Create Claude configuration directory and copy settings
#   Note: We pre-configure known_marketplaces.json because extraKnownMarketplaces doesn't seem to work in non-interactive mode.
RUN mkdir -p /home/claude/.claude/plugins
COPY ./claude-settings.json /home/claude/.claude/settings.json
COPY ./known_marketplaces.json /home/claude/.claude/plugins/known_marketplaces.json
RUN chown -R claude:claude /home/claude/.claude

# Create workspace directory
RUN mkdir -p /workspace && chown -R claude:claude /workspace
WORKDIR /workspace

# Switch to claude user
USER claude

# Set Claude Code as the default command
ENTRYPOINT ["claude"]

# Default to showing help
CMD ["--help"]

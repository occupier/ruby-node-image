# No defaults: the build is given all three versions (see .github/workflows/next.yml).
# An ARG declared before FROM is empty after it, so each is declared again below.
ARG RUBY_VERSION
FROM cimg/ruby:${RUBY_VERSION}

ARG RUBY_VERSION
# a major or an exact version is resolved to an exact one by scripts/resolve-node.sh before the build
ARG NODE_VERSION
ARG YARN_VERSION

LABEL org.occupier.ruby-version="${RUBY_VERSION}" \
  org.occupier.node-version="${NODE_VERSION}" \
  org.occupier.yarn-version="${YARN_VERSION}"

# manually install node lts
ENV NODE_VERSION=${NODE_VERSION}
RUN [[ $(uname -m) == "x86_64" ]] && ARCH="x64" || ARCH="arm64" && \
  curl -L -o node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" && \
  sudo tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
  rm node.tar.xz && \
  sudo ln -s /usr/local/bin/node /usr/local/bin/nodejs

# corepack is no longer bundled with node as of v25, so install it from npm
RUN sudo npm install -g corepack && sudo corepack enable

ENV YARN_VERSION=${YARN_VERSION}
RUN corepack install -g yarn@$YARN_VERSION && yarn --version

RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
  postgresql-client \
  libgtk-3-0t64 libgbm-dev libnotify-dev libnss3 libxss1 libasound2t64 libxtst6 xauth xvfb \
  libvips \
  xmlstarlet \
  libjemalloc2

RUN sudo apt-get clean
RUN sudo rm -rf /var/lib/apt/lists/*

ENV LD_PRELOAD="libjemalloc.so.2" \
  RUBY_YJIT_ENABLE="1"

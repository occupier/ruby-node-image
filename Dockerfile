FROM cimg/ruby:4.0.5

# manually install node lts
ENV NODE_VERSION=24.17.0
RUN [[ $(uname -m) == "x86_64" ]] && ARCH="x64" || ARCH="arm64" && \
  curl -L -o node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" && \
  sudo tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
  rm node.tar.xz && \
  sudo ln -s /usr/local/bin/node /usr/local/bin/nodejs

ENV YARN_VERSION=4.17.0
RUN corepack enable && corepack install -g yarn@$YARN_VERSION && yarn --version

RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
  postgresql-client \
  libgtk-3-0t64 libgbm-dev libnotify-dev libnss3 libxss1 libasound2t64 libxtst6 xauth xvfb \
  libvips \
  xmlstarlet \
  libjemalloc2

RUN sudo apt-get clean
RUN sudo rm -rf /var/lib/apt/lists/*

ENV LD_PRELOAD="libjemalloc.so.2" \
  RUBY_JYIT_ENABLE="1"

FROM cimg/ruby:3.3.6

# manually install node lts
ENV NODE_VERSION=22.16.0
RUN [[ $(uname -m) == "x86_64" ]] && ARCH="x64" || ARCH="arm64" && \
  curl -L -o node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" && \
  sudo tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
  rm node.tar.xz && \
  sudo ln -s /usr/local/bin/node /usr/local/bin/nodejs

ENV YARN_VERSION=4.9.2
RUN corepack enable && corepack install -g yarn@$YARN_VERSION && yarn --version

RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
  postgresql-client \
  libgtk2.0-0 \
  libgtk-3-0 \
  libgbm-dev \
  libnotify-dev \
  libgconf-2-4 \
  libnss3 \
  libxss1 \
  libasound2 \
  libxtst6 \
  xauth \
  xvfb \
  libvips \
  xmlstarlet \
  libjemalloc2

RUN sudo apt-get clean
RUN sudo rm -rf /var/lib/apt/lists/*

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

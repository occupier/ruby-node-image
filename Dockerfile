FROM cimg/ruby:2.7.6-node

RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
  postgresql-client \
  libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb

RUN sudo apt-get clean
RUN sudo rm -rf /var/lib/apt/lists/*

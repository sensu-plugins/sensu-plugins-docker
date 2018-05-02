#!/bin/bash
set -e

# start docker daemon
nohup dockerd --host=unix:///var/run/docker.sock &

source /etc/profile

DATA_DIR=/tmp/kitchen/data
RUBY_HOME=${MY_RUBY_HOME}

cd $DATA_DIR
SIGN_GEM=false gem build sensu-plugins-docker.gemspec
gem install sensu-plugins-docker-*.gem

# start container for testing

docker run --name test -d --rm alpine sh -c 'while true; do sleep 1; done'

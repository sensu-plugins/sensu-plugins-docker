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

docker run --name test_running -d --rm alpine sh -c 'while true; do sleep 1; done'
docker run --name test_exited_ok -d alpine sh -c 'exit 0'
docker run --name test_exited_fail -d alpine sh -c 'exit 1'

# for debugging
docker ps -a

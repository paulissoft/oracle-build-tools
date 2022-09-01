#!/bin/bash -eux

# Setup Jenkins via Docker on Linux/Mac, see https://www.jenkins.io/doc/book/installing/docker/#setup-wizard

# Setup SSH between Jenkins and Github, see https://levelup.gitconnected.com/setup-ssh-between-jenkins-and-github-e4d7d226b271

# TBD: setting up SSH agent later
test $# -gt 0 || set -- 1 2 3 4 5 6

jenkins_network=jenkins

# Generate a SSH keypair in order to access the Jenkins agent from the Jenkins controller
test -d ~/.ssh || mkdir -m 700 ~/.ssh
test -f ~/.ssh/jenkins_agent_key || ssh-keygen -t rsa -f ~/.ssh/jenkins_agent_key

export SQLCL_ZIP=sqlcl-21.4.1.17.1458.zip
export SQLCL_URL=https://download.oracle.com/otn_software/java/sqldeveloper/$SQLCL_ZIP
export JENKINS_PLUGINS="blueocean:latest docker-workflow:latest"
export JENKINS_AGENT_SSH_PUBKEY=$(cat ~/.ssh/jenkins_agent_key.pub)

# version: latest or lts (long term support)
JENKINS_IMAGE_VERSION=latest
export JENKINS_IMAGE=jenkins/jenkins:${JENKINS_IMAGE_VERSION}-jdk11

docker network ls | grep " $jenkins_network " || docker network create $jenkins_network
! docker compose ls jenkins | grep running || docker-compose down
docker-compose build --build-arg SQLCL_ZIP --build-arg SQLCL_URL --build-arg JENKINS_PLUGINS --build-arg JENKINS_IMAGE
docker-compose up -d

#!/bin/bash -xe

DOCKER_REPO=774915305292.dkr.ecr.us-west-2.amazonaws.com/silinternational-ecs-deploy
VERSION=3.10.5
aws ecr get-login --no-include-email --region us-west-2 | bash

docker build --no-cache -t $DOCKER_REPO:latest -t $DOCKER_REPO:$VERSION -f Dockerfile .
docker push $DOCKER_REPO:latest
docker push $DOCKER_REPO:$VERSION
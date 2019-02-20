#! /bin/bash

##
# Deploy docker image to AWS ECS and execute ecs-deploy script to update ECS service
# Usage: service-deploy.sh {Tag name} {registry URL} {ECS cluster name} {AWS access key ID} {AWS access key secret}
##

TAG=$(echo $1 | tr '/' '-')
REGISTRY=$2
SERVICE_NAME=$3
CLUSTER_NAME=$4
export AWS_ACCESS_KEY_ID=$5
export AWS_SECRET_ACCESS_KEY=$6

eval $(aws ecr get-login --region $AWS_REGION --no-include-email) #needs AWS_REGION AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY envvars

docker tag $IMAGE_NAME:$COMMIT $REGISTRY:$TAG
# "latest" tag is only needed for dev or master
if [ "$TRAVIS_BRANCH" != "stg" ]; then 
	docker tag $IMAGE_NAME:$COMMIT $REGISTRY:latest
else
	docker tag $IMAGE_NAME:$COMMIT $REGISTRY:RC
fi
docker tag $IMAGE_NAME:$COMMIT $REGISTRY:travis-$TRAVIS_BUILD_NUMBER
docker push $REGISTRY:$TAG
# "latest" tag is only needed for dev or master
if [ "$TRAVIS_BRANCH" != "stg" ]; then 
	docker push $REGISTRY:latest
else
	docker push $REGISTRY:RC
fi
docker push $REGISTRY:travis-$TRAVIS_BUILD_NUMBER
curl https://raw.githubusercontent.com/AttestationLegale/ecs-deploy/master/ecs-deploy > ecs-deploy
chmod +x ecs-deploy

echo "Deploying $TRAVIS_BRANCH on $SERVICE_NAME (tag: $REGISTRY:$TAG)"
./ecs-deploy -n $SERVICE_NAME -c $CLUSTER_NAME -i $REGISTRY:$TAG -r $AWS_REGION -k $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY

echo "Deploying $TRAVIS_BRANCH on $SERVICE_NAME done !"

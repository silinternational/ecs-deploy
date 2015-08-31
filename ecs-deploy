#!/usr/bin/env bash

function usage() {
    set -e
    cat <<EOM
    ##### ecs-deploy #####
    Simple script for triggering blue/green deployments on Amazon Elastic Container Service
    https://github.com/silinternational/ecs-deploy

    Required arguments:
        -k | --aws-access-key   AWS Access Key ID. May also be set as environment variable AWS_ACCESS_KEY_ID
        -s | --aws-secret-key   AWS Secret Access Key. May also be set as environment variable AWS_SECRET_ACCESS_KEY
        -r | --region           AWS Region Name. May also be set as environment variable AWS_DEFAULT_REGION
        -c | --cluster          Name of ECS cluster
        -n | --service-name     Name of service to deploy
        -i | --image            Name of Docker image to run, ex: mariadb:latest

    Optional arguments:
        -t | --timeout          Default is 90s. Script monitors ECS Service for new task definition to be running.

    Example:
        ecs-deploy -k ABC123 -s SECRETKEY -c production1 -n doorman-service -i docker.repo.com/doorman:latest

EOM

    exit 2
}

if [ $# == 0 ]; then usage; fi

# Setup default values for variables
CLUSTER=false
SERVICE=false
IMAGE=false
TIMEOUT=90
VERBOSE=false

# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY can be set as environment variables 
if [ -z ${AWS_ACCESS_KEY_ID+x} ]; then AWS_ACCESS_KEY_ID=false; fi
if [ -z ${AWS_SECRET_ACCESS_KEY+x} ]; then AWS_SECRET_ACCESS_KEY=false; fi

# Loop through arguments, two at a time for key and value
while [[ $# > 0 ]]
do
    key="$1"

    case $key in
        -k|--aws-access-key)
            AWS_ACCESS_KEY_ID="$2"
            shift # past argument
            ;;
        -s|--aws-secret-key)
            AWS_SECRET_ACCESS_KEY="$2"
            shift # past argument
            ;;
        -c|--cluster)
            CLUSTER="$2"
            shift # past argument
            ;;
        -n|--service-name)
            SERVICE="$2"
            shift # past argument
            ;;
        -i|--image)
            IMAGE="$2"
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        *)
            usage
            exit 2
        ;;
    esac
    shift # past argument or value
done

if [ $VERBOSE == true ]; then
    set -x
fi

# Make sure we have all the variables needed: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, CLUSTER, SERVICE, IMAGE
if [ $AWS_ACCESS_KEY_ID == false ]; then 
    echo "AWS_ACCESS_KEY_ID is required. You can set it as an environment variable or pass the value using -k or --aws-access-key"
    exit 1
fi
if [ $AWS_SECRET_ACCESS_KEY == false ]; then 
    echo "AWS_SECRET_ACCESS_KEY is required. You can set it as an environment variable or pass the value using -s or --aws-secret-key"
    exit 1
fi
if [ $CLUSTER == false ]; then 
    echo "CLUSTER is required. You can pass the value using -c or --cluster"
    exit 1
fi
if [ $SERVICE == false ]; then 
    echo "SERVICE is required. You can pass the value using -n or --service-name"
    exit 1
fi
if [ $IMAGE == false ]; then 
    echo "IMAGE is required. You can pass the value using -i or --image"
    exit 1
fi

# Get current task definition name from service
TASK_DEFINITION=`aws ecs describe-services --services $SERVICE --cluster $CLUSTER | jq .services[0].taskDefinition | tr -d '"'`
echo "Current task definition: $TASK_DEFINITION";

# Get a JSON representation of the current task definition
aws ecs describe-task-definition --task-def $TASK_DEFINITION > def

# Extract the image from its tag
if ! [[ $IMAGE =~ ^[^:]+:[^:]+$ ]]; then echo "You must specify an image with a tag" && exit 1; fi
im=`echo $IMAGE | cut -d':' -f 1`
tag=`echo $IMAGE | cut -d':' -f 2`

# Extract out the repository from the image, if applicable
if ! [[ $im =~ ^[^/]+/[^/]+$|^[^/]+$ ]]; then echo "Your image/repository specification string is invalid" && exit 1; fi
repo=`echo $im | cut -d '/' -f 1`
imend=`echo $im | cut -d '/' -f 2`

# Replace the image tag in the old def
if [[ $repo == $imend ]]; then
  sed -i def -e "s/\(\"image\": \"$repo\)\(:[^ ]\+\)*\"/\1:$tag\"/"
else
  sed -i def -e "s/\(\"image\": \"$repo\/$imend\)\(:[^ ]\+\)*\"/\1:$tag\"/"
fi

# Filter the def
jq < def > newdef '.taskDefinition|{family: .family, volumes: .volumes, containerDefinitions: .containerDefinitions}'

# Register the new task definition, and store its ARN
NEW_TASKDEF=`aws ecs register-task-definition --cli-input-json file://newdef | jq .taskDefinition.taskDefinitionArn | tr -d '"'`
echo "New task definition: $NEW_TASKDEF";

# Update the service
UPDATE=`aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $NEW_TASKDEF`

# See if the service is able to come up again
every=10
i=0
while [ $i -lt $TIMEOUT ] 
do
  # Scan the list of running tasks for that service, and see if one of them is the
  # new version of the task definition
  rm -f tasks
  
  aws ecs list-tasks --cluster $CLUSTER  --service-name $SERVICE --desired-status RUNNING \
    | jq '.taskArns[]' \
    | xargs -I{} aws ecs describe-tasks --cluster $CLUSTER --tasks {} >> tasks
  
  jq < tasks > results ".tasks[]| if .taskDefinitionArn == \"$NEW_TASKDEF\" then . else empty end|.lastStatus"
  
  RUNNING=`grep -e "RUNNING" results`

  if [ $RUNNING ]; then
    echo "Service updated successfully, new task definition running.";
    exit 0
  fi
  
  sleep $every
  i=$(( $i + $every ))
done

# Timeout
echo "ERROR: New task definition not running within $TIMEOUT seconds"
exit 1


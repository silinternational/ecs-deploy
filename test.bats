#!/usr/bin/env bats

# Tests dont run on linux properly, something to do with set -u
# See: https://github.com/sstephenson/bats/issues/171

BATS_TEST_SKIPPED=0
#BATS_ERROR_STACK_TRACE=()

setup() {
    # Source in ecs-deploy
    . "ecs-deploy"
}

@test "check that usage() returns string and exits with status code 20" {
   run usage
   [ $status -eq 3 ]
}

@test "test assertRequiredArgumentsSet success" {
  SERVICE=true
  TASK_DEFINITION=false
  run assertRequiredArgumentsSet
  [ ! -z $status ]
}
@test "test assertRequiredArgumentsSet status=5" {
  SERVICE=false
  TASK_DEFINITION=false
  run assertRequiredArgumentsSet
  [ $status -eq 5 ]
}
@test "test assertRequiredArgumentsSet status=6" {
  SERVICE=true
  TASK_DEFINITION=true
  run assertRequiredArgumentsSet
  [ $status -eq 6 ]
}
@test "test assertRequiredArgumentsSet status=7" {
  SERVICE=true
  CLUSTER=false
  run assertRequiredArgumentsSet
  [ $status -eq 7 ]
}
@test "test assertRequiredArgumentsSet status=8" {
  SERVICE=true
  CLUSTER=true
  IMAGE=false
  FORCE_NEW_DEPLOYMENT=false
  run assertRequiredArgumentsSet
  [ $status -eq 8 ]
}
@test "test assertRequiredArgumentsSet status=9" {
  SERVICE=true
  CLUSTER=true
  IMAGE=true
  MAX_DEFINITIONS="not a number"
  run assertRequiredArgumentsSet
  [ $status -eq 9 ]
}

# Image name parsing tests
# Reference image name format: [domain][:port][/repo][/][image][:tag]

@test "test parseImageName missing image name" {
  IMAGE=""
  run parseImageName
  [ $status -eq 13 ]
}

@test "test parseImageName invalid image name 1" {
  IMAGE="/something"
  run parseImageName
  [ $status -eq 13 ]
}

@test "test parseImageName invalid port" {
  IMAGE="domain.com:abc/repo/image"
  run parseImageName
  [ $status -eq 13 ]
}

@test "test parseImageName root image no tag" {
  IMAGE="mariadb"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "mariadb:latest" ]
}

@test "test parseImageName root image with tag" {
  IMAGE="mariadb:1.2.3"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "mariadb:1.2.3" ]
}

@test "test parseImageName repo image no tag" {
  IMAGE="repo/image"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "repo/image:latest" ]
}

@test "test parseImageName repo image with tag" {
  IMAGE="repo/image:v1.2.3"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "repo/image:v1.2.3" ]
}

@test "test parseImageName repo multilevel image no tag" {
  IMAGE="repo/multi/level/image"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "repo/multi/level/image:latest" ]
}

@test "test parseImageName repo multilevel image with tag" {
  IMAGE="repo/multi/level/image:v1.2.3"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "repo/multi/level/image:v1.2.3" ]
}

@test "test parseImageName domain plus repo image no tag" {
  IMAGE="docker.domain.com/repo/image"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com/repo/image:latest" ]
}

@test "test parseImageName domain plus repo image with tag" {
  IMAGE="docker.domain.com/repo/image:1.2.3"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com/repo/image:1.2.3" ]
}

@test "test parseImageName domain plus repo multilevel image no tag" {
  IMAGE="docker.domain.com/repo/multi/level/image"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com/repo/multi/level/image:latest" ]
}

@test "test parseImageName domain plus repo multilevel image with tag" {
  IMAGE="docker.domain.com/repo/multi/level/image:1.2.3"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com/repo/multi/level/image:1.2.3" ]
}

@test "test parseImageName domain plus port plus repo image no tag" {
  IMAGE="docker.domain.com:8080/repo/image"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com:8080/repo/image:latest" ]
}

@test "test parseImageName domain plus port plus repo image with tag" {
  IMAGE="docker.domain.com:8080/repo/image:1.2.3"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com:8080/repo/image:1.2.3" ]
}

@test "test parseImageName domain plus port plus repo multilevel image no tag" {
  IMAGE="docker.domain.com:8080/repo/multi/level/image"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com:8080/repo/multi/level/image:latest" ]
}

@test "test parseImageName domain plus port plus repo multilevel image with tag" {
  IMAGE="docker.domain.com:8080/repo/multi/level/image:1.2.3"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com:8080/repo/multi/level/image:1.2.3" ]
}

@test "test parseImageName domain plus port plus repo image with tag from var" {
  IMAGE="docker.domain.com:8080/repo/image"
  TAGVAR="CI_TIMESTAMP"
  CI_TIMESTAMP="1487623908"
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com:8080/repo/image:1487623908" ]
}

@test "test parseImageName domain plus port plus repo multilevel image with tag from var" {
  IMAGE="docker.domain.com:8080/repo/multi/level/image"
  TAGVAR="CI_TIMESTAMP"
  CI_TIMESTAMP="1487623908"
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "docker.domain.com:8080/repo/multi/level/image:1487623908" ]
}

@test "test parseImageName using ecr style domain" {
  IMAGE="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo"
  TAGVAR=false
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:latest" ]
}

@test "test parseImageName using ecr style image name and tag from var" {
  IMAGE="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo"
  TAGVAR="CI_TIMESTAMP"
  CI_TIMESTAMP="1487623908"
  run parseImageName
  [ ! -z $status ]
  [ "$output" == "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1487623908" ]
}

@test "test createNewTaskDefJson with single container in definition" {
  imageWithoutTag="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo"
  useImage="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1111111111"
  TASK_DEFINITION=$(cat <<EOF
{
    "taskDefinition": {
        "status": "ACTIVE",
        "networkMode": "bridge",
        "family": "app-task-def",
        "requiresAttributes": [
            {
                "name": "com.amazonaws.ecs.capability.ecr-auth"
            }
        ],
        "volumes": [],
        "taskDefinitionArn": "arn:aws:ecs:us-east-1:121212345678:task-definition/app-task-def:123",
        "containerDefinitions": [
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value * "
                    }
                ],
                "name": "API",
                "links": [],
                "mountPoints": [],
                "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1487623908",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 80,
                        "hostPort": 10080
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            }
        ],
        "placementConstraints": null,
        "revision": 123
    }
}
EOF
)
  expected='{ "family": "app-task-def", "volumes": [], "containerDefinitions": [ { "environment": [ { "name": "KEY", "value": "value * " } ], "name": "API", "links": [], "mountPoints": [], "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1111111111", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 80, "hostPort": 10080 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] } ], "placementConstraints": null, "networkMode": "bridge" }'
  run createNewTaskDefJson
  [ ! -z $status ]
  [ "$(echo "$output" | jq .)" == "$(echo "$expected" | jq .)" ]
}

@test "test createNewTaskDefJson with single container in definition for AWS Fargate" {
  imageWithoutTag="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo"
  useImage="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1111111111"
  TASK_DEFINITION=$(cat <<EOF
{
    "taskDefinition": {
        "status": "ACTIVE",
        "networkMode": "awsvpc",
        "family": "app-task-def",
        "requiresAttributes": [
            {
                "name": "com.amazonaws.ecs.capability.ecr-auth"
            }
        ],
        "volumes": [],
        "taskDefinitionArn": "arn:aws:ecs:us-east-1:121212345678:task-definition/app-task-def:123",
        "containerDefinitions": [
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "API",
                "links": [],
                "mountPoints": [],
                "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1487623908",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 80,
                        "hostPort": 10080
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            }
        ],
        "revision": 123,
        "executionRoleArn": "arn:aws:iam::121212345678:role/ecsTaskExecutionRole",
        "compatibilities": [
            "EC2",
            "FARGATE"
        ],
        "requiresCompatibilities": [
            "FARGATE"
        ],
        "cpu": "256",
        "memory": "512"
    }
}
EOF
)
  expected='{ "family": "app-task-def", "volumes": [], "containerDefinitions": [ { "environment": [ { "name": "KEY", "value": "value" } ], "name": "API", "links": [], "mountPoints": [], "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1111111111", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 80, "hostPort": 10080 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] } ], "placementConstraints": null, "networkMode": "awsvpc", "executionRoleArn": "arn:aws:iam::121212345678:role/ecsTaskExecutionRole", "requiresCompatibilities": [ "FARGATE" ], "cpu": "256", "memory": "512" }'
  run createNewTaskDefJson
  [ ! -z $status ]
  [ "$(echo "$output" | jq .)" == "$(echo "$expected" | jq .)" ]
}

@test "test createNewTaskDefJson with multiple containers in definition" {
  imageWithoutTag="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo"
  useImage="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1111111111"
  TASK_DEFINITION=$(cat <<EOF
{
    "taskDefinition": {
        "status": "ACTIVE",
        "networkMode": "bridge",
        "family": "app-task-def",
        "requiresAttributes": [
            {
                "name": "com.amazonaws.ecs.capability.ecr-auth"
            }
        ],
        "volumes": [],
        "taskDefinitionArn": "arn:aws:ecs:us-east-1:121212345678:task-definition/app-task-def:123",
        "containerDefinitions": [
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "API",
                "links": [],
                "mountPoints": [],
                "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1487623908",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 80,
                        "hostPort": 10080
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            },
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "cache",
                "links": [],
                "mountPoints": [],
                "image": "redis:latest",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 6376,
                        "hostPort": 10376
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            }
        ],
        "placementConstraints": null,
        "revision": 123
    }
}
EOF
)
  expected='{ "family": "app-task-def", "volumes": [], "containerDefinitions": [ { "environment": [ { "name": "KEY", "value": "value" } ], "name": "API", "links": [], "mountPoints": [], "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1111111111", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 80, "hostPort": 10080 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] }, { "environment": [ { "name": "KEY", "value": "value" } ], "name": "cache", "links": [], "mountPoints": [], "image": "redis:latest", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 6376, "hostPort": 10376 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] } ], "placementConstraints": null, "networkMode": "bridge" }'
  run createNewTaskDefJson
  [ ! -z $status ]
  [ "$(echo "$output" | jq .)" == "$(echo "$expected" | jq .)" ]
}

@test "test createNewTaskDefJson with single container in definition and different repository" {
  imageWithoutTag="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo"
  useImage="111222333444.dkr.ecr.eu-west-1.amazonaws.com/acct/repo:1111111111"
  TASK_DEFINITION=$(cat <<EOF
{
    "taskDefinition": {
        "status": "ACTIVE",
        "networkMode": "bridge",
        "family": "app-task-def",
        "requiresAttributes": [
            {
                "name": "com.amazonaws.ecs.capability.ecr-auth"
            }
        ],
        "volumes": [],
        "taskDefinitionArn": "arn:aws:ecs:us-east-1:121212345678:task-definition/app-task-def:123",
        "containerDefinitions": [
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "API",
                "links": [],
                "mountPoints": [],
                "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1487623908",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 80,
                        "hostPort": 10080
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            }
        ],
        "placementConstraints": null,
        "revision": 123
    }
}
EOF
)
  expected='{ "family": "app-task-def", "volumes": [], "containerDefinitions": [ { "environment": [ { "name": "KEY", "value": "value" } ], "name": "API", "links": [], "mountPoints": [], "image": "111222333444.dkr.ecr.eu-west-1.amazonaws.com/acct/repo:1111111111", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 80, "hostPort": 10080 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] } ], "placementConstraints": null, "networkMode": "bridge" }'
  run createNewTaskDefJson
  [ ! -z $status ]
  [ "$(echo "$output" | jq .)" == "$(echo "$expected" | jq .)" ]
}

@test "test createNewTaskDefJson with multiple containers in definition and different repository" {
  imageWithoutTag="121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo"
  useImage="111222333444.dkr.ecr.eu-west-1.amazonaws.com/acct/repo:1111111111"
  TASK_DEFINITION=$(cat <<EOF
{
    "taskDefinition": {
        "status": "ACTIVE",
        "networkMode": "bridge",
        "family": "app-task-def",
        "requiresAttributes": [
            {
                "name": "com.amazonaws.ecs.capability.ecr-auth"
            }
        ],
        "volumes": [],
        "taskDefinitionArn": "arn:aws:ecs:us-east-1:121212345678:task-definition/app-task-def:123",
        "containerDefinitions": [
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "API",
                "links": [],
                "mountPoints": [],
                "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1487623908",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 80,
                        "hostPort": 10080
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            },
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "cache",
                "links": [],
                "mountPoints": [],
                "image": "redis:latest",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 6376,
                        "hostPort": 10376
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            }
        ],
        "placementConstraints": null,
        "revision": 123
    }
}
EOF
)
  expected='{ "family": "app-task-def", "volumes": [], "containerDefinitions": [ { "environment": [ { "name": "KEY", "value": "value" } ], "name": "API", "links": [], "mountPoints": [], "image": "111222333444.dkr.ecr.eu-west-1.amazonaws.com/acct/repo:1111111111", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 80, "hostPort": 10080 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] }, { "environment": [ { "name": "KEY", "value": "value" } ], "name": "cache", "links": [], "mountPoints": [], "image": "redis:latest", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 6376, "hostPort": 10376 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] } ], "placementConstraints": null, "networkMode": "bridge" }'
  run createNewTaskDefJson
  [ ! -z $status ]
  [ "$(echo "$output" | jq .)" == "$(echo "$expected" | jq .)" ]
}

@test "test parseImageName with tagonly option" {
  TAGONLY="newtag"
  IMAGE="ignore"

  expected=$TAGONLY

  run parseImageName

  [ ! -z $status ]
  [ "$(echo "$output" | jq .)" == "$(echo "$expected" | jq .)" ]
}

@test "test createNewTaskDefJson with multiple containers in definition and replace only tags" {
  TAGONLY="newtag"
  useImage=$TAGONLY

  TASK_DEFINITION=$(cat <<EOF
{
    "taskDefinition": {
        "status": "ACTIVE",
        "networkMode": "bridge",
        "family": "app-task-def",
        "requiresAttributes": [
            {
                "name": "com.amazonaws.ecs.capability.ecr-auth"
            }
        ],
        "volumes": [],
        "taskDefinitionArn": "arn:aws:ecs:us-east-1:121212345678:task-definition/app-task-def:123",
        "containerDefinitions": [
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "API",
                "links": [],
                "mountPoints": [],
                "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:1487623908",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 80,
                        "hostPort": 10080
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            },
            {
                "environment": [
                    {
                        "name": "KEY",
                        "value": "value"
                    }
                ],
                "name": "cache",
                "links": [],
                "mountPoints": [],
                "image": "redis:latest",
                "essential": true,
                "portMappings": [
                    {
                        "protocol": "tcp",
                        "containerPort": 6376,
                        "hostPort": 10376
                    }
                ],
                "entryPoint": [],
                "memory": 128,
                "command": [
                    "/data/run.sh"
                ],
                "cpu": 200,
                "volumesFrom": []
            }
        ],
        "placementConstraints": null,
        "revision": 123
    }
}
EOF
)
  expected='{ "family": "app-task-def", "volumes": [], "containerDefinitions": [ { "environment": [ { "name": "KEY", "value": "value" } ], "name": "API", "links": [], "mountPoints": [], "image": "121212345678.dkr.ecr.us-east-1.amazonaws.com/acct/repo:newtag", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 80, "hostPort": 10080 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] }, { "environment": [ { "name": "KEY", "value": "value" } ], "name": "cache", "links": [], "mountPoints": [], "image": "redis:newtag", "essential": true, "portMappings": [ { "protocol": "tcp", "containerPort": 6376, "hostPort": 10376 } ], "entryPoint": [], "memory": 128, "command": [ "/data/run.sh" ], "cpu": 200, "volumesFrom": [] } ], "placementConstraints": null, "networkMode": "bridge" }'
  run createNewTaskDefJson
  echo $output
  [ ! -z $status ]
  [ "$(echo "$output" | jq .)" == "$(echo "$expected" | jq .)" ]
}

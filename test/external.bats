#!/usr/bin/env bats

# Tests dont run on linux properly, something to do with set -u
# See: https://github.com/sstephenson/bats/issues/171

BATS_TEST_SKIPPED=0
TASK_SET=$(cat <<EOF
{
  "id": "ecs-svc/99",
  "taskSetArn": "arn:aws:ecs:us-east-1:777:task-set/my-cluster/my-spike/ecs-svc/99",
  "serviceArn": "arn:aws:ecs:us-east-1:777:service/my-spike",
  "clusterArn": "arn:aws:ecs:us-east-1:777:cluster/my-cluster",
  "externalId": "stable",
  "status": "ACTIVE",
  "taskDefinition": "arn:aws:ecs:us-east-1:777:task-definition/my-spike:72",
  "computedDesiredCount": 4,
  "pendingCount": 0,
  "runningCount": 4,
  "createdAt": "2021-04-24T19:33:18.289000+02:00",
  "updatedAt": "2021-04-24T19:34:15.229000+02:00",
  "launchType": "FARGATE",
  "platformVersion": "1.4.0",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": [ ],
      "securityGroups": [ ],
      "assignPublicIp": "DISABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:777:targetgroup/my-spike-59b/abc123",
      "containerName": "application",
      "containerPort": 8080
    }
  ],
  "serviceRegistries": [
    {
      "registryArn": "arn:aws:servicediscovery:us-east-1:777:service/xyz789"
    }
  ],
  "scale": {
    "value": 100.0,
    "unit": "PERCENT"
  },
  "stabilityStatus": "STEADY_STATE",
  "stabilityStatusAt": "2021-04-24T19:34:15.229000+02:00",
  "tags": [ ]
}
EOF
)

setup() {
    # Source in ecs-deploy
    . "ecs-deploy"
}

@test "test _EXTERNAL_deploymentScaledTo given percent" {
  local output=$( echo "$TASK_SET" | _EXTERNAL_deploymentScaledTo 30.0 )

  [ "$( echo $output | jq -cr '.scale' )" == "{\"value\":30,\"unit\":\"PERCENT\"}" ]
}

@test "test _EXTERNAL_deploymentLabeledTo given label" {
  local output=$( echo "$TASK_SET" | _EXTERNAL_deploymentLabeledTo canary )

  [[ "$( echo $output | jq -cr '.externalId' )" =~ 'canary-' ]]
}

@test "test _EXTERNAL_deploymentTargetingTaskDefinition given definition" {
  local output=$( echo "$TASK_SET" | _EXTERNAL_deploymentTargetingTaskDefinition "arn:aws:ecs:us-east-1:777:task-definition/my-spike:99" )

  [[ "$( echo $output | jq -cr '.taskDefinition' )" == 'arn:aws:ecs:us-east-1:777:task-definition/my-spike:99' ]]
}
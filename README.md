ecs-deploy
=================

[ ![Codeship Status for silinternational/ecs-deploy](https://app.codeship.com/projects/393a91e0-da8d-0134-6603-1e487e818871/status?branch=master)](https://app.codeship.com/projects/203720)

This script uses the Task Definition and Service entities in Amazon's ECS to instigate an automatic blue/green deployment.

Usage
-----

    One of the following is required:
        -n | --service-name     Name of service to deploy
        -d | --task-definition  Name of task definition to deploy

    Required arguments:
        -k | --aws-access-key         AWS Access Key ID. May also be set as environment variable AWS_ACCESS_KEY_ID
        -s | --aws-secret-key         AWS Secret Access Key. May also be set as environment variable AWS_SECRET_ACCESS_KEY
        -r | --region                 AWS Region Name. May also be set as environment variable AWS_DEFAULT_REGION
        -p | --profile                AWS Profile to use - If you set this aws-access-key, aws-secret-key and region are not needed
           | --aws-instance-profile   Use the IAM role associated with the current AWS instance. Can only be used from within a running AWS instance. If you set this, aws-access-key and aws-secret-key are not needed
        -c | --cluster                Name of ECS cluster
        -n | --service-name           Name of service to deploy
        -i | --image                  Name of Docker image to run, ex: repo/image:latest
                                      Format: [domain][:port][/repo][/][image][:tag]
                                      Examples: mariadb, mariadb:latest, silintl/mariadb,
                                                silintl/mariadb:latest, private.registry.com:8000/repo/image:tag

    Optional arguments:
        -a | --aws-assume-role        ARN for AWS Role to assume for ecs-deploy operations.
        -D | --desired-count          The number of instantiations of the task to place and keep running in your service.
        -m | --min                    minumumHealthyPercent: The lower limit on the number of running tasks during a deployment. (default: 100)
        -M | --max                    maximumPercent: The upper limit on the number of running tasks during a deployment. (default: 200)
        -t | --timeout                Default is 90s. Script monitors ECS Service for new task definition to be running.
        -e | --tag-env-var            Get image tag name from environment variable. If provided this will override value specified in image name argument.
        -to | --tag-only              New tag to apply to all images defined in the task (multi-container task). If provided this will override value specified in image name argument.
        --max-definitions             Number of Task Definition Revisions to persist before deregistering oldest revisions.
                                      Note: This number must be 1 or higher (i.e. keep only the current revision ACTIVE).
                                            Max definitions causes all task revisions not matching criteria to be deregistered, even if they're created manually.
                                            Script will only perform deregistration if deployment succeeds.
        --task-definition-file        File used as task definition to deploy
        --enable-rollback             Rollback task definition if new version is not running before TIMEOUT
        --use-latest-task-def         Will use the most recently created task definition as it's base, rather than the last used.
        --force-new-deployment        Force a new deployment of the service. Default is false.
        --skip-deployments-check      Skip deployments check for services that take too long to drain old tasks
        --run-task                    Run created task now. If you set this, service-name are not needed.
        --wait-for-success            Wait for task execution to complete and to receive the exitCode 0.
        --launch-type                 The launch type on which to run your task. (https://docs.aws.amazon.com/cli/latest/reference/ecs/run-task.html)
        --network-configuration       The network configuration for the task. This parameter is required for task definitions that use
                                          the awsvpc network mode to receive their own elastic network interface, and it is not supported
                                          for other network modes. (https://docs.aws.amazon.com/cli/latest/reference/ecs/run-task.html)
        -v | --verbose                Verbose output
             --version                Display the version

    Requirements:
        aws:  AWS Command Line Interface
        jq:   Command-line JSON processor

    Examples:
      Simple deployment of a service (Using env vars for AWS settings):

        ecs-deploy -c production1 -n doorman-service -i docker.repo.com/doorman:latest

      All options:

        ecs-deploy -k ABC123 -s SECRETKEY -r us-east-1 -c production1 -n doorman-service -i docker.repo.com/doorman -m 50 -M 100 -t 240 -D 2 -e CI_TIMESTAMP -v

      Updating a task definition with a new image:

        ecs-deploy -d open-door-task -i docker.repo.com/doorman:17

      Using profiles (for STS delegated credentials, for instance):

        ecs-deploy -p PROFILE -c production1 -n doorman-service -i docker.repo.com/doorman -t 240 -e CI_TIMESTAMP -v

      Update just the tag on whatever image is found in ECS Task (supports multi-container tasks):

        ecs-deploy -c staging -n core-service -to 0.1.899 -i ignore

    Notes:
      - If a tag is not found in image and an ENV var is not used via -e, it will default the tag to "latest"

Installation
------------

* Install and configure [aws-cli](http://docs.aws.amazon.com/cli/latest/userguide/tutorial-ec2-ubuntu.html#install-cli)
* Install [jq](https://github.com/stedolan/jq/wiki/Installation)
* Install ecs-deploy:
```
curl https://raw.githubusercontent.com/silinternational/ecs-deploy/master/ecs-deploy | sudo tee /usr/bin/ecs-deploy
sudo chmod +x /usr/bin/ecs-deploy

```


How it works
------------

_Note: Some nouns in the next paragraphs are capitalized to indicate that they are words which have specific meanings in AWS_

Remember that in the EC2 Container Service, the relationship between the group of containers which together provide a
useful application (e.g. a database, web frontend, and perhaps some for maintenance/cron) is specified in a Task Definition.
The Task Definition then acts a sort of template for actually running the containers in that group. That resulting group of
containers is known as a Task. Due to the way docker implements networking, generally you can only run one Task per Task
Definition per Container Instance (the virtual machines providing the cluster infrastructure).

Task Definitions are automatically version controlled---the actual name of a Task Definition is composed of two parts, the
Family name, and a version number, like so: `phpMyAdmin:3`

Since a Task is supposed to be a fully self-contained "worker unit" of a broader application, Amazon uses another configuration
entity, Services, to manage the number of Tasks running at any given time. As Tasks are just instantiations of Task Definitions,
a Service is just a binding between a specified revision of a Task Definition, and the number of Tasks which should be run from
it.

Conveniently, Amazon allows this binding to be updated, either to change the number of Tasks running or to change the Task
Definition they are built from. In the former case, the Service will respond by building or killing Tasks to bring the count to
specifications. In the latter case, however, it will do a blue/green deployment, that is, before killing any of the old Tasks,
it will first ensure that a new Task is brought up and ready to use, so that there is no loss of service.

_Naturally, enough computing resources must be available in the ECS cluster for any of this to work._

Consequently, all that is needed to deploy a new version of an application is to update the Service which is running its
Tasks to point at a new version of the Task Definition. `ecs-deploy` uses the python `aws` utility to do this. It,

  * Pulls the JSON representation of the in-use Task Definition; or the most recently created if using `--use-latest-task-def`
  * Edits it
  * Defines a new version, with the changes
  * Updates the Service to use the new version
  * Waits, querying Amazon's API to make sure that the Service has been able to create a new Task

The second step merits more explanation: since a Task Definition [may] define multiple containers, the question arises, "what
must be changed to create a new revision?" Empirically, the surprising answer is nothing; Amazon allows you to create a new
but identical version of a Task Definition, and the Service will still do a blue/green deployment of identical tasks.

Nevertheless, since the system uses docker, the assumption is that improvements to the application are built into
its container images, which are then pushed into a repository (public or private), to then be pulled down for use by ECS. This
script therefore uses the specified `image` parameter as a modification key to change the tag used by a container's image. It
looks for images with the same repository name as the specified parameter, and updates its tag to the one in the specified
parameter.

_A direct consequence of this is that if you define more than one container in your Task Definition to use the same image, all
of them will be updated to the specified tag, even if you set them to use different tags initially. But this is considered to
be an unlikely use case._

This behavior allows two possible process to specify which images, and therefore which configurations, to deploy. First, you
may set the tag to always be `latest` (or some other static value), like so:

    ecs-deploy -c CLUSTERNAME -n SERVICENAME -i my.private.repo.com/frontend_container:latest

This will result in identical new versions of the Task Definition being created, but the Service will still do a blue/green
deployment, and will so will pull down the latest version (if you previously pushed it into the registry).

Alternatively, you may specify some other means of obtaining the tag, since the script `eval`s the image string. You could use
git tags as a map to docker tags:

    ecs-deploy -c CLUSTERNAME -n SERVICENAME -i 'my.private.repo.com/frontend_container:`git describe`'

Or perhaps just obtain read the docker tag from another file in your development:

    ecs-deploy -c CLUSTERNAME -n SERVICENAME -i 'my.private.repo.com/frontend_container:$(< VERSION)'

In any case, just make sure your process builds, tags, and pushes the docker image you use to the repository before running
this script.

Use Environment Variable for tag name value
-------------------------------------------
In some cases you may want to use an environment variable for the tag name of your image.
For instance, we use Codeship for continuous integration and deployment. In their Docker
environment they can build images and tag them with different variables, such as
the current unix timestamp. We want to use these unique and changing values for image tags
so that each task definition refers to a unique docker image/tag. This gives us the
ability to revert/rollback changes by just selecting a previous task definition and
updating the service. We plan to add a revert command/option to ecs-deploy to simplify this further.

Using the ```-e``` argument you can provide the name of an environment variable that
holds the value you wish to use for the tag. On Codeship they set an env var named CI_TIMESTAMP.

So we use ```ecs-deploy``` like this:

    ecs-deploy -c production1 -n doorman-api -i my.private.repo/doorman-api -e CI_TIMESTAMP

AWS IAM Policy Configuration
-------------------------------------------
Here's an example of a suitable custom policy for [AWS IAM](https://aws.amazon.com/documentation/iam/):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DeregisterTaskDefinition",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:ListTaskDefinitions",
        "ecs:RegisterTaskDefinition",
        "ecs:StartTask",
        "ecs:StopTask",
        "ecs:UpdateService",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

Troubleshooting
---------------
 - You must provide AWS credentials in one of the supported formats. If you do
   not, you'll see some error output from the AWS CLI, something like:

        You must specify a region. You can also configure your region by running "aws configure".

Testing
-------
Automated tests are performed using [bats](https://github.com/sstephenson/bats).
The goal of testing is to ensure that updates/changes do not break core functionality.
Unfortunately not all of `ecs-deploy` is testable since portions interact with
AWS APIs to perform actions. So for now any parsing/processing of data locally
is tested.

Any new functionality and pull requests should come with tests as well (if possible).

Github Actions Support
-------
Github Actions support is available.  Add a code block similar to that below to your actions yaml file.  Parameters are passed to the ecs-deploy tool under 'with' section. For each parameter, the parameter name followed by _cmd must be called with the appropriate parameter option like '--aws-access-key' in addition to supplying the parameter aws_access_key with the appropriate value.
```
deploy_to_ecs:
  name: 'Deploy updated container image via blue/green deployment to ECS service.'
  runs-on: ubuntu-18.04
  steps:
  - uses: silinternational/ecs-deploy@master
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: 'us-east-1'
    with:
      aws_access_key_cmd: '--aws-access-key'
      aws_access_key: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws_secret_key_cmd: '--aws-secret-key'
      aws_secret_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      cluster_cmd: '--cluster'
      cluster: 'cluster-name'
      image_cmd: '--image'
      image: '{amazon_id}.dkr.ecr.us-east-1.amazonaws.com/cluster-name/image_name:latest'
      region_cmd: '--region'
      region: 'us-east-1'
      service_name_cmd: '--service-name'
      service_name: 'aws-service-name'
      timeout_cmd: '--timeout'
      timeout: '360'
```
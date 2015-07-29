ecs-deploy
=================

This script uses the Task Definition and Service entities in Amazon's ECS to instigate an automatic blue/green deployment.

Usage
-----

    ecs-deploy <aws_access_key> <aws_secret_key> <aws_region> <cluster> <task_definition> <service> <image> [timeout]

  * `aws_access_key`: your amazon credentials, the access key id
  * `aws_secret_key`: the access key's corresponding secret key
  * `aws_region`: the region your ECS Services are located in

  * `cluster`: the name of the cluster to operate on
  * `task_definition`: the Task Definition to create a new revision of
  * `service`: the name of the Service to update
  * `image`: docker image, and tag to set
  * `timeout`: optional, number of seconds to query Amazon before concluding that the deployment failed. Default is 80 seconds.

How it works
------------

_Note: Some nouns in the next paragraphs are capitalized to indicate that they are words which have specific meanings in AWS_

Remember that in the Elastic Container Service, the relationship between the group of containers which together provide a
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
Tasks to point at a new version of the Task Definition. `aws_ecs_deploy.sh` uses the python `aws` utility to do this. It,

  * Pulls the JSON representation of the in-use Task Definition
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

    ecs-deploy XXXXX XXXXX us-east-1 default my_task_def my_app my.private.repo.com/frontend_container:lastest

This will result in identical new versions of the Task Definition being created, but the Service will still do a blue/green
deployment, and will so will pull down the latest version (if you previously pushed it into the registry).

Alternatively, you may specify some other means of obtaining the tag, since the script `eval`s the image string. You could use
git tags as a map to docker tags:

    ecs-deploy XXXXX XXXXX us-east-1 default my_task_def my_app 'my.private.repo.com/frontend_container:`git describe`'

Or perhaps just obtain read the docker tag from another file in your development:

    ecs-deploy XXXXX XXXXX us-east-1 default my_task_def my_app 'my.private.repo.com/frontend_container:$(< VERSION)'

In any case, just make sure your process builds, tags, and pushes the docker image you use to the repository before running
this script.

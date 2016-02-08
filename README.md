ecs-deploy
=================

This script uses the Task Definition and Service entities in Amazon's ECS to instigate an automatic blue/green deployment.

Usage
-----

    Required arguments:
        -k | --aws-access-key   AWS Access Key ID. May also be set as environment variable AWS_ACCESS_KEY_ID
        -s | --aws-secret-key   AWS Secret Access Key. May also be set as environment variable AWS_SECRET_ACCESS_KEY
        -r | --region           AWS Region Name. May also be set as environment variable AWS_DEFAULT_REGION
        -p | --profile          AWS Profile to use - If you set this aws-access-key, aws-secret-key and region are not needed
        -c | --cluster          Name of ECS cluster
        -n | --service-name     Name of service to deploy
        -i | --image            Name of Docker image to run, ex: repo/image:latest
                                Format: [domain][:port][/repo][/][image][:tag]
                                Examples: mariadb, mariadb:latest, silintl/mariadb,
                                          silintl/mariadb:latest, private.registry.com:8000/repo/image:tag

    Optional arguments:
        -m | --min              minumumHealthyPercent: The lower limit on the number of running tasks during a deployment. (default: 100)
        -M | --max              maximumPercent: The upper limit on the number of running tasks during a deployment. (default: 200)
        -t | --timeout          Default is 90s. Script monitors ECS Service for new task definition to be running.
        -e | --tag-env-var      Get image tag name from environment variable. If provided this will override value specified in image name argument.
        -v | --verbose          Verbose output

    Examples:
      Simple (Using env vars for AWS settings):

        ecs-deploy -c production1 -n doorman-service -i docker.repo.com/doorman:latest

      All options:

        ecs-deploy -k ABC123 -s SECRETKEY -r us-east-1 -c production1 -n doorman-service -i docker.repo.com/doorman -m 50 -M 100 -t 240 -e CI_TIMESTAMP -v

        Using profiles (for STS delegated credentials, for instance):

        ecs-deploy -p PROFILE -c production1 -n doorman-service -i docker.repo.com/doorman -m 50 -M 100 -t 240 -e CI_TIMESTAMP -v

    Notes:
      - If a tag is not found in image and an ENV var is not used via -e, it will default the tag to "latest"

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

    ecs-deploy -c CLUSTERNAME -n SERVICENAME -i my.private.repo.com/frontend_container:lastest

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
For instance, we use Codeship for continous integration and deployment. In their Docker
environment they can build images and tag them with different variables, such as
the current unix timestamp. We want to use these unique and changing values for image tags
so that each task definition refers to a unique docker image/tag. This gives us the
ability to revert/rollback changes by just selecting a previous task definition and
updating the service. We plan to add a revert command/option to ecs-deploy to simplify this further.

Using the ```-e``` argument you can provide the name of an environment variable that
holds the value you wish to use for the tag. On Codeship they set an env var named CI_TIMESTAMP.

So we use ```ecs-deploy``` like this:

    ecs-deploy -c production1 -n doorman-api -i my.private.repo/doorman-api -e CI_TIMESTAMP

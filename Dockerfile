FROM alpine:3.5

# Update APK cache
RUN apk update

# Install packges needed
RUN apk add ca-certificates curl bash jq py2-pip && \
    pip install awscli

COPY ecs-deploy /ecs-deploy
RUN chmod a+x /ecs-deploy

COPY test.bats /test.bats
COPY run-tests.sh /run-tests.sh
RUN chmod a+x /run-tests.sh

ENTRYPOINT ["/ecs-deploy"]

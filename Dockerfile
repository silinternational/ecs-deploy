FROM alpine:3.12

# Install packges needed
RUN apk --no-cache add ca-certificates curl bash jq py3-pip && \
    pip install awscli

COPY ecs-deploy /ecs-deploy
RUN chmod a+x /ecs-deploy

COPY test.bats /test.bats
COPY run-tests.sh /run-tests.sh
RUN chmod a+x /run-tests.sh

ENTRYPOINT ["/ecs-deploy"]

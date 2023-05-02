FROM alpine:3.13

# Install required packages
RUN apk --no-cache add ca-certificates curl bash jq py3-pip && \
    pip install awscli

COPY ecs-deploy /usr/local/bin/ecs-deploy
RUN chmod a+x /usr/local/bin/ecs-deploy
RUN ln -s /usr/local/bin/ecs-deploy /ecs-deploy

COPY test.bats /test.bats
COPY run-tests.sh /run-tests.sh
RUN chmod a+x /run-tests.sh

ENTRYPOINT ["ecs-deploy"]

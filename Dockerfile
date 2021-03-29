FROM alpine:3.13.3

# Install packges needed
RUN apk update && \
    apk add py-pip && \
    apk --no-cache add ca-certificates curl bash jq py3-pip && \
    pip install awscli

COPY ecs-deploy /usr/local/bin/ecs-deploy
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/ecs-deploy /usr/local/bin/entrypoint.sh

COPY test.bats /test.bats
COPY run-tests.sh /run-tests.sh
RUN chmod a+x /run-tests.sh

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "/usr/local/bin/ecs-deploy" ]

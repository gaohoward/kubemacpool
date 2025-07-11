#!/bin/bash

if [ -z "$ARCH" ] || [ -z "$PLATFORMS" ] || [ -z "$KUBEMACPOOL_IMAGE_TAGGED" ] || [ -z "$KUBEMACPOOL_IMAGE_GIT_TAGGED" ] || [ -z "$DOCKER_BUILDER" ]  || [ -z "$REGISTRY" ]; then
    echo "Error: ARCH, PLATFORMS, KUBEMACPOOL_IMAGE_TAGGED, KUBEMACPOOL_IMAGE_GIT_TAGGED and DOCKER_BUILDER must be set."
    exit 1
fi

IFS=',' read -r -a PLATFORM_LIST <<< "$PLATFORMS"

if [[ "${REGISTRY}" == localhost* || "${REGISTRY}" == 127.0.0.1* ]]; then
    echo "Local registry detected (${REGISTRY}). Skipping $KUBEMACPOOL_IMAGE_GIT_TAGGED handling.";
    BUILD_ARGS="--build-arg BUILD_ARCH=$ARCH -f build/Dockerfile -t $KUBEMACPOOL_IMAGE_TAGGED ."
else
    if skopeo inspect docker://${KUBEMACPOOL_IMAGE_GIT_TAGGED} >/dev/null 2>&1; then
        echo "Tag '${KUBEMACPOOL_IMAGE_GIT_TAGGED}' already exists in the registry. Skipping tagging with ${KUBEMACPOOL_IMAGE_GIT_TAGGED}."
        BUILD_ARGS="--build-arg BUILD_ARCH=$ARCH -f build/Dockerfile -t $KUBEMACPOOL_IMAGE_TAGGED ."
    else
        BUILD_ARGS="--build-arg BUILD_ARCH=$ARCH -f build/Dockerfile -t $KUBEMACPOOL_IMAGE_TAGGED -t $KUBEMACPOOL_IMAGE_GIT_TAGGED ."
    fi
fi

echo "Building image with the following arguments: $BUILD_ARGS"

if [ ${#PLATFORM_LIST[@]} -eq 1 ]; then
    echo "Building for a single platform: ${PLATFORM_LIST[0]}"
    docker build --platform "$PLATFORMS" $BUILD_ARGS
    docker push "$KUBEMACPOOL_IMAGE_TAGGED"
else
    echo "Building for multiple platforms, docker_builder: ${DOCKER_BUILDER}"
    ./hack/init-buildx.sh "$DOCKER_BUILDER"
    docker buildx build --platform "$PLATFORMS" $BUILD_ARGS
    docker buildx rm "$DOCKER_BUILDER" 2>/dev/null || echo "Builder ${DOCKER_BUILDER} not found or already removed, skipping."
fi

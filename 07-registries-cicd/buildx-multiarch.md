# Multi-Arch Builds with Buildx

Build AMD64 and ARM64 images once and push to Docker Hub.

## Setup
```bash
docker buildx version
# Create and use a builder
docker buildx create --name multi --use || docker buildx use multi
# Optional: install QEMU for emulation on x86 hosts
docker run --privileged --rm tonistiigi/binfmt --install all
```

## Build & Push
```bash
export IMAGE="$DOCKERHUB_USERNAME/app"
export TAG="v1"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t $IMAGE:$TAG \
  --push .
```

## Caching
```bash
# Registry cache to speed up CI
--cache-to=type=registry,ref=$IMAGE:buildcache,mode=max \
--cache-from=type=registry,ref=$IMAGE:buildcache
```

## Bake Files
Use `docker-bake.hcl` for structured targets and platforms.

```hcl
# docker-bake.hcl
variable "IMAGE" {}
variable "TAG" { default = "v1" }

group "default" { targets = ["app"] }

target "app" {
  context   = "."
  tags      = ["${IMAGE}:${TAG}"]
  platforms = ["linux/amd64","linux/arm64"]
}
```

```bash
docker buildx bake --set app.tags=$IMAGE:$TAG --push
```

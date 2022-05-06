set -ex

docker run -it --rm \
 -v `realpath .`:/host \
 debian:bullseye-slim \
 /bin/sh /host/prepare.sh

docker build -t dmikhin/busybox:minimal .
docker push dmikhin/busybox:minimal

# busybox-docker

Build hush and timeout applets in busybox. Binary is statically linked with uclibc, so resulting size is less then 100kb. Resulting binary is wrapped inside docker container and pushed to https://hub.docker.com/r/dmikhin/busybox.

To build and push docker image just execute ./run.sh inside this repo.

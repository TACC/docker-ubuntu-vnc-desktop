docker-ubuntu-vnc-desktop-application-base
=========================

Base docker image (HTML5 VNC interface to access Ubuntu 16.04 LXDE desktop environment) for applications. This image is used by interactive/gui applications.  Details on how to use this image to create an application can be found in [below](#use-base-image-to-create-an-application).


Fork of https://github.com/fcwu/docker-ubuntu-vnc-desktop
(see [that readme file ](README_original.md) for general information)


### Build base image

docker build -t taccaci/docker-ubuntu-vnc-desktop-application-base:TAG .

### Run docker container locally

Run the docker container and access at http://127.0.0.1:6080/
```
docker run -p 6080:80 taccaci/docker-ubuntu-vnc-desktop-application-base:TAG
```

### Run docker container on designsafe-exec-01

Run the docker container and access with https://designsafe-exec-01.tacc.utexas.edu:$port/#/
(note command has env variables: port, AGAVE_JOB_OWNER, and GUI_APPLICATION_DIRECTORY)

```
export port=59XX
export AGAVE_JOB_OWNER=USER
export MYDATA=/tmp #e.g. "/corral-repl/tacc/NHERI/shared/$AGAVE_JOB_OWNER"
docker run -i --rm -p $port:6080 -e SSL_PORT=6080 -v $MYDATA:"/home/ubuntu/mydata" -e GUI_APPLICATION_DIRECTORY=/home/ubuntu/mydata  -e VNC_PASSWORD=1234 -e RESOLUTION="1080x720" --name "base_image_test_$AGAVE_JOB_OWNER"   -v /etc/pki/tls/certs/designsafe-exec-01.tacc.utexas.edu.cer:/etc/nginx/ssl/nginx.crt -v /etc/pki/tls/private/designsafe-exec-01.tacc.utexas.edu.key:/etc/nginx/ssl/nginx.key taccaci/docker-ubuntu-vnc-desktop-application-base:TAG
```

### Screen depth

DISPLAY_SCREEN_DEPTH (i.e.`-e DISPLAY_SCREEN_DEPTH=24`) can be used to change the color depth which defaults to 16

### Dockerhub

https://hub.docker.com/r/taccaci/docker-ubuntu-vnc-desktop-application-base

## Use base image to create an application
[1] The base image supervisord configuration is configured so that it starts `/applcations.sh`. In the base image, this script file just contains `xterm` so that is what starts when you run the base image.

To create an app using this base image, just create a container where your application is installed and replace `/application.sh` with a call to your application:

```
FROM taccaci/docker-ubuntu-vnc-desktop-application-base:TAG

# Install your app dependencies and app

# Replace application script with script running your application
COPY application.sh /
```

Note that `application.sh` should have proper permissions set (`chmod +xr application.sh`) so the user can run it.

### Working directory of app 
Working directory of the gui app can be set by environement varaible `GUI_APPLICATION_DIRECTORY` (default value if not set is:  `/home/ubuntu/mydata`)

```
mkdir temp_my_data
docker run -p 6080:80 -e GUI_APPLICATION_DIRECTORY=/home/ubuntu/mydata -v temp_my_data:/home/ubuntu/mydata taccaci/docker-ubuntu-vnc-desktop-application-base:TAG
```

### User and group identity
A user ubuntu is creaed with a home of `/home/ubuntu` a uid of `458981` and a gid of `816877`. The uid and gid can be set by the environment variable APP_USER_GROUP_ID and APP_USER_ID
```
docker run ... -e APP_USER_GROUP_ID=12345 -e APP_USER_ID=12345 ...
```

#!/bin/bash

if [ -n "$VNC_PASSWORD" ]; then
    echo -n "$VNC_PASSWORD" > /.password1
    x11vnc -storepasswd $(cat /.password1) /.password2
    chmod 400 /.password*
    sed -i 's/^command=x11vnc.*/& -rfbauth \/.password2/' /etc/supervisor/conf.d/supervisord.conf
    export VNC_PASSWORD=
fi

if [ -n "$X11VNC_ARGS" ]; then
    sed -i "s/^command=x11vnc.*/& ${X11VNC_ARGS}/" /etc/supervisor/conf.d/supervisord.conf
fi

if [ -n "$OPENBOX_ARGS" ]; then
    sed -i "s#^command=/usr/bin/openbox\$#& ${OPENBOX_ARGS}#" /etc/supervisor/conf.d/supervisord.conf
fi

if [ -n "$RESOLUTION" ]; then
    sed -i "s/1024x768/$RESOLUTION/" /usr/local/bin/xvfb.sh
fi

USER=${USER:-root}
HOME=/root
USER_GROUP_ID=${USER_GROUP_ID:-1000}
groupadd --gid $USER_GROUP_ID appgroup

if [ "$USER" != "root" ]; then
    echo "* enable custom user: $USER"
    useradd --uid ${USER_ID:-1001} --create-home --shell /bin/bash --user-group --groups appgroup,adm,sudo $USER
    usermod -g appgroup $USER
    if [ -z "$PASSWORD" ]; then
        echo "  set default password to \"ubuntu\""
        PASSWORD=ubuntu
    fi
    HOME=/home/$USER
    echo "$USER:$PASSWORD" | chpasswd
    cp -r /root/{.config,.gtkrc-2.0,.asoundrc} ${HOME}

    # chown all files and directories excluding mounted dirs
    find $HOME \( -path $HOME/mydata -prune -o \
                  -path $HOME/community -prune -o \
                  -path $HOME/projects -prune -o \
                  -path $HOME/published -prune -o \
                  -path $HOME/public -prune \
                \) \
                -o -print0 | xargs -0 chown $USER:appgroup

    [ -d "/dev/snd" ] && chgrp -R adm /dev/snd
fi
sed -i -e "s|%USER%|$USER|" -e "s|%HOME%|$HOME|" /etc/supervisor/conf.d/supervisord.conf

# check for working directory
if [ ! -d "$GUI_APPLICATION_DIRECTORY" ]; then
    echo "* Not able to find $GUI_APPLICATION_DIRECTORY. Exiting."
    exit 1
fi

# home folder
if [ ! -x "$HOME/.config/pcmanfm/LXDE/" ]; then
    echo "* creating and configuring $HOME/.config/pcmanfm/LXDE/"
    mkdir -p $HOME/.config/pcmanfm/LXDE/
    ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/

    # chown all files and directories excluding mounted dirs
    find $HOME \( -path $HOME/mydata -prune -o \
                  -path $HOME/community -prune -o \
                  -path $HOME/projects -prune -o \
                  -path $HOME/published -prune -o \
                  -path $HOME/public -prune \
                \) \
                -o -print0 | xargs -0 chown $USER:appgroup
fi

# nginx workers
sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# nginx ssl
if [ -n "$SSL_PORT" ]; then
    if [ -e '/etc/nginx/ssl/nginx.crt' -a -e '/etc/nginx/ssl/nginx.key' ]; then
        echo "* enabling SSL"
    else
	echo "enabling SSL failed as /etc/nginx/ssl/nginx.crt and/or /etc/nginx/ssl/nginx.key  were not found!"
	exit 1
    fi
    sed -i 's|#_SSL_PORT_#\(.*\)443\(.*\)|\1'$SSL_PORT'\2|' /etc/nginx/sites-enabled/default
    sed -i 's|#_SSL_PORT_#||' /etc/nginx/sites-enabled/default
fi

# nginx http base authentication
if [ -n "$HTTP_PASSWORD" ]; then
    echo "* enable HTTP base authentication"
    htpasswd -bc /etc/nginx/.htpasswd $USER $HTTP_PASSWORD
	sed -i 's|#_HTTP_PASSWORD_#||' /etc/nginx/sites-enabled/default
fi

# dynamic prefix path renaming
if [ -n "$RELATIVE_URL_ROOT" ]; then
    echo "* enable RELATIVE_URL_ROOT: $RELATIVE_URL_ROOT"
	sed -i 's|#_RELATIVE_URL_ROOT_||' /etc/nginx/sites-enabled/default
	sed -i 's|_RELATIVE_URL_ROOT_|'$RELATIVE_URL_ROOT'|' /etc/nginx/sites-enabled/default
fi

# clearup
PASSWORD=
HTTP_PASSWORD=

exec /bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf

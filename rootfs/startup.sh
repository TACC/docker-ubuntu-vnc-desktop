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
    sed -i "s#^command=/usr/bin/openbox.*#& ${OPENBOX_ARGS}#" /etc/supervisor/conf.d/supervisord.conf
fi

if [ -n "$RESOLUTION" ]; then
    sed -i "s/1024x768/$RESOLUTION/" /usr/local/bin/xvfb.sh
fi

if [ -n "$DISPLAY_SCREEN_DEPTH" ]; then
    sed -i "s/x24/x$DISPLAY_SCREEN_DEPTH/" /usr/local/bin/xvfb.sh
fi

USER="ubuntu"
HOME=/home/$USER
PASSWORD=ubuntu1234!!
groupadd --gid $APP_USER_GROUP_ID appgroup
useradd --uid $APP_USER_ID --create-home --shell /bin/bash --user-group --groups appgroup,adm,sudo $USER && chown $USER:appgroup $HOME
usermod -g appgroup $USER
mkdir -p $HOME/.config/pcmanfm/LXDE/ && cp /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/ && chown -R $USER:appgroup $HOME/.config
echo "$USER:$PASSWORD" | chpasswd
cp -r /root/{.gtkrc-2.0,.asoundrc} ${HOME}
[ -d "/dev/snd" ] && chgrp -R adm /dev/snd
chown -R $USER:$USER $HOME/.[^.]*
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
    chown -R $USER:$USER $HOME/.config/pcmanfm/LXDE
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

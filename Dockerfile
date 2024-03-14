#modified https://github.com/scottyhardy/docker-remote-desktop/

#========================================================================================================
# Build xrdp pulseaudio modules in builder container
# See https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/README
#========================================================================================================

ARG TAG=20.04
FROM ubuntu:$TAG as builder

RUN sed -i -E 's/^# deb-src /deb-src /g' /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        build-essential \
        dpkg-dev \
        git \
        libpulse-dev \
        pulseaudio \
    && apt-get build-dep -y pulseaudio \
    && apt-get source pulseaudio \
    && rm -rf /var/lib/apt/lists/*

RUN cd /pulseaudio-$(pulseaudio --version | awk '{print $2}') \
    && ./configure

RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git /pulseaudio-module-xrdp \
    && cd /pulseaudio-module-xrdp \
    && ./bootstrap \
    && ./configure PULSE_DIR=/pulseaudio-$(pulseaudio --version | awk '{print $2}') \
    && make \
    && make install

#========================================================================================================
# Build the final image
#========================================================================================================

FROM ubuntu:$TAG

ENV LANG en_US.UTF-8
ENV SESUSER=ubuntu
ENV SESPASSWD=ubuntu
# note: ubuntu by default gives the user's group the same name as the user's name

# https://github.com/scottyhardy/docker-remote-desktop/ installs xfce ; this image rather uses openbox
#RUN apt-get update \
#    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
#        dbus-x11 \
#        firefox \
#        git \
#        locales \
#        pavucontrol \
#        pulseaudio \
#        pulseaudio-utils \
#        sudo \
#        x11-xserver-utils \
#        xfce4 \
#        xfce4-pulseaudio-plugin \
#        xorgxrdp \
#        xrdp \
#        xubuntu-icon-theme \
#    && rm -rf /var/lib/apt/lists/*

# minimal install without xfce/openbox
##RUN apt-get update \
##    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
##        firefox \
##        locales \
##        xorgxrdp \
##        xrdp \
##        pulseaudio \
##        pulseaudio-utils \
##    && rm -rf /var/lib/apt/lists/*


# Install xrdp with openbox window manager.
# Having a window manager next to gui app gives us some developer abilities in the image,
# so we also install extra's to have a more developer friendly environment.
#  - xterm/xdotool: to get a terminal and place the window fullscreen with xdotool ( see bin/xterm_custom) 
#  - vim/ne/less: to view/edit files
#  - htop: to see performance of processes
#  - mesa-utils: to test opengl
#  - sudo: to give user root rights; a window manager is run under a normal user account 
RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        locales \
        xorgxrdp \
        xrdp \
        pulseaudio \
        pulseaudio-utils \
        sudo \
        x11-apps \
        mesa-utils \
        xterm \
        x11-xserver-utils \
        xdotool \
        openbox \
        vim \
        ne \
        less \
        htop \
    && rm -rf /var/lib/apt/lists/*




#-----------------------------------------------------------------------------------------------------------------------------
# configure image 
#-----------------------------------------------------------------------------------------------------------------------------


# we use openbox window manager which is best run under a none-root user account

# Create the 'SESUSER' user account with sudo rights
RUN groupadd --gid 1020 $SESUSER
RUN useradd --shell /bin/bash --uid 1020 --gid 1020 --password $(openssl passwd $SESPASSWD) --create-home --home-dir /home/$SESUSER $SESUSER
RUN usermod -aG sudo $SESUSER

# create user's bin folder 
RUN mkdir -p /home/$SESUSER/bin
RUN chown -R $SESUSER:$SESUSER /home/$SESUSER/bin


# add custom xrdp session (run with credentials of user who logs in) 
# - launches openbox 
# - setup environment for openbox: adds $HOME/bin to PATH 
#      instead setting PATH in $HOME/.bashrc we set it in the openbox gui environment 
#      in $HOME/.config/openbox/environment  
# - setup autostart config of openbox to launch a gui program (in $HOME/.config/openbox/autostart)
#   * only if bin/gui-program script exist will gui-program be launched when openbox starts
#   * only if bin/relaunch-gui-program script exists will the gui-program be automatically relaunched on exit (eg. when crashed)
COPY resources/scripts/startwm.sh /etc/xrdp/startwm.sh

# start xrdp sesman service and xrdp service on entrypoint of image
COPY resources/scripts/entrypoint.sh /usr/bin/entrypoint


#-----------------------------------------------------------------------------------------------------------------------------
# install pulseaudio support for xrdp  so that we have sound in our image over RDP
#-----------------------------------------------------------------------------------------------------------------------------

# autospawn pulse audio  
RUN sed -i -E 's/^; autospawn =.*/autospawn = yes/' /etc/pulse/client.conf \
    && [ -f /etc/pulse/client.conf.d/00-disable-autospawn.conf ] && sed -i -E 's/^(autospawn=.*)/# \1/' /etc/pulse/client.conf.d/00-disable-autospawn.conf || : \
    && locale-gen en_US.UTF-8

# copy pulse audio modules for xrdp from builder image to this image 
COPY --from=builder /usr/lib/pulse-*/modules/module-xrdp-sink.so /usr/lib/pulse-*/modules/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer/


# fix for broken audio after reconnecting a rdp session in /etc/xrdp/reconnectwm.sh
# see: https://github.com/scottyhardy/docker-remote-desktop/issues/32
RUN echo 'if ps -e -o cmd | grep "\[xrdp-chansrv\] <defunct>"; then DISPLAY=:10.0 /sbin/xrdp-chansrv & fi' >> /etc/xrdp/reconnectwm.sh

# add test file for sound : left_right.wav
# test in terminal with command:  
#      paplay ~/sound/left_right.wav 
RUN mkdir -p /home/$SESUSER/sound
COPY resources/sound/left_right.wav /home/$SESUSER/sound/left_right.wav


#-----------------------------------------------------------------------------------------------------------------------------
# install gui program in /home/$SESUSER/bin :  firefox
#-----------------------------------------------------------------------------------------------------------------------------
# #install gui program
# note: no option '--no-install-recommends' because that breaks pip3 install (which build pymunk wheel)
RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y  \
        firefox \
    && rm -rf /var/lib/apt/lists/*

# we made wrapper script around firefox so end user can easily change its configuration (options)
COPY resources/bin/firefox_custom /home/$SESUSER/bin/firefox_custom
# to automatically launch it make a softlink with name guiprogram to it (then code in startwm.sh launches it)
RUN ln -r -s  /home/$SESUSER/bin/firefox_custom /home/$SESUSER/bin/guiprogram
#-----------------------------------------------------------------------------------------------------------------------------

# #-----------------------------------------------------------------------------------------------------------------------------
# # install gui program in /home/$SESUSER/bin :  xterm
# #-----------------------------------------------------------------------------------------------------------------------------
# # we made wrapper script around xterm so end user can easily change its configuration (options)
# # the xterm_custom script opens a xterminal maximized running htop
# COPY resources/bin/xterm_custom /home/$SESUSER/bin/xterm_custom
# # to automatically launch it make a softlink with name guiprogram to it (then code in startwm.sh launches it)
# RUN ln -r -s  /home/$SESUSER/bin/xterm_custom  /home/$SESUSER/bin/guiprogram
# #-----------------------------------------------------------------------------------------------------------------------------



# #-----------------------------------------------------------------------------------------------------------------------------
# # install gui program in /home/$SESUSER/bin : ev3dev2simulator
# #-----------------------------------------------------------------------------------------------------------------------------
# # #install gui program
# # note: no option '--no-install-recommends' because that breaks pip3 install (which build pymunk wheel)
# RUN apt-get update \
#     && DEBIAN_FRONTEND="noninteractive" apt-get install -y  \
#         libasound2-dev \
#         python3-pip \
#     && rm -rf /var/lib/apt/lists/* \
#     && pip3 install ev3dev2simulator==2.0.6
#
# # we made wrapper script around ev3dev2simulator so end user can easily change its configuration (options)
# COPY resources/bin/ev3dev2sim /home/$SESUSER/bin/ev3dev2sim
# # to automatically launch it make a softlink with name guiprogram to it (then code in startwm.sh launches it)
# RUN ln -r -s  /home/$SESUSER/bin/ev3dev2sim /home/$SESUSER/bin/guiprogram
# #-----------------------------------------------------------------------------------------------------------------------------


# if you also install relaunch then the gui program will be automatically relaunched on exit (by startwm.sh)
COPY resources/bin/relaunch-gui-program  /home/$SESUSER/bin/relaunch-gui-program

# fix permissions
RUN chmod a+x /home/$SESUSER/bin/*
RUN chown -R $SESUSER:$SESUSER /home/$SESUSER/bin


#-----------------------------------------------------------------------------------------------------------------------------
# launch xrdp server to which rdp clients can connect on port 3389 
#-----------------------------------------------------------------------------------------------------------------------------

EXPOSE 3389/tcp
ENTRYPOINT ["/usr/bin/entrypoint"]



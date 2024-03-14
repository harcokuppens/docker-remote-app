#!/bin/bash

    
# get screen size
#----------------
sleep 0.1
screenwidth=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f1)
screenheight=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f2)


# xterm clipboard
#-----------------

# needed otherwise sharing clipboard between  the host of the RDP client and the terminal running in the RDP client does not work
#. https://askubuntu.com/questions/237942/how-does-copy-paste-work-with-xterm
#echo 'XTerm*selectToClipboard: true' > ~/.Xresources # this line also works ~~> using classname instead of instance name (=program name)
# see: https://unix.stackexchange.com/questions/216723/xterm-or-xterm-in-configuration-file
echo 'xterm*selectToClipboard: true' > ~/.Xresources
xrdb -merge ~/.Xresources


# setup openbox
# --------------
#  src: http://openbox.org/wiki/Help:Autostart

# create config directory for openbox
mkdir -p $HOME/.config/openbox/ 

# setup autostart config of openbox to launch a gui program
# only if bin/gui-program script exist will program launched when session starts
# only if bin/relaunch-gui-program script exists will the gui program be automatically relaunched on exit (eg. when crashed)
if [[ -e $HOME/bin/guiprogram ]]
then
    if [[ -e $HOME/bin/relaunch-gui-program ]]
    then
        echo 'relaunch-gui-program guiprogram  &' > $HOME/.config/openbox/autostart        
    else
        echo 'guiprogram  &' > $HOME/.config/openbox/autostart        
    fi
fi

# setup environment for openbox
echo 'export PATH=$HOME/bin:$PATH' > $HOME/.config/openbox/environment

# execute openbox window manager
# ------------------------------
exec openbox-session





# Docker-remote-app: containerized GUI app 

Docker image running a GUI application accessible over RDP. Audio in the application is supported over the RDP connection. Copy and pasting between the application and your local system is also supported.

The end user runs the container first, and then runs a remote desktop client to open the window of the GUI application remotely. 

By containerizing a GUI app in this way we can easily run a GUI application on any OS supporting a RDP client and running docker.

The default GUI application is [firefox](http://mozilla.org/firefox/) which opens youtube playing 'David Bowie - Absolute Beginners'. But you can easily adapt it by installing a custom gui app in `bin/guiprogram` by adapting the `Dockerfile`. The `resources/bin/` folder contains several examples. These alternative examples our also in the Dockerfile but commented out.

To run the GUI application the Docker image runs a RDP server using [xrdp](http://xrdp.org) on Ubuntu. Instead of running the GUI application directly in the xrdp session the GUI application is run within the window manager [openbox](http://openbox.org/). This gives the extra flexibility to easily run also other applications. 

This image is based on a fork of the [docker-remote-desktop](https://github.com/scottyhardy/docker-remote-desktop/) image.


## Persistence of GUI application

The GUI application is automatically launched on the first RDP connection and persists on running when the RDP connection is disconnected and reconnected again. In case the GUI application exits for some reason, it will automatically be relaunched in the container.



## Building docker-remote-app image on your own machine

First, clone the GitHub repository:

```bash
git clone https://github.com/harcokuppens/docker-remote-app.git

cd docker-remote-app
```

You can then build the image with the supplied script:

```bash
./build
```

To script contains a `docker` command which can also be run directly from the bash command line. 


## Running docker-remote-app image with scripts

I've created some simple scripts that give the minimum requirements for either running and stopping the container.


To start as a detached daemon:

```bash
./start
```

To stop the detached container:

```bash
./stop
```
To scripts contain docker commands which can also be run directly from the bash command line. 

## Connecting with an RDP client

All Windows desktops and servers come with Remote Desktop pre-installed and macOS users can download the Microsoft Remote Desktop application for free from the App Store.  For Linux users, I'd suggest using the Remmina Remote Desktop client.

For the hostname, use `localhost` if the container is hosted on the same machine you're running your Remote Desktop client on and for remote connections just use the name or IP address of the machine you are connecting to. The RDP client connects by default to  the TCP port 3389. 
NOTE: to connect to a remote machine, it will require TCP port 3389 to be exposed through the firewall. Thus:

```bash
Hostname: localhost
TCP port: 3389 (default)
```

To log in, use the following default user account details:

```bash
Username: ubuntu
Password: ubuntu
```


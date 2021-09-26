# This Dockerfile is used to build an ROS + VNC + Tensorflow image based on Ubuntu 18.04
FROM nvidia/cuda:11.4.2-cudnn8-devel-ubuntu18.04

ENV REFRESHED_AT 2021-09-23

# Install sudo
RUN apt-get update && \
    apt-get install -y sudo \
    xterm \
    curl

# Configure user
ARG user=yapbenzet
ARG passwd=yapbenzet
ARG uid=1000
ARG gid=1000
ENV USER=$user
ENV PASSWD=$passwd
ENV UID=$uid
ENV GID=$gid
RUN groupadd $USER && \
    useradd --create-home --no-log-init -g $USER $USER && \
    usermod -aG sudo $USER && \
    echo "$PASSWD:$PASSWD" | chpasswd && \
    chsh -s /bin/bash $USER && \
    # Replace 1000 with your user/group id
    usermod  --uid $UID $USER && \
    groupmod --gid $GID $USER

### Install VScode
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/ && \
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'

RUN sudo apt-get install -y apt-transport-https && \
    sudo apt-get update && \
    sudo apt-get install -y code

### VNC Installation
LABEL io.k8s.description="VNC Container with ROS with Xfce window manager" \
      io.k8s.display-name="VNC Container with ROS based on Ubuntu" \
      io.openshift.expose-services="6901:http,5901:xvnc,6006:tnesorboard" \
      io.openshift.tags="vnc, ros, gazebo, tensorflow, ubuntu, xfce" \
      io.openshift.non-scalable=true

ENV DEBIAN_FRONTEND=noninteractive


## Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

## Envrionment config
ENV VNCPASSWD=vncpassword
ENV HOME=/home/$USER \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/home/$USER/install \
    NO_VNC_HOME=/home/$USER/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1920x1080 \
    VNC_PW=$VNCPASSWD \
    VNC_VIEW_ONLY=false
WORKDIR $HOME

## Add all install scripts for further steps
ADD ./src/common/install/ $INST_SCRIPTS/
ADD ./src/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

## Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

## Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

## Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh
RUN $INST_SCRIPTS/chrome.sh

## Install xfce UI
RUN $INST_SCRIPTS/xfce_ui.sh
ADD ./src/common/xfce/ $HOME/

## configure startup
RUN $INST_SCRIPTS/libnss_wrapper.sh
ADD ./src/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME


### ROS and Gazebo Installation
# Install other utilities
RUN apt-get update && \
    apt-get install -y vim \
    tmux \
    git

# Install ROS
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -cs` main" > /etc/apt/sources.list.d/ros-latest.list' && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add - && \
        apt-get update && apt-get install -y ros-melodic-desktop && \
    apt-get install -y python-rosinstall 

# Install Gazebo
RUN sh -c 'echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable `lsb_release -cs` main" > /etc/apt/sources.list.d/gazebo-stable.list' && \
    wget http://packages.osrfoundation.org/gazebo.key -O - | sudo apt-key add - && \
    apt-get update && \
    apt-get install -y gazebo9 libgazebo9-dev && \
    apt-get install -y ros-melodic-gazebo-ros-pkgs ros-melodic-gazebo-ros-control


#install missing rosdep
RUN apt-get install python-rosdep

# Setup ROS
#USER $USER
RUN rosdep init
RUN rosdep fix-permissions 
USER $USER
RUN rosdep update

#RUN echo "source /opt/ros/melodic/setup.bash" >> ~/.bashrc
#RUN /bin/bash -c "source ~/.bashrc"

USER root

RUN echo "[Environment setup and getting rosinstall]" \
source /opt/ros/$name_ros_version/setup.sh   \
sudo apt install -y python-rosinstall python-rosinstall-generator python-wstool git 

RUN echo "[Make the catkin workspace and test the catkin_make]"  \
mkdir -p $HOME/$name_catkin_workspace/src  \
cd $HOME/$name_catkin_workspace/src  \
catkin_init_workspace \
cd $HOME/$name_catkin_workspace  \
catkin_make  

RUN sudo apt-get update
RUN sudo apt-get upgrade -y  
RUN  echo "[Set the ROS evironment]"
RUN sh -c "echo \"alias eb='nano ~/.bashrc'\" >> ~/.bashrc" 
RUN sh -c "echo \"alias sb='source ~/.bashrc'\" >> ~/.bashrc" 
RUN sh -c "echo \"alias gs='git status'\" >> ~/.bashrc" \ 
sh -c "echo \"alias gp='git pull'\" >> ~/.bashrc" \ 
sh -c "echo \"alias cw='cd ~/$name_catkin_workspace'\" >> ~/.bashrc" \ 
sh -c "echo \"alias cs='cd ~/$name_catkin_workspace/src'\" >> ~/.bashrc" \  
sh -c "echo \"alias cm='cd ~/$name_catkin_workspace && catkin_make'\" >> ~/.bashrc"\ 
sh -c "echo \"source /opt/ros/$name_ros_version/setup.bash\" >> ~/.bashrc" \ 
sh -c "echo \"source ~/$name_catkin_workspace/devel/setup.bash\" >> ~/.bashrc" \ 
sh -c "echo \"export ROS_MASTER_URI=http://localhost:11311\" >> ~/.bashrc" \ 
sh -c "echo \"export ROS_HOSTNAME=localhost\" >> ~/.bashrc" \ 
source $HOME/.bashrc



RUN sudo apt-get install -y ros-melodic-joy ros-melodic-teleop-twist-joy \
  ros-melodic-teleop-twist-keyboard ros-melodic-laser-proc \
  ros-melodic-rgbd-launch ros-melodic-depthimage-to-laserscan \
  ros-melodic-rosserial-arduino ros-melodic-rosserial-python \
  ros-melodic-rosserial-server ros-melodic-rosserial-client \
  ros-melodic-rosserial-msgs ros-melodic-amcl ros-melodic-map-server \
  ros-melodic-move-base ros-melodic-urdf ros-melodic-xacro \
  ros-melodic-compressed-image-transport ros-melodic-rqt* \
  ros-melodic-gmapping ros-melodic-navigation ros-melodic-interactive-markers

RUN sudo apt-get -y install ros-melodic-dynamixel-sdk && \ 
sudo apt-get install -y ros-melodic-turtlebot3-msgs && \
sudo apt-get install -y ros-melodic-turtlebot3

###Tensorflow Installation
# Install pip
USER root
RUN apt-get install -y wget python-pip python-dev libgtk2.0-0 unzip libblas-dev liblapack-dev libhdf5-dev
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
#RUN python get-pip.py

# prepare default python 2.7 environment
USER root
RUN pip install --ignore-installed --upgrade https://storage.googleapis.com/tensorflow/linux/gpu/tensorflow_gpu-1.11.0-cp27-none-linux_x86_64.whl && \
    pip install keras==2.2.4 matplotlib pandas scipy h5py testresources scikit-learn

# Expose Tensorboard
EXPOSE 6006

# Expose Jupyter 
EXPOSE 8888

### Switch to root user to install additional software
USER $USER

ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]

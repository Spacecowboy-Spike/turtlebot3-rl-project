#!/bin/bash

WS=~/turtlebot3_ws

MODEL_FILE=$1
STAGE_NUM=${2:-4}

if [ -z "$MODEL_FILE" ]; then
    echo "Usage: $0 <model_file> [stage_num]"
    exit 1
fi

echo "==== BUILD + TEST ===="
echo "Model: $MODEL_FILE"
echo "Stage: $STAGE_NUM"

cd $WS || exit 1

colcon build --symlink-install
if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

source $WS/install/local_setup.bash

pkill -f turtlebot3_dqn
pkill -f gzserver
pkill -f gzclient
sleep 2

gnome-terminal --title="Gazebo Launch" -- bash -c "
source $WS/install/local_setup.bash
ros2 launch turtlebot3_gazebo turtlebot3_dqn_${STAGE_NUM}.launch.py
exec bash
"

sleep 8

gnome-terminal --title="DQN Gazebo Node" -- bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_gazebo ${STAGE_NUM}
exec bash
"

sleep 3

gnome-terminal --title="DQN Environment" -- bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_environment
exec bash
"

sleep 3

gnome-terminal --title="DQN Test" -- bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_test --ros-args \
  -p model_file:=${MODEL_FILE} \
  -p verbose:=true
exec bash
"

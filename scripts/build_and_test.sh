#!/bin/bash

WS=~/turtlebot3_ws
EXP_BASE=$WS/experiments

STAGE_NUM=${1:-4}
MODEL_FILE=${2:-model1.h5}
LABEL=${3:-test}
USE_GPU=${4:-true}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXP_NAME="test_${TIMESTAMP}_${LABEL}"
EXP_DIR="$EXP_BASE/$EXP_NAME"

mkdir -p "$EXP_DIR"

echo "==== TEST MODEL ===="
echo "Test run: $EXP_NAME"
echo "Stage: $STAGE_NUM"
echo "Model file: $MODEL_FILE"
echo "Use GPU: $USE_GPU"

cat > "$EXP_DIR/meta.txt" <<EOF
test_name=$EXP_NAME
created_at=$(date)
stage_num=$STAGE_NUM
model_file=$MODEL_FILE
use_gpu=$USE_GPU
mode=test
EOF

cd "$WS" || exit 1

colcon build --symlink-install
if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

source "$WS/install/local_setup.bash"

pkill -f "ros2 launch turtlebot3_gazebo turtlebot3_dqn_stage"
pkill -f "ros2 run turtlebot3_dqn dqn_gazebo"
pkill -f "ros2 run turtlebot3_dqn dqn_environment"
pkill -f "ros2 run turtlebot3_dqn dqn_agent"
pkill -f "ros2 run turtlebot3_dqn dqn_test"
pkill -f "ros2 run turtlebot3_dqn result_graph"
pkill -f "ros2 run turtlebot3_dqn action_graph"
pkill -f gzserver
pkill -f gzclient
sleep 2

konsole --new-tab -p tabtitle="Gazebo Launch" -e bash -c "
source $WS/install/local_setup.bash
ros2 launch turtlebot3_gazebo turtlebot3_dqn_stage${STAGE_NUM}.launch.py
exec bash
" &

sleep 8

konsole --new-tab -p tabtitle="DQN Gazebo Node" -e bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_gazebo ${STAGE_NUM}
exec bash
" &

sleep 3

konsole --new-tab -p tabtitle="DQN Environment" -e bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_environment
exec bash
" &

sleep 3

konsole --new-tab -p tabtitle="DQN Test" -e bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_test --ros-args \
  -p model_file:=${MODEL_FILE} \
  -p use_gpu:=${USE_GPU} \
  -p verbose:=true 2>&1 | tee '$EXP_DIR/test.log'
exec bash
" &

echo "Test launched."
echo "Test folder: $EXP_DIR"
echo "Model file: $MODEL_FILE"

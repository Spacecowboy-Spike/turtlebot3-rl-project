#!/bin/bash

WS=~/turtlebot3_ws
EXP_BASE=$WS/experiments

STAGE_NUM=${1:-4}
EPISODES=${2:-300}
LABEL=${3:-baseline}
EPSILON_DECAY=${4:-6000}
USE_GPU=${5:-true}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXP_NAME="exp_${TIMESTAMP}_${LABEL}"
EXP_DIR="$EXP_BASE/$EXP_NAME"
MODEL_FILE="${EXP_NAME}.h5"

mkdir -p "$EXP_DIR"

echo "==== BUILD + TRAIN ===="
echo "Experiment: $EXP_NAME"
echo "Stage: $STAGE_NUM"
echo "Episodes: $EPISODES"
echo "Epsilon decay: $EPSILON_DECAY"
echo "Use GPU: $USE_GPU"
echo "Model file: $MODEL_FILE"

cat > "$EXP_DIR/meta.txt" <<EOF
experiment_name=$EXP_NAME
created_at=$(date)
stage_num=$STAGE_NUM
episodes=$EPISODES
epsilon_decay=$EPSILON_DECAY
use_gpu=$USE_GPU
model_file=$MODEL_FILE
mode=train
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
pkill -f "tensorboard --logdir=~/turtlebot3_dqn_logs/gradient_tape"
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

konsole --new-tab -p tabtitle="Result Graph" -e bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn result_graph
exec bash
" &

sleep 2

konsole --new-tab -p tabtitle="Action Graph" -e bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn action_graph
exec bash
" &

sleep 2

konsole --new-tab -p tabtitle="TensorBoard" -e bash -c "
tensorboard --logdir=~/turtlebot3_dqn_logs/gradient_tape
exec bash
" &

sleep 2

konsole --new-tab -p tabtitle="DQN Agent Training" -e bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_agent --ros-args \
  -p epsilon_decay:=${EPSILON_DECAY} \
  -p max_training_episodes:=${EPISODES} \
  -p use_gpu:=${USE_GPU} \
  -p model_file:=${MODEL_FILE} \
  -p verbose:=true 2>&1 | tee '$EXP_DIR/train.log'
exec bash
" &

echo "Training launched."
echo "Experiment folder: $EXP_DIR"
echo "Model file: $MODEL_FILE"
echo "TensorBoard: http://localhost:6006"

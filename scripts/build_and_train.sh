#!/bin/bash

WS=~/turtlebot3_ws
EXP_BASE=$WS/experiments

STAGE_NUM=${1:-4}
EPISODES=${2:-300}
LABEL=${3:-baseline}
EPSILON_DECAY=${4:-6000}

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
echo "Model file: $MODEL_FILE"

cat > "$EXP_DIR/meta.txt" <<EOF
experiment_name=$EXP_NAME
created_at=$(date)
stage_num=$STAGE_NUM
episodes=$EPISODES
epsilon_decay=$EPSILON_DECAY
model_file=$MODEL_FILE
EOF

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

gnome-terminal --title="DQN Agent Training" -- bash -c "
source $WS/install/local_setup.bash
ros2 run turtlebot3_dqn dqn_agent --ros-args \
  -p epsilon_decay:=${EPSILON_DECAY} \
  -p max_training_episodes:=${EPISODES} \
  -p model_file:=${MODEL_FILE} \
  -p verbose:=true 2>&1 | tee '$EXP_DIR/train.log'
exec bash
"

echo "Training started."
echo "Experiment folder: $EXP_DIR"
echo "Model name to look for later: $MODEL_FILE"

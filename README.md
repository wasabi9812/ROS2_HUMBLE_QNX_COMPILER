# ROS2_HUMBLE_QNX_COMPILER

This is rep for crosscompile x86 to aarch64 on QNX



Documentation for QNX ROS2 Humble https://ros2-qnx-documentation.readthedocs.io/en/humble/
Enviroment https://github.com/qnx/ros2


qnx neutrino 8.0 target for aarch64le  build file(must adjust env and path)
https://drive.google.com/file/d/1UOBp5FzGtpFmqkFf4e1iVw-AIKHhcUEJ/view?usp=sharing

after you cross-compile, you must modifiy your setup.sh and local_setup.sh to adjust your env path

in setup.sh
COLCON_CURRENT_PREFIX="$_colcon_prefix_chain_sh_COLCON_CURRENT_PREFIX"
_colcon_prefix_chain_sh_source_script "$COLCON_CURRENT_PREFIX/local_setup.sh"
export PYTHON3_EXECUTABLE=/system/bin/python3
export PATH=$PATH:/home/qnxuser/ros2_humble/opt/ros/humble/bin
export PYTHON3_EXECUTABLE=/system/bin/python3
export PATH=$PATH:/data/home/qnxuser/ros2_humble/opt/ros/humble/bin
export PYTHONPATH=$PYTHONPATH:/data/home/qnxuser/ros2_humble/opt/ros/humble/lib/python3.11/site-packages
export AMENT_PREFIX_PATH=/data/home/qnxuser/ros2_humble/opt/ros/humble
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/home/qnxuser/ros2_humble/opt/ros/humble/lib:/system/lib
_colcon_prefix_chain_sh_source_script "$COLCON_CURRENT_PREFIX/update_packages.sh"


in local_setup.sh 
you just need to adjust python path with your device path

and just add update_packages.sh which i made for declaration to use command ros2 run
it will allow you to use new package with ros2 run command

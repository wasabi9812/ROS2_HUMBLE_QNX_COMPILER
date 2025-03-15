#!/bin/bash

set -e
trap 'last_command=; current_command=cat <<EOF > packagebuild.sh
#!/bin/bash

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
start=$(date +%s.%N)

# 1️⃣ QNX 장비의 IP 주소 입력받기
echo "📡 QNX 장비의 : 192.168.0.203):"
read -p "> " QNX_IP

# 2️⃣ 빌드할 패키지 입력 받기
echo "🛠️ 빌드할 패키지 이름을 입력하세요 (모든 패키지를 빌드    'all' 입력):"
read -p "> " PACKAGE_NAME

# 3️⃣ 아 입력 받기
echo "⚙️ 아키텍처를 입력하세요 (aarch64 또는 x86_64):"
read -p "> " CPU

# 4️⃣ **QNX 환경 확인 (빌드 전에 체크)**
if [ -z "$QNX_TARGET" ]; then
    echo "🚨 QNX_TARGET이 설정되지 않았습니다. 종료합니다..."
    exit 1
fi

build_custom_package() {
    # 아키텍처 설정
    if [ "${CPU}" == "aarch64" ]; then
        CPUVARDIR=aarch64le
        CPUVAR=aarch64le
    elif [ "${CPU}" == "x86_64" ]; then
        CPUVARDIR=x86_64
        CPUVAR=x86_64
    else
        echo "🚨 잘못된 아키텍처입니다. 종료합니다..."
        exit 1
    fi

    echo "🛠 CPU set to ${CPUVAR}"
    echo "🛠 CPUVARDIR set to ${CPUVARDIR}"
    export CPUVARDIR CPUVAR
    export ARCH=${CPU}
    export WORKSPACE=${PWD}
    export INSTALL_BASE=${PWD}/install/${CPUVARDIR}
    export PROJECT_ROOT=${PWD}
    export LC_NUMERIC="en_US.UTF-8"
    export PYTHONPYCACHEPREFIX=/tmp
    export PYTHONPATH=/home/ds/ros2_workspace/ros2/install/aarch64le/lib/python3.11/site-packages:$PYTHONPATH

    # 가상환경 활성화
    if [ -d "$HOME/env" ]; then
        . ~/env/bin/activate
        echo "🐍 Python 가상환경 활성화: $(python3 --version)"
    else
        echo "🚨 ~/env에 가상환경이 없습니다. Python 3.11로 만들    주세요."
        exit 1
    fi

    # QNX 환경 설정
    . /home/ds/ros2_workspace/ros2/qnx/build/docker/qnx800/qnxsdp-env.sh
    export OPENSSL_ROOT_DIR=/home/ds/ros2_workspace/ros2/qnx/build/docker/qnx800/target/qnx/aarch64le/usr
    export OPENSSL_CRYPTO_LIBRARY=/home/ds/ros2_workspace/ros2/qnx/build/docker/qnx800/target/qnx/aarch64le/usr/lib/libcrypto.so

    # ROS 2 환경 소싱
    source install/aarch64le/setup.bash

    # 기존 빌드 잔재 제거
    if [ "$PACKAGE_NAME" == "all" ]; then
        rm -rf build/${CPUVARDIR} install/${CPUVARDIR}
    else
        rm -rf build/${CPUVARDIR}/${PACKAGE_NAME} install/${CPUVARDIR}/${PACKAGE_NAME}
    fi

    # 빌드 실행
    echo "🚀 빌드 시작..."
    if [ "$PACKAGE_NAME" == "all" ]; then
        colcon build --merge-install --cmake-force-configure             --build-base=build/${CPUVARDIR}             --install-base=install/${CPUVARDIR}             --cmake-args                 -DCMAKE_TOOLCHAIN_FILE="${PWD}/toolchain.cmake"                 -DCMAKE_MODULE_PATH="${PWD}/qnx/build/modules"                 -DBUILD_TESTING:BOOL="OFF"                 -DCMAKE_BUILD_TYPE="Release"                 -DTHIRDPARTY=FORCE                 -DPYTHON_EXECUTABLE=/home/ds/env/bin/python3                 -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR}"                 -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}"                 --no-warn-unused-cli                 -DCPU=${CPU}
    else
        colcon build --merge-install --cmake-force-configure             --build-base=build/${CPUVARDIR}             --install-base=install/${CPUVARDIR}             --packages-select ${PACKAGE_NAME}             --cmake-args                 -DCMAKE_TOOLCHAIN_FILE="${PWD}/toolchain.cmake"                 -DCMAKE_MODULE_PATH="${PWD}/qnx/build/modules"                 -DBUILD_TESTING:BOOL="OFF"                 -DCMAKE_BUILD_TYPE="Release"                 -DTHIRDPARTY=FORCE                 -DPYTHON_EXECUTABLE=/home/ds/env/bin/python3                 -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR}"                 -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}"                 --no-warn-unused-cli                 -DCPU=${CPU}
    fi

    # 5️⃣  검증
    echo "✅ 빌드 검증 중..."
    LIB_PATH="install/${CPUVARDIR}/lib/${PACKAGE_NAME}"
    SHARE_PATH="install/${CPUVARDIR}/share/${PACKAGE_NAME}"

    if [ ! -d "$LIB_PATH" ]; then
        echo "🚨 오류: 바이너리(${LIB_PATH})가 생성되지 않았습니다!"
        exit 1
    fi

    if [ ! -d "$SHARE_PATH" ]; then
        echo "🚨 오류: 패키지 설정 파일(${SHARE_PATH})이 생성되지 않았습니다!"
        exit 1
    fi

    echo "🎉 빌드 성공: ${PACKAGE_NAME}이(가) install/${CPUVARDIR}에 정상적으로 생성됨!"

    # 6️⃣ QNX로 복사 (scp)
    echo "📡 QNX(${QNX_IP})로 파일 전송 중..."
    scp -r "${LIB_PATH}" "qnxuser@${QNX_IP}:/data/home/qnxuser/ros2_humble/opt/ros/humble/lib/"
    scp -r "${SHARE_PATH}" "qnxuser@${QNX_IP}:/data/home/qnxuser/ros2_humble/opt/ros/humble/share/"

    echo "✅ 파일 전송 완료!"
}

# ✅ 빌드 실행
build_custom_package

# ⏳ 빌드 시간 출력
duration=$(echo "$(date +%s.%N) - $start" | bc)
execution_time=$(printf "%.2f seconds" $duration)
echo "✅ 빌드 및 배포 성공! 소요 시간: $execution_time"
exit 0
EOF
' DEBUG
start=1741944142.549867466

# 1️⃣ QNX 장비의 IP 주소 입력받기
echo "📡 QNX 장비의 : 192.168.0.203):"
read -p "> " QNX_IP

# 2️⃣ 빌드할 패키지 입력 받기
echo "🛠️ 빌드할 패키지 이름을 입력하세요 (모든 패키지를 빌드    'all' 입력):"
read -p "> " PACKAGE_NAME

# 3️⃣ 아 입력 받기
echo "⚙️ 아키텍처를 입력하세요 (aarch64 또는 x86_64):"
read -p "> " CPU

# 4️⃣ **QNX 환경 확인 (빌드 전에 체크)**
if [ -z "/home/ds/qnx800/target/qnx" ]; then
    echo "🚨 QNX_TARGET이 설정되지 않았습니다. 종료합니다..."
    exit 1
fi

build_custom_package() {
    # 아키텍처 설정
    if [ "" == "aarch64" ]; then
        CPUVARDIR=aarch64le
        CPUVAR=aarch64le
    elif [ "" == "x86_64" ]; then
        CPUVARDIR=x86_64
        CPUVAR=x86_64
    else
        echo "🚨 잘못된 아키텍처입니다. 종료합니다..."
        exit 1
    fi

    echo "🛠 CPU set to "
    echo "🛠 CPUVARDIR set to "
    export CPUVARDIR CPUVAR
    export ARCH=
    export WORKSPACE=/home/ds/ros2_workspace/ros2
    export INSTALL_BASE=/home/ds/ros2_workspace/ros2/install/
    export PROJECT_ROOT=/home/ds/ros2_workspace/ros2
    export LC_NUMERIC="en_US.UTF-8"
    export PYTHONPYCACHEPREFIX=/tmp
    export PYTHONPATH=/home/ds/ros2_workspace/ros2/install/aarch64le/lib/python3.11/site-packages:/home/ds/ros2_workspace/ros2/install/aarch64le/lib/python3.11/dist-packages:/home/ds/ros2_workspace/ros2/install/aarch64le/lib/python3.11/site-packages

    # 가상환경 활성화
    if [ -d "/home/ds/env" ]; then
        . ~/env/bin/activate
        echo "🐍 Python 가상환경 활성화: Python 3.11.11"
    else
        echo "🚨 ~/env에 가상환경이 없습니다. Python 3.11로 만들    주세요."
        exit 1
    fi

    # QNX 환경 설정
    . /home/ds/ros2_workspace/ros2/qnx/build/docker/qnx800/qnxsdp-env.sh
    export OPENSSL_ROOT_DIR=/home/ds/ros2_workspace/ros2/qnx/build/docker/qnx800/target/qnx/aarch64le/usr
    export OPENSSL_CRYPTO_LIBRARY=/home/ds/ros2_workspace/ros2/qnx/build/docker/qnx800/target/qnx/aarch64le/usr/lib/libcrypto.so

    # ROS 2 환경 소싱
    source install/aarch64le/setup.bash

    # 기존 빌드 잔재 제거
    if [ "" == "all" ]; then
        rm -rf build/ install/
    else
        rm -rf build// install//
    fi

    # 빌드 실행
    echo "🚀 빌드 시작..."
    if [ "" == "all" ]; then
        colcon build --merge-install --cmake-force-configure             --build-base=build/             --install-base=install/             --cmake-args                 -DCMAKE_TOOLCHAIN_FILE="/home/ds/ros2_workspace/ros2/toolchain.cmake"                 -DCMAKE_MODULE_PATH="/home/ds/ros2_workspace/ros2/qnx/build/modules"                 -DBUILD_TESTING:BOOL="OFF"                 -DCMAKE_BUILD_TYPE="Release"                 -DTHIRDPARTY=FORCE                 -DPYTHON_EXECUTABLE=/home/ds/env/bin/python3                 -DOPENSSL_ROOT_DIR=""                 -DOPENSSL_CRYPTO_LIBRARY=""                 --no-warn-unused-cli                 -DCPU=
    else
        colcon build --merge-install --cmake-force-configure             --build-base=build/             --install-base=install/             --packages-select              --cmake-args                 -DCMAKE_TOOLCHAIN_FILE="/home/ds/ros2_workspace/ros2/toolchain.cmake"                 -DCMAKE_MODULE_PATH="/home/ds/ros2_workspace/ros2/qnx/build/modules"                 -DBUILD_TESTING:BOOL="OFF"                 -DCMAKE_BUILD_TYPE="Release"                 -DTHIRDPARTY=FORCE                 -DPYTHON_EXECUTABLE=/home/ds/env/bin/python3                 -DOPENSSL_ROOT_DIR=""                 -DOPENSSL_CRYPTO_LIBRARY=""                 --no-warn-unused-cli                 -DCPU=
    fi

    # 5️⃣  검증
    echo "✅ 빌드 검증 중..."
    LIB_PATH="install//lib/"
    SHARE_PATH="install//share/"

    if [ ! -d "" ]; then
        echo "🚨 오류: 바이너리()가 생성되지 않았습니다!"
        exit 1
    fi

    if [ ! -d "" ]; then
        echo "🚨 오류: 패키지 설정 파일()이 생성되지 않았습니다!"
        exit 1
    fi

    echo "🎉 빌드 성공: 이(가) install/에 정상적으로 생성됨!"

    # 6️⃣ QNX로 복사 (scp)
    echo "📡 QNX()로 파일 전송 중..."
    scp -r "" "qnxuser@:/data/home/qnxuser/ros2_humble/opt/ros/humble/lib/"
    scp -r "" "qnxuser@:/data/home/qnxuser/ros2_humble/opt/ros/humble/share/"

    echo "✅ 파일 전송 완료!"
}

# ✅ 빌드 실행
build_custom_package

# ⏳ 빌드 시간 출력
duration=
execution_time=0.00 seconds
echo "✅ 빌드 및 배포 성공! 소요 시간: "
exit 0

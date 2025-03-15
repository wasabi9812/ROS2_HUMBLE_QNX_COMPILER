#!/bin/bash

# 패키지 디렉토리
LIB_PATH="/data/home/qnxuser/ros2_humble/opt/ros/humble/lib"
SHARE_PATH="/data/home/qnxuser/ros2_humble/opt/ros/humble/share"
AMENT_INDEX_PATH="${SHARE_PATH}/ament_index/resource_index/packages"

# 패키지 목록 가져오기
echo "1. 현재 설치된 패키지 목록을 확인 중..."
for package in $(ls -1 "$LIB_PATH"); do
    if [ -d "$LIB_PATH/$package" ]; then
        # 패키지 리소스 인덱스 파일 경로
        PACKAGE_FILE="$AMENT_INDEX_PATH/$package"
        
        #  이미 존재하는지 확인 후 추가
        if [ ! -f "$PACKAGE_FILE" ]; then
            echo " 2. 새로운 패키지 추가: $package"
            touch "$PACKAGE_FILE"
        else
            echo " 3. 패키지 존재함: $package"
        fi
    fi
done

echo "🎉 패키지 업데이트 완료!"

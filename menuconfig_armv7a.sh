#!/usr/bin/env bash
set -e

export PATH="/home/hma/mypython/myenv/bin:/home/hma/open-vela/vela-opensource/prebuilts/tools/python/bin:/home/hma/open-vela/vela-opensource/prebuilts/gcc/linux-x86_64/arm-none-eabi/bin:/home/hma/open-vela/vela-opensource/prebuilts/cmake/linux-x86_64/bin:/home/hma/open-vela/vela-opensource/prebuilts/build-tools/linux-x86_64/bin:/home/hma/open-vela/vela-opensource/prebuilts/clang/linux/wasm/bin:$PATH"

export PYTHONPATH="/home/hma/open-vela/vela-opensource/prebuilts/tools/python/dist-packages:/home/hma/open-vela/vela-opensource/prebuilts/tools/python/dist-packages/kconfiglib:/home/hma/open-vela/vela-opensource/prebuilts/tools/python/dist-packages/pyelftools:/home/hma/open-vela/vela-opensource/prebuilts/tools/python/dist-packages/cxxfilt${PYTHONPATH:+:$PYTHONPATH}"

cd /home/hma/apache/nuttx
cmake --build /home/hma/apache/build-qemu-armv7a-full --target menuconfig

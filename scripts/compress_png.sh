#!/bin/bash

# --- 脚本功能：原地压缩指定文件夹内所有PNG图片至90%画质 ---
# --- 作者：Gemini
# --- 日期：2025-06-27

# 设定脚本在遇到错误时立即退出
set -e

# --- 步骤 1: 检查输入参数 ---
# 检查用户是否提供了一个文件夹路径作为参数
if [ "$#" -ne 1 ]; then
    echo "错误：请提供一个文件夹路径作为参数。"
    echo "用法: $0 <目标文件夹>"
    exit 1
fi

TARGET_DIR="$1"

# 检查提供的路径是否确实是一个目录
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误：提供的路径 '$TARGET_DIR' 不是一个有效的文件夹。"
    exit 1
fi

# --- 步骤 2: 检查依赖工具 ---
# 检查 'mogrify' (ImageMagick的一部分) 命令是否存在
if ! command -v mogrify &> /dev/null; then
    echo "错误：依赖工具 ImageMagick (mogrify) 未安装。"
    echo "请使用 'sudo apt install imagemagick' 或类似的命令进行安装。"
    exit 1
fi

# --- 步骤 3: 执行压缩 ---
echo "================================================="
echo "开始处理文件夹: $TARGET_DIR"
echo "目标: 压缩所有PNG文件，画质90%，并原地替换"
echo "================================================="

# 使用 find 命令查找所有 .png 文件 (不区分大小写)
# 然后通过管道将每个文件路径传递给 while 循环进行处理
# -print0 和 read -d $'\0' 是为了安全处理包含空格或特殊字符的文件名
find "$TARGET_DIR" -type f -iname "*.png" -print0 | while IFS= read -r -d $'\0' file; do
    echo "正在压缩: $file"
    # 使用 mogrify 命令进行原地压缩
    # -quality 90 指定了JPEG/MIFF/PNG的压缩质量
    mogrify -quality 90 "$file"
done

echo "================================================="
echo "所有PNG文件处理完毕！"
echo "================================================="

exit 0
#!/bin/bash

# 拷贝 jar 文件到 Flink 的 lib 目录（如果该文件夹没有相同的文件）
if [ -d "/tmp/jar" ]; then
  cp -n /tmp/jar/* /opt/flink/lib/
fi
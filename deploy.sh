#!/bin/bash

. $(dirname $0)/selector.sh

##
## 使用此脚本前，需要先执行 ssh-copy-id root@server_ip，或手动将 ssh key 设置到服务器上
##

# 存放所有源码项目的目录，例如 /d/Projects
base_dir=$(cd $(dirname $0)/..; pwd)

app_list=(
  vehicles-frontend
  efacecloud-frontend
  viid-data-frontend
  epidemic-investigation-frontend
  portrait-portal-frontend
)

start () {
  if [[ $1 != "" && "${app_list[@]}" =~ "$1" ]]; then
    ##
    ## 定制化打包命令
    ##
    app_name="$1" # 应用名
    work_dir="$base_dir/$app_name" # 项目路径
    ssh_server="root@172.25.22.178" # 服务器地址
    target_dir="/opt/frontend/$app_name" # 部署到服务器的路径

    if [ $app_name = "vehicles-frontend" ]; then
      build_script="yarn build:ga"
    elif [ $app_name = "efacecloud-frontend" ]; then
      build_script="yarn build:faceUni"
    elif [ \
      $app_name = "viid-data-frontend" -o \
      $app_name = "epidemic-investigation-frontend" -o \
      $app_name = "portrait-portal-frontend" \
    ]; then
      build_script="yarn build:uni"
    fi

    # 开始部署应用
    deploy_app $app_name $work_dir "$build_script" $ssh_server $target_dir

    # 多行注释
    : '
      1. $(deploy_app) 会将deploy_app的echo标准输出作为命令执行，多个echo输出值会合并
      2. $? 可以获取deploy_app的return值
      3. "deploy_app" 也可以成功调用
      4. $_ 表示上一个命令的最后一个参数
      5. $0 表示当前脚本的文件路径
      6. deploy_app "$@"
          $@ 表示 $1 $2 ...
          "$@" 表示 "$1" "$2" ...
    '
    # 恢复工作目录，正确或错误信息都重定向到该文件
    cd - &> /dev/null

  else
    if [ "$1" = "" ]; then
      echo "参数不能为空"
    else
      echo "参数错误"
    fi
    echo "Usage: sh deploy_app.sh [-l] [arguments]"
    echo "arguments:"
    for item in ${app_list[@]}
    do
      echo "- $item"
    done
  fi
}

deploy_app () {
  local app_name=$1
  local work_dir=$2
  local build_script=$3

  if [ ! -d $work_dir ]; then
    echo "[$app_name] 源码目录：$work_dir 不存在，无法进行部署！"
    exit
  fi

  cd $work_dir # 脚本执行结束后，会恢复之前的工作目录，并不会影响父shell的工作目录

  ##
  ## 编译
  ##
  echo "[$app_name] 开始编译"
  yarn install && $build_script
  # $? 表示上一条命令执行的返回值，值为0表示执行成功，其他值则为失败
  [ $? -ne 0 ] && return 1 # 执行失败或ctrl+c取消，则返回

  ##
  ## 文件传输
  ##
  local ssh_server=$4
  local source_dir="${PWD}/dist"
  local target_dir=$5
  local backup_dir="./dist--$(date '+%Y%m%d%H%M')"

  echo "[$app_name] 开始传输文件"
  # 将dist目录下所有文件同步到服务器，并重启服务
  rsync \
    -rv \
    -e "ssh -l root" \
    --exclude=*.sh \
    --backup \
    --backup-dir=$backup_dir $source_dir $ssh_server:$target_dir && \
      echo "[$app_name] 重启服务" && \
      ssh $ssh_server "sh $target_dir/bin/run.sh restart"

  if [ $? -eq 0 ]; then
    echo "[$app_name] 部署成功"
  else
    echo "[$app_name] 部署失败"
  fi
}

if [ "$1" = "" ]; then
  # 如果没有参数，则带上 -l 参数再次执行当前脚本
  $0 -m
fi

trap 'printf "\nexit"; exit' INT

while [ -n "$1" ]
do
  case "$1" in
    -m)
      # default_values=( "true" "false" "true" )
      multi_selector selected_apps app_list default_values
      i=0
      for item in "${app_list[@]}"
      do
        if [ "${selected_apps[i]}" = "true" ]; then
          start $item
        fi
        ((i++))
      done
      break
      ;;
    -l)
      selector "请选择需要部署的应用：" selected_app "${app_list[@]}"
      start $selected_app
      break
      ;;
    -v)
      echo "请选择需要部署的应用："
      select item in ${app_list[@]}
      do
        if [ "$item" = "" ]; then
          echo "请选择正确选项！"
        elif [[ "${app_list[@]}" =~ "$item" ]]; then
          start $item
          break
        fi
      done
      ;;
    -c)
      echo "发现 $1 选项，值为 $2"
      shift
      ;;
    *)
      start $1
      ;;
  esac
  shift
done

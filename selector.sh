##
## 列表单选
##
function selector () {
  # prompt提示信息 outvar选择结果
  local prompt="$1" outvar="$2"
  shift
  shift
  # options剩下的参数作为选项列表
  # count选项个数
  local options=("$@") cur=0 count=${#options[@]} index=0
  local esc=$(echo -en "\e") # cache ESC as test doesn't allow esc codes
  printf "$prompt\n"

  while true
  do
    # 遍历选项列表
    index=0
    for o in "${options[@]}"
    do
      if [ "$index" == "$cur" ]; then
        echo -e "\e[38;5;46m✔\e[0m \e[7m$o\e[0m" # mark & highlight the current option
      else
        echo "  $o"
      fi
      index=$(( $index + 1 ))
    done

    read -s -n3 key # wait for user to key in arrows or ENTER
    if [[ $key == $esc[A ]]; then # up arrow
      cur=$(( $cur - 1 ))
      [ "$cur" -lt 0 ] && cur=0
    elif [[ $key == $esc[B ]]; then # down arrow
      cur=$(( $cur + 1 ))
      [ "$cur" -ge $count ] && cur=$(( $count - 1 ))
    elif [[ $key == "" ]]; then # nothing, i.e the read delimiter - ENTER
      break
    fi
    echo -en "\e[${count}A" # go up to the beginning to re-render
  done

  # export the selection to the requested output variable
  printf -v $outvar "${options[$cur]}"
}

##
## 列表多选
##
function multi_selector () {
  # little helpers for terminal print control and key input
  ESC=$( printf "\033")
  cursor_blink_on()   { printf "$ESC[?25h"; }
  cursor_blink_off()  { printf "$ESC[?25l"; }
  cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
  print_inactive()    { printf "$2   $1 "; }
  print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }

  local return_value=$1
  local -n options=$2
  local -n defaults=$3

  local selected=()
  for ((i=0; i<${#options[@]}; i++)); do
    if [[ ${defaults[i]} = "true" ]]; then
      selected+=("true")
    else
      selected+=("false")
    fi
    printf "\n"
  done

  # determine current screen position for overwriting the options
  local lastrow=`get_cursor_row`
  local startrow=$(($lastrow - ${#options[@]}))

  # ensure cursor and input echoing back on upon a ctrl+c during read -s
  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off

  key_input() {
    local key
    IFS= read -rsn1 key 2>/dev/null >&2
    if [[ $key = ""      ]]; then echo enter; fi;
    if [[ $key = $'\x20' ]]; then echo space; fi;
    if [[ $key = "k" ]]; then echo up; fi;
    if [[ $key = "j" ]]; then echo down; fi;
    if [[ $key = $'\x1b' ]]; then
      read -rsn2 key
      if [[ $key = [A || $key = k ]]; then echo up;    fi;
      if [[ $key = [B || $key = j ]]; then echo down;  fi;
    fi
  }

  toggle_option() {
    local option=$1
    if [[ ${selected[option]} == true ]]; then
      selected[option]=false
    else
      selected[option]=true
    fi
  }

  print_options() {
    # print options by overwriting the last lines
    local idx=0
    for option in "${options[@]}"; do
      local prefix="[ ]"
      if [[ ${selected[idx]} == true ]]; then
        prefix="[\e[38;5;46m✔\e[0m]"
      fi

      cursor_to $(($startrow + $idx))
      if [ $idx -eq $1 ]; then
        print_active "$option" "$prefix"
      else
        print_inactive "$option" "$prefix"
      fi
      ((idx++))
    done
  }

  local active=0
    while true; do
      print_options $active

      # user key control
      case `key_input` in
        space)  toggle_option $active;;
        enter)  print_options -1; break;;
        up)     ((active--));
                if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
        down)   ((active++));
                if [ $active -ge ${#options[@]} ]; then active=0; fi;;
      esac
  done

  # cursor position back to normal
  cursor_to $lastrow
  printf "\n"
  cursor_blink_on

  eval $return_value='("${selected[@]}")'
}

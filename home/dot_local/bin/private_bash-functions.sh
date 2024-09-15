# BEGIN----------------------- HELPER FUNCTIONS ---------------------------BEGIN

# __count_open_files
# - Helper function which takes in an array of pids and uses lsof to count the
#   the number of open files that counts towards the ulimit. It returns a string
#   with a table of pids with their open file counts as well a summary total.
#   Requires root as it makes use of: lsof
#
function __count_open_files () {

  local -n __pids=$1
  __total=0

  for __pid in "${__pids[@]}"
  do
    __limits="$(grep 'open files' "/proc/${__pid}/limits" 2>/dev/null)"

    # Check that the process has not terminated
    if [ "${__limits}" != "" ]; then
      __cmd="$(ps -o cmd -p "${__pid}" -hc)"
      # Not every type of entry in lsof counts towards ulimit. The following
      # command gets only those fds that count towards ulimit.
      # Source: https://stackoverflow.com/a/58567709
      __fd_count=$(lsof -b -w -P -l -n -d '^cwd,^err,^ltx,^mem,^mmap,^pd,^rtd,^txt' -p "${__pid}" -a | awk '{if (NR>1) print}' | wc -l)
      __hard_ulimit="$(echo "${__limits}" | awk '{print $5}')"
      __soft_ulimit="$(echo "${__limits}" | awk '{print $4}')"
      printf "%s\t%s\t%s\t%s\t%s\n" "${__fd_count}" "${__soft_ulimit}" "${__hard_ulimit}" "${__pid}" "${__cmd}"
      __total=$(( __total + __fd_count ))
    fi
  done > >(sort -n | column -t -s $'\t' -N "Open files,Soft ulimit,Hard ulimit,Process ID,Command")

  # Global limits
  __global_max=$(cut -f 3 "/proc/sys/fs/file-nr" 2>&1)
  __global_cur=$(cut -f 1 "/proc/sys/fs/file-nr" 2>&1)

  read -r -d '' __output <<-EOF
Total : ${__total} open files

System-wide file descriptors
- Current : ${__global_cur}
- Limit   : ${__global_max}
EOF
  printf "\n%s\n" "$__output"
}


# __dir_count
# - Count the number of directories in the specified path. Default is current
#   dir
#
function __dir_count () { find "${1:-.}" -maxdepth 1 -type d | /usr/bin/wc -l; }


# __disk_usage_by_size
# - Returns a sorted by size disk usage report for the specified directory.
#
function __disk_usage_by_size () { find "${1:-.}" -maxdepth 1 -exec /usr/bin/du -sh "{}" \; | /usr/bin/sort -h; }


# __file_count
# - Count the number of files in the specified path. Default is current dir
#
function __file_count () { find "${1:-.}" -maxdepth 1 -type f | /usr/bin/wc -l; }


# __find_dos_files
# - Find text files with CRLF terminators (anywhere in the file) in the
#   specified directory
#
function __find_dos_files () {
  find "${1:-.}" \( -type d -a \( -name '.git' -o -name '.svn' -o -name 'CVS' \)  \) -prune -o \( -type f -print0 \) |
  xargs -r0 file | LANG=C \grep -F "text, with CRLF" | cut -d: -f1
}

# __find_files
# - Finds files under the current directory. Case sensitive
function __find_files () { find . -name "${1:-*}" ; }


# __find_files_endswith
# - Finds files whose name ends with a given string. Case sensitive
#
function __find_files_endswith () { find . -name '*'"${1:-*}" ; }


# __find_files_insensitive
# - Finds files under the current directory. Case insensitive
#
function __find_files_insensitive () { find . -iname "${1:-*}" ; }


# __find_file_startswith
# - Finds files whose name starts with a given string. Case sensitive
#
function __find_files_startswith () { find . -name "$1"'*' ; }


# __find_text_files
# - Find text files in the specified directory
#
function __find_text_files () {
  # Source: http://stackoverflow.com/a/13659891
  find "${1:-.}" -type f -exec "grep" -Iq . {} \; -and -print
}


# __find_text_files0
# - Find text files in the specified directory (output for use with xargs)
#
function __find_text_files0 () {
    # Source: http://stackoverflow.com/a/13659891
    find "${1:-.}" -type f -exec "grep" -Iq . {} \; -and -print0
}


# __fix_dos_files
# - Find text files with CRLF terminators (anywhere in the file) in the
#   specified directory and run dos2unix on them
#
function __fix_dos_files () {
    find "${1:-.}" \( -type d -a \( -name '.git' -o -name '.svn' -o -name 'CVS' \)  \) -prune -o \( -type f -print0 \) |
    xargs -r0 file | LANG=C \grep -F "text, with CRLF" | cut -d: -f1 | xargs --verbose dos2unix
}


# __grep_find
# - Grep for a specified pattern on files found that match the specified name in
#   the current directory. Case sensitive. e.g.
#
#     __grep_find pattern '*.c'
#
function __grep_find () { find . -type f -name "$2" -print0 | xargs -0 "grep" "$1" ; }


# __grep_find_insensitive
# - Grep for a specified pattern on files found that match the specified name in
#   the current directory. Case insensitive. e.g.
#
#     __grep_find pattern '*.c'
#
function __grep_find_insensitive () { find . -type f -iname "$2" -print0 | xargs -0 "grep" -i "$1" ; }


# __history_search
# - Search bash history for specified string. Case insensitive
function __history_search () { history | grep -ie "$1"; }


# __indirect_expand
# - Helper function used by other path manipulation functions
#   Usage: __indirect_expand PATH -> $PATH
#
function __indirect_expand () {
    env |sed -n "s/^$1=//p"
}


# __process_search
# - Search ps output for the specified string. Case insensitive
#
function __process_search () { ps -eFww | { head -1 ; grep -ie "$1" ; } }


# __recursive_dir_count
# - Recursively count the number of directories in the specified path. Default
#   is current dir
#
function __recursive_dir_count () { find "${1:-.}" -type d | /usr/bin/wc -l; }


# __recursive_file_count
# - Recursively count the number of files in the specified path. Default is
#   current dir
#
function __recursive_file_count () { find "${1:-.}" -type f | /usr/bin/wc -l; }


# END------------------------- HELPER FUNCTIONS -----------------------------END

# case-pattern
# - Generates a case-insensitive pattern. e.g.
#
#   echo "FooBar" | case-pattern = [FF][Oo][Oo][BB][Aa][Rr]
#
function case-pattern () { perl -pe 's/([a-zA-Z])/sprintf("[%s%s]",uc($1),$1)/ge' ; }


# command-exists
# - Returns an exit status of 0 if command was found, and 1 if not.
#
function command-exists () { command -v "$1" >/dev/null 2>&1; }


# external_ip
# - Get external IP address via a specified method. Default http.
#   e.g.
#     external_ip dns
#     external_ip http
#     external_ip https
#
function external_ip () {
  local method="${1:-http}"
  case "$method" in
    dns) dig +short myip.opendns.com @resolver1.opendns.com ;;
    #dns) dig +short myip.opendns.com @resolver2.opendns.com ;;
    #dns) dig +short myip.opendns.com @resolver3.opendns.com ;;
    #dns) dig +short myip.opendns.com @resolver4.opendns.com ;;
    #http) curl -s http://api.infoip.io/ip && echo ;;
    #http) curl -s http://canhazip.com  ;;
    http) curl -s http://checkip.amazonaws.com ;;
    #http) curl -s http://eth0.me  ;;
    #http) curl -s http://icanhazip.com  ;;
    #http) curl -s http://ident.me && echo ;;
    #http) curl -s http://ifconfig.co  ;;
    #http) curl -s http://ifconfig.io  ;;
    #http) curl -s http://ifconfig.me/ip && echo ;;
    #http) curl -s http://ip-adresim.app  ;;
    #http) curl -s http://ip1.dynupdate.no-ip.com && echo  ;;
    #http) curl -s http://ipaddress.sh  ;;
    #http) curl -s http://ipecho.net/plain && echo ;;
    #http) curl -s http://ipinfo.io/ip && echo ;;
    #http) curl -s http://l2.io/ip && echo ;;
    #http) curl -s http://myexternalip.com/raw && echo ;;
    #http) curl -s http://tnx.nl/ip && echo ;;
    #http) curl -s http://trackip.net/ip && echo ;;
    #http) curl -s http://wgetip.com && echo ;;
    #http) curl -s http://whatismyip.akamai.com && echo ;;
    #http) curl -s http://wtfismyip.com/text  ;;
    #https) curl -s https://api.infoip.io/ip && echo ;;
    #https) curl -s https://canhazip.com  ;;
    https) curl -s https://checkip.amazonaws.com ;;
    #https) curl -s https://eth0.me  ;;
    #https) curl -s https://icanhazip.com  ;;
    #https) curl -s https://ident.me && echo ;;
    #https) curl -s https://ifconfig.co  ;;
    #https) curl -s https://ifconfig.io  ;;
    #https) curl -s https://ifconfig.me/ip && echo ;;
    #https) curl -s https://ip-adresim.app  ;;
    #https) curl -s https://ipaddress.sh  ;;
    #https) curl -s https://ipecho.net/plain && echo ;;
    #https) curl -s https://ipinfo.io/ip && echo ;;
    #https) curl -s https://l2.io/ip && echo ;;
    #https) curl -s https://myexternalip.com/raw && echo ;;
    #https) curl -s https://tnx.nl/ip && echo ;;
    #https) curl -s https://trackip.net/ip && echo ;;
    #https) curl -s https://wgetip.com && echo ;;
    #https) curl -s https://whatismyip.akamai.com && echo ;;
    #https) curl -s https://wtfismyip.com/text  ;;
    *) echo Bad argument >&2 &&  echo "Usage: external_ip [ dns | http | https ]" ;;
  esac
}


# Shows the full path of the specified command
# Usage: find_command <command>
function find_command {
  if which "$1" >/dev/null 2>&1 ; then
    ls -l "$(which "$1")"
  else
    echo "File not found"
  fi
}


# internal_ips
# - Get internal IP addresses. Source: http://unix.stackexchange.com/a/182471
#
function internal_ips () {
  for IF in $(ip link show | awk -F: '$1>0 {print $2}')
  do
    echo -n "$IF : "
    ip addr show dev "$IF" | awk '$1=="inet"{ip=$2; gsub("/.*","",ip); print ip}' | xargs
  done
}

# lower_case
# - Convert any arguments passed to it, to lowercase. Works correctly with
#   Unicode
#
# shellcheck disable=SC2001
function lower_case () { echo "$*" | sed 's/.*/\L&/'; }


# open_files
# - Returns details of the open files for all processes for all users.
#   Requires root due to the use of: lsof
function open_files () {
  readarray -t __all_pids < <(ps --no-headers -e -o pid:1)
  __result=$(__count_open_files __all_pids)
  printf "%s\n" "$__result"
}


# open_files_per_process
# - Returns details of the open files for specified processes.
#   Requires root due to the use of: lsof
function open_files_per_process () {
  __specific_pids=( "$@" )
  __result=$(__count_open_files __specific_pids)
  printf "%s\n" "$__result"
}


# open_files_per_user
# - Returns details of the open files for all processes for a specified user.
#   Requires root due to the use of: lsof and su
function open_files_per_user () {

  __user=${1:-$LOGNAME}
  readarray -t __user_pids < <(ps --no-headers -U "${__user}" -o pid:1)
  result=$(__count_open_files __user_pids)

  # User limits
  __user_hard_ulimit=$(su - "${__user}" -s '/usr/bin/bash' -c 'ulimit -Hn')
  __user_soft_ulimit=$(su - "${__user}" -s '/usr/bin/bash' -c 'ulimit -Sn')

  read -r -d '' __output <<-EOF
${result}

${__user} user's open files limits
- Soft ulimit : ${__user_soft_ulimit}
- Hard ulimit : ${__user_hard_ulimit}
EOF
  printf "%s\n" "$__output"
}


# path_append
# - Generic way to append a path to specified environment variable
#   Usage: path_append /path/to/bin [PATH]
#   Eg, to append ~/bin to $PATH
#     path_append ~/bin PATH
#
function path_append () {
  path_remove "${1}" "${2}"
  #[ -d "${1}" ] || return
  local var=${2:-PATH}
  value=$(__indirect_expand "$var")
  export "$var"="${value:+${value}:}${1}"
}


# path_prepend
# - Generic way to prepend a path to specified environment variable
#   Usage: path_prepend /path/to/bin [PATH]
#   Eg, to prepend ~/bin to $PATH
#     path_prepend ~/bin PATH
#
function path_prepend () {
  # if the path is already in the variable,
  # remove it so we can move it to the front
  path_remove "$1" "$2"
  #[ -d "${1}" ] || return
  local var="${2:-PATH}"
  value=$(__indirect_expand "$var")
  export "${var}"="${1}${value:+:${value}}"
}


# path_remove
# - Generic way to remove a path in specified environment variable
# - Usage: path_remove /path/to/bin [PATH]
#   eg, to remove ~/bin from $PATH
#     path_remove ~/bin PATH
#
function path_remove () {
  local IFS=':'
  local newpath
  local dir
  local var=${2:-PATH}
  # Bash has ${!var}, but this is not portable.
  for dir in $(__indirect_expand "$var"); do
    IFS=''
    if [ "$dir" != "$1" ]; then
      newpath=$newpath:$dir
    fi
  done
  export "$var"="${newpath#:}"
}


# pathmunge
# - This function  will add a directory to the beginning of your PATH if it is
#   missing from your PATH. This means that you can safely .source ~/.bashrc
#   without ending up with duplicate folders in your path.
#
#   e.g. to add the folder to begining of the PATH
#
#     pathmunge ~/bin
#     export PATH
#
#     OR (to add the folder to the end of the PATH)
#
#     pathmunge ~/bin after
#     export PATH
#
function pathmunge () {
  if ! echo "$PATH" | grep -q -E "(^|:)$1($|:)" ; then
    if [ "$2" = "after" ] ; then
      PATH=$PATH:$1
    else
      PATH=$1:$PATH
    fi
  fi
}

# pause
# - Pause and wait for user interaction
function pause () { read -r -s -p "Press any key to continue..." -n1 && echo >&2 ; }


# string_find
# - Searches a path for a string in a commonly named file
#   Usage string_find <path> <file> <search_string>
#
function string_find {
  if [[ -z "$3" ]] ; then
    echo "string_find - searches a path for a string in a commonly named file i.e. 'Vagrantfile' or '.gitignore'"
    echo "usage $0 <path> <file> <search_string>" >&2
    return 1
  fi
  typeset lc_path lc_file lc_string
  lc_path="$1"
  lc_file="$2"
  lc_string="$3"
  find "${lc_path}" \
      -name "${lc_file}" | \
    ( # shellcheck disable=SC2034
      while read -r file ; do
        eval "grep -lE '${lc_string}' \"\${file}\" && grep -nE '${lc_string}' \"\${file}\""
      done
    )
}


# trim
# - Remove leading & trailing white space from a Bash variable
#   Source: http://stackoverflow.com/a/3352015
#   e.g.: trim "   blah   "
#   Outputs: "blah"
#
trim () {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
  var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
  echo -n "$var"
}


# up
# - Chdir to parent folder when no argument given. With a numeric argument,
#   chdir's n times. e.g.
#
#   up 4 = cd ../../../..
#
function up () { local p='' i=${1:-1}; while (( i-- )); do p+=../; done; cd "$p$2" && pwd; }


# upper_case
# - Convert any arguments passed to it, to uppercase. Works correctly with
#   Unicode
#
function upper_case () { echo "$*" | /bin/sed 's/.*/\U&/'; }


# command_exists
# - Returns 0 if command exists else returns 1
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# tput-16-colors
# - Output all the colors to the screen using tput
function tput-16-colors () {
    T='Test'   # The test text
    for FGs in 0 1 2 3 4 5 6 7;
      do FG=${FGs// /}
      echo -en "     $FGs $(tput setaf $FG) $T "
      for BG in 0 1 2 3 4 5 6 7;
        do echo -en "$EINS $(tput setaf $FG)$(tput setab $BG) $T $(tput sgr0)";
      done
      echo;
      echo -en "bold $FGs $(tput bold; tput setaf $FG) $T "
      for BG in 0 1 2 3 4 5 6 7;
        do echo -en "$EINS $(tput bold; tput setaf $FG)$(tput setab $BG) $T $(tput sgr0)";
      done
      echo;
    done
}

# colors
# - Echoes a bunch of color codes to the  terminal to demonstrate what's
#   available. Each line is the color code of one forground color, out of
#   17 (default + 16 escapes), followed by a test use of that color on all
#   nine background colors (default + 8 escapes).
#   Source: http://tldp.org/HOWTO/Bash-Prompt-HOWTO/x329.html
function colors () {
  T='gYw'   # The test text

  echo -e "\n                 40m     41m     42m     43m\
       44m     45m     46m     47m";

  for FGs in '    m' '   1m' '  30m' '1;30m' '  31m' '1;31m' '  32m' \
             '1;32m' '  33m' '1;33m' '  34m' '1;34m' '  35m' '1;35m' \
             '  36m' '1;36m' '  37m' '1;37m';
    do FG=${FGs// /}
    echo -en " $FGs \033[$FG  $T  "
    for BG in 40m 41m 42m 43m 44m 45m 46m 47m;
      do echo -en "$EINS \033[$FG\033[$BG  $T  \033[0m";
    done
    echo;
  done
}

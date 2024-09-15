# This override autocd's .. with the "up" function as the latter is a lot more
# functional.
alias ..='up'

# Make using the bash directory stack easier
# shellcheck disable=SC2290
alias -- +="pushd ."
alias -- -="popd"

# Show only non hidden filedirectories in ls output
alias ls='/usr/bin/ls --color=auto -Fh --time-style=long-iso'
alias ll='/usr/bin/ls --color=auto -Fhl --time-style=long-iso'

# Show only hidden files/directories in ls output
alias ls.='/usr/bin/ls --color=auto -Fha --ignore "[^\.]*" --time-style=long-iso'
alias ll.='/usr/bin/ls --color=auto -Fhla --ignore "[^\.]*" --time-style=long-iso'

# Show all files/directories in ls output
alias lsa='/usr/bin/ls --color=auto -Fha --time-style=long-iso'
alias lla='/usr/bin/ls --color=auto -Fhla --time-style=long-iso'

# Sort by extension (alphabetical)
alias lx='/usr/bin/ls --color=auto -FhX --time-style=long-iso'
alias lxa='/usr/bin/ls --color=auto -FhXa --time-style=long-iso'
alias llx='/usr/bin/ls --color=auto -FhlX --time-style=long-iso'
alias llxa='/usr/bin/ls --color=auto -FhlXa --time-style=long-iso'

# Sort by size (smallest to largest)
alias lz='/usr/bin/ls --color=auto -FhSr --time-style=long-iso'
alias lza='/usr/bin/ls --color=auto -FhSra --time-style=long-iso'
alias llz='/usr/bin/ls --color=auto -FhlSr --time-style=long-iso'
alias llza='/usr/bin/ls --color=auto -FhlSra --time-style=long-iso'
# ...largest to smallest
alias llzr='/usr/bin/ls --color=auto -FhlS --time-style=long-iso'
alias llzar='/usr/bin/ls --color=auto -FhlSa --time-style=long-iso'

# Sort by time (oldest to newest)
alias lt='/usr/bin/ls --color=auto -Fhtr --time-style=long-iso'
alias lta='/usr/bin/ls --color=auto -Fhtra --time-style=long-iso'
alias llt='/usr/bin/ls --color=auto -Fhltr --time-style=long-iso'
alias llta='/usr/bin/ls --color=auto -Fhltra --time-style=long-iso'
# ...newest to oldest
alias lltr='/usr/bin/ls --color=auto -Fhlt --time-style=long-iso'
alias lltar='/usr/bin/ls --color=auto -Fhlta --time-style=long-iso'

# Show only directories in ls output
alias lsd="/usr/bin/ls --color=auto -Fhla --time-style=long-iso | /usr/bin/grep '^d'"

# Show only files in ls output
alias lsf="/usr/bin/ls --color=auto -Fhla --time-style=long-iso | /usr/bin/grep -v '^d'"

# Search ls output for string
alias lss='/usr/bin/ls --color=auto -Fhla --time-style=long-iso | /usr/bin/grep -ie'

# Safer variants of copy/move/delete/link operations
alias cp='/usr/bin/cp -iv'
alias ln='/usr/bin/ln -iv'
alias mv='/usr/bin/mv -iv'
alias rm='/usr/bin/rm -Iv --preserve-root'

# Safer variants of chmod/chown/chgrp operations
alias chgrp='/usr/bin/chgrp -cv --preserve-root'
alias chmod='/usr/bin/chmod -cv --preserve-root'
alias chown='/usr/bin/chown -cv --preserve-root'

# Make mkdir/rmdir verbose
alias mkdir='/usr/bin/mkdir -v'
alias rmdir='/usr/bin/rmdir -v'

# Make grep more friendly
alias egrep='/usr/bin/grep -E -n --color=auto'
alias fgrep='/usr/bin/fgrep -n --color=auto'
alias grep='/usr/bin/grep -n --color=auto'

# Make df/du more friendly
alias df='/usr/bin/df --sync --total -Tah'
alias du='/usr/bin/du -ch'
alias dus='/usr/bin/du -sch'
alias dusz="__disk_usage_by_size"

# Make free/top more friendly
alias free='/usr/bin/free -lht'
alias top='/usr/bin/top -d1'

# Make netstat more friendly
alias netstat='/usr/bin/netstat -tuanp'

# Display the value of $PATH environment variable in an easy to view format
alias path='echo -e ${PATH//:/\\n}'

# To check if a process is running
alias pss="__process_search"

## Show top process(es) using memory
alias psmem='/usr/bin/ps auxf | /usr/bin/sort -nr -k 4'
alias psmem10='/usr/bin/ps auxf | /usr/bin/sort -nr -k 4 | /usr/bin/head -10'

## Show top process(es) using cpu
alias pscpu='/usr/bin/ps auxf | /usr/bin/sort -nr -k 3'
alias pscpu10='/usr/bin/ps auxf | /usr/bin/sort -nr -k 3 | /usr/bin/head -10'

# Find files under current directory
alias ff='__find_files'
alias ffi='__find_files_insensitive'
alias ffs='__find_files_startswith'
alias ffe='__find_files_endswith'
alias fds='__find_dos_files'
alias ftf='__find_text_files'
alias ftf0='__find_text_files0'

# Find files and grep through them
alias gf='__grep_find'
alias gfi='__grep_find_insensitive'

# Display the octal file/dir permissions
alias perms='/usr/bin/stat -c "%a %n"'

# Use vim's less.vim mode to view files with syntax highlighting
alias o='/usr/share/vim/vim91/macros/less.sh'

# I'm lazy!
alias v='/usr/bin/vim'
alias c='/usr/bin/clear'

# Show (only) mounted drives
alias mounted="/usr/bin/mount | /usr/bin/column -t | /usr/bin/grep -E ^/dev/ | /usr/bin/sort"

# Search bash command history
alias hiss="__history_search"

# Show cpu information
alias cpuinfo="/usr/bin/lscpu; /usr/bin/lscpu --all --extended --output-all"

# File / dir counts
alias filecount='__file_count'
alias filecountr='__recursive_file_count'
alias dircount='__dir_count'
alias dircountr='__recursive_dir_count'

# Restore terminal settings when they get completely screwed up
alias fix_tty='/usr/bin/stty sane'

# This will clear the screen AND the PuTTY scroll back buffer. Neat!
alias csb="/usr/bin/clear && printf '\033[3J';"

# Show a config file with all blank lines / comments stripped. Useful for easy
# diffing.
alias cleancat="/usr/bin/grep -vE '^[[:blank:]]*(#|$)'"

# Show tree with colour output
alias tree='/usr/bin/tree -C'

# When exiting mc, changes the current working directory to mc’s last selected
# one
alias mc='. /usr/lib/mc/mc-wrapper.sh'

# # Apt
# alias apt_check_for_updates="/usr/bin/apt-get -qq update && /usr/bin/apt-get -s -o Debug::NoLocking=true dist-upgrade | /usr/bin/grep -v '^\(Inst\|Conf\)'"
# alias aptsearch='/usr/bin/apt-cache search'
# alias aptshow='/usr/bin/apt-cache show'
# alias aptinstall='/usr/bin/apt-get install -V'
# alias aptupdate='/usr/bin/apt-get update'
# alias aptupgrade='/usr/bin/apt-get update && /usr/bin/apt-get upgrade -V && /usr/bin/apt-get autoremove'
# alias aptdistupgrade='/usr/bin/apt-get update && /usr/bin/apt-get dist-upgrade -V && /usr/bin/apt-get autoremove'
# alias aptremove='/usr/bin/apt-get remove'
# alias aptpurge='/usr/bin/apt-get remove --purge'
# alias aptfilesearch='/usr/bin/apt-file search'
# alias aptfileshow='/usr/bin/apt-file show'

# # Dpkg
# # shellcheck disable=SC2154
# alias dpkgquerypkg="/usr/bin/dpkg-query -Wf '\${Package}\n' | /usr/bin/sort | /usr/bin/grep -ie"
# alias dpkgqueryallpkgs="/usr/bin/dpkg-query -Wf '\${Package}\n' | /usr/bin/sort"
# alias dpkgpkgs='/usr/bin/dpkg --no-pager -l'
# alias dpkgfiles='/usr/bin/dpkg --no-pager -L'
# alias dpkgfilesearch='/usr/bin/dpkg --no-pager -S'

# Xclip
alias clipcopy="/usr/bin/xclip -selection clipboard"
alias clippaste="/usr/bin/xclip -selection clipboard -o"

# Curl
# - see only response headers from a get request
alias curlresphdrs='/usr/bin/curl -D - -so /dev/null'
# - follow redirects, download as original name, continue, retry 5 times
alias curldownload='/usr/bin/curl -L -C - -O --retry 5'


#
# Git
#
if command_exists git; then
  alias g='git'
  # add
  alias ga='git add'
  alias gall='git add -A'
  alias gap='git add -p'
  alias gav='git add -v'
  # branch
  alias gb='git branch'
  alias gba='git branch --all'
  alias gbd='git branch -d'
  alias gbD='git branch -D'
  alias gbl='git branch --list'
  alias gbla='git branch --list --all'
  alias gblr='git branch --list --remotes'
  alias gbm='git branch --move'
  alias gbr='git branch --remotes'
  alias gbt='git branch --track'
  alias gdel='git branch -D'
  # for-each-ref (FROM https://stackoverflow.com/a/58623139/10362396)
  alias gbc='git for-each-ref --format="%(authorname) %09 %(if)%(HEAD)%(then)*%(else)%(refname:short)%(end) %09 %(creatordate)" refs/remotes/ --sort=authorname DESC'
  # commit
  alias gc='git commit -v'
  alias gca='git commit -v -a'
  alias gcaa='git commit -a --amend -C HEAD' # Add uncommitted and unstaged changes to the last commit
  alias gcam='git commit -v -am'
  alias gcamd='git commit --amend'
  alias gcm='git commit -v -m'
  alias gci='git commit --interactive'
  alias gcsam='git commit -S -am'
  # checkout
  alias gcb='git checkout -b'
  alias gco='git checkout'
  alias gcob='git checkout -b'
  alias gcobu='git checkout -b ${USER}/'
  alias gcom='git checkout $(get_default_branch)'
  alias gcpd='git checkout $(get_default_branch); git pull; git branch -D'
  alias gct='git checkout --track'
  # clone
  alias gcl='git clone'
  # clean
  alias gclean='git clean -fd'
  # cherry-pick
  alias gcp='git cherry-pick'
  alias gcpx='git cherry-pick -x'
  # diff
  alias gd='git diff'
  alias gds='git diff --staged'
  alias gdt='git difftool'
  # archive
  alias gexport='git archive --format zip --output'
  # fetch
  alias gf='git fetch --all --prune'
  alias gft='git fetch --all --prune --tags'
  alias gftv='git fetch --all --prune --tags --verbose'
  alias gfv='git fetch --all --prune --verbose'
  alias gmu='git fetch origin -v; git fetch upstream -v; git merge upstream/$(get_default_branch)'
  alias gup='git fetch && git rebase'
  # log
  alias gg='git log --graph --pretty=format:'\''%C(bold)%h%Creset%C(magenta)%d%Creset %s %C(yellow)<%an> %C(cyan)(%cr)%Creset'\'' --abbrev-commit --date=relative'
  alias ggf='git log --graph --date=short --pretty=format:'\''%C(auto)%h %Cgreen%an%Creset %Cblue%cd%Creset %C(auto)%d %s'\'''
  alias ggs='gg --stat'
  alias ggup='git log --branches --not --remotes --no-walk --decorate --oneline' # FROM https://stackoverflow.com/questions/39220870/in-git-list-names-of-branches-with-unpushed-commits
  alias gll='git log --graph --pretty=oneline --abbrev-commit'
  alias gnew='git log HEAD@{1}..HEAD@{0}' # Show commits since last pull, see http://blogs.atlassian.com/2014/10/advanced-git-aliases/
  alias gwc='git whatchanged'
  # ls-files
  alias gu='git ls-files . --exclude-standard --others' # Show untracked files
  alias glsut='gu'
  alias glsum='git diff --name-only --diff-filter=U' # Show unmerged (conflicted) files
  # gui
  alias ggui='git gui'
  # home
  alias ghm='cd "$(git rev-parse --show-toplevel)"' # Git home
  # merge
  alias gm='git merge'
  # mv
  alias gmv='git mv'
  # patch
  alias gpatch='git format-patch -1'
  # push
  alias gp='git push'
  alias gpd='git push --delete'
  alias gpf='git push --force'
  alias gpo='git push origin HEAD'
  alias gpom='git push origin $(get_default_branch)'
  alias gpu='git push --set-upstream'
  alias gpunch='git push --force-with-lease'
  alias gpuo='git push --set-upstream origin'
  alias gpuoc='git push --set-upstream origin $(git symbolic-ref --short HEAD)'
  # pull
  alias gl='git pull'
  alias glum='git pull upstream $(get_default_branch)'
  alias gpl='git pull'
  alias gpp='git pull && git push'
  alias gpr='git pull --rebase'
  # remote
  alias gr='git remote'
  alias gra='git remote add'
  alias grv='git remote -v'
  # rm
  alias grm='git rm'
  # rebase
  alias grb='git rebase'
  alias grbc='git rebase --continue'
  alias grm='git rebase $(get_default_branch)'
  alias grmi='git rebase $(get_default_branch) -i'
  alias grma='GIT_SEQUENCE_EDITOR=: git rebase  $(get_default_branch) -i --autosquash'
  alias gprom='git fetch origin $(get_default_branch) && git rebase origin/$(get_default_branch) && git update-ref refs/heads/$(get_default_branch) origin/$(get_default_branch)' # Rebase with latest remote
  # reset
  alias gus='git reset HEAD'
  alias gpristine='git reset --hard && git clean -dfx'
  # status
  alias gs='git status'
  alias gss='git status -s'
  # shortlog
  alias gcount='git shortlog -sn'
  alias gsl='git shortlog -sn'
  # show
  alias gsh='git show'
  # stash
  alias gst='git stash'
  alias gstb='git stash branch'
  alias gstd='git stash drop'
  alias gstl='git stash list'
  alias gstp='git stash pop'  # kept due to long-standing usage
  alias gstpo='git stash pop' # recommended for it's symmetry with gstpu (push)
  ## 'stash push' introduced in git v2.13.2
  alias gstpu='git stash push'
  alias gstpum='git stash push -m'
  ## 'stash save' deprecated since git v2.16.0, alias is now push
  alias gsts='git stash push'
  alias gstsm='git stash push -m'
  # submodules
  alias gsu='git submodule update --init --recursive'
  # switch
  # these aliases requires git v2.23+
  alias gsw='git switch'
  alias gswc='git switch --create'
  alias gswm='git switch $(get_default_branch)'
  alias gswt='git switch --track'
  # tag
  alias gt='git tag'
  alias gta='git tag -a'
  alias gtd='git tag -d'
  alias gtl='git tag -l'
  alias gtls='git tag -l | sort -V'
  function gdv() {
    git diff --ignore-all-space "$@" | vim -R -
  }
  function get_default_branch() {
    if git branch | grep -q '^. main\s*$'; then
      echo main
    else
      echo master
    fi
  }
fi


#
# Systemctl
#
alias sc='/usr/bin/systemctl'
alias scu='/usr/bin/systemctl --user'
alias scdr='/usr/bin/systemctl daemon-reload'
alias scdru='/usr/bin/systemctl --user daemon-reload'
alias scr='/usr/bin/systemctl restart'
alias scru='/usr/bin/systemctl --user restart'
alias sce='/usr/bin/systemctl stop'
alias sceu='/usr/bin/systemctl --user stop'
alias scs='/usr/bin/systemctl start'
alias scsu='/usr/bin/systemctl --user start'


#
# Tmux
#
if command_exists tmux; then
  alias txl='/usr/bin/tmux ls'
  alias txn='/usr/bin/tmux new -s'
  alias txa='/usr/bin/tmux a -t'
fi

#
# Kubectl
#
if command_exists kubectl; then
  alias kc='/usr/bin/kubectl'
  alias kcgp='/usr/bin/kubectl get pods'
  alias kcgd='/usr/bin/kubectl get deployments'
  alias kcgn='/usr/bin/kubectl get nodes'
  alias kcdp='/usr/bin/kubectl describe pod'
  alias kcdd='/usr/bin/kubectl describe deployment'
  alias kcdn='/usr/bin/kubectl describe node'
  alias kcgpan='/usr/bin/kubectl get pods --all-namespaces'
  alias kcgdan='/usr/bin/kubectl get deployments --all-namespaces'
  # launches a disposable netshoot pod in the k8s cluster
  alias kcnetshoot='/usr/bin/kubectl run netshoot-$(date +%s) --rm -i --tty --image nicolaka/netshoot -- /bin/bash'
fi

if command_exists eza; then
  # Show only non hidden files/directories
  alias e='/usr/bin/eza --classify --color=auto --color-scale --group-directories-first --icons --time-style=long-iso'
  alias el='/usr/bin/eza --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --time-style=long-iso'

  # Show only hidden files/directories
  alias e.="/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --ignore-glob='[!\.]*' --time-style=long-iso"
  alias el.="/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --ignore-glob='[!\.]*' --links --long --time-style=long-iso"

  # Show all files/directories
  alias ea='/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --time-style=long-iso'
  alias ela='/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --time-style=long-iso'

  # Sort by extension (alphabetical)
  alias ex='/usr/bin/eza --classify --color=auto --color-scale --group-directories-first --icons --sort=extension --time-style=long-iso'
  alias exa='/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --sort=extension --time-style=long-iso'
  alias elx='/usr/bin/eza --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --sort=extension --time-style=long-iso'
  alias elxa='/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --sort=extension --time-style=long-iso'

  # Sort by size (smallest to largest)
  alias ez='/usr/bin/eza --classify --color=auto --color-scale --group-directories-first --icons --sort=size --time-style=long-iso'
  alias eza='/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --sort=size --time-style=long-iso'
  alias elz='/usr/bin/eza --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --sort=size --time-style=long-iso'
  alias elza='/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --sort=size --time-style=long-iso'
  # ...largest to smallest
  alias ezr='/usr/bin/eza --classify --color=auto --color-scale --group-directories-first --icons --reverse --sort=size --time-style=long-iso'
  alias ezar='/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --reverse --sort=size --time-style=long-iso'
  alias elzr='/usr/bin/eza --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --reverse --sort=size --time-style=long-iso'
  alias elzar='/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --reverse --sort=size --time-style=long-iso'

  # Sort by time (oldest to newest)
  alias et='/usr/bin/eza --classify --color=auto --color-scale --group-directories-first --icons --sort=modified --time-style=long-iso'
  alias eta='/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --sort=modified --time-style=long-iso'
  alias elt='/usr/bin/eza --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --sort=modified --time-style=long-iso'
  alias elta='/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --sort=modified --time-style=long-iso'
  # ...newest to oldest
  alias etr='/usr/bin/eza --classify --color=auto --color-scale --group-directories-first --icons --reverse --sort=modified --time-style=long-iso'
  alias etar='/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --reverse --sort=modified --time-style=long-iso'
  alias eltr='/usr/bin/eza --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --reverse --sort=modified --time-style=long-iso'
  alias eltar='/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --reverse --sort=modified --time-style=long-iso'

  # Show only directories
  alias ed='/usr/bin/eza --classify --color=auto --color-scale --group-directories-first --icons --only-dirs --time-style=long-iso'
  alias eld='/usr/bin/eza --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --only-dirs --time-style=long-iso'
  alias eda='/usr/bin/eza --all --all --classify --color=auto --color-scale --group-directories-first --icons --only-dirs --time-style=long-iso'
  alias edla='/usr/bin/eza --all --all --bytes --classify --color=auto --color-scale --extended --git --group --group-directories-first --header --icons --links --long --only-dirs --time-style=long-iso'
fi

#!/usr/bin/env bash
set -o pipefail

function print_help() {
  echo "Runs a job on one or more machines using the appropriate remoting mechanism."
  echo "   "
  echo "'machine1..n' is a list of machines on which the job will be run."
  echo "'job' is the job to run on the machines."
  echo "Arguments after '--' will be passed on to the job script."
  echo "  "
  echo "Options:"
  echo "  "
  echo "--parallel triggers parallel execution of the job on several machines."
  echo "  By default, the job is executed on each machine sequentially."
  echo "--continuous runs the job in a loop (implies --parallel), waiting"
  echo "  after each run for the next invocation, which will be executed without"
  echo "  the overhead of setting the job up again."
  echo "--abort makes a current continuous run break out of the loop and exit."
  echo
}

machines=()
job="-1"
script_args=()
parallel="false"
verbose="false"
continuous="false"
abort="false"

function list_jobs() {
  ls jobs | awk {'printf (" - %s\n", $1)'}  
}

for arg in "${@}"; do
  if [[ "$arg" = "--" ]]
  then
    job="--"
  elif [[ "$job" == "-1" ]]
  then
    if [[ "$arg" == "--jobs" ]]
    then
      list_jobs
      exit 0
    elif [[ "$arg" == "--help" ]]
    then
      print_help
      exit 0
    elif [[ "$arg" == "--parallel" ]]
    then
      parallel="true"
    elif [[ "$arg" == "--verbose" ]]
    then
      verbose="true"
    elif [[ "$arg" == "--continuous" ]]
    then
      continuous="true"
    elif [[ "$arg" == "--abort" ]]
    then
      abort="true"
    else
      machines+=("$arg")
    fi
  else
    script_args+=("$arg")
  fi
done

job="${machines[@]: -1}"

if [ ! -d "jobs/$job" ]
then
  echo "There's no job '$job'. Available jobs are:"
  list_jobs
  exit -1
fi

unset "machines[${#machines[@]}-1]"

if [[ ${#machines} == 0 ]]
then
  print_help
  exit 0
fi

log_stamp=$(date "+%Y%m%d-%H%M%S")

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\e[0;33m"
NOCOL="\033[0m"

function log_progress() {
  if [[ "$verbose" == "true" ]]
  then
    >&2 printf "${YELLOW}%s${NOCOL}\n" "$1"
  fi
}

# continuous runs with more than one machine need to run parallel
if [[ $continuous == "true" && $(( ${#machines[@]} - 1 )) -gt 0 ]]
then
  log_progress "More than one machine running continuously - running parallel"
  parallel="true"
fi

function test_continue() {
  local continuous_file=$1
  local continuous=$2
  local machine=$3
  local run="true"

  if [ $continuous == "true" ] || [ $continuous == "wakeup" ]
  then
    if [ $continuous == "true" ]
    then
      log_progress "==> $machine: Continuous process, waiting to wake up..."
    fi
    run="true"

    timestamp_old=$(stat -f "%m" $continuous_file 2> /dev/null)
    timestamp_new=$timestamp_old
    while [[ $timestamp_new -eq $timestamp_old ]]
    do
      sleep 1
      timestamp_new=$(stat -f "%m" $continuous_file 2> /dev/null)
      staterror=$?
      if [[ $staterror != 0 ]]
      then
        log_progress "==> $machine: Aborted, exiting"
        run="false"
      fi
    done
  else
    run="false"
  fi

  echo $run
}

function trap_handler() {
  [[ -n $out_pid ]] && kill $out_pid 2>/dev/null
  [[ -n $err_pid ]] && kill $err_pid 2>/dev/null
}

function clean_log() {
  for ext in "${@}"
  do
    rm $run_file.$ext 2>/dev/null
  done
}

function run_on_machine() {
  local machine="$1"
  continuous_file=".logs/$job-$machine"
  run_file="$continuous_file-$log_stamp"
  if [[ -f "$continuous_file.pid" ]]
  then
    log_progress "==> $machine: Checking '$continuous_file.pid'"
    pid=$(head -n 1 "$continuous_file.pid")
    log_progress "==> $machine: Probing process $pid read from '$continuous_file.pid'"
    local process_info=$(ps -o pid,pgid $pid)
    local process_error=$?

    if [ $process_error -eq 0 ]
    then
      if [[ $abort == "true" ]]
      then
        printf "==> $machine: Waiting for current job '%s' to finish" "$job"
        mv "$continuous_file.pid" "$continuous_file.exiting" 2> /dev/null
        count=0
        while [[ $process_error -eq 0 ]]
        do
          printf "."
          sleep 1
          process_info=$(ps -o pid,pgid $pid)
          process_error=$?
          count=$(( $count+1 ))
          if [[ $count -gt 15 ]]
          then
            break
          fi
        done
        printf "\n"
        process_info=$(ps $pid)
        if [[ $? -eq 0 ]]
        then
          printf "${YELLOW}==> $machine: $Timeout - terminating job '$job'${NOCOL}\n"
          log_progress "==> $machine: sending SIGTERM to processes in group $pid"
          kill -- -$(ps -o pgid,pid | grep ^$pid | awk '{print $2}')
        fi
        process_info=$(ps $pid)
        if [[ $? -eq 0 ]]
        then
          printf "${RED}==> $machine: Failed to terminate job '$job' with process id $pid - killing${NOCOL}\n"
          log_progress "==> $machine: sending SIGKILL to processes in group $pid"
          kill -9 -- -$(ps -o pgid,pid | grep ^$pid | awk '{print $2}')
        fi
        log_progress "==> $machine: job terminated, cleaning up"
        rm $continuous_file.exiting 2> /dev/null
        return 0
      fi
      echo "==> $machine: Waking up current job!"
      echo $log_stamp >> "$continuous_file.pid"
      run=$(test_continue "$continuous_file.pid" "wakeup" $machine)
      local last_error=$(tail -n 1 "$continuous_file.pid" | awk '{print $1}')
      log_progress "==> $machine: Last job existed with '$last_error'"
      return $last_error
    else
      echo "==> $machine: Aborted job '$job' discovered, deleting"
      rm $continuous_file.pid 2> /dev/null
    fi
  fi
  [[ $abort == "true" ]] && return 0

  exec 0<&- # closing stdin

  log_progress "==> $machine: Setting up machine"
  
  if ! $(vagrant ssh-config $machine < /dev/null &> /dev/null)
  then
    log_progress "==> $machine: Machine not running - bringing it up"
    if ! vagrant up $machine
    then
      printf "${RED}Can't bring up machine '$machine' - aborting${NOCOL}\n"
      exit -2
    fi
  fi
  
  if $(vagrant winrm $machine < /dev/null &> /dev/null)
  then
    ext="cmd"
  else
    ext="sh"
  fi

  upload_source=jobs/$job
  scriptfile=$job/main.$ext

  if [ ! -f "jobs/$scriptfile" ]; then
    >&2 printf "${RED}'$scriptfile' does not exist - skipping '$machine'${NOCOL}\n"
    return -2
  fi

  echo "==> $machine: running '$job' with arguments '${script_args[@]}'"
  if [ -f "jobs/$job/pre-run.sh" ]; then
    log_progress "==> $machine: Initializing $job"
    source jobs/$job/pre-run.sh $machine "${script_args[@]}" || return $?
  fi

  log_progress "==> $machine: Uploading '$upload_source'..."
  if ! vagrant upload $upload_source $job $machine > /dev/null
  then
    >&2 printf "${RED}==> $machine: Error uploading '$upload_source' to machine '$machine' - skipping machine${NOCOL}\n"
    return -3
  fi

  # poorest-man yaml parser
  if [[ -f "$HOME/minicoin/boxes.yml" ]]
  then
    home_share=$(cat $HOME/minicoin/boxes.yml | grep "home_share:" | awk '{print $2}')
  fi
  if [[ $host_home == "" ]]
  then
    home_share=$(cat boxes.yml | grep "home_share:" | awk '{print $2}')
  fi
  if [[ $home_share == "" ]]
  then
    home_share=$HOME
  fi
  host_home=${home_share/\~/$HOME}
  host_home=${home_share/\$HOME/$HOME}

  # job scripts can expect P0 to be home on host, and P1 PWD on host
  job_args=( "$host_home" )

  # quote arguments with spaces to make guests behave identically
  whitespace=" |'|,"
  for arg in "${script_args[@]}"; do
    if [[ $arg =~ $whitespace ]]; then
      arg=\"$arg\"
    fi
    log_progress "==> $machine: Argument '$arg' added"

    job_args+=($arg)
  done

  error=0
  run="true"
  mkdir .logs 2> /dev/null
  echo $$ > "$continuous_file.pid"
  command=""
  communicator="ssh"
  cleanup_command="rm -rf"
  if [[ $ext == "cmd" ]];
  then
    command="c:\\minicoin\\util\\run_helper.ps1 Documents\\"
    cleanup_command="Remove-Item -Recurse -Force"
    communicator="winrm"
    scriptfile=${scriptfile//\//\\}
  fi
  command="${command}${scriptfile} ${job_args[@]}"
  cleanup_command="${cleanup_command} ${job}"

  log_progress "==> $machine: Executing '$command' through $communicator at $log_stamp"
  while [ "$run" == "true" ]; do
    if [[ $parallel == "true" ]]; then
      redirect=" > /minicoin/${run_file}.out 2> /minicoin/${run_file}.err"
      command="$command$redirect"
    fi
    error=0
    clean_log out err status
    log_progress "==> $machine: running '$job'"
    vagrant $communicator -c "$command" $machine
    error=$?

    [ $parallel == "false" ] && clean_log out err
    log_progress "==> $machine: Job '$job' exited with error code '$error'"

    echo $error >> "$continuous_file.pid"
    if [ "$continuous" == "true" ]
    then
      echo "==> $machine: Waiting for next run; run 'minicoin run --abort $machine $job' to exit"
    fi
    run=$(test_continue "$continuous_file.pid" $continuous $machine)
  done

  log_progress "==> $machine: Job '$job' finished, cleaning up."
  vagrant $communicator -c "$cleanup_command" $machine < /dev/null 2> /dev/null

  if [ $error -gt 0 ]
  then
    >&2 printf "${RED}==> $machine: Job '%s' started at $log_stamp ended with error${NOCOL}\n" "$job"
    if [[ $parallel == "true" ]]
    then
      >&2 echo "    $machine: See 'tail ${run_file}.out' for stdout"
      >&2 echo "    $machine: See 'tail ${run_file}.err' for stderr"
    fi
  fi
  [ $parallel == "false" ] && clean_log out err
  rm $continuous_file.pid 2> /dev/null

  if [ -f "jobs/$job/post-run.sh" ]
  then
    log_progress "==> $machine: Cleaning up after '$job'"
    source jobs/$job/post-run.sh $machine "${script_args[@]}"
    post_error=$?
    [ $error -eq 0 ] && error=$post_error
  fi
  return $error
}

total_error=0
pids=()

for machine in "${machines[@]}"
do
  if [[ "$parallel" == "true" ]]
  then
    log_progress "Starting job on '$machine'..."
    run_on_machine $machine &
    pid=$!
    pids+=($pid)
    log_progress "==> $machine: process ID $pid"
  else
    run_on_machine $machine
    total_error=$(( total_error+$? ))
  fi
done

index=0
for pid in "${pids[@]}"
do
  log_progress "==> ${machines[$index]}: Waiting for $pid"
  wait $pid
  total_error=$(( total_error+$? ))
  index=$(( index + 1 ))
done

exit $total_error

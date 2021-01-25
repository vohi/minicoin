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
  echo "--no-color don't colorize output"
  echo
}

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\e[0;33m"
NOCOL="\033[0m"

machines=()
job="-1"
script_args=()
parallel="false"
verbose="false"

function list_jobs() {
  for job in $(ls -d jobs/*/)
  do
    basename $job | awk {'printf (" - %s\n", $1)'}
  done

  if [ -d "$HOME/minicoin/jobs" ]
  then
    echo "User-defined jobs:"
    for job in $(ls -d "$HOME/minicoin/jobs"/*/)
    do
      basename $job | awk {'printf (" - %s\n", $1)'}
    done
  fi

  if [ -d "${MINICOIN_PROJECT_DIR}/.minicoin/jobs" ]
  then
    echo "Local jobs:"
    for job in $(ls -d "${MINICOIN_PROJECT_DIR}/.minicoin/jobs"/*/)
    do
      basename $job | awk {'printf (" - %s\n", $1)'}
    done
  fi
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
    elif [[ "$arg" == "--no-color" ]]
    then
      GREEN=
      RED=
      YELLOW=
      NOCOL=
    elif [[ "$arg" == "--jobconfig" ]]
    then
      jobconfig=1
    elif [[ $jobconfig == 1 ]]
    then
      jobconfig="$arg"
    else
      machines+=("$arg")
    fi
  else
    script_args+=("$arg")
  fi
done

job="${machines[@]: -1}"

jobroot=
if [ -d "${MINICOIN_PROJECT_DIR}/.minicoin/jobs/$job" ]
then
  jobroot="${MINICOIN_PROJECT_DIR}/.minicoin/jobs"
elif [ -d "${HOME}/minicoin/jobs/$job" ]
then
  jobroot="${HOME}/minicoin/jobs"
elif [ -d "jobs/$job" ]
then
  jobroot="jobs"
else
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

function log_progress() {
  [ "$verbose" == "true" ] && >&2 printf "${YELLOW}%s${NOCOL}\n" "$1"
}

function clean_log() {
  for ext in "${@}"
  do
    rm $run_file.$ext 2>/dev/null
  done
}

function run_on_machine() {
  local machine="$1"
  run_file=".logs/${job}-${machine}-${log_stamp}"
  exec 0<&- # closing stdin

  upload_source="$jobroot/$job"

  machine_info=$(minicoin info $machine)
  log_progress "==> $machine: Machine info retrieved: '$machine_info'"
  communicator=$(echo $machine_info | awk {'print $3'})
  if [[ $communicator == "winrm" || $communicator == "winssh" ]]
  then
    [ $communicator == "winssh" ] && communicator="ssh"
    ext="cmd"
    [ ! -f "$upload_source/main.cmd" ] && ext="ps1"
  else
    ext="sh"
  fi

  scriptfile=$job/main.$ext

  machine_args="$(minicoin jobconfig $job $machine)"
  [[ ! -z $jobconfig ]] && machine_args=$(echo "$machine_args" | grep "$jobconfig")
  if [ "${machine_args:0:5}" == "--raw" ]
  then
    machine_args="${machine_args:7}"
    machine_args="${machine_args#\"}"
    machine_args="${machine_args%\"*}"
    echo "${machine_args}" > jobs/$job/raw.$ext
    chmod +x jobs/$job/raw.$ext
    machine_args="--command ./raw.$ext"
  else
    machine_args=$(echo "$machine_args" | head -n 1)
  fi

  if [ ! -f "$jobroot/$scriptfile" ]
  then
    >&2 printf "${RED}'$scriptfile' does not exist - skipping '$machine'${NOCOL}\n"
    return -2
  fi

  log_progress "==> $machine: Uploading '$upload_source'..."
  $(vagrant upload $upload_source $job $machine 2> /dev/null > /dev/null)
  if [[ $? -gt 0 ]]
  then
    log_progress "==> $machine: Upload failed, trying to set up machine"
  
    if ! vagrant status --machine-readable $machine | grep "$machine,state,running" > /dev/null
    then
      log_progress "==> $machine: Machine not running - bringing it up"
      if ! vagrant up $machine
      then
        >&2 printf "${RED}Can't bring up machine '$machine' - aborting${NOCOL}\n"
        exit -2
      fi
    fi

    log_progress "==> $machine: Retrying uploading '$upload_source'..."
    $(vagrant upload $upload_source $job $machine > /dev/null)
    if [[ $? -gt 0 ]]
    then
      >&2 printf "${RED}==> $machine: Error uploading '$upload_source' to machine '$machine' - skipping machine${NOCOL}\n"
      return -3
    fi
  fi

  home_share=$(echo $machine_info | awk {'print $5'})
  [ -z $home_share ] && home_share=$HOME

  # job scripts can expect P0 to be home on host, and P1 PWD on host
  job_args=( "$home_share" )

  # quote arguments with spaces to make guests behave identically
  whitespace=" |'|,"
  for arg in "${script_args[@]}"; do
    [[ $arg =~ $whitespace ]] && arg=\"$arg\"
    job_args+=($arg)
  done

  job_args+=($machine_args)

  # pass --verbose through to guest
  [ $verbose == "true" ] && job_args+=( "--verbose" )

  echo "==> $machine: running '$job' with arguments '${job_args[@]}' via '$communicator'"

  error=0
  run="true"
  mkdir .logs 2> /dev/null
  command="chmod +x ${scriptfile} && "
  cleanup_command="rm -rf"
  if [[ $ext == "cmd" || $ext == "ps1" ]];
  then
    command="c:\\minicoin\\util\\run_helper.ps1 "
    [ $communicator=="winrm" ] && command="${command}Documents\\"
    cleanup_command="Remove-Item -Recurse -Force"
    scriptfile=${scriptfile//\//\\}
  fi
  command="${command}${scriptfile} ${job_args[@]}"
  cleanup_command="${cleanup_command} ${job}"

  log_progress "==> $machine: Executing '$command' through $communicator at $log_stamp"

  if [[ $parallel == "true" ]]; then
    redirect=" > /minicoin/${run_file}.out 2> /minicoin/${run_file}.err"
    command="$command$redirect"
  fi
  error=0
  clean_log out err status
  log_progress "==> $machine: running '$job'"
  start_seconds=$(date +%s)

  vagrant $communicator -c "$command" $machine < /dev/null \
    1> >(while IFS= read -r line; do
      >&1 printf "%s\n" "$line"
    done) \
    2> >(while IFS= read -r line; do
      [[ "$line" =~ "^==> vagrant:" ]] || >&2 printf "${RED}%s\n${NOCOL}" "$line"
    done)
  error=$?

  end_seconds=$(date +%s)
  diff_seconds=$((end_seconds-start_seconds))
  time_format="%S seconds"
  [ $diff_seconds -gt 60 ] && time_format="%M minutes, $time_format"
  [ $diff_seconds -gt 3600 ] && time_format="%H hours, $time_format"
  readable_time=$(date -r $diff_seconds -u +"$time_format")
  printf "==> $machine: Job '$job' finished in %s\n" "$readable_time"

  [ $parallel == "false" ] && clean_log out err
  log_progress "==> $machine: Job '$job' exited with error code '$error'"
  log_progress "==> $machine: Cleaning up."
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

  return $error
}

total_error=0
pids=()

if [ -f "$jobroot/$job/pre-run.sh" ]; then
  log_progress "==> $machine: Running pre-run script for $job"
  $jobroot/$job/pre-run.sh "${script_args[@]}"
  error=$?
  if [ $error -gt 0 ]
  then
    >&2 printf "${RED}Pre-run initialization exited with error code $error, assuming error and aborting!${NOCOL}"
    return -3
  fi
fi

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

if [ -f "$jobroot/$job/post-run.sh" ]
then
  log_progress "==> $machine: Running post-run script for $job"
  $jobroot/$job/post-run.sh "${script_args[@]}"
  post_error=$?
  [ $post_error -gt 0 ] && >&2 printf "${RED}Post-run clean-up exited with error code $post_error${NOCOL}"
  [ $error -eq 0 ] && error=$post_error
fi

exit $total_error

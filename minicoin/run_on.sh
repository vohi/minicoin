#!/usr/bin/env bash

function print_help() {
  echo "Runs a job on one or more machines using the appropriate remoting mechanism."
  echo "   "
  echo "'machine1..n' is a list of machines on which the job will be run."
  echo "'job' is the job to run on the machines."
  echo "Arguments after '--' will be passed on to the job script. Job arguments that"
  echo "expand to paths on the host will be mapped to the guest's file system."
  echo "  "
  echo "Options:"
  echo "  "
  echo "--use-guest job arguments with paths to the host file system will not be"
  echo "  mapped to the corresponding shared folder, but will be mapped directly"
  echo "  to the guest file system, ie a local ~/workdir will also be ~/workdir"
  echo "  on the guest".
  echo "  "
  echo "--parallel triggers parallel execution of the job on several machines."
  echo "  By default, the job is executed on each machine sequentially."
  echo "  "
  echo "--continuous runs the job in a loop (implies --parallel), waiting"
  echo "  after each run for the next invocation, which will be executed without"
  echo "  the overhead of setting the job up again."
  echo "--abort makes a current continuous run break out of the loop and exit."
  echo
}

machines=()
pids=()
job="-1"
script_args=()
parallel="false"
verbose="false"
continuous="false"
abort="false"
useGuestHome="false"
redirect_output="false"
path_separator="/"
runwithgui="false"

function list_jobs() {
  ls jobs | awk {'printf (" - %s\n", $1)'}  
}

for arg in "${@}"; do
  if [[ "$arg" = "--" ]]; then
    job="--"
  elif [[ "$job" == "-1" ]]; then
    if [[ "$arg" == "--jobs" ]]; then
      list_jobs
      exit 0
    elif [[ "$arg" == "--help" ]]; then
      print_help
      exit 0
    elif [[ "$arg" == "--parallel" ]]; then
      parallel="true"
      redirect_output="true"
    elif [[ "$arg" == "--verbose" ]]; then
      verbose="true"
    elif [[ "$arg" == "--continuous" ]]; then
      continuous="true"
    elif [[ "$arg" == "--abort" ]]; then
      abort="true"
    elif [[ "$arg" == "--use-guest" ]]; then
      useGuestHome="true"
    elif [[ "$arg" == "--gui" ]]; then
      runwithgui="true"
    else
      machines+=("$arg")
    fi
  else
    script_args+=("$arg")
  fi
done

job="${machines[@]: -1}"

if [ ! -d "jobs/$job" ]; then
  echo "There's no job '$job'. Available jobs are:"
  list_jobs
  exit -1
fi

unset "machines[${#machines[@]}-1]"

if [[ ${#machines} == 0 ]]; then
  print_help
  exit 0
fi

log_stamp=$(date "+%Y%m%d-%H%M%S")

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\e[0;33m"
NOCOL="\033[0m"

function log_progress() {
  if [[ "$verbose" == "true" ]]; then
    >&2 printf "${YELLOW}%s${NOCOL}\n" "$1"
  fi
}

# continuous runs with more than one machine need to run parallel
if [[ $continuous == "true" && $(( ${#machines[@]} - 1 )) -gt 0 ]]; then
  log_progress "More than one machine running continuously - running parallel"
  parallel="true"
  redirect_output="true"
fi

function test_continue() {
  continuous_file=$1
  continuous=$2
  machine=$3
  local run="true"

  if [ $continuous == "true" ] || [ $continuous == "wakeup" ]
  then
    if [ $continuous == "true" ]
    then
      log_progress "==> $machine: Continuous process, waiting to wake up..."
    fi
    run="true"

    timestamp_old=$(stat -f "%m" $continuous_file 2> /dev/null)
    error=$?
    timestamp_new=$timestamp_old
    while [[ $timestamp_new -eq $timestamp_old ]]; do
      sleep 1
      timestamp_new=$(stat -f "%m" $continuous_file 2> /dev/null)
      error=$?
      if [[ $error != 0 ]]
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

function run_on_machine() {
  machine="$1"
  continuous_file="/tmp/minicoin-$machine-run-$job.pid"
  if [[ -f $continuous_file ]]; then
    pid=$(head -n 1 $continuous_file)
    log_progress "==> $machine: Probing process $pid"
    process_info=$(ps -o pid,pgid $pid)
    process_error=$?

    if [ $process_error -eq 0 ]
    then
      if [[ $abort == "true" ]]
      then
        printf "==> $machine: Waiting for current job '%s' to finish" "$job"
        mv $continuous_file $continuous_file.exiting 2> /dev/null
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
      echo $log_stamp >> $continuous_file
      run=$(test_continue $continuous_file "wakeup" $machine)
      error=$(tail -n 1 $continuous_file | awk '{print $1}')
      log_progress "==> $machine: Last job existed with '$error'"
      return $error
    else
      echo "==> $machine: Aborted job '$job' discovered, deleting"
      rm $continuous_file
    fi
  fi
  [[ $abort == "true" ]] && return 0

  exec 0<&- # closing stdin

  log_progress "==> $machine: Setting up machine"
  vagrant ssh-config $machine < /dev/null &> /dev/null
  error=$?
  if [[ $error -gt 0 ]]; then
    log_progress "==> $machine: Machine not running - bringing it up"
    vagrant up $machine
    error=$?
    if [[ $error -gt 0 ]]; then
      printf "${RED}Can't bring up machine '$machine' - aborting${NOCOL}\n"
      exit $error
    fi
  fi
  vagrant winrm $machine < /dev/null &> /dev/null
  error=$?
  if [[ $error == 0 ]]; then
    path_separator="\\"
    if [ "$useGuestHome" == "true" ]; then
      guest_home="c:\\Users\\vagrant"
    else
      guest_home="c:\\Users\\host"
    fi
    ext="cmd"
  else
    uname=$(vagrant ssh -c uname $machine < /dev/null &> /dev/null)
    if [[ "$uname" =~ "Darwin" ]]; then
      guest_home="/Users/host"
    else
      guest_home="/home/host"
    fi
    ext="sh"
  fi

  upload_source=jobs/$job
  scriptfile=$job/main.$ext

  if [ ! -f "jobs/$scriptfile" ]; then
    >&2 printf "${RED}'$scriptfile' does not exist - skipping '$machine'${NOCOL}\n"
    return
  fi

  echo "==> $machine: running '$job' with arguments '${script_args[@]}'"
  if [ -f "jobs/$job/pre-run.sh" ]; then
    log_progress "==> $machine: Initializing $job"
    source jobs/$job/pre-run.sh $machine "${script_args[@]}"
  fi

  if [[ $redirect_output == "true" ]]; then
    mkdir .logs &> /dev/null
    touch $PWD/.logs/$job-$machine-$log_stamp.log
    touch $PWD/.logs/$job-error-$machine-$log_stamp.log
    ln -sf $PWD/.logs/$job-$machine-$log_stamp.log .logs/$job-$machine-latest.log
    ln -sf $PWD/.logs/$job-error-$machine-$log_stamp.log .logs/$job-error-$machine-latest.log
  fi

  log_progress "==> $machine: Uploading '$upload_source'..."
  out=$(vagrant upload $upload_source $job $machine)
  error=$?
  if [ ! $error == 0 ]; then
    >&2 printf "${RED}==> $machine: Error uploading '$upload_source' to machine '$machine' - skipping machine${NOCOL}\n"
    return
  fi

  # poorest-man yaml parser
  if [[ -f "$HOME/minicoin/boxes.yml" ]]; then
    home_share=$(cat $HOME/minicoin/boxes.yml | grep "home_share:" | awk '{print $2}')
  fi
  if [[ $host_home == "" ]]; then
    home_share=$(cat boxes.yml | grep "home_share:" | awk '{print $2}')
  fi
  if [[ $home_share == "" ]]; then
    home_share=$HOME
  fi
  host_home=${home_share/\~/$HOME}
  host_home=${home_share/\$HOME/$HOME}

  job_args=()

  # replace host home with guest home in all arguments
  # and quote to make guests behave identically
  whitespace=" |'|,"
  for arg in "${script_args[@]}"; do
    mapped="${arg/$host_home/$guest_home}"
    [[ $arg = /* ]] && mapped="${mapped//\//$path_separator}"
    if [[ $mapped =~ $whitespace ]]; then
      mapped=\"$mapped\"
    fi
    log_progress "==> $machine: Argument '$arg' mapped to '$mapped'"

    job_args+=($mapped)
  done

  error=0
  run="true"
  echo $$ > $continuous_file
  if [[ $ext == "cmd" ]]; then
    scriptfile=${scriptfile//\//\\}
    command="Documents\\$scriptfile"

    if [[ "$runwithgui" == "true" ]]
    then
      runner="psexec -i 1 -u vagrant -p vagrant -nobanner -w c:\\users\\vagrant cmd /c $command ${job_args[@]}"
    else
      command="$command ${job_args[@]}"
      errorfile=".logs/$job-error-$machine-$log_stamp.errorcode"
      if [[ $redirect_output == "true" ]]; then
        redirect=" > c:\\minicoin\\.logs\\$job-$machine-$log_stamp.log 2> c:\\minicoin\\.logs\\$job-error-$machine-$log_stamp.log"
        command=$command$redirect
      fi
      runner="cmd /C $command || echo 1 > c:\\minicoin\\$errorfile"
    fi

    log_progress "$machine ==> Executing '$runner' at $log_stamp"

    while [ "$run" == "true" ]; do
      error=0
      log_progress "==> $machine: running $job through winrm"
      vagrant winrm -s cmd -c "$runner" $machine
      error=$?

      if [[ "$runwithgui" == "true" ]]
      then
        log_progress "==> $machine: Capturing $error from winrm return value"
      elif [[ -f "$errorfile" ]]; then
        error=$(tail -n 1 $errorfile | awk '{print $1}')
        log_progress "==> $machine: Reading $error from '$errorfile'"
        rm "$errorfile"
      fi
      if [[ $error -gt 0 ]]
      then
        printf "${RED}"
      else
        printf "${GREEN}"
      fi
      printf "==> $machine: Job '%s' exited with error code '$error'${NOCOL}\n" "$job"

      echo $error >> $continuous_file
      if [ "$continuous" == "true" ]
      then
        echo "==> $machine: Waiting for next run; run 'minicoin run --abort $machine $job' to exit"
      fi
      run=$(test_continue $continuous_file $continuous $machine)
    done
    log_progress "==> $machine: Job '$job' finished, cleaning up."
    vagrant winrm -s cmd -c "rd Documents\\$job /S /Q" $machine 2> /dev/null
  else
    command="$scriptfile ${job_args[@]}"
    log_progress "==> $machine: Executing '$command' at $log_stamp"

    if [[ $redirect_output == "true" ]]; then
      redirect=" > /minicoin/.logs/$job-$machine-$log_stamp.log 2> /minicoin/.logs/$job-error-$machine-$log_stamp.log"
      command="$command$redirect"
    fi
    while [ "$run" == "true" ]; do
      error=0
      log_progress "==> $machine: running $job through ssh"
      vagrant ssh -c "$command" $machine < /dev/null 2> /dev/null
      error=$?
      log_progress "==> $machine: Job '$job' exited with error code '$error'"

      echo $error >> $continuous_file
      if [ "$continuous" == "true" ]
      then
        echo "==> $machine: Waiting for next run; run 'minicoin run --abort $machine $job' to exit"
      fi
      run=$(test_continue $continuous_file $continuous $machine)
    done
    log_progress "==> $machine: Job '$job' finished, cleaning up."
    vagrant ssh -c "rm -rf $job" $machine < /dev/null 2> /dev/null
  fi
  if [ $error -gt 0 ]; then
    >&2 printf "${RED}==> $machine: Job '%s' started at $log_stamp ended with error${NOCOL}\n" "$job"
    if [[ $redirect_output == "true" ]]; then
      >&2 echo "    $machine: See 'tail .logs/$job-$machine-$log_stamp.log' for stdout"
      >&2 echo "    $machine: See 'tail .logs/$job-error-$machine-$log_stamp.log' for stderr"
    fi
  fi
  rm $continuous_file 2> /dev/null

  if [ -f "jobs/$job/post-run.sh" ]; then
    log_progress "==> $machine: Cleaning up after '$job'"
    source jobs/$job/post-run.sh $machine "${script_args[@]}"
  fi
}

error=0
for machine in "${machines[@]}"; do
  if [[ "$parallel" == "true" ]]; then
    log_progress "Starting job on '$machine'..."
    run_on_machine $machine &
    pids[${machine}]=$!
  else
    run_on_machine $machine
    error=$(( $error+$? ))
  fi
done

for pid in ${pids[*]}; do
  wait $pid
  error=$(( $error+$? ))
done

exit $error
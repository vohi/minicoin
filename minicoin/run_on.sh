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
  echo "--no-mapping Job arguments will not be mapped to the guest file system"
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

function log_progress() {
  if [[ "$verbose" == "true" ]]; then
    >&2 echo $1
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
  if [[ $abort == "true" ]]; then
    if [[ -f $continuous_file ]]; then
      echo "==> $machine: Exiting current job!"
      rm $continuous_file 2> /dev/null
    fi
    return 0
  elif [[ -f $continuous_file ]]; then
    pid=$(head -n 1 $continuous_file)
    log_progress "==> $machine: Probing process $pid"
    pid=$(ps $pid)
    if [ $? -eq 0 ]
    then
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

  exec 0<&- # closing stdin

  log_progress "==> $machine: Setting up machine"
  vagrant ssh-config $machine < /dev/null &> /dev/null
  error=$?
  if [[ $error -gt 0 ]]; then
    log_progress "==> $machine: Machine not running - bringing it up"
    vagrant up $machine
    error=$?
    if [[ $error -gt 0 ]]; then
      echo "Can't bring up machine '$machine' - aborting"
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
    >&2 echo "'$scriptfile' does not exist - skipping '$machine'"
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
    >&2 echo "==> $machine: Error uploading '$upload_source' to machine '$machine' - skipping machine"
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
    [[ $mapped = /* ]] && mapped="${mapped//\//$path_separator}"
    if [[ $mapped =~ $whitespace ]]; then
      mapped=\"$mapped\"
    fi

    job_args+=($mapped)
  done

  error=0
  run="true"
  echo $$ > $continuous_file
  if [[ $ext == "cmd" ]]; then
    scriptfile=${scriptfile//\//\\}

    command="Documents\\$scriptfile ${job_args[@]}"
    log_progress "$machine ==> Executing '$command' at $log_stamp"

    if [[ $redirect_output == "true" ]]; then
      redirect=" > c:\\minicoin\\.logs\\$job-$machine-$log_stamp.log 2> c:\\minicoin\\.logs\\$job-error-$machine-$log_stamp.log"
      command=$command$redirect
    fi

    while [ "$run" == "true" ]; do
      error=0
      log_progress "==> $machine: running $job through winrm"
      errorfile=".logs/$job-error-$machine-$log_stamp.errorcode"
      vagrant winrm -s cmd -c \
        "cmd /C $command || echo 1 > c:\\minicoin\\.logs\\$job-error-$machine-$log_stamp.errorcode" \
        $machine
      if [[ -f "$errorfile" ]]; then
        error=$(tail -n 1 $errorfile | awk '{print $1}')
        rm "$errorfile"
      fi
      log_progress "==> $machine: Job '$job' exited with error code '$error'"

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
  if [ "$error" != "0" ]; then
    >&2 echo "==> $machine: Job '$job' started at $log_stamp ended with error"
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
#!/usr/bin/env bash

if [ "$#" -lt 2 ]; then
  echo "Runs a script on a machine using the appropriate remoting mechanism."
  echo
  echo "Usage: $0 [options] machine1 machine2 ... job [--] [args]"
  echo
  echo "  'machine1..n' is a list of machines on which the job will be run sequentially"
  echo "  'job' is the job to run, with the main script in the jobs/job as the entry point"
  echo "  The optional 'args' will be passed to the main script"
  echo
  exit 1
fi

machines=()
pids=()
job="-1"
script_args=()
parallel="true"

for arg in "${@}"; do
  if [[ "$arg" = "--" ]]; then
    job="--"
  elif [[ "$arg" = "--no-parallel" ]]; then
    parallel="false"
  elif [[ "$job" = '-1' ]]; then
    machines=( "${machines[@]}" "$arg" )
  else
    script_args=( "${script_args[@]}" "$arg" )
  fi
done

job="${machines[@]: -1}"
unset "machines[${#machines[@]}-1]"

log_stamp=$(date "+%Y%m%d-%H%M%S")

function run_on_machine() {
  machine=$1

  machine_state=$(vagrant status $machine | grep $machine | awk '{print $2}')
  if [ ! $machine_state == 'running' ]; then
    vagrant up $machine
  fi

  platform_test=$(vagrant ssh -c uname $machine) 2> /dev/null
  case "$platform_test" in
    *"Windows"*) ext="cmd";;
    *"Linux"*)   ext="sh" ;;
    *"Darwin"*)  ext="sh" ;;
    *)           ext="cmd" ;;
  esac

  upload_source=jobs/$job
  scriptfile=$job/main.$ext

  if [ ! -f "jobs/$scriptfile" ]; then
    echo "'$scriptfile' does not exist - skipping '$machine'"
    return
  fi

  if [ -f "jobs/$job/pre-run.sh" ]; then
    echo "$machine ==> Initializing $job"
    source jobs/$job/pre-run.sh $machine "${script_args[@]}"
  fi

  $(mkdir .logs)
  ln -sf $PWD/.logs/$job-$machine-$log_stamp.log .logs/$job-$machine-latest.log
  ln -sf $PWD/.logs/$job-error-$machine-$log_stamp.log .logs/$job-error-$machine-latest.log

  echo "$machine ==> Uploading '$upload_source'..."
  out=$(vagrant upload $upload_source $job $machine)
  error=$?
  if [ ! $error == 0 ]; then
    echo "$machine ==> Error uploading '$upload_source' to machine '$machine' - skipping machine"
    return
  fi

  if [[ $ext == "cmd" ]]; then
    host_home="c:\\Users\\host"
  else
    host_home="/home/host"
  fi

  job_args=()
  for arg in ${script_args[@]}; do
    job_args=(${job_args[@]} ${arg/$HOME/$host_home})
  done

  error=0
  if [[ $ext == "cmd" ]]; then
    scriptfile=${scriptfile//\//\\}
    command="Documents\\$scriptfile \"${job_args[@]}\""
    echo "$machine ==> Executing '$command' at $log_stamp"
    vagrant winrm -s cmd -c \
      "$command > c:\\vagrant\\.logs\\$job-$machine-$log_stamp.log 2> c:\\vagrant\\.logs\\$job-error-$machine-$log_stamp.log" \
      $machine
    error=$?
    if [ $error == 0 ]; then
      vagrant winrm -s cmd -c "rd Documents\\$job /S /Q" $machine
    fi
  else
    command="$scriptfile \"${job_args[@]}\""
    echo "$machine ==> Executing '$command' at $log_stamp"

    vagrant ssh -c \
      "$command > /vagrant/.logs/$job-$machine-$log_stamp.log 2> /vagrant/.logs/$job-error-$machine-$log_stamp.log" \
      $machine 2> /dev/null
    error=$?

    if [ $error == 0 ]; then
      vagrant ssh -c "rm -rf $job" $machine 2> /dev/null
    fi
  fi
  if [ $error != 0 ]; then
    echo "$machine ==> Job ended with error - See files in .logs for complete stdout and stderr"
  fi

  if [ -f "jobs/$job/post-run.sh" ]; then
    echo "$machine ==> Cleaning up after '$job'"
    source jobs/$job/post-run.sh $machine "${script_args[@]}"
  fi
}

for machine in "${machines[@]}"; do
  if [[ "$parallel" == "true" ]]; then
    echo "Starting job on '$machine'..."
    run_on_machine $machine &
    pids[${machine}]=$!
  else
    run_on_machine $machine
  fi
done

for pid in ${pids[*]}; do
  wait $pid
done

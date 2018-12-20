#!/usr/bin/env bash

if [ "$#" -lt 2 ]; then
  echo "Runs a script on a machine using the appropriate remoting mechanism."
  echo
  echo "Usage: $0 machine1 machine2 ... job -- {args}"
  echo
  echo "  'machine1..n' is a list of machines on which the job will be run sequentially"
  echo "  'job' is the job to run, with the main script in the jobs/job as the entry point"
  echo "  The optional 'args' will be passed to the main script"
  echo
  exit 1
fi

machines=()
job="-1"
script_args=()

for arg in "${@}"; do
  if [[ "$arg" = "--" ]]; then
    job="--"
  elif [[ "$job" = '-1' ]]; then
    machines=( "${machines[@]}" "$arg" )
  else
    script_args=( "${script_args[@]}" "$arg" )
  fi
done

job="${machines[@]: -1}"
unset "machines[${#machines[@]}-1]"

for machine in "${machines}"; do
  case "$machine" in
    *"windows"*)   ext=cmd ;;
    *"mac"*)       ext=sh ;;
    *)             ext=sh ;;
  esac

  upload_source=jobs/$job
  scriptfile=$job/main.$ext

  if [ ! -f "jobs/$scriptfile" ]; then
    echo "'$scriptfile' does not exist, aborting"
    exit 1
  fi

  machine_state=$(vagrant status $machine | grep $machine | awk '{print $2}')
  if [ ! $machine_state == 'running' ]; then
    vagrant up $machine
  fi

  vagrant upload $upload_source $job  $machine
  error=$?
  if [ ! $error == 0 ]; then
    echo "Error uploading '$upload_source' to machine '$machine' - skipping machine"
    continue
  fi

  log_stamp=$(date "+%Y%m%d-%H%M%S")

  if [[ $ext == "cmd" ]]; then
    scriptfile=${scriptfile//\//\\}
    command="Documents\\$scriptfile ${script_args[@]}"
    echo "$machine ==> Executing '$command'"
    vagrant winrm -s cmd -c "$command" $machine
    error=$?
    if [ $error == 0 ]; then
      vagrant winrm -s cmd -c "deltree $job" $machine
    fi
  else
    command="$scriptfile ${script_args[@]}"
    echo "$machine ==> Executing '$command'"
    vagrant ssh -c "$command > $job-$log_stamp.log 2> $job-error-$log_stamp.log" $machine
    error=$?
    if [ $error == 0 ]; then
      vagrant ssh -c "rm -rf $job" $machine
    fi
  fi

  # shut machine down to previous state
  if [ $machine_state == 'saved' ]; then
    vagrant suspend $machine
  elif [ $machine_state == 'poweroff' ]; then
    vagrant halt $machine
  elif [ $machine_state == 'not' ]; then
    vagrant destroy -f $machine
  fi

done

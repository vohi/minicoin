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

log_stamp=$(date "+%Y%m%d-%H%M%S")

for machine in "${machines[@]}"; do
  machine_state=$(vagrant status $machine | grep $machine | awk '{print $2}')
  if [ ! $machine_state == 'running' ]; then
    vagrant up $machine
  fi

  platform_test=$(vagrant ssh -c uname $machine) 2> /dev/null
  case "$platform_test" in
    *"Linux"*)  ext="sh" ;;
    *"Darwin"*) ext="sh" ;;
    *)          ext="cmd" ;;
  esac

  upload_source=jobs/$job
  scriptfile=$job/main.$ext

  if [ ! -f "jobs/$scriptfile" ]; then
    echo "'$scriptfile' does not exist, aborting"
    exit 1
  fi

  if [ -f "jobs/$job/pre-run.sh" ]; then
    echo "Initializing $job"
    source jobs/$job/pre-run.sh ${script_args[@]}
  fi

  vagrant upload $upload_source $job  $machine
  error=$?
  if [ ! $error == 0 ]; then
    echo "Error uploading '$upload_source' to machine '$machine' - skipping machine"
    continue
  fi

  if [[ $ext == "cmd" ]]; then
    scriptfile=${scriptfile//\//\\}
    command="Documents\\$scriptfile ${script_args[@]}"
    echo "$machine ==> Executing '$command'"
    vagrant winrm -s cmd -c "$command > $job-$log_stamp.log 2> $job-error-$log_stamp.log" $machine
    error=$?
    if [ $error == 0 ]; then
      vagrant winrm -s cmd -c "rd Documents\\$job /S /Q" $machine
    fi
  else
    command="$scriptfile ${script_args[@]}"
    echo "$machine ==> Executing '$command'"

    $(vagrant ssh -c "touch $job-$log_stamp.log && tail -f $job-$log_stamp.log" $machine > $job-current-$machine.log)&
    stdout_tail_pid=$!
    sleep 5
    $(vagrant ssh -c "touch $job-error-$log_stamp.log && tail -f $job-error-$log_stamp.log" $machine > $job-error-current-$machine.log)&
    stderr_tail_pid=$!
    sleep 5

    vagrant ssh -c "$command > $job-$log_stamp.log 2> $job-error-$log_stamp.log" $machine 2> /dev/null
    error=$?

    kill $stdout_tail_pid
    kill $stderr_tail_pid
    tail $job-current-$machine.log

    if [ $error == 0 ]; then
      vagrant ssh -c "rm -rf $job" $machine 2> /dev/null
    fi
    echo "$machine ==> See '$job-$log_stamp.log' and '$job-error-$log_stamp.log' for complete stdout and stderr"
  fi

  if [ -f "jobs/$job/post-run.sh" ]; then
    echo "Cleaning up after $job"
    source jobs/$job/post-run.sh ${script_args[@]}
  fi

  # shut machine down to previous state
  if [ $machine_state == 'saved' ]; then
    vagrant suspend $machine
  elif [ $machine_state == 'poweroff' ]; then
    vagrant halt $machine
  elif [ $machine_state == 'not' ]; then
    vagrant halt $machine
  fi

done

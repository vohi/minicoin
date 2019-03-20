#!/usr/bin/env bash

if [ "$#" -lt 2 ]; then
  echo "Runs a script on a machine using the appropriate remoting mechanism."
  echo
  echo "Usage: $(basename $0) [options] machine1 machine2 ... job [--] [args]"
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
parallel="false"
verbose="false"

for arg in "${@}"; do
  if [[ "$arg" = "--" ]]; then
    job="--"
  elif [[ "$arg" = "--parallel" && "$job" != "--" ]]; then
    parallel="false"
  elif [[ "$arg" = "--verbose" && "$job" != "--" ]]; then
    verbose='true'
  elif [[ "$job" = '-1' ]]; then
    machines=( "${machines[@]}" "$arg" )
  else
    script_args=( "${script_args[@]}" "$arg" )
  fi
done

job="${machines[@]: -1}"

if [ ! -d "jobs/$job" ]; then
  echo "There's no job '$job'. Available jobs are:"
  ls jobs | awk {'printf (" - %s\n", $1)'}
  exit -1
fi

unset "machines[${#machines[@]}-1]"

log_stamp=$(date "+%Y%m%d-%H%M%S")

function log_progress() {
  if [[ "$verbose" == "true" ]]; then
    echo $1
  fi
}

function run_on_machine() {
  machine=$1

  machine_state=$(vagrant status $machine | grep $machine | awk '{print $2}')
  if [ ! $machine_state == 'running' ]; then
    vagrant up $machine
  fi

  vagrant winrm $machine &> /dev/null
  error=$?
  if [[ $error == 0 ]]; then
    ext="cmd"
  else
    ext="sh"
  fi

  upload_source=jobs/$job
  scriptfile=$job/main.$ext

  if [ ! -f "jobs/$scriptfile" ]; then
    echo "'$scriptfile' does not exist - skipping '$machine'"
    return
  fi

  echo "$machine is up, running '$job' with args '${script_args[@]}'!"
  if [ -f "jobs/$job/pre-run.sh" ]; then
    log_progress "$machine ==> Initializing $job"
    source jobs/$job/pre-run.sh $machine "${script_args[@]}"
  fi

  mkdir .logs &> /dev/null
  touch $PWD/.logs/$job-$machine-$log_stamp.log
  touch $PWD/.logs/$job-error-$machine-$log_stamp.log
  ln -sf $PWD/.logs/$job-$machine-$log_stamp.log .logs/$job-$machine-latest.log
  ln -sf $PWD/.logs/$job-error-$machine-$log_stamp.log .logs/$job-error-$machine-latest.log

  log_progress "$machine ==> Uploading '$upload_source'..."
  out=$(vagrant upload $upload_source $job $machine)
  error=$?
  if [ ! $error == 0 ]; then
    echo "$machine ==> Error uploading '$upload_source' to machine '$machine' - skipping machine"
    return
  fi

  if [[ $ext == "cmd" ]]; then
    guest_home="c:\\Users\\host"
  else
    guest_home="/home/host"
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
  for arg in ${script_args[@]}; do
    job_args=(${job_args[@]} ${arg/$host_home/$guest_home})
  done

  error=0
  if [[ $ext == "cmd" ]]; then
    scriptfile=${scriptfile//\//\\}
    command="Documents\\$scriptfile ${job_args[@]}"
    log_progress "$machine ==> Executing '$command' at $log_stamp"
    vagrant winrm -s cmd -c \
      "($command > c:\\minicoin\\.logs\\$job-$machine-$log_stamp.log \
        2> c:\\minicoin\\.logs\\$job-error-$machine-$log_stamp.log) || \
        echo \"Error %ERRORLEVEL%\" > c:\\minicoin\\.logs\\$job-error-$machine-$log_stamp.errorcode" \
      $machine
    if [[ -f ".logs/$job-error-$machine-$log_stamp.errorcode" ]]; then
      error=1
    fi
    vagrant winrm -s cmd -c "rd Documents\\$job /S /Q" $machine 2> /dev/null
  else
    command="$scriptfile ${job_args[@]}"
    log_progress "$machine ==> Executing '$command' at $log_stamp"

    vagrant ssh -c \
      "$command > /minicoin/.logs/$job-$machine-$log_stamp.log 2> /minicoin/.logs/$job-error-$machine-$log_stamp.log" \
      $machine 2> /dev/null
    error=$?

    vagrant ssh -c "rm -rf $job" $machine 2> /dev/null
  fi
  if [ $error != 0 ]; then
    >&2 echo "$machine ==> Job $job started at $log_stamp ended with error"
    >&2 echo "$machine ==> See 'tail .logs/$job-$machine-$log_stamp.log' for stdout"
    >&2 echo "$machine ==> See 'tail .logs/$job-error-$machine-$log_stamp.log' for stderr"
  fi

  if [ -f "jobs/$job/post-run.sh" ]; then
    log_progress "$machine ==> Cleaning up after '$job'"
    source jobs/$job/post-run.sh $machine "${script_args[@]}"
  fi
}

for machine in "${machines[@]}"; do
  if [[ "$parallel" == "true" ]]; then
    log_progress "Starting job on '$machine'..."
    run_on_machine $machine &
    pids[${machine}]=$!
  else
    run_on_machine $machine
  fi
done

for pid in ${pids[*]}; do
  wait $pid
done

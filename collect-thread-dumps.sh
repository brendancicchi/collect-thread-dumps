#!/usr/bin/env bash

##### Begin Configurations #####

# If jcmd is not on the path but installed on the server, prepend the absolute path here
JCMD=jcmd

##### End of Configurations #####

function main()
{
    if [ $# -ne 3 ]; then
        echo "ERROR: Usage: $0 pid interval count"
        exit 1
    fi

    PID=$1
    INTERVAL=$2
    COUNT=$3
    THREAD_OUTPUT=threads_$(hostname -i)_$(date '+%Y-%m-%d_%H-%M-%S').out
    TOP_OUTPUT=top_$(hostname -i)_$(date '+%Y-%m-%d_%H-%M-%S').out

    if command -v $JCMD &> /dev/null
    then
        echo "Using jcmd to collect Java thread dumps..."
        jcmd_verification
        jcmd_collection
    else
        echo "jcmd could not be found on PATH, falling back to using kill -3 method..."
        kill3_verification
        kill3_collection
    fi
}

function jcmd_collection()
{
    echo "Writing thread dumps to $THREAD_OUTPUT"
    echo "Writing top output to $TOP_OUTPUT"
    top -bH -d $INTERVAL -n $COUNT -p $PID >> $TOP_OUTPUT 2>&1 &
    for _i in $(seq $COUNT)
    do
        echo "stack trace $_i of $COUNT" | tee -a $THREAD_OUTPUT
        $JCMD $PID Thread.print >> $THREAD_OUTPUT
        echo "--------------------" >> $THREAD_OUTPUT
        [ $_i != $COUNT ] && sleep $INTERVAL
    done
}

function jcmd_verification()
{
    _process_user=$(ps -p $PID -o user | grep -Ev "^USER$")
    if [[ $_process_user != $(whoami) ]]
    then
        echo "ERROR: Collecting thread dumps as jcmd must be run as the exact same user as the JVM process owner, $_process_user"
        exit 1
    fi
    if ! grep $PID <($JCMD) &> /dev/null
    then
        echo "ERROR: jcmd cannot find the pid $PID. Visible Java processes are:"
        $JCMD
        exit 1
    fi
    if ! touch $THREAD_OUTPUT $TOP_OUTPUT &> /dev/null
    then
        echo "ERROR: $_process_user does not have permission to write to $THREAD_OUTPUT or $TOP_OUTPUT"
        exit 1
    fi
}

function kill3_collection()
{
    echo "Writing top output to $TOP_OUTPUT"
    top -bH -d $INTERVAL -n $COUNT -p $PID >> $TOP_OUTPUT 2>&1 &
    for _i in $(seq $COUNT); do
        echo "stack trace $_i of $COUNT"
        kill -3 $PID
        [ $_i != $COUNT ] && sleep $INTERVAL
    done
}

function kill3_verification()
{
    _launch_cmd=$(ps -p $PID -o command | grep -Ev "^COMMAND$")
    echo "$_launch_cmd"
    if [ -z "$_launch_cmd" ]
    then
        echo "Unable to find the pid $PID via ps"
        exit 1
    fi
    _output_file=$(awk -F"-XX:LogFile=" '{sub(/ .*/,"",$2);print $2}' <<< $_launch_cmd | tr -d '[:space:]')
    if ! grep -F -- "-XX:+LogVMOutput" <<< $_launch_cmd | grep -F -- "-XX:+UnlockDiagnosticVMOptions" &> /dev/null
    then
        echo -e "ERROR: In order to use kill -3 on the JVM to obtain a thread dump, the following JVM properties must be added:\n-XX:+UnlockDiagnosticVMOptions\n-XX:+LogVMOutput"
        [ -z $_output_file ] && echo "ERROR: The property -XX:LogFile={path} must also be added, substituting a valid path"
        exit 1
    else
        echo "The kill -3 thread dump output will be written to $_output_file as configured by -XX:Logfile in the JVM properties"
    fi
    if ! touch $TOP_OUTPUT &> /dev/null
    then
        echo "ERROR: $(whoami) does not have permission to write to $TOP_OUTPUT"
        exit 1
    fi
}


main "$@"
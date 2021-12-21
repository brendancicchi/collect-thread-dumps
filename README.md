# collect-thread-dumps

## Summary

Helper script which can be used on any JVM process to gather repeated collections of thread dumps. The script leverages the `jcmd` utility which is bundled with the JDK and falls back to using `kill -3` if `jcmd` is not found on the `PATH`. 

## Syntax

```
./collect-thread-dumps.sh <pid> <interval> <count>
```

## History

This script merges the `multidump.sh` and `multidump-alt.sh` scripts used by DataStax as well as adding some additional error handling to make thread dump collection a simpler process.

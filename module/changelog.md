## 1.2.1 Update
- Removed non-existent policy5 CPU governor paths (your phone only has policy0, policy3, and policy7).
- Block device discovery now finds storage devices automatically instead of using a hardcoded list.
- Boot detection now tries both getprop and resetprop for better compatibility.
- Log timestamps are now accurate per line instead of showing the same time for all entries.

DONT combine it with other perf modules (except thermal, but i dont suggests it).

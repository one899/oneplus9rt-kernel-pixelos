#!/bin/bash
# SM8250-style BPF compatibility patches for 9RT kernel
# Only adds what bpf_compat54.h does NOT cover
set -e

OP=$1
OPP=$2

echo "=== Patching 9RT headers for BPF compatibility ==="

# 1. proc_ns.h: add ns_match
if ! grep -q "ns_match" "$OP/include/linux/proc_ns.h"; then
    sed -i '/^extern int proc_ns_common/i\extern bool ns_match(const struct ns_common *ns, dev_t dev, ino_t ino);' "$OP/include/linux/proc_ns.h"
    echo "[OK] proc_ns.h patched"
else
    echo "[OK] proc_ns.h already patched"
fi

# 2. perf_event.h: add get_callchain_entry
if ! grep -q "get_callchain_entry" "$OP/include/linux/perf_event.h"; then
    cat >> "$OP/include/linux/perf_event.h" << 'EOF'

#ifdef CONFIG_PERF_EVENTS
extern struct perf_callchain_entry *get_callchain_entry(int *rctx);
extern void put_callchain_entry(int rctx);
#endif
EOF
    echo "[OK] perf_event.h patched"
else
    echo "[OK] perf_event.h already patched"
fi

echo "=== Patches applied ==="

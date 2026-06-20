#!/bin/bash
# SM8250-style BPF compatibility patches for 9RT kernel
# Adds missing function declarations to existing headers
# without replacing the entire file
set -e

OP=$1
OPP=$2

echo "=== Patching 9RT headers for BPF compatibility ==="

# 1. capability.h: add bpf_capable + perfmon_capable
if ! grep -q "bpf_capable" "$OP/include/linux/capability.h"; then
    cat >> "$OP/include/linux/capability.h" << 'EOF'

#ifndef perfmon_capable
static inline bool perfmon_capable(void) { return capable(CAP_SYS_ADMIN); }
#endif

static inline bool bpf_capable(void) { return capable(CAP_SYS_ADMIN) || capable(CAP_PERFMON); }
EOF
    echo "[OK] capability.h patched"
else
    echo "[OK] capability.h already patched"
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

# 3. proc_ns.h: add ns_match
if ! grep -q "ns_match" "$OP/include/linux/proc_ns.h"; then
    # Insert before the first extern function
    sed -i '/^extern int proc_ns_common/i\extern bool ns_match(const struct ns_common *ns, dev_t dev, ino_t ino);' "$OP/include/linux/proc_ns.h"
    echo "[OK] proc_ns.h patched"
else
    echo "[OK] proc_ns.h already patched"
fi

# 4. vmalloc.h: add vmalloc_user_node_flags
if ! grep -q "vmalloc_user_node_flags" "$OP/include/linux/vmalloc.h"; then
    cat >> "$OP/include/linux/vmalloc.h" << 'EOF'

#ifndef vmalloc_user_node_flags
#include <linux/gfp.h>
static inline void *vmalloc_user_node_flags(unsigned long size, int node, gfp_t flags)
{
    return __vmalloc_node_flags_caller(size, node, flags | __GFP_ZERO, __builtin_return_address(0));
}
#endif
EOF
    echo "[OK] vmalloc.h patched"
else
    echo "[OK] vmalloc.h already patched"
fi

echo "=== Patches applied ==="

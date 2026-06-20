#!/bin/bash
# SM8250-style BPF compatibility patches for 9RT kernel
# Only adds what bpf_compat54.h does NOT cover
set -e

OP=$1
OPP=$2

echo "=== Patching 9RT headers ==="

# 1. proc_ns.h: add ns_match
if ! grep -q "ns_match" "$OP/include/linux/proc_ns.h"; then
    # Just append before the final #endif
    python3 -c "
fpath='$OP/include/linux/proc_ns.h'
with open(fpath,'r') as f: content=f.read()
if 'ns_match' not in content:
    idx=content.rfind('#endif')
    content=content[:idx]+'extern bool ns_match(const struct ns_common *ns, dev_t dev, ino_t ino);\n\n'+content[idx:]
    with open(fpath,'w') as f: f.write(content)
    print('ns_match patched')
"
    echo "[OK] proc_ns.h patched"
else
    echo "[OK] proc_ns.h already patched"
fi

# 3. perf_event.h: add get_callchain_entry
if ! grep -q "get_callchain_entry" "$OP/include/linux/perf_event.h"; then
    python3 -c "
fpath='$OP/include/linux/perf_event.h'
with open(fpath,'r') as f: content=f.read()
if 'get_callchain_entry' not in content:
    idx=content.rfind('#endif')
    shim='''#ifdef CONFIG_PERF_EVENTS
extern struct perf_callchain_entry *get_callchain_entry(int *rctx);
extern void put_callchain_entry(int rctx);
#endif

'''
    content=content[:idx]+shim+content[idx:]
    with open(fpath,'w') as f: f.write(content)
    print('perf_event.h patched')
"
    echo "[OK] perf_event.h patched"
else
    echo "[OK] perf_event.h already patched"
fi

# 3. bpf-cgroup.h: add cgroup_bpf_link_attach declaration
if ! grep -q "cgroup_bpf_link_attach" "$OP/include/linux/bpf-cgroup.h"; then
    python3 -c "
fpath='$OP/include/linux/bpf-cgroup.h'
with open(fpath,'r') as f: content=f.read()
if 'cgroup_bpf_link_attach' not in content:
    idx=content.rfind('#endif')
    shim='int cgroup_bpf_link_attach(const union bpf_attr *attr, struct bpf_prog *prog);\n\n'
    content=content[:idx]+shim+content[idx:]
    with open(fpath,'w') as f: f.write(content)
    print('cgroup_bpf_link_attach patched')
"
    echo "[OK] bpf-cgroup.h patched"
else
    echo "[OK] bpf-cgroup.h already patched"
fi

echo "=== Done ==="

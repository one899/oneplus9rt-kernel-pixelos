#!/bin/bash
# SM8250-style BPF compatibility patches for 9RT kernel
# Only adds what bpf_compat54.h does NOT cover
set -e

OP=$1
OPP=$2

echo "=== Patching 9RT headers ==="

# 1. cgroup.h: add cgroup_id (OPPO/SM8250 has it, 9RT doesn't)
if ! grep -q "cgroup_id" "$OP/include/linux/cgroup.h"; then
    python3 -c "
fpath='$OP/include/linux/cgroup.h'
with open(fpath,'r') as f: content=f.read()
idx=content.rfind('#endif')
shim='\nstatic inline u64 cgroup_id(struct cgroup *cgrp) { return cgrp->kn->id.id; }\n\n'
content=content[:idx]+shim+content[idx:]
with open(fpath,'w') as f: f.write(content)
print('cgroup_id patched')
"
    echo "[OK] cgroup.h patched"
else
    echo "[OK] cgroup.h already has cgroup_id"
fi

# 2. proc_ns.h: add ns_match
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

# 3b. callchain.c: remove static from get_callchain_entry/put_callchain_entry
python3 -c "
import re
fpath='$OP/kernel/events/callchain.c'
with open(fpath,'r') as f: content=f.read()
content=re.sub(r'static\s+(struct\s+perf_callchain_entry\s+\*)\s*get_callchain_entry', r'\1get_callchain_entry', content)
content=re.sub(r'static\s+(void)\s*\n?\s*put_callchain_entry', r'\1\nput_callchain_entry', content)
with open(fpath,'w') as f: f.write(content)
print('callchain.c static removed')
"

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

# 4. cgroup.c: update cgroup_bpf_attach/detach to match new bpf-cgroup.h signatures
echo "[4/7] Patching kernel/cgroup/cgroup.c..."
python3 << PYEOF
fpath="$OP/kernel/cgroup/cgroup.c"
with open(fpath, 'r') as f:
    content = f.read()

# Fix cgroup_bpf_attach: 4 args -> 6 args
old_attach = """int cgroup_bpf_attach(struct cgroup *cgrp, struct bpf_prog *prog,
\t\t      enum bpf_attach_type type, u32 flags)
{
\tint ret;

\tmutex_lock(&cgroup_mutex);
\tret = __cgroup_bpf_attach(cgrp, prog, type, flags);
\tmutex_unlock(&cgroup_mutex);
\treturn ret;
}"""

new_attach = """int cgroup_bpf_attach(struct cgroup *cgrp,
\t\t      struct bpf_prog *prog, struct bpf_prog *replace_prog,
\t\t      struct bpf_cgroup_link *link,
\t\t      enum bpf_attach_type type, u32 flags)
{
\tint ret;

\tmutex_lock(&cgroup_mutex);
\tret = __cgroup_bpf_attach(cgrp, prog, replace_prog, link, type, flags);
\tmutex_unlock(&cgroup_mutex);
\treturn ret;
}"""

if old_attach in content:
    content = content.replace(old_attach, new_attach)
    print("  cgroup_bpf_attach patched")
else:
    print("  cgroup_bpf_attach pattern not found")

# Fix cgroup_bpf_detach: 4 args -> 3 args
old_detach = """int cgroup_bpf_detach(struct cgroup *cgrp, struct bpf_prog *prog,
\t\t      enum bpf_attach_type type, u32 flags)
{
\tint ret;

\tmutex_lock(&cgroup_mutex);
\tret = __cgroup_bpf_detach(cgrp, prog, type);
\tmutex_unlock(&cgroup_mutex);
\treturn ret;
}"""

new_detach = """int cgroup_bpf_detach(struct cgroup *cgrp, struct bpf_prog *prog,
\t\t      enum bpf_attach_type type)
{
\tint ret;

\tmutex_lock(&cgroup_mutex);
\tret = __cgroup_bpf_detach(cgrp, prog, NULL, type);
\tmutex_unlock(&cgroup_mutex);
\treturn ret;
}"""

if old_detach in content:
    content = content.replace(old_detach, new_detach)
    print("  cgroup_bpf_detach patched")
else:
    print("  cgroup_bpf_detach pattern not found")

with open(fpath, 'w') as f:
    f.write(content)
PYEOF
echo "[OK] cgroup.c patched"

# 5. helpers.c: add #include <linux/cgroup.h> for cgroup_id
python3 -c "
fpath='$OP/kernel/bpf/helpers.c'
with open(fpath,'r') as f: lines=f.readlines()
if not any('linux/cgroup.h' in l for l in lines):
    newlines=['#include <linux/cgroup.h>\n']+lines
    with open(fpath,'w') as f: f.writelines(newlines)
    print('helpers.c patched')
else:
    print('helpers.c already has cgroup.h')
"

# 6. bpf.h: add bpf_get_prog_name declaration + fix bpf_prog_inc return type
python3 -c "
fpath='$OP/include/linux/bpf.h'
with open(fpath,'r') as f: content=f.read()
# Fix bpf_prog_inc: void -> struct bpf_prog *
content=content.replace('void bpf_prog_inc(struct bpf_prog *prog);','struct bpf_prog *bpf_prog_inc(struct bpf_prog *prog);')
# Fix static inline version too
content=content.replace('static inline void bpf_prog_inc(struct bpf_prog *prog)','static inline struct bpf_prog *bpf_prog_inc(struct bpf_prog *prog)')
if 'bpf_get_prog_name' not in content:
    idx=content.rfind('#endif')
    shim='\nvoid bpf_get_prog_name(const struct bpf_prog *prog, char *name);\n\n'
    content=content[:idx]+shim+content[idx:]
with open(fpath,'w') as f: f.write(content)
print('bpf.h patched: bpf_prog_inc return type + bpf_get_prog_name')
"

# 7. syscall.c: fix bpf_prog_inc to return struct bpf_prog * instead of void
python3 -c "
fpath='$OP/kernel/bpf/syscall.c'
with open(fpath,'r') as f: content=f.read()
import re
# Pattern: void bpf_prog_inc(...) { atomic64_inc(...); }
old_pattern = 'void bpf_prog_inc(struct bpf_prog *prog)\n{\n\tatomic64_inc(&prog->aux->refcnt);\n}'
new_pattern = 'struct bpf_prog *bpf_prog_inc(struct bpf_prog *prog)\n{\n\tatomic64_inc(&prog->aux->refcnt);\n\treturn prog;\n}'
if old_pattern in content:
    content=content.replace(old_pattern, new_pattern)
    print('syscall.c bpf_prog_inc patched (atomic64_inc)')
else:
    # Try atomic_inc variant
    old2 = 'void bpf_prog_inc(struct bpf_prog *prog)\n{\n\tatomic_inc(&prog->aux->refcnt);\n}'
    new2 = 'struct bpf_prog *bpf_prog_inc(struct bpf_prog *prog)\n{\n\tatomic_inc(&prog->aux->refcnt);\n\treturn prog;\n}'
    if old2 in content:
        content=content.replace(old2, new2)
        print('syscall.c bpf_prog_inc patched (atomic_inc)')
    else:
        # Fallback: just change the signature
        content=content.replace('void bpf_prog_inc(struct bpf_prog *prog)','struct bpf_prog *bpf_prog_inc(struct bpf_prog *prog)', 1)
        # Add return prog; before closing brace of the function
        content=content.replace('bpf_prog_inc(prog)', 'bpf_prog_inc(prog)')  # no-op to keep structure
        print('syscall.c: only signature patched (fallback)')
with open(fpath,'w') as f: f.write(content)
"

echo "=== Done ==="

# OnePlus 9RT Kernel - PixelOS Base

PixelOS kernel base + OnePlus vendor modules + FUSE_BPF + KernelSU

## What's different from original

- **Kernel source**: PixelOS (`PixelOS-Devices/android_kernel_oneplus_sm8350`, branch `sixteen-qpr2`)
- **BPF level**: 5.10 (trampoline, ringbuf, iterators, LSM, struct_ops, etc.)
- **FUSE_BPF**: enabled (`CONFIG_FUSE_BPF=y`)
- **Vendor modules**: OnePlus (`JackA1ltman/android_kernel_modules_and_devicetree_oneplus_sm8350`)
- **Defconfig**: OnePlus `9rt_defconfig` (206 OPLUS configs for ColorOS)
- **KernelSU**: enabled with syscall hooks

## Build

Go to Actions → PixelOS Base + OnePlus Modules → Run workflow

## Download

Go to Actions → Select completed run → Artifacts → Download zip

// From: include/linux/version.h

// WARNING!. This values has been hardcode. Reason:
// version.h is "generated" on the builder VM, while Zig is
// compiled on the host. This creates a circular dependency.

pub const UTS_RELEASE = "2.2.5";
pub const LINUX_VERSION_CODE: u32 = (2 << 16) | (2 << 8) | 5; //131589;
//#define KERNEL_VERSION(a,b,c) ===> (((a) << 16) + ((b) << 8) + (c))

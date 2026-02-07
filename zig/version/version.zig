// zig/version.zig
// Project225 - Replacement for init/version.c (Linux 2.2)

const std = @import("std");
const common = @import("common");

const uts = @import("uts_h.zig");
const version = @import("version_h.zig");
const compile = @import("compile_h.zig");

const UTS_LEN = 65;

// Version_LINUX_VERSION_CODE is created by the preprocesor as Version_131589.
// 131589 = (2 << 16) | (2 << 8) | 5;  (Kernel 2.2.5)
// This cannot be done with Zig. We have to use a few steps:

// This variable should be created in an external file with an script
const v: [3]u32 = .{2,2,5};
// The const's name here doesn't matter.
pub const LINUX_VERSION_CODE: u32 = (v[0] << 16) + (v[1] << 8) + v[2];

// Create a REAL variable i32 in memory.
// The linksection forces the compiler to create the var in the .data section
// like the C version. By default it will be created in .bss.
// THIS STEP IS NOT NECESSARY, THE KERNEL DOES NOT LOOK FOR THE SECTION OFFSETS:
// LOOKS FOR SYMBOLS. It's Only for learning purposes.
var version_storage: i32 
    linksection(".data") = 0;

// Let say to the compiler:
// This memory block version_storage will be called Version_131589 at linking time.
comptime {
    const version_name =
        "Version_" ++ std.fmt.comptimePrint("{}", .{LINUX_VERSION_CODE});
    @export(&version_storage, .{ 
        .name = version_name, 
        .linkage = .strong 
    });
}

// From: include/linux/utsname.h
// ABI structs
pub const new_utsname = extern struct {
    sysname: [UTS_LEN]u8,
    nodename: [UTS_LEN]u8,
    release: [UTS_LEN]u8,
    version: [UTS_LEN]u8,
    machine: [UTS_LEN]u8,
    domainname: [UTS_LEN]u8,
};

pub export var system_utsname: new_utsname = .{
    .sysname = common.fixedStringBare(UTS_LEN, uts.UTS_SYSNAME),
    .nodename = common.fixedStringBare(UTS_LEN, uts.UTS_NODENAME),
    .release = common.fixedStringBare(UTS_LEN, version.UTS_RELEASE),
    .version = common.fixedStringBare(UTS_LEN, compile.UTS_VERSION),
    .machine = common.fixedStringBare(UTS_LEN, uts.UTS_MACHINE),
    .domainname = common.fixedStringBare(UTS_LEN, uts.UTS_DOMAINNAME),
};

// const char *linux_banner =
// '*' in [*:0] => C-style pointer. Instead of [:0]
pub export var linux_banner: [*:0]const u8 =
    "Zinux version " ++ version.UTS_RELEASE ++
    " (" ++ compile.LINUX_COMPILE_BY ++ "@" ++ compile.LINUX_COMPILE_HOST ++ ") (" ++
    compile.LINUX_COMPILER ++ ") " ++ compile.UTS_VERSION ++ "\n";

// string.zig
///! Modules for string management
// Project225. By José Puga 2026

const std = @import("std");

fn fixedString(
    comptime N: usize,
    comptime s: []const u8,
    comptime use_std: bool,
) [N]u8 {
    comptime {
        if (s.len + 1 > N)
            @compileError("fixedStringStd: string too long");
    }

    var buf: [N]u8 = [_]u8{0} ** N;
    if (use_std) {
        const data = s ++ "\x00";
        std.mem.copy(u8, buf[0..data.len], data);
    } else {
        inline for (s, 0..) |c, i| {
            buf[i] = c;
        }
        // Null terminator
        buf[s.len] = 0;
    }    
    return buf;
}   

/// Fixed-size, null-terminated string with std.mem
pub fn fixedStringStd(
    comptime N: usize,
    comptime s: []const u8,
) [N]u8 { return fixedString(N, s, true);}

/// Fixed-size, null-terminated string without std
pub fn fixedStringBare(
    comptime N: usize,
    comptime s: []const u8,
) [N]u8 { return fixedString(N, s, false);}



/// vsprintf(): lib/vsprintf.c
// Temporary Zig wrapper over kernel sprintf().
// z_vsprintf(...) -> sprintf(...) -> vsprintf(...)
// This intentionally introduces extra overhead and C printf semantics.
// Goal: avoid va_list handling in Zig during the initial port.
// Can be replaced by a native Zig formatter later.
// We can implement va_list on Zig. (see README-panic.md).
extern fn sprintf( 
    buf: [*]u8, // C pointer
    fmt: [*:0]const u8,
    ...
) c_int;

// Sample of use: 
//  const s = z_vsprintf(&buf, "message: %s %d", .{ msg, code });
// WARNING: All ars must be casted to C type. c_int, c_ulong, ...
// This is not a variatic function.
pub fn z_vsprintf(
    buf: [*]u8, 
    fmt: [*:0]const u8,
    args: anytype, // (tuple). Elements should be casted to C type. 
) [*]u8 {
    //builtin to call a variadic function
    _ = @call(.auto, sprintf, .{ buf, fmt } ++ args);
    return buf;
}

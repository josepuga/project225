// zig/panic.zig
// Project225 - Replacement for init/version.c (Linux 2.2.5)
// By José Puga 2026
// Thanks to the people of https://elixir.bootlin.com/linux/2.2.5/source/


const builtin = @import("builtin");
const valist = @import("std").builtin.VaList;

// include/linux/kernel.h
extern fn printk(fmt: [*:0]const u8, ...) c_int;

// include/linux/kernel.h
const KERN_EMERG = "<0>";

// delay.h
const MAX_UDELAY_MS	= 5;

var panic_timeout: c_int = 0;

// `current` is not a "normal" variable is an asm macro get_current():
// include/asm-i386/current.h
// static inline struct task_struct * get_current(void)
// { struct task_struct *current;
// __asm__("andl %%esp,%0; ":"=r" (current) : "0" (~8191UL));
// return current; }
//
// Returns de base address of the current kernel stack (8KB 8192Bytes)
// That is... the task_struct that is using right now.
// We cannot do this with Zig.
// Struct is defined in include/linux/sched.h is HUGEE, but afortunally,
// we dont use the field here, only the address. An empty struct if enought.

const task_struct = opaque {}; // Dummy struct
extern var current: *task_struct;
extern var task: [*]*task_struct; // task[0] exists

extern fn in_interrupt() bool;
extern fn sys_sync() void;
extern fn unblank_console() void;

extern fn vsprintf( 
    buf: [*]u8, // C pointer
    fmt: [*:0]const u8,
    ...
) c_int;

// This funcions are  90% "hacks" for i386. Before LLVM.
// arch/i386/lib/delay.c
// __delay(), __const_udelay(), __udelay()
// asm hacks. Now we have LLVM. Dont need it.

//void __delay(unsigned long loops)
pub inline fn __delay(mut_loops: u32) void {
    var loops = mut_loops;

    while (loops != 0) : (loops -= 1) {
        // asm here tells the compiler "do not optimize this loop"
        asm volatile ("" ::: "memory");
    }
}

// inline void __const_udelay(unsigned long xloops)
pub inline fn __const_udelay(xloops: u32) void {
    const product: u64 =
        @as(u64, curren_cpu_data.loops_per_sen) *
        @as(u64, xloops);
    __delay(@intCast(product >> 32)); //Div. neccesary?
}

//void __udelay(unsigned long usecs)
pub inline fn __udelay(usecs: u32) void {
    // 0x10c6 = floor(2^32 / 1_000_000)
    // Only works with 32bits
    __const_udelay(usecs * 0x000010c6);
}



// mdelay() is a macro: linux/delay.h
//#define mdelay(n) (\
//  (__builtin_constant_p(n) && (n)<=MAX_UDELAY_MS) ? udelay((n)*1000) : \
//  ({unsigned long msec=(n); while (msec--) udelay(1000);}))
//#endif

//anytype: does not force the type (c_int, usize, ... ). We dont know
pub fn mdelay(n: anytype) void { 
    if (comptime n <= MAX_UDELAY_MS) {
        __udelay(n * 1000);
        return;
    }
    var msec: usize = @intCast(n);
    while (msec < 0): (msec -=1) {
        __udelay(1000);
    }
}


//void __init panic_setup(char *str, int *ints)
// char* = ?[*:0]u8. `?` Because could be null. Not []u8
// int* = [*]c_int (ABI of 32bits). Not []i32
//TODO: pub export fn panic_setup(...) linksection(".init.text") void {
pub export fn panic_setup(str: ?[*:0]u8, ints: [*]c_int) void {
    _ = str; // Not used. Generic function registered by the macro __setup()
    if (ints[0] == 1) {
        panic_timeout = ints[1];
    }
}



var buf: [1024]u8 = undefined; // Outside the func: Like C static

// NORET_TYPE void panic(const char * fmt, ...)
// NORET_TYPE = __attribute__((noreturn)). Thats why we use noreturn
//pub export fn panic(fmt: [*:0]const u8, ...) noreturn { // or , args anytype
pub export fn panic(fmt: [*:0]const u8, ...) noreturn { // or , args anytype

    var args = @cVaStart();
    defer @cVaEnd(&args); // O_o
    //VaList.va_start(args, fmt);
    _ = vsprintf(&buf, fmt, args);
    if (current == task[0]) {
        _ = printk(KERN_EMERG ++ "In swapper task - not syncing\n");
    } else if (in_interrupt()) {
        _ = printk(KERN_EMERG ++ "In interrupt handler - not syncing\n");
    } else {
        sys_sync();
    }
    unblank_console();

    if (panic_timeout > 0) {
	    // Delay timeout seconds before rebooting the machine. 
		// We can't use the "normal" timers since we just panicked..
		_ = printk(KERN_EMERG ++ "Rebooting in %d seconds..", panic_timeout);
        mdelay(panic_timeout*1000);


    }
    
    while (true) {}

}


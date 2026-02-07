# Project225 — Zig Usage Policy (Draft)

## 1\. Principio fundamental

En Project225, Zig se utiliza exclusivamente como:

> Lenguaje de generación de código estático para entorno kernel legacy.

Zig **no es** un runtime.  
Zig **no es** una plataforma.  
Zig **no gestiona recursos del sistema**.

Todo recurso pertenece al kernel 2.2.x.

* * *

## 2\. Entorno objetivo

| Componente | Valor |
| --- | --- |
| Kernel | Linux 2.2.x |
| Arch | i386 |
| libc | glibc 2.1 / 2.2 |
| Toolchain | GCC ~1999–2001 |
| Runtime | Kernel space / early userspace |

Por tanto:

-   No TLS    
-   No pthread    
-   No mmap moderno    
-   No syscalls recientes    
-   No ELF extensions
    

* * *

## 3\. Subconjunto de Zig permitido

### 3.1. Lenguaje base (100% permitido)

Todo lo siguiente está autorizado:

- `struct`, `union`, `enum`    
- `packed struct`    
- `comptime`    
- `@intCast`, `@ptrCast`, `@bitCast`    
- `@sizeOf`, `@alignOf`    
- generics    
- error unions    
- slices    
- pointers
    
Esto se traduce a C/ASM puro.

* * *
### 3.1 std permitido

std.mem (completo)
copy
set
zeroes
eql
swap

Prohibido:
allocator
interfaces

std.math (parcial)
Permitido:
min
max
abs
clamp

Prohibido:
float heavy ops
transcendentals

std.fmt (restringido)  --> ???
    en compile-time
    generación de tablas
    debug temporal
Prohibido en runtime.

std.debug (solo en desarrollo)

Permitido:

pgsql
Copy code
assert
panic (debug only)

Eliminar antes de producción.
### 3.2 std prohibido

Nunca usar:

|Módulo	|Motivo|
|---|---|
|std.os	|Syscalls modernas|
|std.fs	|POSIX moderno|
|std.net |No soportado|
|std.Thread	|pthread/TLS|
|std.heap	|VM/mmap|
|std.process |fork/exec|
|std.crypto	|CPU nueva|
|std.time |clock syscalls|

#### Gestión de memoria permitido
Memoria pasada desde C/kernel:
- pub export fn foo(buf: []u8)
- buffers estáticos:
    - var table: [1024]u8 = undefined;

#### Gestión de memoria prohibido
- std.heap.page_allocator
- std.heap.c_allocator
- ArenaAllocator

#### Si necesitas heap

Debe venir del kernel y envolverlo tú:
- extern fn kmalloc(size: usize) ?*u8;
- extern fn kfree(ptr: *u8) void;

#### IO y sistema
Todo IO va por C. Nunca por std.
- extern fn printk(fmt: [*]const u8, ...) void;

## 4\. Build constraints
### Compilación

Siempre:
- -fno-pie
- -fno-pic
- -m32
- -no-pie

Zig debe producir objetos, no ejecutables:
- ABI
- cdecl
- SysV i386
- no red zone
- no SSE

Runtime prohibido

No usar:
- defer con heap
- async/await
- coroutines
- reflection runtime
- dynamic dispatch

### Patrón arquitectónico recomendado
Zig nunca cruza al SO directamente:

[ Kernel / C ] --> [ABI boundary] --> [ Zig logic layer ]

### Checklist antes de integrar código Zig
Antes de merge:

- No std.os/fs/net    
- No allocator    
- No threads    
- No mmap    
- Solo ET\_REL    
- Enlaza con gcc antiguo    
- Arranca en tester


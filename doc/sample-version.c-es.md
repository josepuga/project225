### PRUEBA DE CONCEPTO: version.c

Aquí voy a explicar paso a paso cómo he generado el objeto de la versión zig del fichero `init/version.c` y la compilación del mismo junto con el resto del kernel. **Es conveniente hacer todo paso a paso conforme vas leyendo**.

> Primero quiero aclarar que no soy ningún experto en Zig. Como ya comenté, este es un proceso de aprendizaje. Seguramente haya formas más eficientes de programar en Zig, mi intención es servir de guía para tus futuras compilaciones.

>Kernel sources are treated as immutable artifacts.
All modifications are performed via object file injection.

### Preparar el Setup

Aconsejo trabajar cada VM (máquina virtual) en una pestaña de tu consola favorita, es más cómodo que teclear en la ventana de QEMU. Voy a usar 3 ubicaciones (o pestañas) y me voy a referir a ellas a partir de ahora como:

- `host`: Tu PC donde tienes Linux, tu editor favorito y las librerías de desarrollo para compilar Zig.
- `builder`: La VM que compilará el kernel y lo enviará a `tester` para probarlo.
- `tester`: La VM que lanzará el nuevo kernel compilado.

## Lanzamos las VM

En `builder`

```bash
/path/to/project255/bin/run-vm.sh builder
```

En `tester`

```bash
/path/to/project255/bin/run-vm.sh tester
```

En ambas VM el usuario es root sin password

> NOTA: si quieres trabajar sin pestañas, directamente desde las VM, edita la linea de `bin/run-vm.sh` y pon `host_shell=0`

## Preparando host

Los fuentes del kernel están en `builder` en `/usr/src/linux` y los comparte mediante NFSv3. Asegúrate de que está la VM en funcionando antes de seguir.

```bash
cd /patch/to/project255
# Montamos los fuentes del kernel de builder
# Esto monta los fuentes en kernel-shared/.
bin/mount-linux-src.sh
ls kernel-shared  # Para asegurarnos
```

## Empezando

Ya tenemos el setup listo. Ahora debemos usar un directorio dentro de `zig/`, por organización, conviene que coincida con el nombre del "módulo" que quieras compilar, en este caso es `version`. Asumimos que usas VSCode.

>NOTA: El directorio y todos los ficheros del tutorial están ya creados, bórralos para empezar de cero.

```bash
cd zig/version && rm *
code .
```

Desde nuestro editor:

- Creamos un `version.zig`
- Abrimos `kernel-share/init/version.c`.

> TIP: Si quieres abrir de forma rápida un fichero al que apunta version.c, por ejemplo, en la linea

```c
#include <linux/version.h>
```

> Haz CTRL-click en version.h y te lo abrirá directamente en una nueva pestaña

### version.c

```c
#include <linux/uts.h>
#include <linux/utsname.h>
#include <linux/version.h>
#include <linux/compile.h>

#define version(a) Version_ ## a
#define version_string(a) version(a)

int version_string(LINUX_VERSION_CODE) = 0;

struct new_utsname system_utsname = {
	UTS_SYSNAME, UTS_NODENAME, UTS_RELEASE, UTS_VERSION,
	UTS_MACHINE, UTS_DOMAINNAME
};

const char *linux_banner =
	"Linux version " UTS_RELEASE " (" LINUX_COMPILE_BY "@"
	LINUX_COMPILE_HOST ") (" LINUX_COMPILER ") " UTS_VERSION "\n";
```

El codigo es simple a primera vista. La primera parte

```c
#define version(a) Version_ ## a
#define version_string(a) version(a)

int version_string(LINUX_VERSION_CODE) = 0;
```

Es más complicada de lo que parece ya que este código se genera en tiempo de compilación, lo cual no puede hacerse con Zig.

El resto es una estructura y una cadena que coge valores de los headers.

## Recrear los headers en Zig

Para facilitar la vida, he creado un script en python que convierte los diferentes headers de C, en ficheros Zig.

- genera un `headername_h.zig` por cada `headername.h`
- Respeta los comentarios de una linea.
- `#define` de cadenas los convierte en `pub const "value"`.
- `#define` numericos los convierte en `pub const value`.
- `#define` de macros los copia como comentarios en `headername_macros_h.zig`

No es una herramienta perfecta y tiene sus limitaciones:

- Ignora cualquier tipo de variable.
- No procesa comentarios multilinea `/* */`, aunque el fichero es funcional, pierdes dichos comentarios.
- No expande macros.
- `#define NAME` sin valor se comentan sin procesar.
- No procesa `#ifdef /#ifndef`, tan sólo los comenta en su posición para que lo puedas hacer tú manualmente.
- No procesa otros `#include` aunque los comenta. Debes seguir la recursión manualmente

> A pesar de sus limitaciones ahorra muchísimo tiempo.

Vamos a generar los diferentes header que usa `version.c`

```bash
# Asumimos que estamos en zig/version y project225/bin NO está en tu PATH
../../bin/h2zig.py ../../kernel-shared/include/linux/version.h
../../bin/h2zig.py ../../kernel-shared/include/linux/uts.h
../../bin/h2zig.py ../../kernel-shared/include/linux/utsname.h
```

### El primer escollo

Tenemos un problema con `compile.h`. Este fichero se genera al compilar el kernel en `builder`, mientras que Zig lo compila en `host`. Esto crea una dependencia circular.

> Estos ficheros en nuevos kernels se encuentran dentro de `include/generated/`. Desafortunadamente con el 2.2.x se generan todos en el mismo sitio.

La forma de tratar con ello es hacerlo manualmente como se muestra más adelante.

> TIP: La primera vez o si has hecho un `make clean`, no tendrás `compile.h`. Desde `builder`, para compilar el kernel y generarlo ejecuta: `make.sh`. Elimina cualquier `.o` que hubiera en `kernel-shared/zig/` si quieres compilar un kernel "puro linux".

### "Pulir los headers"

```bash
$ ls *_h.zig
uts_h.zig
utsname_h.zig
version_h.zig
version_macros_h.zig
```

Es importante destacar que **no tienes que procesar todo el contenido de los headers**, tan sólo utiliza lo que esté utilizando tu `.c` en el código.

**Compara siempre el header C original con el Zig generado.**

#### compile_h.zig

```javascript
// From: include/linux/compile.h

// WARNING!. This values has been hardcode. Reason:
// compile.h is "generated" on the builder VM, while Zig is
// compiled on the host. This creates a circular dependency.

pub const UTS_VERSION = "Any day of the year 2026";
pub const LINUX_COMPILE_TIME = "00:00:00";
pub const LINUX_COMPILE_BY = "root";
pub const LINUX_COMPILE_HOST = "builder";
pub const LINUX_COMPILE_DOMAIN = "";
pub const LINUX_COMPILER = "gcc version 2.95.3 20010315 (release)";
```

**Hay que crearlo manualmente** como se explicó anteriormente, son cadenas de texto que no afectan al comportamiento interno. Es texto informativo como por ejemplo al hacer `uname -a`.

`version.c` usa estos valores:

```c
// version.c
//(...)
struct new_utsname system_utsname = {
	UTS_SYSNAME, UTS_NODENAME, UTS_RELEASE, UTS_VERSION,
	UTS_MACHINE, UTS_DOMAINNAME
};

const char *linux_banner =
	"Linux version " UTS_RELEASE " (" LINUX_COMPILE_BY "@"
	LINUX_COMPILE_HOST ") (" LINUX_COMPILER ") " UTS_VERSION "\n";
//(...)
```

### uts_h.zig

```javascript
// AUTO-GENERATED from include/linux/uts.h
// DO NOT EDIT MANUALLY

// #ifndef _LINUX_UTS_H
// #ifndef UTS_SYSNAME
pub const UTS_SYSNAME = "Zinux";
// #endif
// #ifndef UTS_MACHINE
pub const UTS_MACHINE = "i386";
// #endif
// #ifndef UTS_NODENAME
pub const UTS_NODENAME = "(none)";
// #endif
// #ifndef UTS_DOMAINNAME
pub const UTS_DOMAINNAME = "(none)";
// #endif
// #endif
```

Este también es muy fácil, en el mismo contexto, cadenas de texto que no influyen en el código. Yo he cambiado `"Linux"` por `"Zinux"` para comprobar que todo ha funcionado al arrancar el nuevo kernel y consultar la versión.

#### utsname_h.zig

```javascript
// AUTO-GENERATED from include/linux/utsname.h
// DO NOT EDIT MANUALLY

// #ifndef _LINUX_UTSNAME_H
pub const __OLD_UTS_LEN = 8;
pub const __NEW_UTS_LEN = 64;
// #endif
```

Aquí el header Zig no nos sirve, se puede borrar ya que los valores `___*_UTS_LEN` no se usan directamente (en realidad `__NEW_UTS_LEN` hay que tenerlo en cuenta, pero lo veremos luego). No obstante, `utsname.h` sí tiene código a convertir.

`version.c` usa la estructura `new_utsname` que se encuentra en `utsname.h` definida como:

```c
// utsname.h
//(...)
struct new_utsname {
	char sysname[65];
	char nodename[65];
	char release[65];
	char version[65];
	char machine[65];
	char domainname[65];
};
//(...)
```

Más adelante definiremos dicha estructura en Zig. Esto es lo único importante de `utsname.h`

#### version_h.zig

```javascript
// AUTO-GENERATED from include/linux/version.h
// DO NOT EDIT MANUALLY

pub const UTS_RELEASE = "2.2.5";
pub const LINUX_VERSION_CODE = 131589;
```

Parece simple, pero aquí tenemos otra de las "triquiñuelas" del toolchain del kernel 2.2. Ese valor de `LINUX_VERSION_CODE` lo usará el preprocesador para crear una variable llamada `Version_131589`. Hay que imitar esto en Zig.

#### version_macros_h.zig

```javascript
// AUTO-GENERATED MACROS FROM version.h
// REVIEW AND PORT MANUALLY

// line 3: #define KERNEL_VERSION(a,b,c) (((a) << 16) + ((b) << 8) + (c))
```

Esta macro indica cómo se genera ese valor "131589". Nos interesa la aritmética binaria que usa. Podemos eliminar `version_macros_h.zig`, copiamos la linea de la macro a nuestro `version.zig` como comentario para tenerla en cuenta.

## Ahora sí, generamos código :)

### struct new_utsname

Ya tenemos una "visión global" de qué hace y usa `version.c`. Incluimos los headers

```javascript
const uts = @import("uts_h.zig");
const version = @import("version_h.zig");
const compile = @import("compile_h.zig");
```

Tenemos que definir la estructura new_utsname que está en `utsname.h`

```c
// utsname.h
//(...)
struct new_utsname {
	char sysname[65];
	char nodename[65];
	char release[65];
	char version[65];
	char machine[65];
	char domainname[65];
};
//(...)
```

Si te fijas en el valor `65` no es otro que `__NEW_UTS_LEN` (+1 para el `\0`). Aquí lo han "harcodeado" directamente, por eso decía que no hacía falta guardar el fichero `utsname_h.zig` para una sóla variable. Podemos crear una constante y ponerle 65 directamente para abreviar.

```javascript
// version.zig
const UTS_LEN = 65;
pub const new_utsname = extern struct {
    sysname: [UTS_LEN]u8,
    nodename: [UTS_LEN]u8,
    release: [UTS_LEN]u8,
    version: [UTS_LEN]u8,
    machine: [UTS_LEN]u8,
    domainname: [UTS_LEN]u8,
};
```

Esto define la estructura igual que la de C.

### Strings C != Strings Zig

La variable system_utsname del tipo struct new_utsname se crea e inicializa.

```c
// version.c
struct new_utsname system_utsname = {
	UTS_SYSNAME, UTS_NODENAME, UTS_RELEASE, UTS_VERSION,
	UTS_MACHINE, UTS_DOMAINNAME
};
```

La conversión a Zig es directa porque ya tenemos definida la estructura

```javascript
pub export var system_utsname: new_utsname = .{
    .sysname = uts.UTS_SYSNAME,
    .nodename = uts.UTS_NODENAME,
    .release = version.UTS_RELEASE,
    .version = compile.UTS_VERSION,
    .machine = uts.UTS_MACHINE,
    .domainname = uts.UTS_DOMAINNAME,
};
```

¿Fácil no?. No tan deprisa. Aquí nos topamos con una gran diferencia entre C y Zig. En C, el compilador rellena estos valores con \0 hasta rellenar los 65 bytes. No guarda puntero, ni longitud ni metadata.

En nuestro ejemplo `.machine = "i386"`. Esto C lo guarda como un `char[65]`:

```c
'i' '3' '8' '6' '\0' 0 0 0 0 0 ...
```

Hasta llegar a 65.

Pero Zig lo trata diferente, .machine se guarda como `*const [4:0]u8`:

```c
'i' '3' '8' '6' '\0'
```

Zig trata los literales como arrays null-terminated, no como buffers fijos. Es decir, no rellena con ceros. Tenemos que tener crear compatiblidad ABI. En este caso en concreto, seguramente el programa funcione, pero es muy arriesgado especialmente en el kernel, dejar una cadena con una longitud inferior: **Lectura de memoria sin inicializar/comportamiento indefinido**.

Para solucionar esto, he creado una función en common.zig (dentro de `zig/_common_modules`) que convierte esa cadena en un array fijo de N longitud. He implementado 2 funciones que hacen lo mismo.

- common.fixedStringStd: Usa `std.mem.copy()`
- common.fixedStringBare: No utiliza `std`

> ¿Porqué 2?. No sé si algún momento puede generar problemas el uso de std.mem.copy(). Por si acaso he dejado una opción libre de std.

Con dicha modificación, el código quedaría así

```javascript
// version.zig
// (...)
const common = @import("common");
// (...)
const UTS_LEN = 65;
pub export var system_utsname: new_utsname = .{
    .sysname = common.fixedStringBare(UTS_LEN, uts.UTS_SYSNAME),
    .nodename = common.fixedStringBare(UTS_LEN, uts.UTS_NODENAME),
    .release = common.fixedStringBare(UTS_LEN, version.UTS_RELEASE),
    .version = common.fixedStringBare(UTS_LEN, compile.UTS_VERSION),
    .machine = common.fixedStringBare(UTS_LEN, uts.UTS_MACHINE),
    .domainname = common.fixedStringBare(UTS_LEN, uts.UTS_DOMAINNAME),
};
```

### linux_banner

Esta variable es usada para mostrar información del kernel en `main.c` y `fs/proc/array.c`.

```c
// version.c
const char *linux_banner =
	"Linux version " UTS_RELEASE " (" LINUX_COMPILE_BY "@"
	LINUX_COMPILE_HOST ") (" LINUX_COMPILER ") " UTS_VERSION "\n";
```

El equivalente Zig:

```javascript
// version.zig
// (...)
// '*' in [*:0] => C-style pointer. Instead of [:0]
pub export var linux_banner: [*:0]const u8 =
    "Zinux version " ++ version.UTS_RELEASE ++
    " (" ++ compile.LINUX_COMPILE_BY ++ "@" ++ compile.LINUX_COMPILE_HOST ++ ") (" ++
    compile.LINUX_COMPILER ++ ") " ++ compile.UTS_VERSION ++ "\n";
```

Bien, parece que tenemos todo terminado, hemos puesto `Zinux` y supuestamente ya está todo. ¿o no?.

## Primera compilación

Antes de nada hay que añadir la siguiente linea (si no está ya) a `zig/objects.txt`. 

>NOTA: `zig/` se refiere a la ruta del kernel `/usr/src/linux/zig` no el `zig/` del host donde tenemos nuestros fuentes Zig.

```
init/version.o:zig/version.o
```

`compile.sh` lee ese fichero y generará el Makefile necesario para que los `.o` de Zig tengan preferencia sobre los de C. Esto está automatizado, tan sólo tienes que añadir la linea del fichero objeto C y Zig en los que trabajas en `zig/objects.txt`.

Compilar Zig no es tan sencillo como en otros lenguajes (Al menos para mi con mis conocimientos actuales). He creado un script en bash que automiza el proceso:
- Genera un `build.zig` temporal.
- Compila el fichero fuente.
- Copia el fichero .o generado a `kernel-shared/zig/`.
- Genera un Makefile que le dice al toolchain de C, que incluya nuestro `.o` en lugar del de C.
 
```bash
../../bin/compile.sh version.zig
```

Salida:

```
Generating build.zig...
Compiling version.o...
Cleaning...

/path/to/kernel-shared/zig/version.o created!
00000000 r __anon_517
00000188 D linux_banner
00000000 D system_utsname
```

### Comprobar ambos ABI

¡Parece que compiló sin problemas y ya podemos generar nuestro primer kernel Zinux!. No tan rápido. Las últimas lineas de las salida son del comando `nm` de la shell para ver la tabla de símbolos del fichero objeto.

Para asegurar compatibilidad binaria, hay que comprobarlo con la tabla que muestra `init/version.o` del kernel.

> TIP: Si aún no tienes `init/version.o`, haz una compilación del kernel en `build` con `make.sh`. Elimina antes `kernel-shared/zig/version.o` si estuviera.

```bash
nm /path/to/kernel-shared/init/version.o
```

```
00000000 D Version_131589
00000000 t gcc2_compiled.
000001a8 D linux_banner
00000020 D system_utsname
```

¡Que decepción!. Calma. Pensemos en lo positivo,`linux_banner` y `system_utsname` coinciden en nombre y sección `.data` (la D). No importa que el offset no coincida, el kernel no mira offsets, sino símbolos.

Vamos a examinar las otras 2 lineas paso a paso.

#### 00000000 t gcc2_compiled.

Esto es un símbolo generado de gcc 2.x. la `t` minúscula indica que es local y static en la sección `.text`

No afecta en nada. El compilador de Zig genera ese valor "basura" local, aunque en la secciones read only como `.rodata` (en este caso). ignorar.

#### 00000000 D Version_131589

Aquí ya estamos entrando en las artimañas y subterfugios del preprocesador del kernel. En importante entender que esta variable **_se genera por el preprocesador de C_**. No es que tenga ningún valor, sino que el valor real es irrelevante, importa el nombre: `Version_131589`. Es una forma bizarra de decir `Version = 131589` bienvenido al mundo del kernel 2.2.

¿Pero dé donde sale ese número?. Volvemos al código fuente de C que nos da la pista:

```c
// version.c
// (...)
#define version(a) Version_ ## a
#define version_string(a) version(a)

int version_string(LINUX_VERSION_CODE) = 0;
// (...)


// version.h
#define UTS_RELEASE "2.2.5"
#define LINUX_VERSION_CODE 131589
#define KERNEL_VERSION(a,b,c) (((a) << 16) + ((b) << 8) + (c))
```

131589 viene de hacer la siguiente operación de aritmética binaria con la versión del kernel `2.2.5` tal y como muestra la macro `KERNEL_VERSION(a,b,c)`

```c
a = 2, b = 2, c = 5
Number = ((a) << 16) + ((b) << 8) + (c))
```

Hay 2 formas de solucionar esto.

##### La opción fácil, pastilla azul

Crear una variable con ese nombre:

```javascript
pub export var Version_131589: i32 = 1;
```

Hay un detalle importante, si tiene un valor 0, el compilador lo guardará en la sección Block Started by Symbol `.bss (B)` en lugar de `.data (D)`. `.bss` funciona exactamente igual que `.data` pero para variables no inicializadas. **Esto no afecta al kernel**, pero yo prefiero tenerlo en `.data`.

El problema de este planteamiento de variable "hardcodeada" es que si cambiaras de versión de kernel, tendrías que acordarte y cambiar manualmente el valor volviendo a calcular `KERNEL_VERSION()`.

> Si te conformas con esto, no pasa nada, pones esa linea, te levantarás mañana en tu cama y creerás lo que quieras creer.

#### La opción difícil, pastilla roja

Está la opción difícil, la que si estás leyendo esto eligirás seguramente, porque quieres **_aprender a hacer las cosas correctamente_**.

Primero debemos hacer un código versátil que sirva para cualquier versión del kernel y nos calcule el número. Esta variable "v" se podría generar en un script, o un proceso externo dependiendo de la versión del kernel. Para este ejemplo la colocamos en el código directamente.

```javascript
// This v variable should be created in an external file
const v: [3]u32 = .{2,2,5};
// The const's name here doesn't matter.
pub const LINUX_VERSION_CODE: u32 = (v[0] << 16) + (v[1] << 8) + v[2];

```

El **nombre de la variable no es importante**, he eligido `LINUX_VERSION_CODE` por afinidad con el código de C, pero puedes llamarlo `foo` si quieres.

Ahora hay que crear una variable que se llame "Version_" + LINUX_VERSION_CODE, es decir `Version_131589`.

```javascript
// var! not const
var version_storage: i32
    linksection(".data") = 0;
```

Variable necesaria (ver abajo), y otra forma de forzar a asignar la sección data con un valor 0, es usar `linksection()`. Aquí tampoco importa el valor de version_storage, usa el método que prefieras si deseas ponerlo en `.data`:

- Valor 0 usando linksection(".data")
- Valor != 0

Ahora tenemos que decirle al compilador de Zig: _"Este bloque de memoria ``version_storage`, se llamará `Version_131589` en el linkado"_.

```javascript
comptime {
    const version_name =
        "Version_" ++ std.fmt.comptimePrint("{}", .{LINUX_VERSION_CODE});
    @export(&version_storage, .{
        .name = version_name,
        .linkage = .strong});
}
```

- Creamos una constante version_name = "Version_131589"
- Exportamos version_storage al linkado y le ponemos el famoso nombre `Version_131589`.

### Código y compilación final

El código de `version.zig` debería ser este.

```javascript
const std = @import("std");
const common = @import("common");

const uts = @import("uts_h.zig");
const version = @import("version_h.zig");
const compile = @import("compile_h.zig");

const v: [3]u32 = .{2,2,5};
pub const LINUX_VERSION_CODE: u32 = (v[0] << 16) + (v[1] << 8) + v[2];


var version_storage: i32
    linksection(".data") = 0;
comptime {
    const version_name =
        "Version_" ++ std.fmt.comptimePrint("{}", .{LINUX_VERSION_CODE});
    @export(&version_storage, {
        .name = version_name,
        .linkage = .strong
    });
}

const UTS_LEN = 65;
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

pub export var linux_banner: [*:0]const u8 =
    "Zinux version " ++ version.UTS_RELEASE ++
    " (" ++ compile.LINUX_COMPILE_BY ++ "@" ++ compile.LINUX_COMPILE_HOST ++ ") (" ++
    compile.LINUX_COMPILER ++ ") " ++ compile.UTS_VERSION ++ "\n";

```

Si volvermos a compilar, ahora sí, coincide el ABI de ambos objetos.

```
00000000 r __anon_517
00000188 D linux_banner
00000000 D system_utsname
00000000 D Version_131589
```

## Comprobar que funciona

### Compilar el kernel

En builder ejecutamos `make.sh` para que compile el kernel. Si todo ha ido bien, veremos el OK final

```
Running: make bzImage to log/make-bzImage.log
Done: make bzImage

Running: make modules to log/make-modules.log
Done: make modules

Running: make modules_install to log/make-modules_install.log
Done: make modules_install

  ZIG:   init/version.o -> init/version.c

OK
```

### Probar el kernel en tester

`tester` es un Slackware 7.1. Distro contemporánea al kernel 2.2. No habrá problemas de compabilidad, por eso la elegí.

En `tester` tengo un script que se queda esperando a que `builder` le envíe el kernel. Lo instala y reinicia arrancando con él.

Teclea:

```bash
watch-deploy.sh
```

El programa se queda en espera a recibir el kernel.

Ahora desde `builder`:

```bash
deploy.sh
```

En pocos segundos `tester` mostrará mensaje:

```
DEPLOY trigger detected!
Calling install-kernel.sh
Copying vmlinuz-test to /boot...
Installing kernel modules...
Configuring LILO and Rebooting...
```

Se reiniciará la VM. ahora desde la shell, se puede comprobar que estamos con nuestro "Zinux" :)

>Elegir `version.c` como conversión inicial nos permite comprobar rápidamente si nuestro kernel funciona antes de comenzar con cosas más complicadas.

Hay varias formas de mostrar la variable `linux_banner` que definimos:

```bash
root@tester[127]:~# uname -a
Zinux tester 2.2.5 Any day of the year 2026 i?86 unknown
root@tester[0]:~# dmesg | head -n 1
Zinux version 2.2.5 (root@builder) (gcc version 2.95.3 20010315 (release)) Any day ...
root@tester[0]:~# cat /proc/version
Zinux version 2.2.5 (root@builder) (gcc version 2.95.3 20010315 (release)) Any day ...
```

<img src="zinux-1.png" alt="logo" style="width:500px;"/> 
<img src="zinux-2.png" alt="logo" style="width:500px;"/>

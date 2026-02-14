# Zig Implementation: `panic.c`

Objetivo: cambiar el mensaje `Kernel panic: %s\n` por `Zernel panic:%s\n`. Para comprobar funcionamiento.

## Primeros pasos
Antes de seguir, necesitamos una forma determinista de generar un `Kernel Panic` (KP) en el sistema. Para probar nuestra función.

He creado un script `vm/builder-scripts/make-kernel-panic-mod.sh`. Tan sólo hay que copiarlo a `builder` y ejecutarlo desde él. Nos generará el `panic.o` en el directorio deploy de `tester`.

A partir de ahora, cada vez que queramos provocar un KP, en `tester` tan sólo tenemos que hacer:

```bash 
insmod /mnt/deploy/panic.o
```


## panic_setup()


```c
int panic_timeout = 0;

void __init panic_setup(char *str, int *ints)
{
	if (ints[0] == 1)
		panic_timeout = ints[1];
}
```

Podemos ignorar la macro `__init`. Aparece en `include/linux/init.h` como
```c
#define __init
```
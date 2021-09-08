# Debug coredump'ов Rust-приложений

В этом репозитории собраны примеры на которых можно потренироваться с диагностикой core-dump'ов из под Rust приложений.
Rust эксплуатирует те же идиомы что и C/C++. Поэтому, практики диагностики для этих языков практически эквивалентны.

Coredump – это состояние памяти процесса в момент аварийного останова (аналог Heapdump'а в терминах Java). Имея его,
а также сам исполняемый файл с отладочными символами, мы можем полноценно использовать отладчик для инспекции состояния
в момент аварийного останова.

## Debug/Release сборка

Для испекции coredump-файла требуется исполняемый файл с отладочными символами. Включение отладочных символов в release
сборке делается следующим образом в `Cargo.toml`:

```toml
[profile.release]
debug = 2
```

Исполняемый файл при этом сильно вырастет в размере. Поэтому, нередко release-артефакт делуют двух версий:

1. stripped – который не содержит отладочных символов и используется в production;
2. unstripped – содержит отладочные символы и используется для диагностики в случае проблем с приложением.

Для того чтобы получить stripped исполняемый файл из обыкновенного достаточно обработать его одноименной командой:

```
$ du -sh target/release/examples/core-dump
3.3M    target/release/examples/core-dump

$ strip target/release/core-dump

$ du -sh target/release/examples/core-dump
272K    target/release/examples/core-dump
```

Как видим, файл значительно уменьшился в размере.

Проверить с каким файлом вы имеете дело можно используя команду `file`:

```
$ file target/release/examples/core-dump
target/release/examples/core-dump: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=9df5db34a93065b305b20bf6e9239cc55189e86f, for GNU/Linux 4.4.0, with debug_info, not stripped

$ file target/release/examples/core-dump-stripped
target/release/examples/core-dump-stripped: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=9df5db34a93065b305b20bf6e9239cc55189e86f, for GNU/Linux 4.4.0, stripped
```

(см. `with debug_info, not stripped`)

## Как читать coredump

Допустим, приложение упало в production-окружении. Нам требуется:

1. сам coredump;
1. терминальный доступ к машине с той же ОС (Linux), а также установленным toolchain'ом Rust;
1. исполняемый файл с отладочными символами.

Команда `rust-gdb ./path/to/app ./path/to/coredump` запустит debugger и укажет где произошел аварийный останов.

Как модельный пример можно запустить `make gdb` из корня этого проекта. Этот пример полагается на то что
coredump файлы создаются ОС по пути `/var/lib/systemd/coredump` и сжаты с `zstd`.

```
$ make gdb
Reading symbols from target/release/examples/core-dump...

warning: core file may not match specified executable file.
[New LWP 3222499]
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/usr/lib/libthread_db.so.1".
Core was generated by `target/release/examples/core-dump-stripped'.
Program terminated with signal SIGABRT, Aborted.
#0  0x00007f17648ccd22 in raise () from /usr/lib/libc.so.6
(gdb) bt
#0  0x00007f17648ccd22 in raise () from /usr/lib/libc.so.6
#1  0x00007f17648b6862 in abort () from /usr/lib/libc.so.6
#2  0x000055c9cd80b967 in std::sys::unix::abort_internal () at library/std/src/sys/unix/mod.rs:206
#3  0x000055c9cd7f7b76 in std::process::abort () at library/std/src/process.rs:1814
#4  0x000055c9cd7f96ce in core_dump::some_func () at examples/core-dump.rs:19
#5  core_dump::main () at examples/core-dump.rs:14
(gdb) 
```

Здесь мы видим что аварийный останов произошел в `core_dump::some_func()`. Мы можем происпектировать
значения локальных переменных на любом уровне стека:

```
(gdb) frame 5
#5  core_dump::main () at examples/core-dump.rs:14
14          some_func();
(gdb) info locals
map = HashMap(size=2) = {[1] = "One", [2] = "Two"}
Python Exception <class 'gdb.error'> value has been optimized out:
dropped_vector = Vec(size=3)
v = Vec(size=3) = {1, 2, 3}
s_copy = "Some string"
s = <error reading variable>
```

## Полезные команды gdb

Вывод списка потоков:

```
(gdb) info threads
  Id   Target Id                           Frame
* 1    Thread 0x7f176488ec00 (LWP 3222499) 0x00007f17648ccd22 in raise () from /usr/lib/libc.so.6
```

Backtrace текущего потока

```
(gdb) bt
#0  0x00007f17648ccd22 in raise () from /usr/lib/libc.so.6
#1  0x00007f17648b6862 in abort () from /usr/lib/libc.so.6
#2  0x000055c9cd80b967 in std::sys::unix::abort_internal () at library/std/src/sys/unix/mod.rs:206
#3  0x000055c9cd7f7b76 in std::process::abort () at library/std/src/process.rs:1814
#4  0x000055c9cd7f96ce in core_dump::some_func () at examples/core-dump.rs:19
#5  core_dump::main () at examples/core-dump.rs:14
```

Выбор фрейма

```
(gdb) frame 5
#5  core_dump::main () at examples/core-dump.rs:14
14          some_func();
```

Вывод списка всех локальных переменных в текущем фрейме:

```
(gdb) info locals
map = HashMap(size=2) = {[1] = "One", [2] = "Two"}
```

Вывод значения переменной в текущем контексте (фрейме):

```
(gdb) p v
$1 = Vec(size=3) = {1, 2, 3}
```

Особенности, которые необходимо учитывать:

* как и в С/С++ не все значения переменных могут быть валидны и доступны на всем протяжении метода.
Если переменная соптимизирована компилятором или уже удалена из памяти из за того что ее жизненный цикл закончился ранее, она будет недоступна.
* `rust-gdb`, который является оберткой на gdb, старается выводить стандартные типы удобночитаемым образом. Но не для
всех типов есть поддержка. Поэтому, иногда приходится смотреть память "в сыром виде".
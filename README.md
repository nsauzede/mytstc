# Implementing "The Super Tiny Compiler" in various languages

This is an experiment, implementing the [TSTC](https://github.com/jamiebuilds/the-super-tiny-compiler)
in [Nelua](https://github.com/edubart/nelua-lang) and [V](https://github.com/vlang/v).

In V :
```
$ touch tstc.v ; /usr/bin/time v run tstc.v
```

In Nelua :
```
$ touch tstc.nelua ; /usr/bin/time nelua --no-cache -q tstc.nelua
```

---
layout: post
title: libgst 的 Makefile.am
categories: libgst building
---
由于在顶层的 `Makefile.am` 的 `SUBDIRS` 变量中包含了 `libgst` 目录，而且在顶层 `configure.ac` 文件中包含了 `AC_CONFIG_FILES(libgst/Makefile)`，所以在 `autoreconf` 的时候 `automake` 会在 `libgst` 目录中根据其中的 `Makefile.am` 生成对应的 `Makefile.in` 模板文件，而后 `configure` 脚本会在其中生成对应的 `Makefile` 文件。当在顶层目录中执行 `make` 的时候，会根据顶层 `Makefile.am` 文件中 `SUBDIRS` 变量中指定的目录次序依次进入其中执行对应的构建动作。例如顶层 `Makefile.am` 包含

```C
SUBDIRS = lib-src lightning $(subdirs)
SUBDIRS += libgst . $(BUILT_PACKAGES) doc tests
```

那么当在顶层目录中执行 `make all` 的时候，会依次进入 `lib-src`、`lightning` 等目录执行 `make all`。`SUBDIRS` 中的 `.` 代表当前目录（此处即为顶层目录）。

## 编译选项相关变量

```Makefile
LEX_OUTPUT_ROOT = lex.yy
## CFLAGS=-O0 -g
AM_CFLAGS = $(LIBGST_CFLAGS)
AM_LFLAGS = -Cfe -o$(LEX_OUTPUT_ROOT).c
AM_YFLAGS = -vy
AM_CPPFLAGS = $(RELOC_CPPFLAGS) \
  -I$(top_srcdir)/lib-src -I$(top_builddir)/lib-src \
  $(INCFFI) $(INCLIGHTNING) $(INCSNPRINTFV) $(INCSIGSEGV) $(INCLTDL)

if !HAVE_INSTALLED_LIGHTNING
AM_CPPFLAGS += -I$(top_srcdir)/lightning -I$(top_builddir)/lightning \
  -I$(top_srcdir) -I$(top_builddir)
endif
```

`CFLAGS` 会被传给 [C 语言][c]编译器；`CPPFLAGS` 会被传给 [C 语言][c] 预处理器。

`LFLAGS` 会被传给 [lex][flex]，而 `YFLAGS` 则是传给 [yacc][bison]。`lex` 是词法分析器生成器，通常使用 [Flex][flex]；`yacc` 则是语法解析器生成器，通常使用 [GNU Bison][bison]。

```Makefile
include_HEADERS = gstpub.h gst.h
lib_LTLIBRARIES = libgst.la
EXTRA_PROGRAMS = genprims genbc genvm
CLEANFILES = genprims$(EXEEXT) genbc$(EXEEXT) genvm$(EXEEXT) \
  genbc-decl.stamp genbc-impl.stamp genpr-parse.stamp genvm-parse.stamp
```

`include_HEADERS` 中指定了当前目录中需要安装的头文件。

`lib_LTLIBRARIES` 表明需要使用 [GNU Libtool][libtool] 生成 `libgst.la` 库。

`EXTRA_PROGRAMS` 指明了当前目录下可能需要编译的额外程序：

* `genprims` 根据 `prims.def` 生成 `prims.inl`，其中包含了 [GNU Smalltalk][gst] 虚拟机 primitive 的实现；
* `genbc` 根据 `byte.def`、`byte.c` 等文件生成 `match.h`，用来执行虚拟机中的[字节码(byte code)][bytecode]匹配动作；
* `genvm` 根据 `vm.def` 生成 `vm.inl`，其中包含了对 [GNU Smalltalk][gst] [字节码][bytecode]的实现。

## libgst.la 相关定义

```Makefile
libgst_la_LIBADD=$(top_builddir)/lib-src/library.la \
        $(LIBSIGSEGV) $(LIBFFI) $(LIBSNPRINTFV) $(LIBREADLINE) $(LIBLTDL) \
        $(LIBGMP) $(LIBTHREAD)

libgst_la_DEPENDENCIES=$(top_builddir)/lib-src/library.la $(LIBSNPRINTFV)

libgst_la_LDFLAGS = -version-info $(VERSION_INFO) -no-undefined \
        -export-symbols-regex "^gst_.*" -bindir $(bindir)
```

`libgst_la_LIBADD` 里面包含了链接 `libgst` 库需要的依赖库。

`libgst_la_LDFLAGS` 给出了链接 `libgst` 库时的链接选项，其中的 `-export-symbols-regex "^gst_.*"` 是给 [GNU Libtool][libtool] 的的选项，表示在 libgst 库中只导出(export)以 "gst_" 开头的符号。可以用 [GNU Binutils][binutils] 中的 `readelf` 工具来验证：

```shell
$ readelf -Ws libgst/.libs/libgst.so.7.1.3 | grep gst_initialize    
   255: 0000000000010880     5 FUNC    GLOBAL DEFAULT   12 gst_initialize
  1307: 0000000000011130  1602 FUNC    LOCAL  DEFAULT   12 _gst_initialize
```

虽然在 `libgst/files.c` 中 `_gst_initialize` 被定义为外部（全局）变量，但是在最终的 `libgst.so` 中，该符号仍然是局部的。

[TODO]: <> (为何 gst_initialize 等全局变量在 libgst.so 的符号表中出现了两次？)

## genprims 相关定义

```Makefile
genprims_SOURCES = \
       genpr-parse.y genpr-scan.l
```

## genbc 相关定义

```Makefile
genbc_SOURCES = \
       genbc-decl.y genbc-impl.y genbc-scan.l genbc.c
```

## genvm 相关定义

```Makefile
genvm_SOURCES = \
       genvm-parse.y genvm-scan.l
```

## 调用 genbc 的规则

```Makefile
$(srcdir)/match.h: $(srcdir)/match.stamp
        @:

$(srcdir)/match.stamp: byte.def byte.c opt.c xlat.c
        @$(MAKE) genbc$(EXEEXT)
        @echo "./genbc$(EXEEXT) $(srcdir)/byte.def $(srcdir)/byte.c $(srcdir)/opt.c $(srcdir)/xlat.c > match.h"; \
          ./genbc$(EXEEXT) $(srcdir)/byte.def $(srcdir)/byte.c $(srcdir)/opt.c $(srcdir)/xlat.c > _match.h
        @if cmp _match.h $(srcdir)/match.h > /dev/null 2>&1; then \
          echo match.h is unchanged; \
          rm _match.h; \
        else \
          mv _match.h $(srcdir)/match.h; \
        fi
        @echo timestamp > $(srcdir)/match.stamp
```

## 调用 genprims 的规则

```Makefile
$(srcdir)/prims.inl: $(srcdir)/prims.stamp
        @:

$(srcdir)/prims.stamp: prims.def
        @$(MAKE) genprims$(EXEEXT)
        @echo "./genprims$(EXEEXT) < $(srcdir)/prims.def > prims.inl"; \
          ./genprims$(EXEEXT) < $(srcdir)/prims.def > _prims.inl
        @if cmp _prims.inl $(srcdir)/prims.inl > /dev/null 2>&1; then \
          echo prims.inl is unchanged; \
          rm _prims.inl; \
        else \
          mv _prims.inl $(srcdir)/prims.inl; \
        fi
        @echo timestamp > $(srcdir)/prims.stamp
```

## 调用 genvm 的规则

```Makefile
$(srcdir)/vm.inl: $(srcdir)/vm.stamp
        @:

$(srcdir)/vm.stamp: vm.def
        @$(MAKE) genvm$(EXEEXT)
        @echo "./genvm$(EXEEXT) < $(srcdir)/vm.def | awk '{ /^#/ && gsub(/__oline__/,NR+1); print }' > vm.inl"; \
          ./genvm$(EXEEXT) < $(srcdir)/vm.def | awk '{ /^#/ && gsub(/__oline__/,NR+1); print }' > _vm.inl
        @if cmp _vm.inl $(srcdir)/vm.inl > /dev/null 2>&1; then \
          echo vm.inl is unchanged; \
          rm _vm.inl; \
        else \
          mv _vm.inl $(srcdir)/vm.inl; \
        fi
        @echo timestamp > $(srcdir)/vm.stamp
```

## 生成 binutils.inl 的规则

```Makefile
%.inl: %.gperf
        @opts="$< `$(SED) -ne /.*gperf/!d -e s///p -e q $< | \
            $(SED) 's,$$(srcdir),$(srcdir),g'`"; \
          echo $(GPERF) $$opts " > $@"; \
          for i in a b c d e f g h j; do \
            if test $$i = j; then \
              eval $(GPERF) $$opts > $@ && break; \
            else \
              eval $(GPERF) $$opts > $@ 2>/dev/null && break; \
              echo Retrying...; sleep 1; \
            fi; \
          done

builtins.inl: builtins.gperf
```

`builtins.gperf` 包含了 [GNU Smalltalk][gst] 中所有的内置(builtin) selector。


[links]: <> (Link list)
{% include Links.markdown %}

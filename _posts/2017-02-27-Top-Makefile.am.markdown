---
layout: post
title: 顶层 Makefile.am
categories: building
---
`Makefile.am` 中包含按照特定规则命名的变量和少量 [Make][gmake] 规则，[Automake][automake] 会将其作为输入文件生成模板文件 `Makefile.in`, 其中包含编译工程需要的各种变量和规则。在执行配置脚本 `configure` 的时候，会根据检测到的编译环境信息设置相关变量的值，并对 `Makefile.in` 中的变量进行替换以生成对应的 `Makefile` 文件。

`Makefile.am` 中设置与构建目标、规则相关变量的规则称为[统一命名规则(the uniform naming scheme)][automake-uniform]。

## `Makefile.am` 头部

```Makefile
# Automake requirements
AUTOMAKE_OPTIONS = gnu 1.11 dist-xz
ACLOCAL_AMFLAGS = -I build-aux

PACKAGE=smalltalk
gstdatadir=$(pkgdatadir)

DIST_SUBDIRS = lib-src snprintfv lightning libgst \
	. $(ALL_PACKAGES) tests doc

SUBDIRS = lib-src lightning $(subdirs)
SUBDIRS += libgst . $(BUILT_PACKAGES) doc tests

# Running gst inside the build directory...

GST_OPTS = --kernel-dir "@srcdir@/kernel" --image gst.im
GST = $(WINEWRAPPER) ./gst$(EXEEXT) --no-user-files $(GST_OPTS)
GST_PACKAGE = XZIP="$(XZIP)" $(WINEWRAPPER) ./gst-tool$(EXEEXT) gst-package $(GST_OPTS)
```
    
`AUTOMAKE_OPTIONS` 设置处理当前 `Makefile.am` 时需要传给 [automake][automake] 的选项，其中的 `1.11` 指定了需要的最低版本，而 `gnu` 则表示当前项目将[严格][automake-strictness]遵守 [GNU 的软件包标准][gnu-coding-standards]。

`ACLOCAL_AMFLAGS` 表示要传给 [aclocal][automake-aclocal] 的选项。

`PACKAGE` 则用来设置当前软件包的名字。

`DIST_SUBDIRS` 表示在发布当前软件包的时候包含这些子目录中的内容，而 `SUBDIRS` 则表示在这些子目录中执行编译动作。

由于在构建 [GNU Smalltalk][gst] 过程中需要执行 `gst` 和 `gst-package`，`GST` 和 `GST_PACKAGE` 设置要执行的具体命令，包括必要的选项。

## 配置(configuration)相关文件的规则

```Makefile
aclocaldir = $(datadir)/aclocal
dist_aclocal_DATA = build-aux/gst.m4 build-aux/gst-package.m4
dist_noinst_DATA = Doxyfile
dist_noinst_SCRIPTS = build-aux/texi2dvi build-aux/texi2html \
	build-aux/help2man build-aux/config.rpath 
```

`dist_aclocal_DATA` 即是一个符合 [Automake][automake] [统一命名规则][automake-uniform]的变量，其中的 `DATA` 在 [Automake][automake] 术语中称为 [primary][automake-uniform]，指示 [Automake][automake] 当前变量定义的是数据文件，中间的 `aclocal` 表示这些文件需要被安装到 `aclocaldir` 指定的目录中，而前缀 `dist` 表示在构造发布包的时候包含这些文件。

`dist_noinst_SCRIPTS` 中的 `SCRIPTS` 表示这些文件是可执行脚本，中间的 `noinst` 是个前缀，表示这些脚本文件不需要安装，而前缀 `dist` 则表示在软件发布包中包含这些文件。

## 脚本和数据文件的规则

```Makefile
if NEED_LIBC_LA
module_DATA = libc.la
endif
```

`if` 条件语句需和 `configure.ac` 中的 `AM_CONDITIONAL` 宏配合，来根据配置脚本 `configure` 检测的构建环境相关信息决定是否设置相关变量。这里的 `NEED_LIBC_LA` 其实是在 `build-aux/libc-so-name.m4` 中定义。

```Makefile
bin_SCRIPTS = gst-config
DISTCLEANFILES = termbold termnorm pkgrules.tmp
CLEANFILES = gst.im $(nodist_lisp_LISP) $(nodist_lispstart_LISP)
```

`bin_SCRIPTS = gst-config` 表示 `gst-config` 是脚本，讲被安装到 `bindir` 目录。

`CLEANFILES` 设置 `Makefile` `clean` 目标额外要删除的文件；`DISTCLEANFILES` 则是设置 `distclean` 目标额外要删除的文件。

```Makefile
smalltalk-mode-init.el: smalltalk-mode-init.el.in
	$(SED) -e "s,@\(lispdir\)@,$(lispdir)," \
	  -e "s/@\(WITH_EMACS_COMINT_TRUE\)@/$(LISP_WITH_EMACS_COMINT)/" \
	  $(srcdir)/smalltalk-mode-init.el.in > smalltalk-mode-init.el

gst-mode.el: gst-mode.el.in
	$(SED) -e "s,@\(bindir\)@,$(bindir)," $(srcdir)/gst-mode.el.in \
	  > gst-mode.el
```

在 `Makefile.am` 中也可以包含一些普通的 [Make][gmake] 规则，这些规则会被 [Automake][automake] 原样拷贝到生成的 `Makefile.in` 中去。

## 编译虚拟机的规则

```Makefile
AM_CPPFLAGS = -I$(top_srcdir)/libgst		\
	-I$(top_srcdir)/lib-src			\
	-DCMD_XZIP="\"$(XZIP)\""		\
	-DCMD_INSTALL="\"$(INSTALL)\""		\
	-DCMD_LN_S="\"$(LN_S)\""		\
	$(RELOC_CPPFLAGS)

bin_PROGRAMS = gst

gst_SOURCES = main.c
gst_LDADD = libgst/libgst.la lib-src/library.la @ICON@
gst_DEPENDENCIES = libgst/libgst.la lib-src/library.la @ICON@
gst_LDFLAGS = -export-dynamic $(RELOC_LDFLAGS) $(LIBFFI_EXECUTABLE_LDFLAGS)
```
    
`AM_CPPFLAGS` 设置编译时传给 [C 语言][C]预处理器的参数。

`bin_PROGRAMS` 表示需要编译的 `gst` 为程序，将被安装到 `bindir` 目录。

`gst_SOURCES` 设置 `gst` 的源码列表，`gst_LDADD` 设置 `gst` 需要链接的本地库（包含在当前项目中的库），`gst_DEPENDENCIES` 是其依赖，而 `gst_LDFLAGS` 则给出了链接 `gst` 时的参数。对于 `LDADD` 和 `LDFLAGS`，若是没有设置针对 `gst` 的对应变量，则 [Automake][automake] 在生成 `gst` 编译规则的时候会使用这些变量的全局值。

```Makefile
# Used to call the Unix zip from Wine
EXTRA_PROGRAMS = winewrapper
winewrapper_SOURCES = winewrapper.c
```

`EXTRA_PROGRAMS` 中的 [primary][automake-uniform] 指示 [Automake][automake] `winewrapper` 是个程序，但是 `EXTRA` 则表示需要根据 `configure` 配置脚本对构建环境的检测结果来决定是否需要编译 `winewrapper`。

```Makefile
uninstall-local::
	@for i in gst-load $(GST_EXTRA_TOOLS); do \
	  echo rm -f "$(DESTDIR)$(bindir)/$$i$(EXEEXT)"; \
	  rm -f "$(DESTDIR)$(bindir)/$$i$(EXEEXT)"; \
	done

install-exec-hook::
	$(INSTALL_PROGRAM_ENV) $(LIBTOOL) --mode=install $(INSTALL) gst-tool$(EXEEXT) "$(DESTDIR)$(bindir)/gst-load$(EXEEXT)"
	@for i in $(GST_EXTRA_TOOLS); do \
	  echo $(LN) -f "$(DESTDIR)$(bindir)/gst-load$(EXEEXT)" "$(DESTDIR)$(bindir)/$$i$(EXEEXT)"; \
	  $(LN) -f "$(DESTDIR)$(bindir)/gst-load$(EXEEXT)" "$(DESTDIR)$(bindir)/$$i$(EXEEXT)"; \
	done
```

目标 `uninstall-local` 和标准目标 `uninstall` 关联，用来对其进行扩展，而 `install-exec-hook` 则用来扩展 `install-exec`。`-local` 和 `-hook` 的区别则：`-local` 目标和其关联目标的执行顺序是不确定的；而 `-hook` 目标则总是在其关联目标之后执行。

上述目标之后的 `::` 表示其为 [GNU Make][gmake] 的 [double-clone 规则][gmake-double-clone]。

## 安装和发布相关规则

```Makefile
-include $(srcdir)/kernel/Makefile.frag
all-local: $(srcdir)/kernel/stamp-classes
```

`-include` 中的 `-` 表示若要包含的文件找不到，则忽略该包含语句继续处理。

```Makefile
$(srcdir)/kernel/Makefile.frag: $(srcdir)/packages.xml $(WINEWRAPPERDEP)
	(echo '$$(srcdir)/kernel/stamp-classes: \'; \
	  $(GST_PACKAGE) --list-files Kernel --vpath --srcdir="$(srcdir)" $(srcdir)/packages.xml | \
	    tr -d \\r | tr \\n ' '; \
	echo; \
	echo '	touch $$(srcdir)/kernel/stamp-classes') \
	  > $(srcdir)/kernel/Makefile.frag
```

`Makefile.frag` 和 `stamp-classes` 用来避免项目构建过程中的一些不必要的重复动作，可以加快当前项目的构建过程。这是 [GNU Smalltalk][gst] 构建过程的一个优化措施。

```Makefile
@PACKAGE_RULES@
```
    
`build-aux/gst-package.m4` 中定义的 [Autoconf][automake] 宏 `GST_PACKAGE_ENABLE` 会定义 [GNU Smalltalk 包][gst-package]编译的规则，并将其输出到变量 `PACKAGE_RULES` 指定的文件中。由于在 `configure.ac` 中（通过 `GST_PACKAGE_ENABLE`）调用了 `AC_SUBST_FILE([PACKAGE_RULES])])`，这个文件会被配置脚本 `configure` 在生成 `Makefile` 文件的时候将其内容包含进最终生成的 `Makefile` 中。


[links]: <> (Link list)

{% include Links.markdown %}

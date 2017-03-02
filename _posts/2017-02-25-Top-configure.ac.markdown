---
layout: post
title: 顶层 configure.ac
categories: building
---
`configure.ac` 描述了当前项目编译时需要的特性。[Autotools][autotools] 工具集使用 `configure.ac` 配合 `Makefile.am` 等文件生成配置脚本 `configure` 以及 `Makefile` 等文件。`configure` 是个 [Shell][shell] 脚本，用来执行实际的编译环境检测，并将检测结果传递给构建系统的其他部分；`Makefile` 文件定义了实际的编译规则。

`configure.ac` 里面主要包含的是对 [Autoconf][autoconf] 宏的调用，以及一些 [Shell][shell] 脚本片段。`configure.ac` 中所使用的宏有两个来源：一是 [Autoconf 预定义的宏][autoconf-macro-index]，用来执行通用、常见的编译环境特性检测；一是当前项目[自定义的宏][autoconf-writing-tests]，用来进行一些更特殊的检测。[GNU Smalltalk][gst] 的 `build-aux` 目录中包含其[自定义的宏][autoconf-writing-tests]。`configure.ac` 以及项目[自定义宏][autoconf-writing-tests]中使用的 [Shell][shell] 脚本片段应保证其[可移植性][autoconf-portable-shell]。

[Autoconf][autoconf] 的[用户手册][autoconf-manual]详细描述了如何使用该工具，包括[如何书写 `configure.ac`][autoconf-writing-autoconf-input]，和完整的[预定义宏列表][autoconf-macro-index]，这些宏的名字都带有前缀 `AC_`。

另外，名字带有前缀 `AM_` 的宏是 [Automake 的内置宏][automake-macro-index]。

## `configure.ac` 头部

```M4Sugar
dnl 2.63 needed by testsuite, actually
AC_PREREQ(2.63)
AC_INIT([GNU Smalltalk], 3.2.92, help-smalltalk@gnu.org, smalltalk,
        [http://smalltalk.gnu.org/])
MAINTAINER="bonzini@gnu.org"

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

dnl CURRENT:REVISION:AGE means this is the REVISION-th version of
dnl the CURRENT-th interface; all the interface from CURRENT-AGE
dnl to CURRENT are supported.
GST_REVISION(8:3:1)
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([build-aux])
AC_CONFIG_SRCDIR([main.c])
AC_CONFIG_TESTDIR(tests)
AC_CONFIG_HEADERS([config.h])
GST_PROG_GAWK
AM_INIT_AUTOMAKE
AC_CANONICAL_HOST
```

`AC_PREREQ` 用来指定处理当前 `configure.ac` 需要的 [Autoconf][autoconf] 的最低版本，而 `AC_INIT` 则用来进行初始化。

`AM_SILENT_RULES` 用来在最终生成的 `Makefile` 文件中提供简化的编译输出，而不是直接输出完整的编译命令。

`GST_REVISION` 则是在 `build-aux/version.m4` 中定义的宏，用来设置 [GNU Smalltalk][gst] 版本相关的变量。

`AC_CONFIG_AUX_DIR` 用来设置包含 [Autoconf][autoconf] 辅助文件的目录；而 `AC_CONFIG_MACRO_DIR` 则用来设置包含本地宏定义的目录。

`AC_CONFIG_SRCDIR([main.c])` 用来告诉 [Autoconf][autoconf] 包含 `main.c` 的目录是当前项目的源码顶层目录。

`AC_CONFIG_TESTDIR` 用来指定 [Autotest][autoconf-autotest] 测试集(test suite)所在的目录。

`AC_CONFIG_HEADERS([config.h])` 用来指示 [Autoconf][autoconf] 工具 `autoheader` 根据 `configure.ac` 中的 `AC_DEFINE` 和 `AC_DEFINE_UNQUOTED` 来生成模板文件 `config.h.in`。在编译过程中执行 `configure` 脚本的时候，会根据检测到的编译环境信息和该模板文件生成头文件 `config.h`，使用 [C][c] 语言预处理宏的形式向要编译的代码传递编译环境的相关信息。

`AM_INIT_AUTOMAKE` 则是用来初始化 [Automake][automake]。

`dnl` 用来在 `configure.ac` 和 [GNU M4][m4] 宏定义文件中引入注释。

## 检测编译需要的程序

```M4Sugar
AC_PROG_SED
AC_PROG_LN_S
GST_PROG_LN
PKG_PROG_PKG_CONFIG
AC_PATH_TOOL(WINDRES, windres, no)
AC_PATH_PROG(INSTALL_INFO, install-info, :, $PATH:/sbin:/usr/sbin)
AC_PATH_PROG(ZIP, zip, no, $PATH)
AC_CHECK_PROG(TIMEOUT, timeout, [timeout 600s], [env])
````

`AC_PROG_SED` 用来检测行编辑器 [`sed`][sed] 工具是否存在。

`AC_PATH_PROG(ZIP, zip, no, $PATH)` 用来在环境变量 `PATH` 的目录列表中查找工具 `zip`，并将其绝对路径保存在变量 `ZIP` 中。

```M4Sugar
AM_CONDITIONAL(WITH_EMACS, test "$EMACS" != no)
AM_CONDITIONAL(WITH_EMACS_COMINT, test "$ac_cv_emacs_comint" != no)
```

`AM_CONDITIONAL(WITH_EMACS, test "$EMACS" != no)` 根据 `configure` 脚本变量 `EMACS` 的值来设置 `WITH_EMACS` 相关的两个变量（`WITH_EMACS_TRUE` 和 `WITH_EMACS_FALSE`），和下述 `Makefile.am` 语句配合来实现在 `Makefile` 中条件定义相关的变量和规则：

```Makefile
if WITH_EMACS
dist_lisp_LISP = smalltalk-mode.el
nodist_lispstart_LISP = smalltalk-mode-init.el
if WITH_EMACS_COMINT
nodist_lisp_LISP = gst-mode.el
endif
endif
```
    
## 处理子模块

```M4Sugar
AC_CONFIG_SUBDIRS(snprintfv)
```

`AC_CONFIG_SUBDIRS(snprintfv)` 指示 [Autoconf][autoconf] `snprintfv` 是包含在当前项目中的一个自模块，它包含自己的 `configure.ac` 和 `Makefile.am` 等文件。当在顶层目录中执行 `autoreconf` 的时候，会在恰当时机进入相应子目录处理其中的 `configure.ac` 和 `Makefile.am` 以生成供该模块使用的 `configure` 脚本和 `Makefile.in` 模板文件；而当在顶层目录执行 `configure` 的时候，也会在恰当时机进入子目录，执行其中的 `configure` 脚本。

另外，之所以对 `libsigsegv` 和 `libffi` 的检测也包含在该部分，是因为最开始 [GNU Smalltalk][gst] 并不使用系统中的这两个库，而是直接在其源码目录中包含了这两个库的源码。

## 检测编译器和操作系统特性

```M4Sugar
GST_C_SYNC_BUILTINS
if test $gst_cv_have_sync_fetch_and_add = no; then
  AC_MSG_ERROR([Synchronization primitives not found, please use a newer compiler.])
fi
```

`GST_C_SYNC_BUILTINS` 是 `build-aux/sync-builtins.m4` 中定义的 [Autoconf][autoconf] 宏，用来检测当前所用 [C 语言][c]编译器是否支持 [GNU Smalltalk][gst] 实现代码中使用的一些[原子内存访问相关函数][gcc-sync-builtins]。

```M4Sugar
AC_CHECK_ALIGNOF(double)
AC_CHECK_ALIGNOF(long double)
AC_CHECK_ALIGNOF(long long)
AC_CHECK_SIZEOF(off_t)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)
```

`AC_CHECK_ALIGNOF` 用来检测相应数据类型的对齐要求；`AC_CHECK_SIZEOF` 则用来检测数据类型的大小。

## 检测 C 库特性

```M4Sugar
AC_TYPE_SIGNAL
AC_TYPE_PID_T
AC_TYPE_SIZE_T

AC_HEADER_ASSERT
AC_CHECK_HEADERS_ONCE(stdint.h inttypes.h unistd.h poll.h sys/ioctl.h \
	sys/resource.h sys/utsname.h stropts.h sys/param.h stddef.h limits.h \
	sys/timeb.h termios.h sys/mman.h sys/file.h execinfo.h utime.h \
	sys/select.h sys/wait.h fcntl.h crt_externs.h, [], [], [AC_INCLUDES_DEFAULT])

AC_CHECK_MEMBERS([struct stat.st_mtim.tv_nsec, struct stat.st_mtimensec,
		  struct stat.st_mtimespec.tv_nsec])
```
    
`AC_TYPE_PID_T` 检测当前 [C 库][glibc]是否定义了类型 `pid_t`；若没有定义，则提供合适的定义。

`AC_CHECK_HEADERS_ONCE` 用来检测当前编译系统中是提供了这些头文件。若是提供，则会在 `config.h` 中定义对应的名为 `HAVE_HEADER-FILE` 的 [C 语言][c]预处理宏，例如若 `stdint.h` 存在，则定义 `HAVE_STDIN_H`。

`AC_CHECK_MEMBERS` 用来检测当前 [C 库][glibc]提供的结构体定义中是否包含需要的成员。

```M4Sugar
AC_REPLACE_FUNCS(putenv strdup strerror strsignal mkstemp getpagesize \
	getdtablesize strstr ftruncate floorl ceill sqrtl frexpl ldexpl asinl \
	acosl atanl logl expl tanl sinl cosl powl truncl lrintl truncf lrintf \
        lrint trunc strsep strpbrk symlink mkdtemp)
```

`AC_REPLACE_FUNCS` 用来检测当前编译环境是否提供了需要的函数。若是没有提供，或者提供的实现有已知问题，那么则将其替换为源码中的版本。例如若当前编译环境中没有提供 `putenv` 函数，则使用 `lib-src/putenv.c` 提供的实现。

```M4Sugar
AC_SEARCH_LIBS([nanosleep], [rt])
if test "$ac_cv_search_nanosleep" != no; then
  AC_DEFINE(HAVE_NANOSLEEP, 1, 
    [Define if the system provides nanosleep.])
fi
```

`AC_SEARCH_LIBS([nanosleep], [rt])` 检测库 `librt` (为 [GNU libc][glibc] 的一部分) 是否提供了函数 `nanosleep`。

## 其他编译依赖库

```M4Sugar
GST_LIBC_SO_NAME
GST_HAVE_GMP
GST_HAVE_READLINE

GST_PACKAGE_ALLOW_DISABLING
GST_PACKAGE_PREFIX([packages])
GST_PACKAGE_DEPENDENCIES([gst-tool$(EXEEXT) gst.im $(WINEWRAPPERDEP)])

GST_PACKAGE_ENABLE([Announcements], [announcements])
GST_PACKAGE_ENABLE([BloxTK], [blox/tk],
   [GST_HAVE_TCLTK],
   [gst_cv_tcltk_libs],
   [Makefile], [blox-tk.la])
```

`GST_PACKAGE_ENABLE` 是 `build-aux/gst-package.m4` 中定义的宏，用来检测是否要编译对应的 [GNU Smalltalk 包][gst-package]。

## 文件生成

```M4Sugar
GST_RUN='$(top_builddir)/gst -I $(top_builddir)/gst.im -f'

AC_SUBST(GST_RUN)
AC_SUBST(CFLAGS)
AC_SUBST(INCLTDL)
AC_SUBST(LIBLTDL)
AC_SUBST(LTALLOCA)
AC_SUBST(LTLIBOBJS)

dnl Scripts & data files
AC_CONFIG_FILES(gnu-smalltalk.pc)
AC_CONFIG_FILES(gst-config, chmod +x gst-config)
AC_CONFIG_FILES(tests/gst, chmod +x tests/gst)
AC_CONFIG_FILES(tests/atlocal)

dnl Master Makefile
AC_CONFIG_FILES(Makefile)

dnl VM makefiles
AC_CONFIG_FILES(doc/Makefile lib-src/Makefile libgst/Makefile)
AC_CONFIG_FILES(lightning/Makefile tests/Makefile)

AC_OUTPUT
```

`AC_SUBST` 用来指示 [Autoconf][autoconf] 设置对应的[输出变量(output variable)][autoconf-output-variables]已记录编译环境检测结果，并且在生成文件的时候替换掉其中的对应变量。例如对于 `AC_SUBST(GST_RUN)`，[Autoconf][autoconf] 会设置[输出变量][autoconf-output-variables] `GST_RUN`，并在生成 `Makefile` 等文件的时候，将其中的 `@GST_RUN@` 替换为对应变量实际的值。

`AC_CONFIG_FILES` 用来指示 [Autoconf][autoconf] 在调用 `AC_OUTPUT` 的时候要生成哪些文件。例如 `AC_CONFIG_FILES(gnu-smalltalk.pc)` 表示使用模板文件 `gnu-smalltalk.pc.in` 作为输入文件，将其中的[Autoconf 输出变量][autoconf-output-variables]替换为其对应的值以生成文件 `gnu-smalltalk.pc`。

调用 `AC_OUTPUT` 以在 `configure` 脚本中生成实际的文件生成代码。`AC_OUTPUT` 会生成脚本 `config.status` 并执行该脚本，由该脚本完成所有的配置(configuration)动作，例如生成 `AC_CONFIG_FILES` 指定的文件，等等。


[links]: <> (Link list)

{% include Links.markdown %}

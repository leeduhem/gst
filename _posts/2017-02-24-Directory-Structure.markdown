---
layout: post
title: 目录结构
categories: building
---

[GNU Smalltalk][gst] [官方源码仓库][gst-git] 包含如下内容：

* 编译相关

        configure.ac  Makefile.am build-aux/
        
  [Autotools][autotools] 构建工具根据上述文件生成 `configure` 脚本及相关 `Makefile` 文件。除了顶层的 `Makefile.am` 文件，许多源码目录下也有其对应的 `Makefile.am` 文件用来指定如何编译该目录下的源码文件。
  
  `build-aux` 目录下主要是提供给 [Autoconf][autoconf] 的 [GNU M4][m4] 宏定义文件，`configure.ac` 主要使用这些本地宏以及系统提供的宏完成。

* [GNU Smalltalk][gst] 的实现

        libgst/ kernel/ lightning/ superops/ main.c

  `main.c` 包含 `gst` 的 `main` 函数，但是其功能的实际实现是在 `libgst` 中。`libgst` 提供了 [GNU Smalltalk][gst] 编译器及其[虚拟机][hllca]的实现。
  
  `kernel` 中包含的是 [GNU Smalltalk][gst] 系统中 [Smalltalk][smalltalk] 部分的实现。
  
  `lightning` 是 `libgst` 所用的 [JIT][jit] 引擎，名为 [GNU lightning][lightning]，最初是为实现 [GNU Smalltalk][gst] 的 [JIT][jit] 功能而设计实现。`superops` 用来生成 `libgst` 中的一些源码文件，包括 `byte.def`，`vm.def`，`superop1.inl` 和 `superop2.inl`。
  
  [GNU Smalltalk][gst] 本身的功能、特性，包括其对 [Smalltalk][smalltalk] 语法的扩展皆在其[用户手册][gst-manual]中有描述。
  
* [GNU Smalltalk][gst] 模块

        packages.xml packages scripts/ gst-tool.c
        
  `packages.xml` 是模块顶层模块描述文件。`packages` 目录包含各个模块的实现。`gst-tool.c` 是模块安装工具的源码，`scripts` 中包含其需要的一些 [Smalltalk][smalltalk] 脚本。
  
* 文档和例子

        doc/  examples/
        
  `doc` 目录中包含的是 [GNU Smalltalk][gst] 文档的源码，这些文档也可以通过如下链接访问：
  - [User's manual][gst-manual] 为其用户手册
  - [Class library reference (part I - base classes)][gst-manual-base] 包含基础类的手册
  - [Class library reference (part II - other)][gst-manual-libs] 包含一些额外类的手册
  
  `examples` 目录下包含了一些例子程序。
  
* 测试用例

        tests/  unsupported/
        
  `tests` 中包含 [GNU Smalltalk][gst] 的回归测试，`make check` 的时候会执行其中的测试用例。`unsupported` 中包含一些额外的测试用例。
  
* [GNU Emacs][emacs] 支持

        gst-mode.el.in  smalltalk-mode.el  smalltalk-mode-init.el.in

* 辅助源码

        lib-src/  snprintfv/

* 其他文件

  在顶层目录还包含其他一些文件，例如 `README`。另外，顶层目录还包含一个 [GDB][gdb] [初始化文件][gdbinit] `.gdbinit`，可以辅助用 [GDB][gdb] 来调试 `libgst` 中的 [C 语言][c] 代码。

[comment]: <> (Link list)

[gst]: http://smalltalk.gnu.org/
[git]: https://git-scm.com/
[gst-git]: git://git.sv.gnu.org/smalltalk.git
[autotools]: https://www.gnu.org/software/automake/manual/html_node/Autotools-Introduction.html
[autoconf]: https://www.gnu.org/software/autoconf/autoconf.html
[m4]: https://www.gnu.org/software/m4/m4.html
[hllca]: https://en.wikipedia.org/wiki/High-level_language_computer_architecture
[smalltalk]: http://stephane.ducasse.free.fr/FreeBooks/BlueBook/Bluebook.pdf
[jit]: https://en.wikipedia.org/wiki/Just-in-time_compilation
[lightning]: https://www.gnu.org/software/lightning/
[gst-manual]: https://www.gnu.org/software/smalltalk/manual/gst.html
[gst-manual-base]: https://www.gnu.org/software/smalltalk/manual-base/gst-base.html
[gst-manual-libs]: https://www.gnu.org/software/smalltalk/manual-libs/gst-libs.html
[emacs]: https://www.gnu.org/software/emacs/
[gdb]: https://www.gnu.org/software/gdb/
[gdbinit]: https://sourceware.org/gdb/onlinedocs/gdb/gdbinit-man.html
[c]: https://en.wikipedia.org/wiki/C_(programming_language)

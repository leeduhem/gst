---
layout: post
title: libgst 的公开接口 (gstpub.h 和 gstpub.c)
categories: libgst
---
`libgst` 提供了 [GNU Smalltalk][gst] 的实现，包括编译器和[虚拟机][hllca]，其中的代码最终会被编译为库 `libgst.la` 供其他代码链接。`gstpub.h` 提供了 `libgst` 的公开接口，而 `gstpub.c` 则提供了该接口的实现。

链接 `libgst.la` 代码的一个例子是顶层目录中用来实现 `gst` 的 `main.c`。

## gstpub.h

```C
#include "gst.h"
```

`gst.h` 提供了 `libgst` 内部最常用的一些数据结构和宏的定义，例如 `OOP`。

```C
typedef struct VMProxy
{
  OOP nilOOP, trueOOP, falseOOP;

  OOP (*msgSend) (OOP receiver,
		  OOP selector, 
		  ...);
  OOP (*vmsgSend) (OOP receiver,
		   OOP selector,
		   OOP * args);
  ...
} VMProxy;
```

`VMProxy` 定义了 [GNU Smalltalk][gst] 虚拟机提供的接口，通过全局变量 `gst_interpreter_proxy` 访问。

```C
/* These are extern in case one wants to link to libgst.a; these
   are not meant to be called by a module, which is brought up by
   GNU Smalltalk when the VM is already up and running.  */

/* These are the library counterparts of the functions in files.h.  */
extern void gst_smalltalk_args (int argc, const char **argv);
extern int gst_initialize (const char *kernel_dir,
			   const char *image_file,
			   int flags);
```

`libgst` 中公开接口的声明。

```C
/* These are the library counterparts of the functions in
   gst_vm_proxy.  */
extern OOP gst_msg_send (OOP receiver, OOP selector, ...);
extern OOP gst_vmsg_send (OOP receiver, OOP selector, OOP * args);
```

和 `VMProxy` 中函数指针对应的函数声明。

```C
/* This is exclusively for programs who link with libgst.a; plugins
   should not use this VMProxy but rather the one they receive in
   gst_initModule.  */
extern VMProxy gst_interpreter_proxy;
```

可以通过全局变量 `gst_interpreter_proxy` 访问 [GNU Smalltalk][gst] 虚拟机提供的接口[^1]。

[^1]: 目前该变量只在 `packages/glib/gst-gobject.c` 中有用到。

## gstpub.c

```C
#include "gstpriv.h"
```

`gstpriv.h` 提供了 `libgst` 内部使用的另外一些定义。

```C
VMProxy gst_interpreter_proxy = {
  NULL, NULL, NULL,

  _gst_msg_send, _gst_vmsg_send, _gst_nvmsg_send, _gst_str_msg_send,
  _gst_msg_sendf,
  _gst_eval_expr, _gst_eval_code,
```

对全局变量 `gst_interpreter_proxy` 进行初始化。

```C
int
gst_initialize (const char *kernel_dir,
                const char *image_file,
                int flags)
{
  return _gst_initialize (kernel_dir, image_file, flags);
}
```

`gstpub.c` 中的函数基本都是这种对 `libgst` 内部函数的简单封装。

------

[links]: <> (Link list)

{% include Links.markdown %}

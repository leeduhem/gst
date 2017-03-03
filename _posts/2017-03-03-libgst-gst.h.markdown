---
layout: post
title: libgst 的公开接口(gst.h)
categories: libgst
---
`libgst` 中的 `gst.h` 提供了一些最常用的数据类型和宏的定义，会被 `gstpub.h` 包含，因此也是 libgst 公开接口的一部分。

```C
/* Defined as char * in traditional compilers, void * in
   standard-compliant compilers.  */
#ifndef PTR
#if !defined(__STDC__)
#define PTR char *
#else
#define PTR void *
#endif
#endif
```

`PTR` 是 `libgst` 中的通用指针类型。

```C
/* An indirect pointer to object data.  */
typedef struct oop_s *OOP;

/* A direct pointer to the object data.  */
typedef struct object_s *gst_object, *mst_Object;

/* The contents of an indirect pointer to object data.  */
struct oop_s
{
  gst_object object;
  unsigned long flags;          /* FIXME, use uintptr_t */
};
```

`OOP` 是间接指向对象(object)的指针类型。`struct oop_s` 表示一个间接指向对象的类型，其中的成员 `object` 指向实际的对象，而 `flags` 则是该对象的一些标志。


```C
/* The header of all objects in the system.
   Note how structural inheritance is achieved without adding extra levels of 
   nested structures.  */
#define OBJ_HEADER \
  OOP           objSize; \
  OOP           objClass


/* Just for symbolic use in sizeof's */
typedef struct gst_object_header
{
  OBJ_HEADER;
}
gst_object_header;

#define OBJ_HEADER_SIZE_WORDS   (sizeof(gst_object_header) / sizeof(PTR))

/* A bare-knuckles accessor for real objects */
struct object_s
{
  OBJ_HEADER;
  OOP data[1];                  /* variable length, may not be objects, 
                                   but will always be at least this
                                   big.  */
};
```

`OBJ_HEADER` 表示每个对象的头部(header)都包含两个成员，`objSize` 和 `objClass`，类型皆为 `OOP`，其中 `objSize` 记录对象的大小，而 `objClass` 则记录了对象所属的类(class)。

在 `libgst` 中，所有的对象都是有一个头部和一系列的类型为 `OOP` 的数据域(field)组成，对应的类型为 `struct object_s`。

```C
/* Convert an OOP (indirect pointer to an object) to the real object
   data.  */
#define OOP_TO_OBJ(oop) \
  ((oop)->object)

/* Retrieve the class for the object pointed to by OOP.  OOP must be
   a real pointer, not a SmallInteger.  */
#define OOP_CLASS(oop) \
  (OOP_TO_OBJ(oop)->objClass)
```

`OOP_TO_OBJ` 和 `OOP_CLASS` 是访问 `OOP` 对应成员的两个宏。

```C
/* Answer whether OOP is a SmallInteger or a `real' object pointer.  */
#define IS_INT(oop) \
  ((intptr_t)(oop) & 1)
```

在 `libgst` 中，`OOP` 指针至少是四字节对齐的，这意味着指针 `oop` 值的最低两位并未被使用，所以可以用来记录一些和此指针相关的信息，这些信息称为标签(tag)，这类指针称为 [tagged pointer][taggedPointer]。在 `libgst` 中，[Smalltalk][smalltalk] 语言中的 `SmallInteger` 即是通过 [tagged 指针]实现的。

```C
/* Answer whether OOP is a `real' object pointer or rather a
   SmallInteger.  */
#define IS_OOP(oop) \
  (! IS_INT(oop) )
```

`IS_OOP` 和 `IS_INT` 的语义是互补的。

```C
/* Keep these in sync with _gst_sizes, in dict.c.
   FIXME: these should be exported in a pool dictionary.  */
enum gst_indexed_kind {
  GST_ISP_FIXED = 0,
  GST_ISP_SCHAR = 32,
  GST_ISP_UCHAR = 34,
  ...
};
```

枚举(enum)类型 `gst_indexed_kind` 定义了 `libgst` 使用的一些常量。

```C
enum gst_var_index {
  GST_DECLARE_TRACING,
  GST_EXECUTION_TRACING,
  GST_EXECUTION_TRACING_VERBOSE,
  GST_GC_MESSAGE,
  GST_VERBOSITY,
  GST_MAKE_CORE_FILE,
  GST_REGRESSION_TESTING,
  GST_NO_LINE_NUMBERS
};
```

`enum gst_var_index` 对应 `gst_set_var` 和 `gst_get_var` 可以设置和获取的所有变量。

```C
enum gst_init_flags {
  GST_REBUILD_IMAGE = 1,
  GST_MAYBE_REBUILD_IMAGE = 2,
  GST_IGNORE_USER_FILES = 4,
  GST_IGNORE_BAD_IMAGE_PATH = 8,
  GST_IGNORE_BAD_KERNEL_PATH = 16,
  GST_NO_TTY = 32,
};
```

`enum gst_init_flags` 定义了 `gst_initialize` 接受的所有 flag。

```C
enum gst_vm_hook {
  GST_BEFORE_EVAL,
  GST_AFTER_EVAL,
  GST_RETURN_FROM_SNAPSHOT,
  GST_ABOUT_TO_QUIT,
  GST_ABOUT_TO_SNAPSHOT,
  GST_FINISHED_SNAPSHOT
};
```

`enum gst_vm_hook` 指定了虚拟机目前支持的所有 hook。


[links]: <> (Link list)

{% include Links.markdown %}

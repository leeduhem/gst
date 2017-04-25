---
layout: post
title: 对象表(object table)管理 (libgst/oop.c) -- GC
categories: libgst oop
---
* TOC
{:toc}

[GNU Smalltalk][gst] 的 [GC][gst-gc] 采用不同的算法管理多个不同的堆(heap)：

1. generation scavenger (`NewSpace`)；
2. mark-sweep collector and compactor (`OldSpace`)；
3. mark-sweep collector (`FixedSpace`)。

[TODO]: <> (根据代码确认上述内容)

## 全局变量

```C
/* This is != 0 in the middle of a GC.  */
int _gst_gc_running = 0;

/* This is the memory area which holds the object table.  */
static heap oop_heap;

/* This variable represents information about the memory space.
   _gst_mem holds the required information: basically the
   pointer to the base and top of the space, and the pointers into it
   for allocation and copying.  */
struct memory_space _gst_mem;
```

## _gst_init_mem

```C
void
_gst_init_mem (size_t eden, size_t survivor, size_t old,
	       size_t big_object_threshold, int grow_threshold_percent,
	       int space_grow_rate)
{
```

`_gst_init_mem` 的参数用来设定内存分配器(memory allocator)的内部参数。


```C
  if (!_gst_mem.old)
    {
#ifndef NO_SIGSEGV_HANDLING
      sigsegv_install_handler (oldspace_sigsegv_handler);
#endif
      if (!eden)
        eden = 3 * K * K;
      if (!survivor)
        survivor = 128 * K;
      if (!old)
        old = 4 * K * K;
      if (!big_object_threshold)
        big_object_threshold = 4 * K;
      if (!grow_threshold_percent)
        grow_threshold_percent = 80;
      if (!space_grow_rate)
        space_grow_rate = 30;
    }
  else
    {
      if (eden || survivor)
        _gst_scavenge ();

      if (survivor)
        _gst_tenure_all_survivors ();

      if (old && old != _gst_mem.old->heap_total)
        _gst_grow_memory_to (old);
    }
```

若是 `_gst_mem` 尚未被初始化，且 `_gst_init_mem` 的某些参数为零，则为其设置对应的默认值。


```C
  if (eden)
    {
      _gst_mem.eden.totalSize = eden;
      _gst_mem.eden.minPtr = (OOP *) xmalloc (eden);
      _gst_mem.eden.allocPtr = _gst_mem.eden.minPtr;
      _gst_mem.eden.maxPtr = (OOP *)
        ((char *)_gst_mem.eden.minPtr + eden);
    }
```

初始化 `NewSpace` 中的 `Eden`，用来创建新的对象。

```C
  if (survivor)
    {
      init_survivor_space (&_gst_mem.surv[0], survivor);
      init_survivor_space (&_gst_mem.surv[1], survivor);
      init_survivor_space (&_gst_mem.tenuring_queue,
		           survivor / OBJ_HEADER_SIZE_WORDS);
    }
```

初始化 `NewSpace` 中的 `SurvivorSpace`，两个 `SurvivorSpace` 的大小相等。同时初始化 tenuring 时使用的 `tenuring_queue`。

```C
  if (big_object_threshold)
    _gst_mem.big_object_threshold = big_object_threshold;

  if (_gst_mem.eden.totalSize < _gst_mem.big_object_threshold)
    _gst_mem.big_object_threshold = _gst_mem.eden.totalSize;

  if (grow_threshold_percent)
    _gst_mem.grow_threshold_percent = grow_threshold_percent;

  if (space_grow_rate)
    _gst_mem.space_grow_rate = space_grow_rate;
```

设置内存分配器的内部参数。

```C
  if (!_gst_mem.old)
    {
      if (old)
        {
          _gst_mem.old = init_old_space (old);
          _gst_mem.fixed = init_old_space (old);
        }

      _gst_mem.active_half = &_gst_mem.surv[0];
      _gst_mem.active_flag = F_EVEN;
      _gst_mem.live_flags = F_EVEN | F_OLD;

      stats.timeOfLastScavenge = stats.timeOfLastGlobalGC =
        stats.timeOfLastGrowth = stats.timeOfLastCompaction =
        _gst_get_milli_time ();

      _gst_mem.factor = 0.4;

      _gst_inc_init_registry ();
    }
```

初始化 `OldSpace` 和 `FixedSpace`。初始化 [Incubator][gst-gc-incubator]。

```C
  _gst_mem.markQueue = (struct mark_queue *)
    xcalloc (8 * K, sizeof (struct mark_queue));
  _gst_mem.lastMarkQueue = &_gst_mem.markQueue[8 * K];
}
```

初始化 `markQueue`。

[TODO]: <> (详细解释 _gst_mem 各个成员的作用)

### init_survivor_space

```C
typedef struct surv_space {
  OOP *tenurePtr;               /* points to oldest object */
  OOP *allocPtr;                /* points to past newest object */
  OOP *minPtr;                  /* points to lowest addr in heap */
  OOP *maxPtr;                  /* points to highest addr in heap */
  OOP *topPtr;                  /* points to highest used addr in heap */
  int  allocated;               /* bytes allocated in the last scavenge */
  int  filled;                  /* bytes currently used */
  int  totalSize;               /* allocated size */
} surv_space;
```


```C
void
init_survivor_space (struct surv_space *space, size_t size)
{
  space->totalSize = size;
  space->minPtr = (OOP *) xmalloc (size);
  space->maxPtr = (OOP *) ((char *)space->minPtr + size);

  reset_survivor_space (space);
}
```

```C
void
reset_survivor_space (surv_space *space)
{
  space->allocated = space->filled = 0;
  space->tenurePtr = space->allocPtr = space->topPtr = space->minPtr;
}
```

### init_old_space

```C
struct heap_data
{
  heap_block *freelist[NUM_FREELISTS];
  int mmap_count;
  size_t heap_total, heap_allocation_size, heap_limit;
  int probes, failures, splits, matches;

  allocating_hook_t after_allocating, before_prim_freeing, after_prim_allocating;
  nomemory_hook_t nomemory;
};
```

`struct heap_data` 定义于 `libgst/alloc.h`。


```C
heap_data *
init_old_space (size_t size)
{
  heap_data *h = _gst_mem_new_heap (0, size);
  h->after_prim_allocating = oldspace_after_allocating;
  h->before_prim_freeing = oldspace_before_freeing;
  h->nomemory = oldspace_nomemory;

  return h;
}
```

`_gst_mem_new_heap` 定义于 `libgst/alloc.c`。


[TODO]: <> (添加链接)

[TODO]: <> (描述 heap_data 中各个 hook 的作用)


### _gst_inc_init_registry

```C
void
_gst_inc_init_registry (void)
{
  _gst_mem.inc_base =
    (OOP *) xmalloc (INIT_NUM_INCUBATOR_OOPS * sizeof (OOP *));
  _gst_mem.inc_ptr = _gst_mem.inc_base;
  _gst_mem.inc_end =
    _gst_mem.inc_base + INIT_NUM_INCUBATOR_OOPS;

  /* Make the incubated objects part of the root set */
  _gst_register_oop_array (&_gst_mem.inc_base, &_gst_mem.inc_ptr);
}
```

`_gst_register_oop_array` 定义于 `libgst/callin.c`。

[TODO]: <> (添加链接)


## _gst_init_oop_table

`_gst_init_oop_table` 会在 [GNU Smalltalk][gst] 初始化时被调用，用来创建 OOP 表。

[TODO]: <> (添加链接)



## _gst_alloc_obj

```C
gst_object
_gst_alloc_obj (size_t size,
                OOP *p_oop)
{
  OOP *newAllocPtr;
  gst_object p_instance;

  size = ROUNDED_BYTES (size);

  /* We don't want to have allocPtr pointing to the wrong thing during
     GC, so we use a local var to hold its new value */
  newAllocPtr = _gst_mem.eden.allocPtr + BYTES_TO_SIZE (size);

  if UNCOMMON (size >= _gst_mem.big_object_threshold)
    return alloc_fixed_obj (size, p_oop);

  if UNCOMMON (newAllocPtr >= _gst_mem.eden.maxPtr)
    {
      _gst_scavenge ();
      newAllocPtr = _gst_mem.eden.allocPtr + BYTES_TO_SIZE (size);
    }

  p_instance = (gst_object) _gst_mem.eden.allocPtr;
  _gst_mem.eden.allocPtr = newAllocPtr;
  *p_oop = alloc_oop (p_instance, _gst_mem.active_flag);
  p_instance->objSize = FROM_INT (BYTES_TO_SIZE (size));

  return p_instance;
}
```

`_gst_alloc_obj` 用来给大小为 `size` 字节的对象分配内存。若是欲分配的新对象为大对象，则直接将其分配在 OldSpace 中；否则该对象将位于 Eden 空间中 `allocPtr` 指向的位置。

`alloc_oop` 定义于 `libgst/oop.inl`，用来给新分配的对象分配 OOP。

## alloc_fixed_obj

```C
alloc_fixed_obj (size_t size,
                 OOP *p_oop)
{
  gst_object p_instance;

  size = ROUNDED_BYTES (size);

  /* If the object is big enough, we put it directly in oldspace.  */
  p_instance = (gst_object) _gst_mem_alloc (_gst_mem.old, size);
  if COMMON (p_instance)
    goto ok;

  _gst_global_gc (size);
  p_instance = (gst_object) _gst_mem_alloc (_gst_mem.old, size);
  if COMMON (p_instance)
    goto ok;

  compact (0);
  p_instance = (gst_object) _gst_mem_alloc (_gst_mem.old, size);
  if UNCOMMON (!p_instance)
    {
      /* !!! do something more reasonable in the future */
      _gst_errorf ("Cannot recover, exiting...");
      exit (1);
    }

ok:
  *p_oop = alloc_oop (p_instance, F_OLD);
  p_instance->objSize = FROM_INT (BYTES_TO_SIZE (size));
  return p_instance;
}
```

`alloc_fixed_obj` 实际是在 OldSpace 中分配新对象。

## compact

----

[links]: <> (Link list)

{% include Links.markdown %}

---
layout: post
title: 对象表(object table)管理 (libgst/oop.h) -- GC 相关数据结构
categories: libgst oop
---
* TOC
{:toc}

[GNU Smalltalk][gst] 的 [GC][gst-gc] 采用 generation scavenger 管理 `NewSpace`，采用 mark-sweep collector 管理 `OldSpace` 和 `FixedSpace`，并在 `OldSpace` 上实现了 compactor。这些在 `libgst/oop.h` 定义的 [GC][gst-gc] 相关数据结构上有充分的体现。

## 相关预处理宏

```C
#define NUM_CHAR_OBJECTS        256
#define NUM_BUILTIN_OBJECTS     3
#define FIRST_OOP_INDEX         (-NUM_CHAR_OBJECTS-NUM_BUILTIN_OBJECTS)
#define CHAR_OBJECT_BASE        FIRST_OOP_INDEX
#define BUILTIN_OBJECT_BASE     (-NUM_BUILTIN_OBJECTS)
```

访问对象表(object table)相关的宏。

```C
/* The number of OOPs in the system.  This is exclusive of Character,
   True, False, and UndefinedObject (nil) oops, which are
   built-ins.  */
#define INITIAL_OOP_TABLE_SIZE  (1024 * 128 + FIRST_OOP_INDEX)
#define MAX_OOP_TABLE_SIZE      (1 << 23)
```

对象表的初始容量和允许的最大容量。

```C
/* The number of free OOPs under which we trigger GCs.  0 is not
   enough because _gst_scavenge might still need some oops in
   empty_context_stack!!! */
#define LOW_WATER_OOP_THRESHOLD (1024 * 2)
```

对象表中至少应剩余的空闲 OOP[^1]，不足即出发 [GC][gst-gc] 动作。

[^1]: OOP 是 Ordinary Object Pointer 的缩写。

```C
#define SMALLTALK_OOP_INDEX     0
#define PROCESSOR_OOP_INDEX     1
#define SYM_TABLE_OOP_INDEX     2
#define NIL_OOP_INDEX           (BUILTIN_OBJECT_BASE + 0)
#define TRUE_OOP_INDEX          (BUILTIN_OBJECT_BASE + 1)
#define FALSE_OOP_INDEX         (BUILTIN_OBJECT_BASE + 2)
```

关键 OOP 在对象表中的索引(index)。


## 全局变量

```C
/* This is true in the middle of a GC.  */
extern int _gst_gc_running
  ATTRIBUTE_HIDDEN;
```

`ATTRIBUTE_HIDDEN` 定义于 `libgst/gstpriv.h`，将符号 `_gst_gc_running` 的可见性(visibility)设置为隐藏(hidden)，需要编译器和可执行文件格式的支持[^2]。

[^2]: 参见 [Visibility - GCC Wiki][gcc-visibility]。

```C
/* This variable represents information about the memory space.  _gst_mem
   holds the required information: basically the pointer to the base and
   top of the space, and the pointers into it for allocation and copying.  */
extern struct memory_space _gst_mem
  ATTRIBUTE_HIDDEN;
```

## 数据结构

### memory_space

```C
struct memory_space
{
  heap_data *old, *fixed;
  struct new_space eden;
  struct surv_space surv[2], tenuring_queue;

  struct mark_queue *markQueue, *lastMarkQueue;

  /* The current state of the copying collector's scan phase.  */
  struct cheney_scan_state scan;

  /* The object table.  This contains a pointer to the object, and some flag
     bits indicating whether the object is read-only, reachable and/or pooled.
     Some of the bits indicate the difference between the allocated length
     (stored in the object itself), and the real length, because variable
     byte objects may not be an even multiple of sizeof(PTR).  */
  struct oop_s *ot, *ot_base;

  /* The number of OOPs in the free list and in the full OOP
     table.  num_free_oops is only correct after a GC!  */
  int num_free_oops, ot_size;

  /* The root set of the scavenger.  This includes pages in oldspace that
     were written to, and objects that had to be tenured before they were
     scanned.  */
  grey_area_list grey_pages, grey_areas;
  int rememberedTableEntries;

  /* A list of areas used by weak objects.  */
  weak_area_tree *weak_areas; 

  /* These are the pointer to the first allocated OOP since the last
     completed incremental GC pass, to the last low OOP considered by
     the incremental sweeper, to the first high OOP not considered by
     the incremental sweeper.  */
  OOP last_allocated_oop, last_swept_oop, next_oop_to_sweep;

  /* The active survivor space */
  struct surv_space *active_half;

  /* The beginning and end of the area mmap-ed directly from the image.  */
  OOP *loaded_base, *loaded_end;

  /* The OOP flag corresponding to the active survivor space */
  int active_flag;

  /* The OOP flag corresponding to the inactive survivor space.  */
  int live_flags;

  /* These hold onto the object incubator's state */
  OOP *inc_base, *inc_ptr, *inc_end;
  int inc_depth;

  /* Objects that are at least this big (in bytes) are allocated outside
     the main heap, hoping to provide more locality of reference between
     small objects.  */
  size_t big_object_threshold;

  /* If there is this much space used after a oldspace collection, we need to
     grow the object heap by _gst_space_grow_rate % next time we
     do a collection, so that the storage gets copied into the new, larger
     area.  */
  int grow_threshold_percent;

  /* Grow the object heap by this percentage when the amount of space
     used exceeds _gst_grow_threshold_percent.  */
  int space_grow_rate;

  /* Some statistics are computed using exponential smoothing.  The smoothing
     factor is stored here.  */
  double factor;

  /* Here are the stats.  */
  int numScavenges, numGlobalGCs, numCompactions, numGrowths;
  int numOldOOPs, numFixedOOPs, numWeakOOPs;

  double timeBetweenScavenges, timeBetweenGlobalGCs, timeBetweenGrowths;
  double timeToScavenge, timeToCollect, timeToCompact;
  double reclaimedBytesPerScavenge,
	 tenuredBytesPerScavenge, reclaimedBytesPerGlobalGC,
         reclaimedPercentPerScavenge;
};
```

[TODO]: <> (添加详细描述)


#### heap_data

`heap_data` 定义于 `libgst/alloc.h`。

[TODO]: <> (添加链接)

#### new_space

```C
typedef struct new_space {
  OOP *minPtr;			/* points to lowest addr in heap */
  OOP *maxPtr;			/* points to highest addr in heap */
  OOP *allocPtr;		/* new space ptr, starts low, goes up */
  unsigned long totalSize;	/* allocated size */
} new_space;
```

#### surv_space

```C
typedef struct surv_space {
  OOP *tenurePtr;		/* points to oldest object */
  OOP *allocPtr;		/* points to past newest object */
  OOP *minPtr;			/* points to lowest addr in heap */
  OOP *maxPtr;			/* points to highest addr in heap */
  OOP *topPtr;			/* points to highest used addr in heap */
  int  allocated;  		/* bytes allocated in the last scavenge */
  int  filled;  		/* bytes currently used */
  int  totalSize;               /* allocated size */
} surv_space;
```

#### mark_queue

```C
struct mark_queue
{
  OOP *firstOOP, *endOOP;
};
```

#### cheney_scan_state

```C
typedef struct cheney_scan_state {
  OOP *queue_at;		/* Next scanned object in queue */
  OOP *at;			/* Base of currently scanned object */
  OOP current;			/* Currently scanned object */
} cheney_scan_state;
```

#### grey_area_list

```C
typedef struct grey_area_node {
  struct grey_area_node *next;
  OOP *base;
  int n;
  OOP oop;
} grey_area_node;
```

```C
typedef struct grey_area_list {
  grey_area_node *head, *tail;
} grey_area_list;
```

#### weak_area_tree

```C
typedef struct weak_area_tree
{
  rb_node_t rb;
  OOP oop;			/* Weak OOP */
}
weak_area_tree;
```

`rb_node_t` 定义于 `lib-src/rbtrees.h`，和 `lib-src/rbtrees.c` 一起实现了红黑树(red black tree)。


### gst_object_memory

```C
typedef struct gst_object_memory
{
  OBJ_HEADER;
  OOP bytesPerOOP, bytesPerOTE,
      edenSize, survSpaceSize, oldSpaceSize, fixedSpaceSize,
      edenUsedBytes, survSpaceUsedBytes, oldSpaceUsedBytes,
      fixedSpaceUsedBytes, rememberedTableEntries,
      numScavenges, numGlobalGCs, numCompactions, numGrowths,
      numOldOOPs, numFixedOOPs, numWeakOOPs, numOTEs, numFreeOTEs,
      timeBetweenScavenges, timeBetweenGlobalGCs, timeBetweenGrowths,
      timeToScavenge, timeToCollect, timeToCompact,
      reclaimedBytesPerScavenge, tenuredBytesPerScavenge,
      reclaimedBytesPerGlobalGC, reclaimedPercentPerScavenge,
      allocFailures, allocMatches, allocSplits, allocProbes;
} *gst_object_memory;
```

`gst_object_memory` 用来支持 `ObjectMemory` 的实现。

----

[links]: <> (Link list)

{% include Links.markdown %}


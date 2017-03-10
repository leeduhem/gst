---
layout: post
title: 生成及加载 image 文件 (libgst/save.c)
categories: libgst image
---
* TOC
{:toc}


[GNU Smalltalk][gst] 可以将当前正在运行的 [Smalltalk][smalltalk] 系统的快照(snapshot)保存到 [image 文件][gst-image]中，过后可以加载此 [image 文件][gst-image]以恢复当前的 [Smalltalk][smalltalk] 系统的状态。

## 类型、宏及全局变量定义

```C
/* These flags help defining the flags and checking whether they are
   different between the image we are loading and our environment.  */

#define MASK_ENDIANNESS_FLAG 1
#define MASK_SLOT_SIZE_FLAG 2

#ifdef WORDS_BIGENDIAN
# define LOCAL_ENDIANNESS_FLAG MASK_ENDIANNESS_FLAG
#else
# define LOCAL_ENDIANNESS_FLAG 0
#endif

#if SIZEOF_OOP == 4
# define LOCAL_SLOT_SIZE_FLAG 0
#else /* SIZEOF_OOP == 8 */
# define LOCAL_SLOT_SIZE_FLAG MASK_SLOT_SIZE_FLAG
#endif /* SIZEOF_OOP == 8 */

#define FLAG_CHANGED(flags, whichFlag)  \
  ((flags ^ LOCAL_##whichFlag) & MASK_##whichFlag)
```

欲加载的 [image 文件][gst-image]的[字节序(endianness)][endianness]若和当前系统不同，则需要转换。由于[image 文件][gst-image]中还保存了一些内存地址，若是当前系统的地址宽度和生成 [image 文件][gst-image]的系统不一致，例如在 64 位系统中加载在 32 位系统生成的 [image 文件][gst-image]，则无法加载此 [image 文件][gst-image]。


```C
#define VERSION_REQUIRED        \
  ((ST_MAJOR_VERSION << 16) + (ST_MINOR_VERSION << 8) + ST_EDIT_VERSION)
```

不同版本的 [GNU Smaltalk][gst] 生成的 [image 文件][gst-image]可能互不兼容，因此在 [image 文件][gst-image]中还保存了生成该 [image 文件][gst-image]的 [GNU Smalltalk][gst] 实现的版本。


```C
/* The binary image file has the following format:
        header
        complete oop table
        object data */
```

此即 [GNU Smalltalk][gst] [image 文件][gst-image]的格式。


```C
#define EXECUTE      "#! /usr/bin/env gst -aI\nexec gst -I \"$0\" -a \"$@\"\n"
#define SIGNATURE    "GSTIm"

typedef struct save_file_header
{
  char dummy[64];       /* Bourne shell command to execute image */
  char signature[6];    /* 6+2=8 should be enough to align version! */
  char unused;
  char flags;           /* flags for endianness and sizeof(PTR) */
  size_t version;       /* the Smalltalk version that made this dump */
  size_t oopTableSize;  /* size of the oop table at dump */
  size_t edenSpaceSize; /* size of new space at dump time */
  size_t survSpaceSize; /* size of survivor spaces at dump time */
  size_t oldSpaceSize;  /* size of old space at dump time */
  size_t big_object_threshold;
  size_t grow_threshold_percent;
  size_t space_grow_rate;
  size_t num_free_oops;
  intptr_t ot_base;
  intptr_t prim_table_md5[16 / sizeof (intptr_t)]; /* checksum for the primitive table */
}
save_file_header;
```

结构体类型 `save_file_header` 定义了在 [image 文件][gst-image]的头部要保存哪些信息。


```C
/* Convert from relative offset to actual oop table address.  */
#define OOP_ABSOLUTE(obj) \
  ( (OOP)((intptr_t)(obj) + ot_delta) )
```

宏 `OOP_ABSOLUTE` 用来把 [image 文件][gst-image]加载后的对象的地址转换为其在当前系统中的地址。

[TODO]: <> (添加链接)

## _gst_save_to_file

`_gst_save_to_file` 保存当前 [Smalltalk][smalltalk] 系统的快照，生成 [image 文件][gst-image]。


```C
mst_Boolean
_gst_save_to_file (const char *fileName)
{
  int imageFd;
  int save_errno;
  mst_Boolean success;

  _gst_invoke_hook (GST_ABOUT_TO_SNAPSHOT);
  _gst_global_gc (0);
  _gst_finish_incremental_gc ();
```

在生成 [image 文件][gst-image]之前，先调用 `GST_ABOUT_TO_SNAPSHOT` hook，然后执行 [GC][gc] 动作，以免在 [image 文件][gst-image]中保存已经无法访问的对象。


```C
  success = false;
  unlink (fileName);
  imageFd = _gst_open_file (fileName, "w");
  if (imageFd >= 0)
    {
      if (setjmp(save_jmpbuf) == 0)
        {
          save_to_fd (imageFd);
          success = true;
        }

      save_errno = errno;
      close (imageFd);
      if (!success)
        unlink (fileName);
      if (myOOPTable)
        xfree (myOOPTable);
      myOOPTable = NULL;
    }
  else
    save_errno = errno;
```

`save_to_fd` 实现了实际生成 [image 文件][gst-image]的逻辑。


```C
  _gst_invoke_hook (GST_FINISHED_SNAPSHOT);
  errno = save_errno;
  return success;
}
```

生成 [image 文件][gst-image]之后执行 `GST_FINISHED_SNAPSHOT` hook。

### save_to_fd

```C
void
save_to_fd (int imageFd)
{
  save_file_header header;
  memset (&header, 0, sizeof (header));
  myOOPTable = make_oop_table_to_be_saved (&header);
```

`make_oop_table_to_be_saved` 将 oop 表中需要写入 [image 文件][gst-image]的部分保存到全局变量 `myOOPTable` 中。

```C
  buffer_write_init (imageFd, WRITE_BUFFER_SIZE);
  save_file_version (imageFd, &header);
```

`save_file_version` 向 [image 文件][gst-image]中写入文件头。

```C
  /* save up to the last oop slot in use */
  buffer_write (imageFd, myOOPTable,
                sizeof (struct oop_s) * num_used_oops);
```

`buffer_write` 将 `myOOPTable` 中的数据作为字节流写入 [image 文件][gst-image]。

```C
  save_all_objects (imageFd);
```

最后依次写入所有的对象。

```C
  buffer_write_flush (imageFd);
}
```

将写缓存(buffer)的内容写入文件，然后返回。

### make_oop_table_to_be_saved

```C
struct oop_s *
make_oop_table_to_be_saved (struct save_file_header *header)
{
  OOP oop;
  struct oop_s *myOOPTable;
  int i;

  num_used_oops = 0;

  for (oop = _gst_mem.ot; oop < &_gst_mem.ot[_gst_mem.ot_size];
       oop++)
    if (IS_OOP_VALID_GC (oop))
      num_used_oops = OOP_INDEX (oop) + 1;

  _gst_mem.num_free_oops = _gst_mem.ot_size - num_used_oops;
```

在 oop 表中查找有多少对象需要保存。

`OOP_INDEX` 位于 `libgst/oop.inl`，定义如下：

```C
/* Answer the index of OOP in the table.  */
#define OOP_INDEX(oop) \
  ( (OOP)(oop) - _gst_mem.ot )
```

给出的是 `oop` 在 oop 表中的索引(index)。

```C
  myOOPTable = xmalloc (sizeof (struct oop_s) * num_used_oops);

  for (i = 0, oop = _gst_mem.ot; i < num_used_oops; oop++, i++)
    {
      if (IS_OOP_VALID_GC (oop))
        {
          myOOPTable[i].flags = (oop->flags & ~F_RUNTIME) | F_OLD;
          myOOPTable[i].object = (gst_object) TO_INT (oop->object->objSize);
        }
      else
        {
          myOOPTable[i].flags = 0;
          header->num_free_oops++;
        }
    }
```

在 `myOOPTable` 数组成员的 `object` 域中，保存的是对应对象的大小(size)，而不是其地址。当在加载 [image 文件][gst-image]的时候，根据 `object` 域保存的对象尺寸(size)信息决定要从文件中读取多少数据来构造对应的对象。

### save_all_objects

```C
void
save_all_objects (int imageFd)
{
  OOP oop;

  for (oop = _gst_mem.ot; oop < &_gst_mem.ot[num_used_oops];
       oop++)
    if (IS_OOP_VALID_GC (oop))
      save_object (imageFd, oop);
}
```

`save_all_objects` 调用 `save_object` 逐个保存需要保留在 [image 文件][gst-image]中的对象。


### save_object

```C
void
save_object (int imageFd,
             OOP oop)
{
  gst_object object, saveObject;
  int numBytes;

  object = OOP_TO_OBJ (oop);
  
  numBytes = sizeof (OOP) * TO_INT (object->objSize);
  
  saveObject = malloc (numBytes);
  fixup_object (oop, saveObject, object, numBytes);
  buffer_write (imageFd, saveObject, numBytes);
  free (saveObject);
}
```

由于对象中可能包含一些和当前运行环境相关的内容，例如打开的文件、C 函数的地址，这些内容在当前正在生成的 [image 文件][gst-image]被加载的时候会变成无效信息，不应该保留在 [image 文件][gst-image]中，调用 `fix_object` 可以将其清除。


### save_file_version

```C
void
save_file_version (int imageFd, struct save_file_header *headerp)
{
  memcpy (headerp->dummy, EXECUTE, strlen (EXECUTE));
  memcpy (headerp->signature, SIGNATURE, strlen (SIGNATURE));
  headerp->flags = FLAGS_WRITTEN;
  headerp->version = VERSION_REQUIRED;
  headerp->oopTableSize = num_used_oops;
  headerp->edenSpaceSize = _gst_mem.eden.totalSize;
  headerp->survSpaceSize = _gst_mem.surv[0].totalSize;
  headerp->oldSpaceSize = _gst_mem.old->heap_limit;

  headerp->big_object_threshold = _gst_mem.big_object_threshold;
  headerp->grow_threshold_percent = _gst_mem.grow_threshold_percent;
  headerp->space_grow_rate = _gst_mem.space_grow_rate;
  headerp->ot_base = (intptr_t) _gst_mem.ot_base;
  memcpy (&headerp->prim_table_md5, _gst_primitives_md5, sizeof (_gst_primitives_md5));

  buffer_write (imageFd, headerp, sizeof (save_file_header));
}
```


## _gst_load_from_file

`_gst_load_from_file` 加载已有的 [image 文件][gst-image]以恢复其对应的 [Smalltalk][smalltalk] 系统的状态。

```C
mst_Boolean
_gst_load_from_file (const char *fileName)
{
  mst_Boolean loaded = 0;
  int imageFd;

  imageFd = _gst_open_file (fileName, "r");
  loaded = (imageFd >= 0) && load_snapshot (imageFd);

  close (imageFd);
  return (loaded);
}
```

`load_snapshot` 实现了实际的 [image 文件][gst-image]加载逻辑，和实际生成 [image 文件][gst-image]的 `save_to_fd` 的逻辑完全对应。

### load_snapshot

```C
mst_Boolean
load_snapshot (int imageFd)
{
  save_file_header header;
  int prim_table_matches;
  char *base, *end;

  base = buffer_read_init (imageFd, READ_BUFFER_SIZE);
  if (!load_file_version (imageFd, &header))
    return false;
```

首先加载 [image 文件][gst-image]头。

```C
  _gst_init_mem (header.edenSpaceSize, header.survSpaceSize,
                 header.oldSpaceSize, header.big_object_threshold,
                 header.grow_threshold_percent, header.space_grow_rate);

  _gst_init_oop_table ((PTR) header.ot_base,
                       MAX (header.oopTableSize * 2, INITIAL_OOP_TABLE_SIZE));
```

根据 [image 文件][gst-image]头中保留的信息创建 [heap][memory-management]，并创建 oop 表。

```C
  ot_delta = (intptr_t) (_gst_mem.ot_base) - header.ot_base;
  num_used_oops = header.oopTableSize;
  _gst_mem.num_free_oops = header.num_free_oops;
```

`ot_delta` 用来调整已加载 [image 文件][gst-image]中的对象的 OOP 成员，使其指向正确的地址。

```C
  load_oop_table (imageFd);
```

加载 oop 表。

```C
  end = load_normal_oops (imageFd);
  if (end)
    {
      _gst_mem.loaded_base = (OOP *) base;
      _gst_mem.loaded_end = (OOP *) end;
    }
```

逐个加载 [image 文件][gst-image]中的对象。

```C
  if (ot_delta)
    restore_all_pointer_slots ();
```

如若 [image 文件][gst-image]中保存的 oop 表的基地址(`ot_base`)和当前的 oop 表的基地址不一致，则需要调整已加载对象中的 `OOP` 成员，以使其指向正确的 oop 表成员。

```C
  prim_table_matches = !memcmp (header.prim_table_md5, _gst_primitives_md5,
                                sizeof (_gst_primitives_md5));
  if (_gst_init_dictionary_on_image_load (prim_table_matches))
      return (true);
```

最后，调用 `_gst_init_dictionary_on_image_load` (位于 `libgst/dict.c`) 初始化当前 [GNU Smalltalk][gst] 系统中的全局对象。


### load_normal_oops

```C
char *
load_normal_oops (int imageFd)
{
  OOP oop;
  int i;

  gst_object object = NULL;
  size_t size = 0;
  mst_Boolean use_copy_on_write
    =
#ifdef NO_SIGSEGV_HANDLING
      0 &&
#endif
      buf_used_mmap && ~wrong_endianness && ot_delta == 0;
```

`use_copy_on_write` 用来检测是否可以使用[写时复制(copy on write)][copy-on-write]来加速加载过程。

```C
  /* Now walk the oop table.  Load the data (or get the addresses from the
     mmap-ed area) and fix the byte order.  */

  _gst_mem.last_allocated_oop = &_gst_mem.ot[num_used_oops - 1];
  PREFETCH_START (_gst_mem.ot, PREF_WRITE | PREF_NTA);
  for (oop = _gst_mem.ot, i = num_used_oops; i--; oop++)
    {
      intptr_t flags;

      PREFETCH_LOOP (oop, PREF_WRITE | PREF_NTA);
      flags = oop->flags;
      if (IS_OOP_FREE (oop))
        continue;
```

`PREFETCH_START` 和 `PREFETCH_LOOP` 皆定义于 `libgst/gstpriv.h`，利用 CPU 的[缓存预取][cache-prefetching]来加速加载过程。

```C
      _gst_mem.numOldOOPs++;
      size = sizeof (PTR) * (size_t) oop->object;
      if (use_copy_on_write)
        {
          oop->flags |= F_LOADED;
          object = buffer_advance (imageFd, size);
        }
```

若可以用[写时复制(COW)][copy-on-write]技术加载 [image 文件]，那么在加载时并不需要从文件中显式的复制数据，只需要把数据所在的内存地址赋给 oop 表成员的对应域即可。

```C
      else
        {
          if (flags & F_FIXED)
            {
              _gst_mem.numFixedOOPs++;
              object = (gst_object) _gst_mem_alloc (_gst_mem.fixed, size);
            }
          else
            object = (gst_object) _gst_mem_alloc (_gst_mem.old, size);

          buffer_read (imageFd, object, size);
          if UNCOMMON (wrong_endianness)
            fixup_byte_order (object,
                              (flags & F_BYTE)
                              ? OBJ_HEADER_SIZE_WORDS
                              : size / sizeof (PTR));

          /* Would be nice, but causes us to touch every page and lose most
             of the startup-time benefits of copy-on-write.  So we only
             do it in the slow case, anyway.  */
          if (object->objSize != FROM_INT ((size_t) oop->object))
            abort ();
        }
```

若无法使用[写时复制][copy-on-write]，则需要在 [heap][memory-management] 中为对象分配内存，并将其内容从 [image 文件][gst-image]拷贝到新分配的内存中。

`COMMON` 和 `UNCOMMON` 位于 `libgst/gstpriv.h` 用来给 [C 语言][c]编译器提供[分支预测][branch-prediction]信息，以便其生成更高效的代码。

```C
      oop->object = object;
      if (flags & F_WEAK)
        _gst_make_oop_weak (oop);
    }
```

新恢复的对象，需要恰当的设置其属性。

```C
  /* NUM_OOPS requires access to the instance spec in the class
     objects. So we start by fixing the endianness of NON-BYTE objects
     (including classes!), for which we can do without NUM_OOPS, then
     do another pass here and fix the byte objects using the now
     correct class objects.  */
  if UNCOMMON (wrong_endianness)
    for (oop = _gst_mem.ot, i = num_used_oops; i--; oop++)
      if (oop->flags & F_BYTE)
        {
          OOP classOOP;
          object = OOP_TO_OBJ (oop);
          classOOP = OOP_ABSOLUTE (object->objClass);
          fixup_byte_order (object->data, CLASS_FIXED_FIELDS (classOOP));
        }
```

修正对象的 OOP 类型成员。

[TODO]: <> (添加链接)


```C
  if (!use_copy_on_write)
    {
      buffer_read_free (imageFd);
      return NULL;
    }
  else
    return ((char *)object) + size;
}
```

若没有使用[写时复制][copy-on-write]，则返回 `NULL`。


### restore_all_pointer_slots

```C
void
restore_all_pointer_slots ()
{
  OOP oop;

  for (oop = _gst_mem.ot; oop < &_gst_mem.ot[num_used_oops];
       oop++)
    if (IS_OOP_VALID_GC (oop))
      restore_oop_pointer_slots (oop);
}
```

`restore_all_pointer_slots` 只是逐个对有效的对象调用 `restore_oop_pointer_slots` 以修正其中的 OOP 类型成员。

### restore_oop_pointer_slots

```C
void
restore_oop_pointer_slots (OOP oop)
{
  int numPointers;
  gst_object object;
  OOP *i;

  object = OOP_TO_OBJ (oop);
  object->objClass = OOP_ABSOLUTE (object->objClass);

  numPointers = NUM_OOPS (object);
  for (i = object->data; numPointers--; i++)
    if (IS_OOP (*i))
      *i = OOP_ABSOLUTE (*i);
}
```

`object` 的内容直接来自 [image 文件][gst-image]，因此有

    object->objClass = headerp->ot_base + index
    
其中 `index` 是 `object->objClass` 在 oop 表中的索引，此索引不论是在生成 [image 文件][gst-image]时，还是在加载 [image 文件][gst-image]之后，都是相同的。由此可得

    index = object->objClass - headerp->ot_base
    
而在加载 [image 文件][gst-image]之后，`object->objClass` 的实际值应该为

      _gst_mem.ot_base + index
    = _gst_mem.ot_base + object->objClass - headerp->ot_base
    = object->objClass + (_gst_mem.ot_base - headerp->ot_base)
    = object->objClass + ot_delta
    
[TODO]: <> (此处应有图)

### fixup_object

`fixup_object` 用来清除对象中一些不适合保留在 [image 文件][gst-image]中的内容。

```C
void
fixup_object (OOP oop, gst_object dest, gst_object src, int numBytes)
{
  OOP class_oop;
  memcpy (dest, src, numBytes);

  /* Do the heavy work on the objects now rather than at load time, in order
     to make the loading faster.  In general, we should do this as little as
     possible, because it's pretty hard: the three cases below for Process,
     Semaphore and CallinProcess for example are just there to terminate all
     CallinProcess objects.  */

  class_oop = src->objClass;

  if (oop->flags & F_CONTEXT)
    {
      /* this is another quirk; this is not the best place to do
         it. We have to reset the nativeIPs so that we can find
         restarted processes and recompile their methods.  */
      gst_method_context context = (gst_method_context) dest;
      context->native_ip = DUMMY_NATIVE_IP;
    }

  else if (class_oop == _gst_callin_process_class)
    {
      gst_process process = (gst_process) dest;
      process->suspendedContext = _gst_nil_oop;
      process->nextLink = _gst_nil_oop;
      process->myList = _gst_nil_oop;
    }

  else if (class_oop == _gst_process_class)
    {
      /* Find the new next link.  */
      gst_process destProcess = (gst_process) dest;
      gst_process next = (gst_process) src;
      while (OOP_CLASS (next->nextLink) == _gst_callin_process_class)
        next = (gst_process) OOP_TO_OBJ (next->nextLink);

      destProcess->nextLink = next->nextLink;
    }
    
  else if (class_oop == _gst_semaphore_class)
    {
      /* Find the new first and last link.  */
      gst_semaphore destSem = (gst_semaphore) dest;
      gst_semaphore srcSem = (gst_semaphore) src;
      OOP linkOOP = srcSem->firstLink;

      destSem->firstLink = _gst_nil_oop;
      destSem->lastLink = _gst_nil_oop;
      while (!IS_NIL (linkOOP))
        {
          gst_process process = (gst_process) OOP_TO_OBJ (linkOOP);
          if (process->objClass != _gst_callin_process_class)
            {
              if (IS_NIL (destSem->firstLink))
                destSem->firstLink = linkOOP;
              destSem->lastLink = linkOOP;
            }
          linkOOP = process->nextLink;
        }
    }
    
  /* File descriptors are invalidated on resume.  */
  else if (is_a_kind_of (class_oop, _gst_file_descriptor_class))
    {
      gst_file_stream file = (gst_file_stream) dest;
      file->fd = _gst_nil_oop;
    }

  /* The other case is to reset CFunctionDescriptor objects, so that we'll
     relink the external functions when we reload the image.  */
  else if (is_a_kind_of (class_oop, _gst_c_callable_class))
    {
      gst_c_callable desc = (gst_c_callable) dest;
      if (desc->storageOOP == _gst_nil_oop)
        SET_COBJECT_OFFSET_OBJ (desc, 0);
    }
}
```




[links]: <> (Link list)

{% include Links.markdown %}

---
layout: post
title: libgst 的 _gst_initialize 函数
categories: libgst
---
* TOC
{:toc}



## 初始化的基本逻辑


`libgst` 的 `_gst_initialize` 函数的基本逻辑如下：

1. 加载 image 文件前：

   ```C
   _gst_init_snprintfv ();
   _gst_init_sysdep ();
   _gst_init_signals ();
   _gst_init_event_loop();
   _gst_init_cfuncs ();
   _gst_init_sockets ();
   _gst_init_primitives ();
   ```

2. 加载 image 文件成功：

   ```C
   _gst_init_interpreter ();
   _gst_init_vmproxy ();
   ```

3. 加载 image 文件失败：

   ```C
   _gst_init_oop_table (NULL, INITIAL_OOP_TABLE_SIZE);
   _gst_init_mem_default ();
   _gst_init_dictionary ();
   _gst_init_interpreter ();
   _gst_init_vmproxy ();

   _gst_install_initial_methods ();

   load_standard_files ();
   _gst_save_to_file (_gst_binary_image_name)
   ```

4. 加载或生成 image 文件之后：

   ```C
   _gst_invoke_hook (GST_RETURN_FROM_SNAPSHOT);
   _gst_process_file (user_init_file, GST_DIR_ABS);
   _gst_initialize_readline ();
   ```

## 加载 image 文件之前

### _gst_init_snprintfv

```C
void _gst_init_snprintfv ()
{
  spec_entry *spec;

  snv_malloc = xmalloc;
  snv_realloc = xrealloc;
  snv_free = xfree;
  spec = register_printf_function ('O', printf_generic,
                                   printf_oop_arginfo);

  spec->user = printf_oop;
}
```

`_gst_init_snprintfv` 定义于 `libgst/print.c`，用来初始化顶层目录的 snprintfv 模块，为 `printf` 注册格式化 `OOP` 类型数据的 `%O` modifier。

### _gst_init_sysdep

```C
void
_gst_init_sysdep (void)
{
  _gst_init_sysdep_timer ();
  tzset ();

#ifdef SIGPIPE
  _gst_set_signal_handler (SIGPIPE, SIG_IGN);
#endif
  _gst_set_signal_handler (SIGFPE, SIG_IGN);
#ifdef SIGPOLL
  _gst_set_signal_handler (SIGPOLL, SIG_IGN);
#elif defined SIGIO
  _gst_set_signal_handler (SIGIO, SIG_IGN);
#endif
#ifdef SIGURG
  _gst_set_signal_handler (SIGURG, SIG_IGN);
#endif
}
```

`_gst_init_sysdep` 定义于 `libgst/sysdep/common/files.c`，进行操作系统相关的初始化。

`_gst_init_sysdep_timer` 调用 `timer_create(2)` 为当前进程创建 timer。`tzset(3)` 初始化 [libc][glibc] 中时区相关信息。调用 `_gst_set_signal_handler` 来忽略一些信号。

### _gst_init_signals

```C
void
_gst_init_signals (void)
{ 
  if (!_gst_make_core_file)
    {
#ifdef ENABLE_JIT_TRANSLATION
      _gst_set_signal_handler (SIGILL, backtrace_on_signal);
#endif
      _gst_set_signal_handler (SIGABRT, backtrace_on_signal);
    }
  _gst_set_signal_handler (SIGTERM, backtrace_on_signal);
  _gst_set_signal_handler (SIGINT, interrupt_on_signal);
#ifdef SIGUSR1
  _gst_set_signal_handler (SIGUSR1, user_backtrace_on_signal);
#endif
}
```

`_gst_int_signals` 定义于 `libgst/interp.c`，使用 `_gst_set_signal_handler` 来为相关信号注册处理函数。

### _gst_init_event_loop

```C
void
_gst_init_event_loop()
{
#ifdef _WIN32
  InitializeCriticalSection(&state_cs);
  state_event = CreateEvent(NULL, TRUE, TRUE, NULL);
#endif 
}
```

`_gst_init_event_loop` 定义于 `libgst/events.c`。

### _gst_init_cfuncs

```C
void
_gst_init_cfuncs (void)
{
  extern char *getenv (const char *);

  cif_cache = pointer_map_create ();

  /* Access to command line args */
  _gst_define_cfunc ("getArgc", get_argc);
  _gst_define_cfunc ("getArgv", get_argv);
  
  /* ... */
  init_dld ();

  /* regex routines */
  _gst_define_cfunc ("reh_search", _gst_re_search);
  _gst_define_cfunc ("reh_match", _gst_re_match);
  _gst_define_cfunc ("reh_make_cacheable", _gst_re_make_cacheable);

  /* Non standard routines */
  _gst_define_cfunc ("marli", marli);
}
```

`_gst_init_cfuncs` 定义于 `libgst/cint.c`，初始化 [GNU Smalltalk][gst] 的和 [C 语言][c]交互的子系统。

`pointer_map_create` 来自 `lib-src/pointer-set.c`，实现了 pointer map。

`_gst_define_cfunc` 用来向 `c_func_root`[^1] 注册 [GNU Smalltalk][gst] 可识别的 [C 语言][c]函数，将函数名字符串和函数地址关联起来。`_gst_lookup_function` 可用来根据函数名字符串在 `c_func_root` 中查找其地址。

[^1]: `c_func_root` 是个二叉树(binary tree)，由 `lib-src/avltrees.h` 和 `lib-src/avltrees.c` 实现。

`init_dld` 用来初始化 [GNU Libtool][libtool] 的 [libltdl][libtool-ltdl]，以便在运行时加载动态链接库。

```C
void
init_dld (void)
{
  char *modules;
  lt_dlinit ();

  modules = _gst_relocate_path (MODULE_PATH);
  lt_dladdsearchdir (modules);
  free (modules);

  if ((modules = getenv ("SMALLTALK_MODULES")))
    lt_dladdsearchdir (modules);

  /* Too hard to support dlpreopen... LTDL_SET_PRELOADED_SYMBOLS(); */

  _gst_define_cfunc ("defineCFunc", _gst_define_cfunc);
  _gst_define_cfunc ("dldLink", dld_open);
  _gst_define_cfunc ("dldGetFunc", lt_dlsym);
  _gst_define_cfunc ("dldError", lt_dlerror);
}
```

### _gst_init_sockets

```C
void
_gst_init_sockets ()
{
#if defined WIN32 && !defined __CYGWIN__
  WSADATA wsaData;
  int iRet;
  iRet = WSAStartup(MAKEWORD(2,2), &wsaData);
  if (iRet != 0) {
    printf("WSAStartup failed (looking for Winsock 2.2): %d\n", iRet);
    return;
  }
#endif /* _WIN32 */

  _gst_define_cfunc ("TCPgetaddrinfo", getaddrinfo);
  _gst_define_cfunc ("TCPfreeaddrinfo", freeaddrinfo);
  _gst_define_cfunc ("TCPgetHostByAddr", myGetHostByAddr);
  _gst_define_cfunc ("TCPgetLocalName", myGetHostName);
  _gst_define_cfunc ("TCPgetAiCanonname", get_aiCanonname);
  _gst_define_cfunc ("TCPgetAiAddr", get_aiAddr);

  /* ... */
}
```

`_gst_init_sockets` 定义于 `libgst/sockets.c`，使用 `_gst_define_cfunc` 向 `c_func_root` 中注册和 socket 相关的函数。

### _gst_init_primitives

```C
void
_gst_init_primitives()
{
  int i;
  _gst_default_primitive_table[1].name = "VMpr_SmallInteger_plus";
  _gst_default_primitive_table[1].attributes = PRIM_SUCCEED | PRIM_FAIL;
  _gst_default_primitive_table[1].id = 0;
  _gst_default_primitive_table[1].func = VMpr_SmallInteger_plus;

  /* ... */
  
  for (i = 242; i < NUM_PRIMITIVES; i++)
    {
      _gst_default_primitive_table[i].name = NULL;
      _gst_default_primitive_table[i].attributes = PRIM_FAIL;
      _gst_default_primitive_table[i].id = i;
      _gst_default_primitive_table[i].func = VMpr_HOLE;
    }
}

```

`_gst_init_primitives` 定义于 `libgst/prims.inl`[^2]，用来初始化 `libgst` 的 primitive 列表 `_gst_default_primitive_table`，共包含 241 个 primitive。

[^2]: `prims.inl` 由 `genprims` 根据 `prims.def` 生成。


## 加载 image 文件成功

`_gst_initialize` 调用 `_gst_load_from_file (_gst_binary_image_name)` 来加载 image 文件。若是加载成功，则继续执行如下初始化动作。

### _gst_init_interpreter

```C
void
_gst_init_interpreter (void)
{
  unsigned int i;

#ifdef ENABLE_JIT_TRANSLATION
  _gst_init_translator ();
  ip = 0;
#else
  ip = NULL;
#endif

  _gst_this_context_oop = _gst_nil_oop;
  for (i = 0; i < MAX_LIFO_DEPTH; i++)
    lifo_contexts[i].flags = F_POOLED | F_CONTEXT;

  _gst_init_async_events ();
  _gst_init_process_system ();
}
```

`_gst_init_interpreter` 定义于 `libgst/interp.c`，用来初始化 [GNU Smalltalk][gst] 的[解释器][interpreter]。

若是启用了 [JIT][jit] 支持，则调用 `_gst_init_translator` (定义于 `libgst/xlat.c`) 初始化 [JIT][jit] 子系统。

`_gst_init_async_events` 定义于 `libgst/sysdep/posix/events.c`：

```C
void
_gst_init_async_events (void)
{
  _gst_set_signal_handler (SIGUSR2, dummy_signal_handler);
}
```

`_gst_init_process_system` 定义于 `libgst/interp.c`，用来初始化 [GNU Smalltalk][gst] 的进程(process)子系统：

```C
void
_gst_init_process_system (void)
{
  gst_processor_scheduler processor;
  int i;
  
  processor = (gst_processor_scheduler) OOP_TO_OBJ (_gst_processor_oop);
  if (IS_NIL (processor->processLists))
    {
      gst_object processLists;

      processLists = instantiate_with (_gst_array_class, NUM_PRIORITIES,
                                       &processor->processLists);

      for (i = 0; i < NUM_PRIORITIES; i++)
        processLists->data[i] = semaphore_new (0);
    } 
  
  if (IS_NIL (processor->processTimeslice))
    processor->processTimeslice =
      FROM_INT (DEFAULT_PREEMPTION_TIMESLICE);

  /* No process is active -- so highest_priority_process() need not
     worry about discarding an active process.  */
  processor->activeProcess = _gst_nil_oop;
  switch_to_process = _gst_nil_oop;
  activate_process (highest_priority_process ());
  set_preemption_timer ();
}
```


### _gst_init_vmproxy

```C
void
_gst_init_vmproxy (void)
{
  gst_interpreter_proxy.nilOOP = _gst_nil_oop;
  gst_interpreter_proxy.trueOOP = _gst_true_oop;
  gst_interpreter_proxy.falseOOP = _gst_false_oop;

  /* ... */
  
  /* And system objects.  */
  gst_interpreter_proxy.processorOOP = _gst_processor_oop;
}
```

`_gst_init_vmproxy` 定义于 `libgst/callin.c`，用来初始化 `libgst` 的全局变量 `gst_interpreter_proxy`。


## 加载 image 文件失败

若是 image 文件加载失败，则 [GNU Smalltalk][gst] 尝试如下初始化动作。

### _gst_init_oop_table

```C
void
_gst_init_oop_table (PTR address, size_t size)
{
  int i;

  oop_heap = NULL;
  for (i = MAX_OOP_TABLE_SIZE; i && !oop_heap; i >>= 1)
    oop_heap = _gst_heap_create (address, i * sizeof (struct oop_s));

  if (!oop_heap)
    nomemory (true);

  alloc_oop_table (size);

  _gst_nil_oop->flags = F_READONLY | F_OLD | F_REACHABLE;
  _gst_nil_oop->object = (gst_object) & _gst_nil_object;
  _gst_nil_object.objSize =
    FROM_INT (ROUNDED_WORDS (sizeof (struct gst_undefined_object)));

  _gst_true_oop->flags = F_READONLY | F_OLD | F_REACHABLE;
  _gst_true_oop->object = (gst_object) & _gst_boolean_objects[0];
  _gst_false_oop->flags = F_READONLY | F_OLD | F_REACHABLE;
  _gst_false_oop->object = (gst_object) & _gst_boolean_objects[1];
  _gst_boolean_objects[0].objSize =
    FROM_INT (ROUNDED_WORDS (sizeof (struct gst_boolean)));
  _gst_boolean_objects[1].objSize =
    FROM_INT (ROUNDED_WORDS (sizeof (struct gst_boolean)));
  _gst_boolean_objects[0].booleanValue = _gst_true_oop;
  _gst_boolean_objects[1].booleanValue = _gst_false_oop;

  for (i = 0; i < NUM_CHAR_OBJECTS; i++)
    {
      _gst_char_object_table[i].objSize =
        FROM_INT (ROUNDED_WORDS (sizeof (struct gst_character)));
      _gst_char_object_table[i].charVal = FROM_INT (i);
      _gst_mem.ot[i + CHAR_OBJECT_BASE].object =
        (gst_object) & _gst_char_object_table[i];
      _gst_mem.ot[i + CHAR_OBJECT_BASE].flags =
        F_READONLY | F_OLD | F_REACHABLE;
    }
}
```

`_gst_init_oop_table` 定义于 `libgst/oop.c`，用来分配并部分初始化 `libgst` 的 oop 表 (oop table)。

`_gst_heap_create` 定义于 `libgst/heap.c`，用来创建 [GNU Smalltalk][gst] 自行管理的[堆(heap)][memory-management]。Oop 表将会被创建于其中，此表的实际分配是在 `alloc_oop_table` 中完成的：

```C
void
alloc_oop_table (size_t size)
{
  size_t bytes;

  _gst_mem.ot_size = size;
  bytes = (size - FIRST_OOP_INDEX) * sizeof (struct oop_s);
  _gst_mem.ot_base =
    (struct oop_s *) _gst_heap_sbrk (oop_heap, bytes);
  if (!_gst_mem.ot_base)
    nomemory (true);

  _gst_mem.ot = &_gst_mem.ot_base[-FIRST_OOP_INDEX];
  _gst_nil_oop = &_gst_mem.ot[NIL_OOP_INDEX];
  _gst_true_oop = &_gst_mem.ot[TRUE_OOP_INDEX];
  _gst_false_oop = &_gst_mem.ot[FALSE_OOP_INDEX];

  _gst_mem.num_free_oops = size;
  _gst_mem.last_allocated_oop = _gst_mem.last_swept_oop = _gst_mem.ot - 1;
  _gst_mem.next_oop_to_sweep = _gst_mem.ot - 1;
}
```

[GNU Smalltalk][gst] oop 表的前 259 (256 + 3) 项是固定的：前 256 分别对应 [ASCII][ascii] 中的 256 个字符，然后依次是 `nil`、`true` 和 `false`。Oop 表的成员类型是 `struct oop_s`，此结构体成员包含指向实际对象的 `object` 指针，和包含此对象状态的标志位 `flags`。

[TODO]: <> (此处应有图来展示 OOP Table)

`_gst_mem` 的类型为 `struct memory_space`，用来表示 [GNU Smalltalk][gst] 的 [garbage collector (gc)][gc] 实际管理的内存。

### _gst_init_mem_default

```C
void
_gst_init_mem_default ()
{
  _gst_init_mem (0, 0, 0, 0, 0, 0);
}
```

`_gst_init_mem_default` 定义于 `libgst/oop.c`，通过调用 `_gst_init_mem` 来给 `_gst_mem` 成员设置默认值。

### _gst_init_dictionary

```C
void
_gst_init_dictionary (void)
{
  memcpy (_gst_primitive_table, _gst_default_primitive_table,
          sizeof (_gst_primitive_table));

  /* The order of this must match the indices defined in oop.h!! */
  _gst_smalltalk_dictionary = alloc_oop (NULL, _gst_mem.active_flag);
  _gst_processor_oop = alloc_oop (NULL, _gst_mem.active_flag);
  _gst_symbol_table = alloc_oop (NULL, _gst_mem.active_flag);

  _gst_init_symbols_pass1 ();

  create_classes_pass1 (class_info, sizeof (class_info) / sizeof (class_info[0]));

  init_proto_oops();
  _gst_init_symbols_pass2 ();
  init_smalltalk_dictionary ();

  create_classes_pass2 (class_info, sizeof (class_info) / sizeof (class_info[0]));

  init_runtime_objects ();
  _gst_tenure_all_survivors ();
}
```

`_gst_init_dictionary` 定义于 `libgst/dict.c`，初始化 `libgst` 里的 primitive 表 `_gst_primitive_table`，创建[核心类(kernel classes)][gst-base-classes]。

在初始化 `_gst_smalltalk_dictionary`、`_gst_processor_oop` 和 `_gst_symbol_table` 的时候，必须按照此顺序，这样 `alloc_oop` 会由低到高分别为它们分配在 oop 表中的下标，正好分别和在 `libgst/oop.h` 中定义的 `SMALLTALK_OOP_INDEX`、`PROCESSOR_OOP_INDEX` 和 `SYM_TABLE_OOP_INDEX` 对应。在加载 image 文件的时候，`_gst_init_dictionary_on_image_load` 直接使用这些下标在 oop 表中查找对应的全局变量。

[GNU Smalltalk][gst] [核心类][gst-base-classes]的创建过程分两个阶段：先创建所有的类对象(class object)[^3]，然后再依次分别初始化。

[^3]: 在 [Smalltalk][smalltalk] 中，类(class)本身也是对象(object)，是其对应的 metaclass 的实例。

[TODO]: <> (详述 _gst_init_dictionary 的实现)


### _gst_init_interpreter

`_gst_init_interpreter` 定义于 `libgst/interp.c`，初始化虚拟机。

[TODO]: <> (添加链接)


### _gst_init_vmproxy

`_gst_init_vmproxy` 定义于 `libgst/callin.c`，初始化全局变量 `gst_interpreter_proxy`。

[TODO]: <> (添加链接)


### _gst_install_initial_methods

```C
void
_gst_install_initial_methods (void)
{
  /* Define the termination method first of all, because
     compiling #methodsFor: will invoke an evaluation
     (to get the argument of the <primitive: ...> attribute.  */
  _gst_alloc_bytecodes ();
  _gst_compile_byte (EXIT_INTERPRETER, 0);
  _gst_compile_byte (JUMP_BACK, 4);

  /* The zeros are primitive, # of args, # of temps, stack depth */
  termination_method = _gst_make_new_method (0, 0, 0, _gst_nil_oop,
                                             _gst_nil_oop,
                                             _gst_get_bytecodes (),
                                             _gst_undefined_object_class,
                                             _gst_terminate_symbol,
                                             _gst_string_new ("private"),
                                             -1, -1);

  ((gst_compiled_method) OOP_TO_OBJ (termination_method))->header.headerFlag
    = MTH_ANNOTATED;

  install_method (termination_method, _gst_undefined_object_class);
}
```

`_gst_install_initial_methods` 定义于 `libgst/comp.c`，手工构造了 `UndefinedObject>>__terminate` [^4] 方法，以备加载 `kernel` 目录下的 [Smalltalk][smalltalk] 源码文件。

[^4]: `UndefinedObject>>__terminate` 表示类 `UndefinedObject` 的 `__terminate` 方法。


### load_standard_files

`load_standard_files` 定义于 `libgst/files.c`，用来加载 `kernel` 目录下的 [Smalltalk][smalltalk] 源码文件。

[TODO]: <> (添加链接)

### _gst_save_to_file

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

  _gst_invoke_hook (GST_FINISHED_SNAPSHOT);
  errno = save_errno;
  return success;
}
```

`_gst_save_to_file` 定义于 `libgst/save.c`，将当前 [GNU Smalltalk][gst] 系统的快照(snapshot)写入 image 文件。

[TODO]: <> (详述 `_gst_save_to_file` 的实现)


## 加载或生成 image 文件之后

加载或生成 image 文件之后，`libgst` 继续剩余的初始化动作。

### 执行 GST_RETURN_FROM_SNAPSHOT hook

```C
_gst_invoke_hook (GST_RETURN_FROM_SNAPSHOT);
```

`_gst_invoke_hook` 定义于 `libgst/comp.c`。

### 加载用户的初始化文件

```C
_gst_process_file (user_init_file, GST_DIR_ABS);
```

`_gst_process_file` 定义于 `libgst/input.c`。

### 初始化 GNU Readline

```C
#ifdef HAVE_READLINE
  _gst_initialize_readline ();
#endif /* HAVE_READLINE */
```

若在配置(configuration)阶段发现可以支持 [GNU Readline][readline]，则调用 `_gst_initialize_readline` 初始化 [GNU Readline][readline]，该函数定义于 `libgst/input.c`。

----

[links]: <> (Link list)

{% include Links.markdown %}

---
layout: post
title: 字典(dictionary)模块 (libgst/dict.c) -- 初始化相关
categories: ligst dictionary
---
* TOC
{:toc}


`libgst` 的字典(dictionary)模块由三部分构成：
* `dict.h` 声明了模块的接口，包括类型和函数原型；
* `dict.c` 实现了 `dict.h` 声明的函数；
* `dict.inl` 通过 `gstpriv.h` 被包含，定义了一些内联(inline)函数和宏。

## 类型及变量定义

```C
typedef struct class_definition
{
  OOP *classVar;
  OOP *superClassPtr;
  intptr_t instanceSpec;
  mst_Boolean reloadAddress;
  int numFixedFields;
  const char *name;
  const char *instVarNames;
  const char *classVarNames;
  const char *sharedPoolNames;
}
class_definition;
```

结构体类型 `class_definition` 给出了定义类(class)时需要的信息。


```C
/* Primary class variables.  These variables hold the class objects for
   most of the builtin classes in the system */
OOP _gst_abstract_namespace_class = NULL;
OOP _gst_array_class = NULL;
OOP _gst_arrayed_collection_class = NULL;
/* ... */
```

[GNU Smalltalk][gst] 里面的内置类(class)基本都有一个对应的全局变量。


```C
/* The class definition structure.  From this structure, the initial
   set of Smalltalk classes are defined.  */

static const class_definition class_info[] = {
  {&_gst_object_class, &_gst_nil_oop,
   GST_ISP_FIXED, true, 0,
   "Object", NULL, "Dependencies FinalizableObjects", "VMPrimitives" },

  /* ... */
/* Classes not defined here (like Point/Rectangle/RunArray) are
   defined after the kernel has been fully initialized.  */
};
```

全局数组 `class_info` 中包含了 [GNU Smalltalk][gst] 内置类的初始信息。

```C
signed char _gst_log2_sizes[32] = {
  0, -1, 0, -1, 0, -1,
  1, -1, 1, -1,
  2, -1, 2, -1, 2, -1,
  3, -1, 3, -1, 3, -1,
  2, -1,
  -1, -1, -1, -1, -1, -1,
  sizeof (long) == 4 ? 2 : 3, -1
};
```

`_gst_log2_sizes` 应和 `libgst/gstpriv.h` 中的 `gst_indexed_kind` 结合在一起看，其使用在 `dict.inl` 和 `prims.def` 中。

[TODO]: <> (详述 _gst_log2_sizes 的使用)


## _gst_init_dictionary

```C
void
_gst_init_dictionary (void)
{
  memcpy (_gst_primitive_table, _gst_default_primitive_table,
          sizeof (_gst_primitive_table));
```

使用 `_gst_default_primitive_table` (定义于 `libgst/prims.inl`) 来初始化 `_gst_primitive_table`。

```C
  /* The order of this must match the indices defined in oop.h!! */
  _gst_smalltalk_dictionary = alloc_oop (NULL, _gst_mem.active_flag);
  _gst_processor_oop = alloc_oop (NULL, _gst_mem.active_flag);
  _gst_symbol_table = alloc_oop (NULL, _gst_mem.active_flag);
```

`alloc_oop` 在分配 oop 表的下标(index)的时候，会选取当前可用的最小下标。由于在调用 `_gst_init_dictionary` 的时候，还没有分配任何的 oop，因此 `_gst_smalltalk_dictionary`、`_gst_processor_oop` 和 `_gst_symbol_table` 会依次获取下标 `0`、`1` 和 `2`，和在 `libgst/oop.h` 中定义的 `SMALLTALK_OOP_INDEX`、`PROCESSOR_OOP_INDEX` 和 `SYM_TABLE_OOP_INDEX` 的值相一致。在加载 [image 文件][gst-image]的过程中，会在 `_gst_init_dictionary_on_image_load` 中直接使用这些预处理宏的值作为下标去访问对应的 OOP。

[TODO]: <> (添加链接)

```C
  _gst_init_symbols_pass1 ();

  create_classes_pass1 (class_info, COUNT_OF (class_info));
```

根据 `class_info` 的信息逐个创建核心(kernel)类，并部分初始化。

```C
  init_proto_oops();
  _gst_init_symbols_pass2 ();
  init_smalltalk_dictionary ();

  create_classes_pass2 (class_info, COUNT_OF (class_info));

  init_runtime_objects ();
```

完成核心类的初始化。

```C
  _gst_tenure_all_survivors ();
}
```

将所有现存对象转入老年代。

[TODO]: <> (添加链接)

## _gst_init_symbols_pass1

`_gst_init_symbols_pass1` 定义于 `libgst/sym.c`，用来完成对全局变量 `sym_info` 和 `_gst_builtin_selectors` 的初始化，其中包含了[虚拟机][hllca]所知道的所有符号(symbol)。

## create_classes_pass1

```C
void
create_classes_pass1 (const class_definition *ci,
                      int n)
{
  OOP superClassOOP;
  int nilSubclasses;
  gst_class classObj, superclass;

  for (nilSubclasses = 0; n--; ci++)
    {
      superClassOOP = *ci->superClassPtr;
      create_class (ci);

      if (IS_NIL (superClassOOP))
        nilSubclasses++;
      else
        {
          superclass = (gst_class) OOP_TO_OBJ (superClassOOP);
          superclass->subClasses =
            FROM_INT (TO_INT (superclass->subClasses) + 1);
        }
    }
```

调用 `create_class` 逐个创建 `class_info` 指定的类。

```C
  /* Object class being a subclass of gst_class is not an apparent link,
     and so the index which is the number of subclasses of the class
     is off by the number of subclasses of nil.  We correct that here.

     On the other hand, we don't want the meta class to have a subclass
     (`Class class' and `Class' are unique in that they don't have the
     same number of subclasses), so since we have the information here,
     we special case the Class class and create its metaclass here.  */
  classObj = (gst_class) OOP_TO_OBJ (_gst_class_class);
  create_metaclass (_gst_class_class,
                    TO_INT (classObj->subClasses),
                    TO_INT (classObj->subClasses) + nilSubclasses);
}
```

创建 `Class` 和 `Class class`。

[TODO]: <> (关于 Class class 和 Class 的更多介绍)

### create_class

```C
void
create_class (const class_definition *ci)
{
  gst_class class;
  intptr_t superInstanceSpec;
  OOP classOOP, superClassOOP;
  int numFixedFields;

  numFixedFields = ci->numFixedFields;
  superClassOOP = *ci->superClassPtr;
  if (!IS_NIL (superClassOOP))
    {
      /* adjust the number of instance variables to account for
         inheritance */
      superInstanceSpec = CLASS_INSTANCE_SPEC (superClassOOP);
      numFixedFields += superInstanceSpec >> ISP_NUMFIXEDFIELDS;
    }
```

若要创建的类(class)有父类(superclass)，则将其固定域(fixed field)的数量累加到当前类的固定域数量中。

```C
  class = (gst_class) _gst_alloc_obj (sizeof (struct gst_class), &classOOP);
```

在 [GNU Smalltalk][gst] 的 [GC][gc] 管理的内存(也即 heap)中为当前正在创建的类分配内存[^1]。

[^1]: 在 [Smalltalk][smalltalk] 中一切皆对象，类(class)本身也是一个对象。

```C
  class->objClass = NULL;
  class->superclass = superClassOOP;
  class->instanceSpec = GST_ISP_INTMARK
    | ci->instanceSpec
    | (numFixedFields << ISP_NUMFIXEDFIELDS);

  class->subClasses = FROM_INT (0);

  *ci->classVar = classOOP;
}
```

初始化新创建的类。

[TODO]: <> (添加对 instanceSpec 使用的描述)


### create_metaclass

```C
void
create_metaclass (OOP class_oop,
                  int numMetaclassSubClasses,
                  int numSubClasses)
{
  gst_class class;
  gst_metaclass metaclass;
  gst_object subClasses;

  class = (gst_class) OOP_TO_OBJ (class_oop);
  metaclass = (gst_metaclass) new_instance (_gst_metaclass_class,
                                            &class->objClass);
```

所有元类(metaclass)[^2]都是 `Metaclass` 的实例(instance)。`new_instance` (定义于 `libgst/dict.inl`) 为 `class` 指定的类创建对应的元类，并将此新创建的元类的 oop 保存到 `class->objClass` 中，表示类对象 `class` 的类是对象 `metaclass`。

[^2]: 普通的类(class)对象是元类(metaclass)的实例。

```C
  metaclass->instanceClass = class_oop;
```

每个元类只有唯一的实例。

```C
  subClasses = new_instance_with (_gst_array_class, numSubClasses,
                                  &class->subClasses);
  if (numSubClasses > 0)
    subClasses->data[0] = FROM_INT (numSubClasses);

  subClasses = new_instance_with (_gst_array_class, numMetaclassSubClasses,
                                  &metaclass->subClasses);
  if (numMetaclassSubClasses > 0)
    subClasses->data[0] = FROM_INT (numMetaclassSubClasses);
}
```

分别创建类和其元类的子类(subclass)列表。

#### new_instance

`new_instance` 定义于 `libgst/dict.inl`。

```C
gst_object
new_instance (OOP class_oop,
              OOP *p_oop)
{
  size_t numBytes;
  intptr_t instanceSpec;
  gst_object p_instance;

  instanceSpec = CLASS_INSTANCE_SPEC (class_oop);
  numBytes = sizeof (gst_object_header) +
    SIZE_TO_BYTES(instanceSpec >> ISP_NUMFIXEDFIELDS);

  p_instance = _gst_alloc_obj (numBytes, p_oop);
  p_instance->objClass = class_oop;

  return p_instance;
}
```

`new_instance` 创建不包含可索引域(indexable field)的类的实例(instance)。

`instanceSpec >> ISP_NUMFIXEDFIELDS` 指定了类 `class_oop` 的实例中包含多少固定域(fixed field)。


#### new_instance_with

`new_instance_with` 定义于 `libgst/dict.inl`。

```C
gst_object
new_instance_with (OOP class_oop,
                   size_t numIndexFields,
                   OOP *p_oop)
{
  size_t numBytes, alignedBytes;
  intptr_t instanceSpec;
  gst_object p_instance;

  instanceSpec = CLASS_INSTANCE_SPEC (class_oop);
  numBytes = sizeof (gst_object_header)
    + SIZE_TO_BYTES(instanceSpec >> ISP_NUMFIXEDFIELDS)
    + (numIndexFields << _gst_log2_sizes[instanceSpec & ISP_SHAPE]);

  alignedBytes = ROUNDED_BYTES (numBytes);
  p_instance = _gst_alloc_obj (alignedBytes, p_oop);
  INIT_UNALIGNED_OBJECT (*p_oop, alignedBytes - numBytes);

  p_instance->objClass = class_oop;

  return p_instance;
}
```

`new_instance_with` 创建包含 `numIndexFields` 个可索引域(indexable field)的类的实例(instance)。

可索引域(indexable field)的类型可通过枚举 `gst_indexed_kind` 类型(定义于 `libgst/gst.h`)的常量，例如 `GST_ISP_FIXED`、`GST_ISP_POINTER`，来指定。不同类型的可索引域的大小(size)不同，通过 `_gst_log2_sizes` (定义于 `libgst/dict.c`)指定，具体关系如下：

```C
numIndexFields << _gst_log2_sizes[instanceSpec & ISP_SHAPE]
```

例如 `GST_ISP_INT` 为 42，`GST_ISP_INT & ISP_SHAPE` 为 10，`_gst_log2_sizes[10]` 为 2，而 `numIndexFields << 2` 等于 `numIndexFields * 4`，也即 `int` 类型的可索引域的大小(size)为 4 字节(byte)。

## init_proto_oops

```C
void
init_proto_oops()
{
  gst_namespace smalltalkDictionary;
  gst_object symbolTable, processorScheduler;
  int numWords;

  /* We can do this now that the classes are defined */
  _gst_init_builtin_objects_classes ();
```

`_gst_init_builtin_objects_classes` 定义于 `libgst/oop.c`，初始化内置(builtin)对象 `nil`、`true`、`false` 和 [ASCII][ascii] 码字符对象。

```C
  /* Also finish the creation of the OOPs with reserved indices in
     oop.h */

  /* the symbol table ...  */
  numWords = OBJ_HEADER_SIZE_WORDS + SYMBOL_TABLE_SIZE;
  symbolTable = _gst_alloc_words (numWords);
  SET_OOP_OBJECT (_gst_symbol_table, symbolTable);

  symbolTable->objClass = _gst_array_class;
  nil_fill (symbolTable->data,
	    numWords - OBJ_HEADER_SIZE_WORDS);
```

创建 `SymbolTable`。

[TODO]: <> (添加链接)

```C
  /* 5 is the # of fixed instvars in gst_namespace */
  numWords = OBJ_HEADER_SIZE_WORDS + INITIAL_SMALLTALK_SIZE + 5;

  /* ... now the Smalltalk dictionary ...  */
  smalltalkDictionary = (gst_namespace) _gst_alloc_words (numWords);
  SET_OOP_OBJECT (_gst_smalltalk_dictionary, smalltalkDictionary);

  smalltalkDictionary->objClass = _gst_system_dictionary_class;
  smalltalkDictionary->tally = FROM_INT(0);
  smalltalkDictionary->name = _gst_smalltalk_namespace_symbol;
  smalltalkDictionary->superspace = _gst_nil_oop;
  smalltalkDictionary->subspaces = _gst_nil_oop;
  smalltalkDictionary->sharedPools = _gst_nil_oop;
  nil_fill (smalltalkDictionary->assoc,
	    INITIAL_SMALLTALK_SIZE);
```

创建 `Smalltalk`。

[TODO]: <> (添加链接)

```C
  /* ... and finally Processor */
  numWords = sizeof (struct gst_processor_scheduler) / sizeof (PTR);
  processorScheduler = _gst_alloc_words (numWords);
  SET_OOP_OBJECT (_gst_processor_oop, processorScheduler);

  processorScheduler->objClass = _gst_processor_scheduler_class;
  nil_fill (processorScheduler->data,
	    numWords - OBJ_HEADER_SIZE_WORDS);
}
```

创建 `Processor`。

[TODO]: <> (添加链接)


## _gst_init_symbols_pass2

`_gst_init_symbols_pass2` 定义于 `libgst/sym.c`，为 `_gst_init_symbols_pass1` 创建的符号(symbol)创建对应的 `SymLink` 对象，并将其添加到 `SymbolTable`。

[TODO]: <> (添加链接)

## init_smalltalk_dictionary

```C
void
init_smalltalk_dictionary (void)
{
  OOP featuresArrayOOP;
  gst_object featuresArray;
  char fullVersionString[200];
  int i, numFeatures;

  _gst_current_namespace = _gst_smalltalk_dictionary;
```

将当前[名字空间(namespace)][gst-namespace]设置为 `Smalltalk`。

[TODO]: <> (添加链接)

```C
  for (numFeatures = 0; feature_strings[numFeatures]; numFeatures++)
	  ;

  featuresArray = new_instance_with (_gst_array_class, numFeatures,
		     		     &featuresArrayOOP);

  for (i = 0; i < numFeatures; i++)
    featuresArray->data[i] = _gst_intern_string (feature_strings[i]);
```

根据 `feature_strings` 里面定义的特性(feature)名字来初始化特性列表。

[TODO]: <> (更详细的解释 feature)

```C
  snprintf (fullVersionString, sizeof (fullVersionString),
	   "GNU Smalltalk version %s", VERSION PACKAGE_GIT_REVISION);

  add_smalltalk ("Smalltalk", _gst_smalltalk_dictionary);
  add_smalltalk ("Version", _gst_string_new (fullVersionString));
  add_smalltalk ("KernelFilePath", _gst_string_new (_gst_kernel_file_path));
  add_smalltalk ("KernelInitialized", _gst_false_oop);
  add_smalltalk ("SymbolTable", _gst_symbol_table);
  add_smalltalk ("Processor", _gst_processor_oop);
  add_smalltalk ("Features", featuresArrayOOP);
```

将一些关键全局变量对象添加到根[名字空间][gst-namespace] `Smalltalk` 中。

[TODO]: <> (添加详细描述)

```C
  /* Add subspaces */
  add_smalltalk ("CSymbols",
    namespace_new (32, "CSymbols", _gst_smalltalk_dictionary));
```

将子[名字空间][gst-namespace] `CSymbols` 添加到根[名字空间][gst-namespace] `Smalltalk` 中。

```C
  init_primitives_dictionary ();
```

创建 `VMPrimitives` 并将其添加到根[名字空间][gst-namespace] `Smalltalk`。

[TODO]: <> (添加链接)

```C
  add_smalltalk ("Undeclared",
    namespace_new (32, "Undeclared", _gst_nil_oop));
```

创建根[名字空间][gst-namespace] `Undeclared`。

```C
  add_smalltalk ("SystemExceptions",
    namespace_new (32, "SystemExceptions", _gst_smalltalk_dictionary));
  add_smalltalk ("NetClients",
    namespace_new (32, "NetClients", _gst_smalltalk_dictionary));
  add_smalltalk ("VFS",
    namespace_new (32, "VFS", _gst_smalltalk_dictionary));
```

在根[名字空间][gst-namespace] `Smalltalk` 中分别创建子[名字空间][gst-namespace] `SystemExceptions`、`NetClients` 和 `VFS`。

[TODO]: <> (添加详细描述)

```C
  _gst_init_process_system ();
}
```

`_gst_init_process_system` 定义于 `libgst/interp.c`，用来初始化 [GNU Smalltalk][gst] 的[进程调度器][process-scheduler]。

[TODO]: <> (添加链接)

### add_smalltalk

```C
static OOP
add_smalltalk (const char *globalName,
               OOP globalValue)
{
  NAMESPACE_AT_PUT (_gst_smalltalk_dictionary,
                    _gst_intern_string (globalName), globalValue);

  return globalValue;
}
```

`NAMESPACE_AT_PUT` 定义于 `libgst/dict.inl`，是对 `_gst_dictionary_add` 的封装，用来向[名字空间][gst-namespace]添加新的成员。

## create_classes_pass2

```C
void
create_classes_pass2 (const class_definition *ci,
                      int n)
{
  OOP class_oop;
  gst_class class;
  int numSubclasses;

  for (; n--; ci++)
    {
      class_oop = *ci->classVar;
      class = (gst_class) OOP_TO_OBJ (class_oop);

      if (!class->objClass)
        {
          numSubclasses = TO_INT (class->subClasses);
          create_metaclass (class_oop, numSubclasses, numSubclasses);
        }

      init_metaclass (class->objClass);
      init_class (class_oop, ci);
    }
}
```

逐个为 `class_info` 中定义的核心(kernel)类创建元类(metaclass)，并初始化元类对象和类对象。

[TODO]: <> (添加详细描述)

### init_metaclass

```C
void
init_metaclass (OOP metaclassOOP)
{
  gst_metaclass metaclass;
  OOP class_oop, superClassOOP;

  metaclass = (gst_metaclass) OOP_TO_OBJ (metaclassOOP);
  class_oop = metaclass->instanceClass;
  superClassOOP = SUPERCLASS (class_oop);

  if (IS_NIL (superClassOOP))
    /* Object case: make this be gst_class to close the circularity */
    metaclass->superclass = _gst_class_class;
  else
    metaclass->superclass = OOP_CLASS (superClassOOP);

  add_subclass (metaclass->superclass, metaclassOOP);

  /* the specifications here should match what a class should have:
     instance variable names, the right number of instance variables,
     etc.  We could take three passes, and use the instance variable
     spec for classes once it's established, but it's easier to create
     them here by hand */
  metaclass->instanceVariables =
    _gst_make_instance_variable_array (_gst_nil_oop,
				       "superClass methodDictionary instanceSpec subClasses "
				       "instanceVariables name comment category environment "
				       "classVariables sharedPools "
				       "pragmaHandlers");

  metaclass->instanceSpec = GST_ISP_INTMARK | GST_ISP_FIXED |
    (((sizeof (struct gst_class) -
       sizeof (gst_object_header)) /
      sizeof (OOP)) << ISP_NUMFIXEDFIELDS);

  metaclass->methodDictionary = _gst_nil_oop;
}
```

[TODO]: <> (添加链接)

### init_class

```C
void
init_class (OOP class_oop, const class_definition *ci)
{
  gst_class class;

  class = (gst_class) OOP_TO_OBJ (class_oop);
  class->name = _gst_intern_string (ci->name);
  add_smalltalk (ci->name, class_oop);

  if (!IS_NIL (class->superclass))
    add_subclass (class->superclass, class_oop);

  class->environment = _gst_smalltalk_dictionary;
  class->instanceVariables =
    _gst_make_instance_variable_array (class->superclass, ci->instVarNames);
  class->classVariables =
    _gst_make_class_variable_dictionary (ci->classVarNames, class_oop);

  class->sharedPools = _gst_make_pool_array (ci->sharedPoolNames);

  /* Other fields are set by the Smalltalk code.  */
  class->methodDictionary = _gst_nil_oop;
  class->comment = _gst_nil_oop;
  class->category = _gst_nil_oop;
  class->pragmaHandlers = _gst_nil_oop;
}
```

[TODO]: <> (添加详细解释和链接)

#### add_subclass

```C
void
add_subclass (OOP superClassOOP,
              OOP subClassOOP)
{
  gst_class_description superclass;
  int index;

  superclass = (gst_class_description) OOP_TO_OBJ (superClassOOP);

#ifndef OPTIMIZE
  if (NUM_WORDS (OOP_TO_OBJ (superclass->subClasses)) == 0)
    {
      _gst_errorf ("Attempt to add subclass to zero sized class");
      abort ();
    }
#endif

  index = TO_INT (ARRAY_AT (superclass->subClasses, 1));
  ARRAY_AT_PUT (superclass->subClasses, 1, FROM_INT (index - 1));
  ARRAY_AT_PUT (superclass->subClasses, index, subClassOOP);
}
```

[TODO]: <> (添加详细解释)


## init_runtime_objects

```C
void
init_runtime_objects (void)
{
  add_smalltalk ("UserFileBasePath", _gst_string_new (_gst_user_file_base_path));

  add_smalltalk ("SystemKernelPath", relocate_path_oop (KERNEL_PATH));
  add_smalltalk ("ModulePath", relocate_path_oop (MODULE_PATH));
  add_smalltalk ("LibexecPath", relocate_path_oop (LIBEXEC_PATH));
  add_smalltalk ("Prefix", relocate_path_oop (PREFIX));
  add_smalltalk ("ExecPrefix", relocate_path_oop (EXEC_PREFIX));
  add_smalltalk ("ImageFilePath", _gst_string_new (_gst_image_file_path));
  add_smalltalk ("ExecutableFileName", _gst_string_new (_gst_executable_path));
  add_smalltalk ("ImageFileName", _gst_string_new (_gst_binary_image_name));
  add_smalltalk ("OutputVerbosity", FROM_INT (_gst_verbosity));
  add_smalltalk ("RegressionTesting",
		 _gst_regression_testing ? _gst_true_oop : _gst_false_oop);

#ifdef WORDS_BIGENDIAN
  add_smalltalk ("Bigendian", _gst_true_oop);
#else
  add_smalltalk ("Bigendian", _gst_false_oop);
#endif

  add_file_stream_object (0, O_RDONLY, "stdin");
  add_file_stream_object (1, O_WRONLY, "stdout");
  add_file_stream_object (2, O_WRONLY, "stderr");

  init_c_symbols ();

  /* Add the root among the roots :-) to the root set */
  _gst_register_oop (_gst_smalltalk_dictionary);
}
```

`relocate_path_oop` 将 `relocate_path_oop` 添加到 [GC][gc] 的 root set 中，以免 `Smalltalk` 及其指向的对象被 [GC][gc] 回收。

[TODO]: <> (添加链接)

### init_c_symbols

```C
void
init_c_symbols ()
{
  OOP cSymbolsOOP = dictionary_at (_gst_smalltalk_dictionary,
                                   _gst_intern_string ("CSymbols"));

  NAMESPACE_AT_PUT (cSymbolsOOP, _gst_intern_string ("HostSystem"),
                    _gst_string_new (HOST_SYSTEM));

  /* ... */
}
```

向 `Smalltalk.CSymbols` 中添加符号(symbol)。

[TODO]: <> (添加链接)

## _gst_init_dictionary_on_image_load

`_gst_init_dictionary_on_image_load` 是加载 [image 文件][gst-image]的最后一步。

[TODO]: <> (添加链接)

```C
mst_Boolean
_gst_init_dictionary_on_image_load (mst_Boolean prim_table_matches)
{
  const class_definition *ci;

  _gst_smalltalk_dictionary = OOP_AT (SMALLTALK_OOP_INDEX);
  _gst_processor_oop = OOP_AT (PROCESSOR_OOP_INDEX);
  _gst_symbol_table = OOP_AT (SYM_TABLE_OOP_INDEX);

  if (IS_NIL (_gst_processor_oop) || IS_NIL (_gst_symbol_table)
      || IS_NIL (_gst_smalltalk_dictionary))
    return (false);
```

直接根据 `libgst/oop.h` 定义的下标(index)在 oop 表中获取 `_gst_smalltalk_dictionary` 等变量对应的对象。

```C
  _gst_restore_symbols ();
```

`_gst_restore_symbols` 定义于 `libgst/sym.c`，和 `_gst_init_symbols_pass1` 作用类似。

```C
  for (ci = class_info; ci < class_info + COUNT_OF (class_info); ci++)
    if (ci->reloadAddress)
      {
	*ci->classVar = dictionary_at (_gst_smalltalk_dictionary,
				       _gst_intern_string (ci->name));
        if UNCOMMON (IS_NIL (*ci->classVar))
	  return (false);
      }
```

根据 [image 文件][gst-image]文件的内容完成 `class_info` 的初始化。

```C
  _gst_current_namespace =
    dictionary_at (_gst_class_variable_dictionary (_gst_namespace_class),
		   _gst_intern_string ("Current"));
```

恢复保存的当前[名字空间(namespace)][gst-namespace]。

```C
  _gst_init_builtin_objects_classes ();
```

初始化内置(builtin)对象。

```C
  /* Important: this is called *after* _gst_init_symbols
     fills in _gst_vm_primitives_symbol! */
  if (prim_table_matches)
    memcpy (_gst_primitive_table, _gst_default_primitive_table,
            sizeof (_gst_primitive_table));
  else
    prepare_primitive_numbers_table ();
```

若是 [image 文件][gst-image]中保存的 primitive 列表的 [MD5][md5] 值和 `_gst_default_primitive_table` 的 [MD5][md5] 值一致，可假设[^3]两个列表的内容也一致，直接使用 `_gst_default_primitive_table` 初始化 `_gst_primitive_table`；否则的话还是使用 [image 文件][gst-image]中保存的 primitive 列表来初始化 `_gst_primitive_table`。

[^3]: [MD5][md5] 存在冲突风险，也即虽然内容不一致，但是计算出的 MD5 值仍然相同。

```C
  init_runtime_objects ();
```

初始化 [GNU Smalltalk][gst] 中的全局变量，并将[名字空间(namespace)][gst-namespace]加入 [GC][gc] 的 root set。


```C
  return (true);
}
```

初始化成功完成。


----

[links]: <> (Link list)

{% include Links.markdown %}

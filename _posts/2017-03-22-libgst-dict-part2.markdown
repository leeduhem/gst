---
layout: post
title: 字典(dictionary)模块 (libgst/dict.c) -- 字典相关操作
category: libgst dictionary
---
* TOC
{:toc}

## _gst_dictionary_new

```C
OOP
_gst_dictionary_new (int size)
{
  gst_dictionary dictionary;
  OOP dictionaryOOP;

  size = new_num_fields (size);
  dictionary = (gst_dictionary)
    instantiate_with (_gst_dictionary_class, size, &dictionaryOOP);

  dictionary->tally = FROM_INT (0);

  return (dictionaryOOP);
}
```

### new_num_fields

```C
size_t
new_num_fields (size_t oldNumFields)
{
  /* Find a power of two that is larger than oldNumFields */

  int n;

  /* Already a power of two? duplicate the size */
  if COMMON ((oldNumFields & (oldNumFields - 1)) == 0)
    return oldNumFields * 2;

  /* Find the next power of two by setting all bits to the right of
     the leftmost 1 bit to 1, and then incrementing.  */
  for (n = 1; oldNumFields & (oldNumFields + 1); n <<= 1)
    oldNumFields |= oldNumFields >> n;

  return oldNumFields + 1;
}
```

在循环中，逐次拷贝 `oldNumFields` 最左边为1的位到其右边[^1]，在循环结束时，原来 `oldNumFields` 中最左边1位的右边所有位都被置为1。

[^1]: 参考 [Round up to the next highest power of 2][libgst-new_num_fields-algo]。


### instantiate_with

`instantiate_with` 定义于 `libgst/dict.inl`。

```C
gst_object
instantiate_with (OOP class_oop,
		  size_t numIndexFields,
		  OOP *p_oop)
{
  size_t numBytes, indexedBytes, alignedBytes;
  intptr_t instanceSpec;
  gst_object p_instance;

  instanceSpec = CLASS_INSTANCE_SPEC (class_oop);
#ifndef OPTIMIZE
  if (!(instanceSpec & ISP_ISINDEXABLE) && numIndexFields != 0)
    _gst_errorf
      ("class without indexed instance variables passed to instantiate_with");
#endif

  indexedBytes = numIndexFields << _gst_log2_sizes[instanceSpec & ISP_SHAPE];
  numBytes = sizeof (gst_object_header)
    + SIZE_TO_BYTES(instanceSpec >> ISP_NUMFIXEDFIELDS)
    + indexedBytes;

  if COMMON ((instanceSpec & ISP_INDEXEDVARS) == GST_ISP_POINTER)
    {
      p_instance = _gst_alloc_obj (numBytes, p_oop);
      p_instance->objClass = class_oop;
      nil_fill (p_instance->data,
	        (instanceSpec >> ISP_NUMFIXEDFIELDS) + numIndexFields);
    }
  else
    {
      alignedBytes = ROUNDED_BYTES (numBytes);
      p_instance = instantiate_numbytes (class_oop,
                                         p_oop,
                                         instanceSpec,
                                         alignedBytes);
      INIT_UNALIGNED_OBJECT (*p_oop, alignedBytes - numBytes);
      memset (&p_instance->data[instanceSpec >> ISP_NUMFIXEDFIELDS], 0,
	      indexedBytes);
    }

  return p_instance;
}
```

`instantiate_with` 和 `new_instance_with` 皆可用来创建新的实例(instance)，区别是 `instantiate_with` 会对实例的数据域进行初始化，而 `new_instance_with` 则没有这种初始化。

`instantiate` 和 `new_instance` 的区别类似。


## _gst_dictionary_add

`_gst_dictionary_add` 用来向字典对象中添加 `Association`。

[TODO]: <> (添加对 Association 的详细介绍或链接)

```C
OOP
_gst_dictionary_add (OOP dictionaryOOP,
		     OOP associationOOP)
{
  intptr_t index;
  gst_association association;
  gst_object dictionary;
  gst_dictionary dict;
  OOP value;
  inc_ptr incPtr;		/* I'm not sure clients are protecting
				   association OOP */

  incPtr = INC_SAVE_POINTER ();
  INC_ADD_OOP (associationOOP);
```

将 `associationOOP` 添加到 [incubator][gst-gc-incubator] 中，避免其被 [GC][gc] 当作垃圾回收。

[TODO]: <> (添加链接)
  
```C
  association = (gst_association) OOP_TO_OBJ (associationOOP);
  dictionary = OOP_TO_OBJ (dictionaryOOP);
  dict = (gst_dictionary) dictionary;
  if UNCOMMON (TO_INT (dict->tally) >= 
	       TO_INT (dict->objSize) * 3 / 4)
    {
      dictionary = grow_dictionary (dictionaryOOP);
      dict = (gst_dictionary) dictionary;
    }
```

如果字典对象 `dictionaryOOP` 的容量(capacity)已经 75% 满了，则增加其容量。

```C
  index = find_key_or_nil (dictionaryOOP, association->key);
  index += OOP_FIXED_FIELDS (dictionaryOOP);
  if COMMON (IS_NIL (dictionary->data[index]))
    {
      dict->tally = INCR_INT (dict->tally);
      dictionary->data[index] = associationOOP;
    }
  else
    {
      value = ASSOCIATION_VALUE (associationOOP);
      associationOOP = dictionary->data[index];
      SET_ASSOCIATION_VALUE (associationOOP, value);
    }
```

如果 `association->key` 不存在于 `dictionaryOOP`，则将 `associationOOP` 添加到其中，并将其大小增一，最终返回 `associationOOP`；否则更新 `association->key` 对应的值(value)，并将已存在的 `Association` 返回。

```C
  INC_RESTORE_POINTER (incPtr);
  return (associationOOP);
}
```

将 `associationOOP` 从 [incubator][gst-gc-incubator] 中移除。


### grow_dictionary

```C
gst_object
grow_dictionary (OOP oldDictionaryOOP)
{
  gst_object oldDictionary, dictionary;
  size_t oldNumFields, numFields, i, index, numFixedFields;
  OOP associationOOP;
  gst_association association;
  OOP dictionaryOOP;

  oldDictionary = OOP_TO_OBJ (oldDictionaryOOP);
  numFixedFields = OOP_FIXED_FIELDS (oldDictionaryOOP);
  oldNumFields = NUM_WORDS (oldDictionary) - numFixedFields;

  numFields = new_num_fields (oldNumFields);
```

增加后的容量(capacity)。

```C
  /* no need to use the incubator here.  We are instantiating just one
     object, the new dictionary itself */

  dictionary = instantiate_with (OOP_CLASS (oldDictionaryOOP), 
				 numFields, &dictionaryOOP);
  memcpy (dictionary->data, oldDictionary->data, sizeof (PTR) * numFixedFields);
  oldDictionary = OOP_TO_OBJ (oldDictionaryOOP);
```

创建新的字典(dictionary)对象，并将 `oldDictionaryOOP` 中的固定域(fixed field)拷贝到新字典对象中。

```C
  /* rehash all associations from old dictionary into new one */
  for (i = 0; i < oldNumFields; i++)
    {
      associationOOP = oldDictionary->data[numFixedFields + i];
      if COMMON (!IS_NIL (associationOOP))
	{
	  association = (gst_association) OOP_TO_OBJ (associationOOP);
	  index = find_key_or_nil (dictionaryOOP, association->key);
	  dictionary->data[numFixedFields + index] = associationOOP;
	}
    }
```

将 `oldDictionaryOOP` 中的 `Association` 拷贝到新创建的字典对象中。

```C
  _gst_swap_objects (dictionaryOOP, oldDictionaryOOP);
  return (OOP_TO_OBJ (oldDictionaryOOP));
}
```

交换新老字典对象并返回。


### find_key_or_nil

```C
static int
find_key_or_nil (OOP dictionaryOOP,
		 OOP keyOOP)
{
  size_t count, numFields, numFixedFields;
  intptr_t index;
  gst_object dictionary;
  OOP associationOOP;
  gst_association association;

  dictionary = (gst_object) OOP_TO_OBJ (dictionaryOOP);
  numFixedFields = OOP_FIXED_FIELDS (dictionaryOOP);
  numFields = NUM_WORDS (dictionary) - numFixedFields;
  index = scramble (OOP_INDEX (keyOOP));
```

`OOP_INDEX` 定义于 `libgst/oop.inl`，返回 `keyOOP` 在 oop 表中的索引(index)。

`scramble` 定义于 `libgst/dict.inl`，是个 [hash 函数][hash-function]。

```C
  for (count = numFields; count; count--)
    {
      index &= numFields - 1;
      associationOOP = dictionary->data[numFixedFields + index];
      if COMMON (IS_NIL (associationOOP))
	return (index);

      association = (gst_association) OOP_TO_OBJ (associationOOP);

      if (association->key == keyOOP)
	return (index);

      /* linear reprobe -- it is simple and guaranteed */
      index++;
    }
```

将 `dictionary->data` 当作一个 [hash table][hash-table]，采取的[冲突解决][hash-collision-resolution]策略是 [open addressing][hash-open-addressing]。

`numFields` 本身是2的幂，因此 `index &= numFields -1` 相当于 `index = index % numFields`。


```C
  _gst_errorf
    ("Error - searching dictionary for nil, but it is full!\n");

  abort ();
}
```

若搜索失败，则 `dictionaryOOP` 已满，意味着程序中存在逻辑错误(bug)，故直接终止。

### _gst_swap_objects

`_gst_swap_objects` 定义于 `libgst/oop.c`，用于交换两个 oop。


## dictionary_at

```C
OOP
dictionary_at (OOP dictionaryOOP,
               OOP keyOOP)
{
  OOP assocOOP;

  assocOOP = dictionary_association_at (dictionaryOOP, keyOOP);

  if UNCOMMON (IS_NIL (assocOOP))
    return (_gst_nil_oop);
  else
    return (ASSOCIATION_VALUE (assocOOP));
}
```

`dictionary_at` 定义于 `libgst/dict.inl`，是对 `dictionary_association_at` 的简单封装。

### dictionary_association_at

`dictionary_association_at` 定义于 `libgst/dict.inl`，和 `find_key_or_nil` 的实现一致，区别在于 `find_key_or_nil` 返回查询结果的的索引(index)，而 `dictionary_association_at` 直接返回对应的 oop。


## namespace_new

```C
OOP
namespace_new (int size, const char *name, OOP superspaceOOP)
{
  gst_namespace ns;
  OOP namespaceOOP, classOOP;

  size = new_num_fields (size);
  classOOP = IS_NIL (superspaceOOP)
    ? _gst_root_namespace_class : _gst_namespace_class;

  ns = (gst_namespace) instantiate_with (classOOP, size, &namespaceOOP);

  ns->tally = FROM_INT (0);
  ns->superspace = superspaceOOP;
  ns->subspaces = _gst_nil_oop;
  ns->name = _gst_intern_string (name);

  return (namespaceOOP);
}
```

创建新的[名字空间(namespace)][gst-namespace]。若 `superspaceOOP` 为 `nil`，则创建根[名字空间][gst-namespace]，否则新创建的[名字空间][gst-namespace]为 `superspaceOOP` 的子[名字空间][gst-namespace]。

## _gst_namespace_at

```C
OOP
_gst_namespace_at (OOP poolOOP,
                   OOP symbol)
{
  OOP assocOOP = _gst_namespace_association_at (poolOOP, symbol);
  if (IS_NIL (assocOOP))
    return assocOOP;
  else
    return ASSOCIATION_VALUE (assocOOP);
}
```

`_gst_namespace_at` 是 `_gst_namespace_association_at` 的简单封装。


### _gst_namespace_association_at

```C
OOP
_gst_namespace_association_at (OOP poolOOP,
                               OOP symbol)
{
  OOP assocOOP;
  gst_namespace pool;

  if (is_a_kind_of (OOP_CLASS (poolOOP), _gst_class_class))
    poolOOP = _gst_class_variable_dictionary (poolOOP);

  for (;;)
    {
      if (!is_a_kind_of (OOP_CLASS (poolOOP), _gst_dictionary_class))
        return (_gst_nil_oop);

      assocOOP = dictionary_association_at (poolOOP, symbol);
      if (!IS_NIL (assocOOP))
        return (assocOOP);

      /* Try to find a super-namespace */
      if (!is_a_kind_of (OOP_CLASS (poolOOP), _gst_abstract_namespace_class))
        return (_gst_nil_oop);

      pool = (gst_namespace) OOP_TO_OBJ (poolOOP);
      poolOOP = pool->superspace;
    }
}
```

在 `poolOOP` 及其父[名字空间][gst-namespace]中搜索 `symbol` 对应的值。

### is_a_kind_of

```C
mst_Boolean
is_a_kind_of (OOP testedOOP,
              OOP class_oop)
{
  do
    {
      if (testedOOP == class_oop)
        return (true);
      testedOOP = SUPERCLASS (testedOOP);
    }
  while (!IS_NIL (testedOOP));

  return (false);
}
```

`is_a_kind_of` 定义于 `libgst/dict.inl`，检查 `testedOOP` 是否为 `class_oop` 的子类(subclass)。


## _gst_binding_dictionary_new

`BindingDictionary` 是特殊的 `Dictionary`。

[TODO]: <> (添加对 BindingDictionary 的详细描述)

## _gst_string_new

`String` 的支持。

[TODO]: <> (添加对 String 的详细描述)

## _gst_unicode_string_new

`UnicodeString` 的支持。

[TODO]: <> (添加对 UnicodeString 的详细描述)


----

[links]: <> (Link list)

{% include Links.markdown %}

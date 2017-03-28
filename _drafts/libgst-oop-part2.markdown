---
layout: post
title: 对象表(object table)管理 (libgst/oop.c) -- GC
category: libgst oop
---
[GNU Smalltalk][gst] 的 [GC][gst-gc] 采用不同的算法管理多个不同的堆(heap)：

1. generation scavenger (`NewSpace`)；
2. mark-sweep collector and compactor (`OldSpace`)；
3. mark-sweep collector (`FixedSpace`)。

[TODO]: <> (根据代码确认上述内容)

## _gst_init_mem


----

[links]: <> (Link list)

{% include Links.markdown %}

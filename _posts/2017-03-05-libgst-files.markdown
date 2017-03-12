---
layout: post
title: GNU Smalltalk 的初始化 (libgst/files.c)
categories: libgst
---
[GNU Smalltalk][gst] 初始化函数 `_gst_initialize` 定义在 `libgst` 目录的 `files.c` 中，其公开接口在 `files.h` 文件中声明。

## 头文件包含

```C
#include "gstpriv.h"
```

`gstpriv.h` 是 `libgst` 的私有头文件，包含了供内部实现使用的诸多宏定义，此头文件同时包含了 `libgst` 内部所有模块对应的头文件，因此 `libgst` 内部模块互相引用的时候只需要包含此头文件即可。

## 宏及变量定义

```C
#ifdef MSDOS
#define LOCAL_BASE_DIR_NAME             "_st"
#else
#define LOCAL_BASE_DIR_NAME             ".st"
#endif

#define USER_INIT_FILE_NAME             "init.st"
#define USER_PRE_IMAGE_FILE_NAME        "pre.st"
#define LOCAL_KERNEL_DIR_NAME           "kernel"
#define SITE_PRE_IMAGE_FILE_NAME        "site-pre.st"
```

[GNU Smalltalk][gst] 在初始化时会加载系统定制(customize)文件（默认为 `/usr/share/smalltalk/site-pre.st`）和用户初始化文件（`~/.st/init.st` 和 `~/.st/pre.st`）。若是在 `~/.st/kernel` 目录下存在和构成 `kernel` 的 [Smalltalk][smalltalk] 源文件同名的文件且比当前 image 更新，[GNU Smalltalk][gst] 会加载该文件并重新生成 image。使用 `gst` 的 `--no-user-files` 选项可以禁止加载这些文件。

```C
/* The complete list of "kernel" class and method definitions.  Each
   of these files is loaded, in the order given below.  Their last
   modification dates are compared against that of the image file; if
   any are newer, the image file is ignored, these files are loaded,
   and a new image file is created.
   
   As a provision for when we'll switch to a shared library, this
   is not an array but a list of consecutive file names.  */
static const char standard_files[] = {
  "Builtins.st\0"
  "SysDict.st\0"
  "Object.st\0"
  "Message.st\0"
  "MessageLookup.st\0"
  ...
};
```

`standard_files` 包含的是构成标准 image 文件的所有 [Smalltalk][smalltalk] 源码文件，这些文件位于 [GNU Smalltalk Git 仓库][gst-git]中 `kernel` 子目录中。在 `gst` 启动时，若 `~/.st/kernel` 目录下有比当前 image 文件更新的源码文件，`gst` 会用这些新的源码文件和系统 `kernel` (默认为 `/usr/share/smalltalk/kernel`)目录下的其他文件重新生成 image。


```C
/* The argc and argv that are passed to libgst via gst_smalltalk_args. 
   The default is passing no parameters.  */
static int smalltalk_argc = 0;
static const char **smalltalk_argv = NULL;

/* The argc and argv that are made available to Smalltalk programs
   through the -a option.  */
int _gst_smalltalk_passed_argc = 0;
const char **_gst_smalltalk_passed_argv = NULL;
```

`_gst_smalltalk_passed_argc` 和 `_gst_smalltalk_passed_argv` 用来从 `gst` 的命令行参数给 [Smalltalk][smalltalk] 代码传递参数。

## _gst_smalltalk_args

```C
void
_gst_smalltalk_args (int argc,
                     const char **argv)
{
  smalltalk_argc = argc;
  smalltalk_argv = argv;
}
```

通过 `_gst_smalltalk_args` 传递的命令行参数最终会被传递给外部可见的 `_gst_smalltalk_passed_argc` 和 `_gst_smalltalk_passed_argv`，并且在 [Smalltalk][smalltalk] 代码中可访问。


## _gst_initialize

```C
int
_gst_initialize (const char *kernel_dir,
                 const char *image_file,
                 int flags)
{
```

`_gst_initialize` 是 `libgst` 的初始化函数，参数中 `kernel_dir` 为在命令行上获取的（可能无效的） `kernel` 目录，`image_file` 为命令行指定的 image 文件的名字。

```C
  /* Even though we're nowhere near through initialization, we set this
     to make sure we don't invoke a callin function which would recursively
     invoke us.  */
  _gst_smalltalk_initialized = true;
```

在一开始就将 `_gst_smalltalk_initialized` 设为真是为了避免对初始化函数的递归调用。

```C
  _gst_init_snprintfv ();
```

`libgst` 中的格式化输出使用的是 `snprintfv` 目录提供的实现，`_gst_init_snprintfv` 是该模块的初始化函数，定义于 `print.c`。该初始化函数为 `printf` 注册了新的 `%O` modifier 用来格式化 `OOP` 类型的数据。

```C
  /* By default, apply this kludge for OSes such as Windows and MS-DOS
     which have no concept of home directories.  */
  if (home == NULL)
    home = xstrdup (currentDirectory);

  asprintf ((char **) &_gst_user_file_base_path, "%s/%s",
	    home, LOCAL_BASE_DIR_NAME);
```

在没有用户主目录(home 目录)的情况下，选取当前目录作为查找用户文件的起始目录。

```C
  if (!_gst_executable_path)
    _gst_executable_path = DEFAULT_EXECUTABLE;
```

`DEFAULT_EXECUTABLE` 在顶层 `configure.ac` 文件中设置，通过 [C 语言][c]预处理器选项 `-D` 传入。

```C
  /* Uff, we're done with the complicated part.  Set variables to mirror
     what we've decided in the above marathon.  */
  _gst_image_file_path = _gst_get_full_file_name (_gst_image_file_path);
  _gst_kernel_file_path = _gst_get_full_file_name (kernel_dir);
  asprintf (&str, "%s/%s", _gst_image_file_path, image_file);
  _gst_binary_image_name = str;

  _gst_smalltalk_passed_argc = smalltalk_argc;
  _gst_smalltalk_passed_argv = smalltalk_argv;
  no_user_files = (flags & GST_IGNORE_USER_FILES) != 0;
  _gst_no_tty = (flags & GST_NO_TTY) != 0 || !isatty (0);
```

在对传入的 `kernel_dir` 和 `image_file` 参数进行检测之后，根据检测结果设置后续初始化动作需要的变量。

```C
  site_pre_image_file = _gst_find_file (SITE_PRE_IMAGE_FILE_NAME,
                                        GST_DIR_KERNEL_SYSTEM);

  user_pre_image_file = find_user_file (USER_PRE_IMAGE_FILE_NAME);

  if (!_gst_regression_testing)
    user_init_file = find_user_file (USER_INIT_FILE_NAME);
  else
    user_init_file = NULL;
```

查找 `site-pre.st` 和 `pre.st`。若是正在进行回归测试(regression testing)，则不使用 `init.st`。

```C
  _gst_init_sysdep ();
  _gst_init_signals ();
  _gst_init_event_loop();
  _gst_init_cfuncs ();
  _gst_init_sockets ();
  _gst_init_primitives ();
```

依次调用 `libgst` 中相关模块的初始化函数。

```C
  if (!rebuild_image_flags)
    loadBinary = abortOnFailure = true;
  else
    {
      loadBinary = (rebuild_image_flags == GST_MAYBE_REBUILD_IMAGE
                    && ok_to_load_binary ());
      abortOnFailure = false;

      /* If we must create a new non-local image, but the directory is
         not writeable, we must resort to the current directory.  In
         practice this is what happens when a "normal user" puts stuff in
         his ".st" directory or does "gst -i".  */

      if (!loadBinary
          && !_gst_file_is_writeable (_gst_image_file_path)
          && (flags & GST_IGNORE_BAD_IMAGE_PATH))
        {
          _gst_image_file_path = _gst_get_cur_dir_name ();
          asprintf (&str, "%s/gst.im", _gst_image_file_path);
          _gst_binary_image_name = str;
          loadBinary = (rebuild_image_flags == GST_MAYBE_REBUILD_IMAGE
                        && ok_to_load_binary ());
        }
    }
```

检测是否能加载已存在的 image 文件。`abortOnFailure` 记录 image 文件加载失败是否要中止初始化并返回错误。


```C
  if (loadBinary && _gst_load_from_file (_gst_binary_image_name))
    {
      _gst_init_interpreter ();
      _gst_init_vmproxy ();
    }
  else if (abortOnFailure)
    {
      _gst_errorf ("Couldn't load image file %s", _gst_binary_image_name);
      return 1;
    }
```

若是已存在 image 文件可加载，则调用 `_gst_load_from_file` 加载。若是 image 文件加载成功，则继续调用 `_gst_init_interpreter` 和 `_gst_init_vmproxy`。

```C
  else
    {
      mst_Boolean willRegressTest = _gst_regression_testing;
      int result;

      _gst_regression_testing = false;
      _gst_init_oop_table (NULL, INITIAL_OOP_TABLE_SIZE);
      _gst_init_mem_default ();
      _gst_init_dictionary ();
      _gst_init_interpreter ();
      _gst_init_vmproxy ();

      _gst_install_initial_methods ();

      result = load_standard_files ();
      _gst_regression_testing = willRegressTest;
      if (result)
        return result;

      if (!_gst_save_to_file (_gst_binary_image_name))
        _gst_errorf ("Couldn't open file %s", _gst_binary_image_name);
    }
```

若是无法加载已有 image 文件，那么重头开始初始化 [GNU Smalltalk][gst] 虚拟机，并加载 `kernel` 文件。如果一切顺利，则生成新的 image 文件。

```C
  _gst_kernel_initialized = true;
  _gst_invoke_hook (GST_RETURN_FROM_SNAPSHOT);
```

至此，kernel 已经完成初始化，设置标志变量并调用对应的 hook。

```C
  if (user_init_file)
    _gst_process_file (user_init_file, GST_DIR_ABS);
```

加载用户的初始化文件 `~/.st/init.st`。

```C
#ifdef HAVE_READLINE
  _gst_initialize_readline ();
#endif /* HAVE_READLINE */
```

最后，若支持 [GNU Readline][readline] 以提供更好的交互式体验，则调用对应的初始化函数。

```C
  return 0;
}
```

初始化完成，返回调用者。

## ok_to_load_binary

```C
mst_Boolean
ok_to_load_binary (void)
{
  const char *fileName;

  if (!_gst_file_is_readable (_gst_binary_image_name))
    return (false);

  for (fileName = standard_files; *fileName; fileName += strlen (fileName) + 1)
    {
      char *fullFileName = _gst_find_file (fileName, GST_DIR_KERNEL);
      mst_Boolean ok = _gst_file_is_newer (_gst_binary_image_name,
                                           fullFileName);
      xfree (fullFileName);
      if (!ok)
        return (false);
    }

  if (site_pre_image_file
      && !_gst_file_is_newer (_gst_binary_image_name, site_pre_image_file))
    return (false);

  if (user_pre_image_file
      && !_gst_file_is_newer (_gst_binary_image_name, user_pre_image_file))
    return (false);

  return (true);
}
```

`ok_to_load_binary` 实现了检查 image 文件是否可加载的逻辑。在检查 kernel 文件的时候优先选择 `~/.st/kernel` 目录下对应文件的逻辑在 `_gst_find_file` 中实现。


## load_standard_files

```C
int
load_standard_files (void)
{
  const char *fileName;

  for (fileName = standard_files; *fileName; fileName += strlen (fileName) + 1)
    {
      if (!_gst_process_file (fileName, GST_DIR_KERNEL))
        {
          _gst_errorf ("couldn't load system file '%s': %s", fileName,
                       strerror (errno));
          _gst_errorf ("image bootstrap failed, use option --kernel-directory");
          return 1;
        }
    }

  _gst_msg_sendf (NULL, "%v %o relocate", _gst_file_segment_class);

  if (site_pre_image_file)
    _gst_process_file (site_pre_image_file, GST_DIR_ABS);

  if (user_pre_image_file)
    _gst_process_file (user_pre_image_file, GST_DIR_ABS);

  return 0;
}
```

依次加载 kernel 中的文件，然后执行 `FileSegment class relocate`，最后依次加载 `site-pre.st` 和 `pre.st`。


## _gst_find_file

```C
char *
_gst_find_file (const char *fileName,
		enum gst_file_dir dir)
{
  char *fullFileName, *localFileName;

  if (dir == GST_DIR_ABS)
    return xstrdup (fileName);

  asprintf (&fullFileName, "%s/%s%s", _gst_kernel_file_path,
	    dir == GST_DIR_KERNEL ? "" : "../",
	    fileName);

  if (!no_user_files && dir != GST_DIR_KERNEL_SYSTEM)
    {
      asprintf (&localFileName, "%s/%s%s",
		_gst_user_file_base_path,
		dir == GST_DIR_BASE ? "" : LOCAL_KERNEL_DIR_NAME "/",
		fileName);

      if (_gst_file_is_newer (localFileName, fullFileName))
	{
	  xfree (fullFileName);
	  return localFileName;
	}
      else
	xfree (localFileName);
    }

  if (_gst_file_is_readable (fullFileName))
    return fullFileName;

  xfree (fullFileName);
  return NULL;
}
```

`_gst_find_file` 实现了在查找 kernel 文件的时候优先选取 `~/.st/kernel` 目录下文件的逻辑。


[links]: <> (Link list)

{% include Links.markdown %}

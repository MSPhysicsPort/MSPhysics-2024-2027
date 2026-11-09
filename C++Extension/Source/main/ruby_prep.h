// Copied and extended from Thomthom's TT_lib2.

#ifndef RUBY_PREP_H
#define RUBY_PREP_H

#ifdef _MSC_VER
    #ifdef _M_X64
        #ifndef _WIN_64_VER
            #define _WIN_64_VER
        #endif
    #else
        /* 32-bit Windows is no longer supported (SU 2017+ is x64 only):
           no _WIN_32_VER branch. See Projects/VS: all Win32 configs removed. */
        #error "MSPhysics msp_lib requires 64-bit Windows (x64). 32-bit (Win32) is unsupported."
    #endif
#elif defined (_WIN32) || defined (__MINGW32__)
    /* MinGW-w64 targeting Windows x64: same as the MSVC branch above.
       (Without this, MinGW fell into the #else branch and wrongly
       defined _MACOSX_VER, pulling in sys/sysctl.h on Windows.) */
    #ifndef _WIN_64_VER
        #define _WIN_64_VER
    #endif
#elif defined(__aarch64__)
    /* Apple Silicon (arm64) macOS: no x86 SSE intrinsic headers.
       _MACOSX_VER is defined below; the SSE includes are guarded by
       __i386__/__x86_64__ and are skipped on arm64. */
    #ifndef _MACOSX_VER
        #define _MACOSX_VER
    #endif
#else
    #ifndef _MACOSX_VER
        #define _MACOSX_VER
    #endif
#endif

#if defined (_WIN_64_VER)
    #include <intrin.h>
    #include <emmintrin.h>
#endif

#ifdef _MACOSX_VER
    #include <unistd.h>
    #include <sys/sysctl.h>
    #include <assert.h>
    #if (defined __i386__ || defined __x86_64__)
        #include <fenv.h>
        #include <pmmintrin.h>
        #include <emmintrin.h> // sse3
        #include <mmintrin.h>
        #ifdef __SSE4_1__
            #include <smmintrin.h>
        #endif
    #elif defined(__aarch64__)
        /* Apple Silicon: no x86 SSE intrinsic headers on arm64. */
    #endif
#endif

// Visual Studio CRT Config

// Must disable the min/max macros defined by windows.h to avoid conflict with
// std::max and std:min. Ruby includes windows.h so it must be disabled here.
// http://stackoverflow.com/a/2789509/486990
#define NOMINMAX

// Ruby in SketchUp was configured with /MD and the headers reflect that.
//
// NOTE (2024-2027 port): the old HAVE_ACOSH/HAVE_CBRT/HAVE_ERF/HAVE_TGAMMA/
// HAVE_ROUND/HAVE_NEXTAFTER/HAVE_STRUCT_TIMESPEC hard-coding for VS2013/2015
// was deleted. Ruby's own config.h (ruby/config.h, included via ruby.h
// below) defines these correctly for the Ruby version actually being built
// against (3.2 / 3.4, VS2022 / v143). Do not re-introduce hand-written
// HAVE_* defines; if a macro is ever missing, branch on
// RUBY_API_VERSION_MAJOR instead.

// Ruby Headers
#ifdef USE_WINSOCK
    #include <Winsock2.h>
#endif

#include <ruby.h>
#ifdef HAVE_RUBY_ENCODING_H
    #include <ruby/encoding.h>
#endif

// Compatibility Macros
//
// NOTE (2024-2027 port): the old 1.8-era fallback macros for RARRAY_PTR /
// RARRAY_LEN / RSTRING_PTR / RSTRING_LEN / DBL2NUM / NUM2SIZET were deleted.
// Ruby 3.2+ provides RSTRING_PTR/RSTRING_LEN/RARRAY_PTR/RARRAY_LEN as
// static inline functions (with null-pointer debug checks) and NUM2SIZET /
// DBL2NUM via its own headers; redefining them from the 1.8 struct layout
// (RARRAY(x)->ptr / ->len) would read the wrong address on Ruby 3.x
// (embedded strings, variable-length layout). Call sites must use the
// Ruby-provided functions directly. Do not re-introduce these fallbacks.


/*
 * NOTE (2024-2027 port): VALUEFUNC / INTFUNC / VOIDFUNC are kept only so the
 * existing ~647 rb_define_module_function call sites keep compiling.
 * New or touched code must use Ruby's own RUBY_METHOD_FUNC(f) instead of
 * VALUEFUNC(f) (same cast, but provided by ruby/internal/anyargs.h and
 * guaranteed to track Ruby 3.2/3.4; ANYARGS is deprecated since Ruby 2.7
 * and its survival in Ruby 3.4 headers is still to be re-verified once the
 * SU2027 Ruby 3.4.9 headers are available). Do NOT mass-replace the 647
 * existing sites in one go: migrate them gradually, per function, with the
 * exact rbf_* signature checked (arity was audited: 0 mismatches).
 */

#define INTFUNC(f) ((int (*)(ANYARGS)) f)
#define VALUEFUNC(f) ((VALUE (*)(ANYARGS)) f)
#define VOIDFUNC(f)  ((RUBY_DATA_FUNC) f)


// Ruby 1.8 headers conflict with ostream because it defined a lot of macros
// that completely mess up the environment.

// win32.h
#ifdef getc
    #undef getc
#endif

#ifdef putc
    #undef putc
#endif

#ifdef fgetc
    #undef fgetc
#endif

#ifdef fputc
    #undef fputc
#endif

#ifdef getchar
    #undef getchar
#endif

#ifdef putchar
    #undef putchar
#endif

#ifdef fgetchar
    #undef fgetchar
#endif

#ifdef fputchar
    #undef fputchar
#endif

#ifdef utime
    #undef utime
#endif


#ifdef close
    #undef close
#endif

#ifdef fclose
    #undef fclose
#endif

#ifdef read
    #undef read
#endif

#ifdef write
    #undef write
#endif

#ifdef getpid
    #undef getpid
#endif

#ifdef sleep
    #undef sleep
#endif

#ifdef connect
    #undef connect
#endif

#ifdef mode_t
    #undef mode_t
#endif

// config.h
#ifdef inline
    #undef inline
#endif

#endif /* RUBY_PREP_H */

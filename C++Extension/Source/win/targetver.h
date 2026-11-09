#pragma once

// Including SDKDDKVer.h defines the highest available Windows platform.

// If you wish to build your application for a previous Windows platform, include WinSDKVer.h and
// set the _WIN32_WINNT macro to the platform you wish to support before including SDKDDKVer.h.

//#include <SDKDDKVer.h>
#include <WinSDKVer.h>

//#ifndef _WIN32_WINNT
	#define _WIN32_WINNT 0x0A00 /* Windows 10 (was 0x0501 / Windows XP).
	                                SU 2024-2026 run on Win10/11; SU 2027 is
	                                Win11-only, for which 0x0B00 would also
	                                be valid -- 0x0A00 keeps Win10 support. */
//#endif

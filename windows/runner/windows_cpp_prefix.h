#pragma once

#ifdef __cplusplus

// 阻止 winsock.h 被包含（与 winsock2.h 冲突）
#ifndef _WINSOCKAPI_
#define _WINSOCKAPI_
#endif

// 阻止 min/max 宏污染
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>

#endif /* __cplusplus */

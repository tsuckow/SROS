#ifndef _FW_TYPE_DEF_H_
#define _FW_TYPE_DEF_H_

#if __CC_ARM
typedef signed char int8;
typedef unsigned char uint8;
typedef short int16;
typedef unsigned short uint16;
typedef int   int32;
typedef unsigned int uint32;
typedef long long int40;
typedef long long int64;
#define bool uint8
#endif

#endif //__TYPEDEF_H__


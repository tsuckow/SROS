#include <LPC23xx.H>                    /* LPC23xx definitions                */

#ifndef _RWLOCK_H_
#define _RWLOCK_H_

#include <rtos.h>

typedef struct
{

   mutexObject_t Entry;
   mutexObject_t Write;
   mutexObject_t Count;
   uint32 volatile cnt;

} rwLockObject_t;

void rwLockObjectInit( rwLockObject_t * lock );
void rwLockObjectLockReader( rwLockObject_t * lock );
void rwLockObjectLockWriter( rwLockObject_t * lock );
void rwLockObjectRelease( rwLockObject_t * lock );

#endif

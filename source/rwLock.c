
#include "rwLock.h"
#include "assert.h"

void rwLockObjectInit( rwLockObject_t * lock )
{
   mutexObjectInit( &(*lock).Entry, 1);
   mutexObjectInit( &(*lock).Write, 1);
   mutexObjectInit( &(*lock).Count, 1);
   (*lock).cnt = 0;
}

void rwLockObjectLockReader( rwLockObject_t * lock )
{
   mutexObjectLock( &(*lock).Entry, -1 );
   mutexObjectLock( &(*lock).Count, -1 );

   if( (*lock).cnt == 0 )
   {
      mutexObjectLock( &(*lock).Write, -1 );
   }
   (*lock).cnt++;

   mutexObjectRelease( &(*lock).Count );
   mutexObjectRelease( &(*lock).Entry );
}

void rwLockObjectLockWriter( rwLockObject_t * lock )
{
   mutexObjectLock( &(*lock).Entry, -1 );
   mutexObjectLock( &(*lock).Write, -1 );

   assert( lock->cnt == 0 );
}

void rwLockObjectRelease( rwLockObject_t * lock )
{
   mutexObjectLock( &(*lock).Count, -1 );

   if( (*lock).cnt == 0 )
   {//Was writing
      mutexObjectRelease( &(*lock).Write );
      mutexObjectRelease( &(*lock).Entry );
   }
   else
   {//Was reading
      (*lock).cnt--;
      if( (*lock).cnt == 0 )
         mutexObjectRelease( &(*lock).Write );
   }

   mutexObjectRelease( &(*lock).Count );
}

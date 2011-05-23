#include "rtosImpl.h"

/*
;The mutexObjectLock function lock the mutex. The pseduo code for 
;mutexObjectLock() is shown below.
;
;@brief Acquires a mutex lock
;
;Blocks till the mutex is acquired for a maximum of waitTime.
;If waitTime is 0 then the function returns immediately.
;If waitTime is negative then the function blocks indefinitely.
;
;@param mutexObjectPtr Pointer to mutex to lock
;@param waitTime Time till mutex acquisition fails
;
;@return 1 on successful acquisition of mutex, 0 on failure
;
;int32 mutexObjectLock(mutexObject_t *mutexObjectPtr, int32 waitTime)
;{
;   if(swap(0, &mutexObjectPtr->mutex))
;   {
;       //Aquired Mutex, no one else can be on wait list cause we would have handed
;       //the mutex to them if there was.
;       return 1;
;   }
;   else
;   {
;       if(waitTime)
;       {
;           interruptsDisable();
;           Get the context which should be functionally equivalent to starting
;              of this function and store that context in the running
;              threadObject i.e. context space of running thread.
;           listObjectInsert(&mutexObjectPtr->waitList,
;              runningThreadObjectPtr);
;           if(waitTime > 0)
;           {
;               //When the timer Expires, the mutex will fail (return 0)
;               insertIntoTimerList(&runningThreadObject,
;                               mutexObjectPtr->waitList);
;           }
;           jump to scheduler();
;       }
;       else
;       {
;           //Failed to aquire mutex
;           return 0;
;       }
;   }
;}
*/
unsigned mutexObjectLockImpl(mutexObject_t * mutex, int waitTime, unsigned previousLockVal)
{
   if( previousLockVal == 1 )
   {
      //We got the lock
      return 1;
   }
   else
   {
      if( waitTime != 0 )
      {
         listObjectInsert(&mutex->waitList, runningThreadObjectPtr);

         if( waitTime > 0 ) //We wont wait forever.
         {
            runningThreadObjectPtr->R[0] = 0;//Default to failure
            insertIntoTimerList( runningThreadObjectPtr, &mutex->waitList );
         }

         scheduler();//Switch threads discarding the current context
         return 999;//Unreachable
      }
      else
      {
         //Failed to aquire lock, no blocking.
         return 0;
      }
   }
}

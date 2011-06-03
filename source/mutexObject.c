#include "rtosImpl.h"
#include "assert.h"

#define IRQ_MODE 0x12
int is_IRQ_MODE()
{
   unsigned int r2;
   __asm("MRS r2,CPSR");
   r2 &= 0x1F;
   return r2 == IRQ_MODE;
}

void promoteThread( threadObject_t * promoter, threadObject_t * promotee )
{
   listObject_t * promoteeWaitList;

   assert( promoter != 0 );
   assert( promotee != 0 );
   assert( promoter->promotee == 0 );
   assert( runningThreadObjectPtr != promotee );

   promoter->promotee = promotee;
   listObjectInsert( &promotee->promoterList, promoter);
   if( promotee->priority > promoter->priority ) //Lower number higher priority
   {
      promotee->priority = promoter->priority;

      promoteeWaitList = promotee->waitListResource;
      waitlistObjectDeleteMiddle( promoteeWaitList, promotee );
      waitlistObjectInsert( promoteeWaitList, promotee );

      while( promotee->promotee != 0 )
      {
         promoter = promotee;
         promotee = promotee->promotee;

         listObjectDeleteMiddle( &promotee->promoterList, promoter );
         listObjectInsert( &promotee->promoterList, promoter );

         promotee->priority = promoter->priority;
      }
   }
}

void demoteThread( threadObject_t * promoter )
{
   threadObject_t * promotee;

   assert( promoter != 0 );
   assert( promoter->promotee != 0 );
   assert( runningThreadObjectPtr != promoter->promotee );

   promotee = promoter->promotee;
   listObjectDeleteMiddle( &promotee->promoterList, promoter );
   promoter->promotee = 0;

   if( listObjectCount( &promotee->promoterList ) == 0 )
   {
      promotee->priority = promotee->innatePriority;
   }
   else
   {
      promotee->priority = listObjectPeek( &promotee->promoterList )->priority;
      if( promotee->priority < promotee->innatePriority )
      {
         promotee->priority = promotee->innatePriority;
      }
   }

   while( promotee->promotee != 0 )
   {
      promoter = promotee;
      promotee = promotee->promotee;

      assert( listObjectCount( &promotee->promoterList ) != 0 );

      listObjectDeleteMiddle( &promotee->promoterList, promoter );
      listObjectInsert( &promotee->promoterList, promoter );

      promotee->priority = listObjectPeek( &promotee->promoterList )->priority;
      if( promotee->priority < promotee->innatePriority )
      {
         promotee->priority = promotee->innatePriority;
      }
   }
}

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
      mutex->owner = runningThreadObjectPtr;
      return 1;
   }
   else
   {
      if( waitTime != 0 )
      {
         waitlistObjectInsert(&mutex->waitList, runningThreadObjectPtr);

         if( mutex->mode == 1 )
         {
            promoteThread( runningThreadObjectPtr, mutex->owner );
         }

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

/*
;The below code implement mutexObjectRelease() function. mutexObjectRelease()
;function release the mutex and do context switch if necessary. The high level
;pseudo code for mutexObjectRelease() is shown below.
;void mutexObjectRelease(mutexObject_t *mutexObjectPtr)
;{
;   threadObject_t *waitingThreadObjectPtr;
;   interruptsDisable();
;   if(listObjectCount(&mutexObjectPtr->waitList))
;   {
;       waitingThreadObjectPtr=listObjectDelete(&mutexObjectPtr->waitList);
;       Update return address to mutexObjectLock_success
;       listObjectInsert(&readyList,waitingThreadObjectPtr);
;       if(waitingThreadObjectPtr->waitTime >= 0)
;       {
;           deleteFromTimerList(waitingThreadObjectPtr);
;       }
;       if(waitingThreadObjectPtr->priority < runningThreadObject.priority &&
;               this function not called from interrupt service routine)
;       {
;           Get the context functionally equivalent to the end
;              this function and save that context into running
;              threadObject.
;           listObjectInsert(&readyList,&runningThreadObject);
;           jump to scheduler();
;       }
;   }
;   else
;   {
;       //Unlock Mutex
;       mutexObjectPtr->mutex = 1;
;   }
;   interruptRestore();
;   return;
;}
*/
/*
TODO:
On timeout demote thread.
*/
void mutexObjectReleaseImpl(mutexObject_t * mutex)
{
   int waitlistCount = listObjectCount(&mutex->waitList);

   assert(waitlistCount >= 0);
   if( waitlistCount > 0 )
   {
      threadObject_t * waitingThreadObjectPtr;
      waitingThreadObjectPtr = waitlistObjectDelete(&mutex->waitList);
      waitingThreadObjectPtr->R[0] = 1;//You Win! Return success of lock
      waitlistObjectInsert(&readyList,waitingThreadObjectPtr);

      if( mutex->mode == 1 )
      {
         threadObject_t * promoter;
         while( (promoter = listObjectPeekWaitlist( &runningThreadObjectPtr->promoterList, &mutex->waitList )) != 0 )
         {
            demoteThread( promoter );
            promoteThread( promoter, waitingThreadObjectPtr );
         }
      }

      mutex->owner = waitingThreadObjectPtr;
      if(waitingThreadObjectPtr->R[1] >= 0)//Wait time
      {
          deleteFromTimerList(waitingThreadObjectPtr);
      }
      if(waitingThreadObjectPtr->priority < runningThreadObjectPtr->priority && !is_IRQ_MODE() )
      {
          waitlistObjectInsert(&readyList,runningThreadObjectPtr);
          scheduler();
      }
   }
   else
   {
      //Unlock Mutex
      mutex->owner = 0;
      mutex->mutex = 1;
   }
}


            PRESERVE8 {TRUE}

            INCLUDE rtosAsm.h

            IMPORT  runningThreadObjectPtr
            IMPORT  oldCPSR

            EXPORT  mutexObjectLock
            EXPORT  mutexObjectRelease

            IMPORT  mutexObjectLockImpl
            IMPORT  mutexObjectReleaseImpl
;The below code section implement the mutexObjectLock() and 
;mutexObjectRelease() functions.

            AREA mutexObjectCode, CODE

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
;Note : This function should not be called from interrupt service 
;routine with nonzero waitTime.

            ;R0 = mutexObjectPtr, R1 = waitTime according to the calling 
            ;convention.
mutexObjectLock
            ;interruptDisable()
            INTERRUPTS_SAVE_DISABLE oldCPSR, R2, R3

            MOV     R2, #0          ;R2=0;
            ASSERT  mutexObject_t_mutex_offset = 0
            SWP     R2, R2, [R0]    ;R2 = mutex

            ;Get running thread object ptr
            LDR     R3, =runningThreadObjectPtr
            LDR     R3, [R3]

            ASSERT  threadObject_t_R_offset = 0

            STMIA   R3, {R0-R14}            ;save all registers R0-R14 in 
                                            ;the running threadObject

            ADR     R4, mutexObjectLockCallback ;get the address to come back to.
            STR     R4, [R3, #(15*4)]           ;save it as the PC to start later.

            ;We need to store the oldCPSR for when we come back
            LDR     R4, =oldCPSR
            LDR     R4, [R4]                ;get original status of the thread
            STR     R4, [R3, #threadObject_t_cpsr_offset]
            LDR     R4, [R3, #(04*4)]           ;Get back R4

            ;Call our C func.
            BL      mutexObjectLockImpl

            LDR     R3, =runningThreadObjectPtr
            LDR     R3, [R3]
            LDR     LR, [R3, #(14*4)] ;Get back the return address
            INTERRUPTS_RESTORE oldCPSR, R1

mutexObjectLockCallback
            BX      LR

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
;This function can be called from interrupt service routine 
;with out any ristrictions.

            ;R0=mutexObjectPtr according to the calling convention.
mutexObjectRelease
            ;interruptDisable()
            INTERRUPTS_SAVE_DISABLE oldCPSR, R2, R3

            ;Get running thread object ptr
            LDR     R3, =runningThreadObjectPtr
            LDR     R3, [R3]

            ASSERT  threadObject_t_R_offset = 0

            STMIA   R3, {R0-R14}            ;save all registers R0-R14 in 
                                            ;the running threadObject

            ADR     R2, mutexObjectReleaseCallback ;get the address to come back to.
            STR     R2, [R3, #(15*4)]           ;save it as the PC to start later.

            ;We need to store the oldCPSR for when we come back
            LDR     R2, =oldCPSR
            LDR     R2, [R2]                ;get original status of the thread
            STR     R2, [R3, #threadObject_t_cpsr_offset]

            ;Call our C func.
            BL      mutexObjectReleaseImpl

            LDR     R3, =runningThreadObjectPtr
            LDR     R3, [R3]
            LDR     LR, [R3, #(14*4)] ;Get back the return address
            INTERRUPTS_RESTORE oldCPSR, R1

mutexObjectReleaseCallback
            BX      LR

            END


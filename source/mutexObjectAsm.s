            INCLUDE rtosAsm.h
            
            IMPORT  runningThreadObjectPtr
            IMPORT  listObjectInsert
            IMPORT  listObjectDelete
            IMPORT  readyList
            IMPORT  scheduler
            IMPORT  oldCPSR

            IMPORT  insertIntoTimerList
            IMPORT  deleteFromTimerList
            
            EXPORT  mutexObjectLock
            EXPORT  mutexObjectRelease
            
;The below code section implement the mutexObjectLock() and 
;mutexObjectRelease() functions.

            AREA mutexObjectCode, CODE
            
;The mutexObjectLock function lock the mutex. The pseduo code for 
;mutexObjectLock() is shown below.
;int32 mutexObjectLock(mutexObject_t *mutexObjectPtr, int32 waitTime)
;{
;   if(swap(0, &mutexObjectPtr->mutex))
;   {
;       return 1;
;   }
;   else        
;   {
;       if(waitTime)
;       {
;           interruptsDisable();
;           get the context which should be functionally equivalent to starting
;           of this function and store that context in the running 
;           threadObject i.e. context space of running thread.
;           listObjectInsert(&mutexObjectPtr->waitList,
;           runningThreadObjectPtr);
;           if(waitTime > 0)
;           {
;               insertIntoTimerList(&runningThreadObject, 
;                               mutexObjectPtr->waitList); 
;           }
;           jump to scheduler();
;       }
;       else
;       {
;           return 0;
;       }
;   }
;}
;Note : This function should not be called from interrupt service 
;routinie with nonzero waitTime.

            ;R0 = mutexObjectPtr, R1 = waitTime according to the calling 
            ;convention.
mutexObjectLock
            
            MOV     R2, #0          ;R2=0;
            
            ASSERT  mutexObject_t_mutex_offset = 0

            SWP     R2, R2, [R0]    ;R2 = mutex
            
            CMP     R2, #1          ;if(mutex == 1)
            
            MOVEQ   R0, #1          ;if(mutex == 1) returnValue = 1.
            
            BXEQ    LR              ;if(mutex == 1) return returnValue.
            
            CMP     R1, #0          ;if(waitTime == 0)
            
            MOVEQ   R0, #0          ;if(mutex == 0 and waitTime == 0) 
                                    ;then returnValue = 0
            
            BXEQ    LR              ;if(mutex == 0 and waitTime == 0) 
                                    ;then return returnValue.
            
            ;waitTime > 0 and mutex is locked by some other thread.
            ;So keep the current thread in waitList of this mutex
            ;If waiting for a limited time, keep the threadObject 
            ;in timerList too
            ;and jump to scheduler.
            
            ;interruptDisable()
            INTERRUPTS_SAVE_DISABLE oldCPSR, R2, R3
            
            ;creating thread object for the current thread.
            LDR     R3, =runningThreadObjectPtr     
                                    ;R3=&runningThreadObjectPtr
            
            LDR     R3, [R3]
            
            ASSERT  threadObject_t_R_offset = 0
            
            STMIA   R3, {R0-R14}            ;save all registers R0-R14 in 
                                            ;the running threadObject
            
            ADR     R4, mutexObjectLock     ;get the address of this function. 
                                            ;(to start this thread later).
                                            ;R4=mutexObjectLock
            
            STR     R4, [R3, #(15*4)]       ;save it as the PC to start later.
            
            LDR     R4, =oldCPSR
            
            LDR     R4, [R4]                ;get original status of the thread
                                            ;before masking interrupts.
            
            STR     R4, [R3, #threadObject_t_cpsr_offset] 
                                            ;save the status of the thread.
            
            ;insert the running thread into waitList of mutexObject.
            
            ADD     R0, R0, #mutexObject_t_waitList_offset 
                                            ;R0=&mutexObject->waitList.
            
            MOV     R1, R3                                 
                                            ;R1=&runningThreadObjectPtr
            
            BL      listObjectInsert;
            
            ;insert the running thread into the waitList of timerList.
            
            LDR     R0, =runningThreadObjectPtr     
                                            ;R0 =&&runningThreadObject
            
            LDR     R0, [R0]                ;R0=&runningThreadObject
            
            LDR     R1, [R0, #threadObject_t_R_offset] 
                                            ;R1=R0 of running 
                                            ;threadObject=mutexObjectPtr
            
            ADD     R1, R1, #mutexObject_t_waitList_offset  
                                            ;R1=mutexObjectPtr->waitList
            
            LDR     R2, [R0, #(threadObject_t_R_offset+4)]  
                                            ;R2=waitTime
            
            CMP     R2, #0                  ;if(waitTime > 0)

            ;insertIntoTimerList(&runningThread, waitList). 
            ;R1 register of threadObject alwasy holds the waitTime.
            BLGT    insertIntoTimerList     
                                            
            ;jump to scheduler
            
            B       scheduler
            
            
;The below code implement mutexObjectRelease() function. mutexObjectRelease()
;function release the mutex and do context switch if necessary. The high level
;pseudo code for mutexObjectRelease() is shown below.
;void mutexObjectRelease(mutexObject_t *mutexObjectPtr)
;{
;   threadObject_t *waitingThreadObjectPtr;
;   interruptsDisable();
;   mutexObjectPtr->mutex = 1;
;   if(listObjectCount(&mutexObjectPtr->waitList))
;   {
;       waitingThreadObjectPtr=listObjectDelete(&mutexObjectPtr->waitList);
;       listObjectInsert(&readyList,waitingThreadObjectPtr);
;       if(waitingThreadObjectPtr->waitTime >= 0)
;       {
;           deleteFromTimerList(waitingThreadObjectPtr);
;       }
;       if(waitingThreadObjectPtr->priority < runningThreadObject.priority &&
;               this function not called from interrupt service routine)
;       {
;           get the context functionally equivalent to the end 
;           this function and save that context into running
;           threadObject.
;           listObjectInsert(&readyList,&runningThreadObject);
;           jump to scheduler();
;       }
;   }
;   interruptRestore();
;   return;
;}
;This function can be called from interrupt service routine 
;with out any ristrictions.

            ;R0=mutexObjectPtr according to the calling convention.
mutexObjectRelease
            ;interruptsDisable
            
            INTERRUPTS_SAVE_DISABLE oldCPSR, R1, R2
            
            MOV     R1, #1  ;R1=1
            
            ASSERT mutexObject_t_mutex_offset = 0
            
            SWP     R1, R1, [R0]    ;mutexObject->mutex = 1;
            
            LDR     R1, [R0, #(mutexObject_t_waitList_offset+ \
                                    listObject_t_auxInfo_offset)] 
                                ;R1=listObjectCount(&mutexObjectPtr->waitList)
            
            CMP     R1, #0
            
            BEQ     no_thread_waiting_for_mutex;
            
            ;some thread is waiting for this mutex.
            
            ADD     R0, R0, #mutexObject_t_waitList_offset 
                                ;R0=&mutexObjectPtr->waitList.
            
            STMFD   SP!, {R14}  ;saving R14 to make function call.
            
            ;listObjectDelete(&mutexObjectPtr->waitList)
            BL      listObjectDelete    
                                ;After returning from the function, 
                                ;R0 contain waitingThreadObjectPtr
            
            MOV     R1, R0      ;R1=waitingThreadObjectPtr
            
            LDR     R0, =readyList  
                                ;R0 = &readyList.
            
            STMFD   SP!, {R1}   ;Save waitingThreadObjectPtr as we are 
                                ;going to make a function call.
            
            BL      listObjectInsert 
                                ;insert waiting thread object into 
                                ;ready list.
            
            LDR     R0, [SP]        ;We get R0=waitingThreadObjectPtr
            
            LDR     R1, [R0, #(threadObject_t_R_offset+4)]  ;R1=waitTime
            
            CMP     R1, #0          ;if(waitTime >= 0)
            
            BLGE    deleteFromTimerList
            ;deleteFromTimerList(waitingThreadObjectPtr) 
            ;(when waitTime greater than or equal to 0, this threadObject will
            ;be in timerList).
            
            ;Now check if the waiting thread has higher priority than the 
            ;current running thread. and switch to the  waiting thread if 
            ;that has high priority.
            
            LDMFD   SP!, {R0, R14}
                                ;R0=waitingThreadObjectPtr, 
                                ;R14=return address from this function.
            
            LDR     R1, =runningThreadObjectPtr 
                                ;R1=&runningThreadObjectPtr     
            
            LDR     R1, [R1]
            
            LDR     R2, [R0, #threadObject_t_priority_offset] 
                                ;R2=waitingThreadObjectPtr->priority
            
            LDR     R3, [R1, #threadObject_t_priority_offset]   
                                ;R3=runningThreadObject.priority.
            
            CMP     R2, R3      ;if(waitingThreadObjectPtr->priority < 
                                ;runningThreadObject.priority)
            
            BHS     waiting_thread_does_not_have_high_priority;
            
            ;check whether we are coming from the interrupt service routine. 
            ;If we are coming from the interrupt service routine we should
            ;not make context switch. IRQ_handler will do the context switch.
            
            MRS     R2, CPSR
            
            AND     R2, R2, #0x1F
                                ;keep only mode bits.
            
            CMP     R2, #IRQ_MODE       
                                ;if(currentMode == IRQ_MODE)
            
            BEQ     called_from_interrupt_service_routine
            
            ;This function is called from user/system mode.
            ;waiting thread has higher priority.
            ;save running thread context to readyList and call scheduler.
            
            STMIA   R1, {R0-R14}
                                ;save registers for running thread.
            
            STR     R14, [R1, #(15*4)]  
                                ;saving the return address as starting 
                                ;program counter.
            
            LDR     R2, =oldCPSR
            
            LDR     R2, [R2]    ;get status.
            
            SET_STATE_OF_PC_IN_CPSR R14, R2 
                                ;set the correct state in CPSR for the 
                                ;starting the thread next time.
                                ;(add the state bit correctly).
            
            STR     R2, [R1, #threadObject_t_cpsr_offset]   ;save status.
            
            LDR     R0, =readyList  
                                ;R0=&readyList.
            
            BL      listObjectInsert 
                                ;Insert the running thread into readyList
            
            B       scheduler   ;Jump to scheduler.
            
            
no_thread_waiting_for_mutex
waiting_thread_does_not_have_high_priority
called_from_interrupt_service_routine
            
            ;interruptsRestore()
            INTERRUPTS_RESTORE oldCPSR, R1
            
            BX      LR

        
            END
            
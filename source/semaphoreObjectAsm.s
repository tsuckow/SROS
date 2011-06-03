            PRESERVE8 {TRUE}

            INCLUDE rtosAsm.h

            IMPORT  runningThreadObjectPtr
            IMPORT  waitlistObjectInsert
            IMPORT  waitlistObjectDelete
            IMPORT  readyList
            IMPORT  oldCPSR
            IMPORT  scheduler
            
            IMPORT  insertIntoTimerList
            IMPORT  deleteFromTimerList

            EXPORT  semaphoreObjectPend
            EXPORT  semaphoreObjectPost
            
;The below code section implement semaphoreObjectPost(), semaphoreObjectPend()
;functions.         

            AREA semaphoreObjectCode, CODE
            
;The semaphoreObjectPend() function decrement the semaphoreCount by 1. The 
;pseudo code for semaphoreObjectPend() function is shown below.
;int32 semaphoreObjectPend(semaphoreObject_t *semaphoreObjectPtr, 
;                                                   int32 waitTime)
;{
;   interruptsDisable();
;
;   if(semaphoreObjectPtr->count > 0)
;   {
;       semaphoreObjectPtr->count--;
;       returnValue = 1;
;   }
;   else
;   {
;       if(waitTime)
;       {
;           get the context same as start of the thread into 
;           runningThreadObject.
;           listObjectInsert(&semaphoreObjectPtr->waitList,
;                                    &runningThreadObject);
;           if(waitTime > 0)
;           {
;               insertIntoTimerList(&runningThread, 
;                                   semaphoreObjectPtr->waitList);
;           }
;           jump to scheduler();
;       }
;       else
;       {
;           returnValue = 0;
;       }
;   }
;   interruptsRestore();
;   return returnValue;
;}
;This function should not be called from interrupt service routine
;with nonzero waitTime.

semaphoreObjectPend

            INTERRUPTS_SAVE_DISABLE oldCPSR, R2, R3

            LDR         R2, [R0, #semaphoreObject_t_count_offset]
                                    ;R2=semaphoreObjectPtr->count
            
            CMP         R2, #0
            
            SUBGT       R2, R2, #1  ;R2=R2-1
            
            STRGT       R2, [R0, #semaphoreObject_t_count_offset]   
                                    ;semaphoreObjectPtr->count--;
            
            MOVGT       R0, #1      ;returnValue = 1;
            
            BGT         semaphore_count_greater_than_0
            
            ;semaphore count equal to zero here.
            
            CMP         R1, #0      ;if(waitTime)
            
            MOVEQ       R0, #0      ;returnValue=0.
            
            BEQ         semaphore_wait_flag_is_zero
            
            ;waitTime is non zero here. So insert the running thread into 
            ;wait list and jump to scheduler.
            ;initialize the context equivalent to starting of the function
            ;into running threadObject.
            LDR         R3, =runningThreadObjectPtr
            
            LDR         R3, [R3]
            
            ASSERT      threadObject_t_R_offset = 0
            
            STMIA       R3, {R0-R14}    ;save current context.
            
            ADR         R4, semaphoreObjectPend 
                                        ;R4=semaphoreObjectPend
            
            STR         R4, [R3, #(15*4)]   
                                        ;save PC as beginning of this 
                                        ;function.
            
            LDR         R4, =oldCPSR
            
            LDR         R4, [R4]        ;get the original status.
            
            STR         R4, [R3, #threadObject_t_cpsr_offset] 
                                    ;save the current status of the thread.
            
            ;insert the running thread into waiting list.
            
            ADD         R0, R0, #semaphoreObject_t_waitList_offset  
                                    ;R0=&semaphoreObjectPtr->waitList
            
            MOV         R1, R3      ;R1=&runningThreadObjectPtr
            
            BL          waitlistObjectInsert    
                                    ;listObjectInsert()
            
            LDR         R0, =runningThreadObjectPtr         
                                    ;R0=&&runningThreadObject
            
            LDR         R0, [R0]    ;R0=&runningThreadObject.
            
            LDR         R1, [R0, #threadObject_t_R_offset]  
                                    ;R1=R0 of running thread i.e. 
                                    ;R1=semaphoreObjectPtr
            
            ADD         R1, R1, #semaphoreObject_t_waitList_offset      
                                    ;R1=&waitList of semaphoreObject.
            
            LDR         R2, [R0, #(threadObject_t_R_offset+4)]  
                                    ;R2=waitTime
            
            CMP         R2, #0      ;if(waitTime > 0)

            BLGT        insertIntoTimerList     
                                    ;insertIntoTimerList(&runningThread). 
                                    ;R1 register of threadObject alwasy holds 
                                    ;the waitTime.
            ;jump to scheduler to start next thread.
            
            B           scheduler
            
            
            
semaphore_wait_flag_is_zero

semaphore_count_greater_than_0
            
            INTERRUPTS_RESTORE oldCPSR, R2
            
            BX          LR          ;return returnValue.
            
            
;The semaphoreObjectPost() function increment the semaphore count by 1.
;The High level pseudo code for semaphoreObjectPost() function is shown below.
;void semaphoreObjectPost(semaphoreObject_t *semaphoreObjectPtr)
;{
;   threadObject_t *waitingThreadObjectPtr;
;
;   interruptsDisable();
;   semaphoreObjectPtr->count++;
;   if(listObjectCount(&semaphoreObjectPtr->waitList) > 0)
;   {
;       waitingThreadObjectPtr = 
;                   listObjectDelete(semaphoreObjectPtr->waitList);
;       assert(waitingThreadObjectPtr != NULL);
;       listObjectInsert(readyList, waitingThreadObjectPtr);
;       if(waitingThreadObjectPtr->waitTime >= 0)
;       {
;           deleteFromTimerList(waitingThreadObjectPtr);
;       }
;       if(waitingThreadObjectPtr->priority < runningThread.priority &&
;               this function is not called from interrupt service routine)
;       {
;           get the context same as the end of this function
;           and keep that into the running threadObject.
;           listObjectInsert(&readyList, &runningThreadObject);
;           jump to scheduler();
;       }
;   }
;   interruptsRestore();
;}
            
semaphoreObjectPost

            INTERRUPTS_SAVE_DISABLE oldCPSR, R1, R2
            
            LDR     R2, [R0, #semaphoreObject_t_count_offset]   
                                    ;R2=semaphoreObjectPtr->count
            
            ADD     R2, R2, #1      ;R2=R2+1
            
            STR     R2, [R0, #semaphoreObject_t_count_offset]   
                                    ;semaphoreObjectPtr->count++

            LDR     R1, [R0, #(semaphoreObject_t_waitList_offset+ \
                                            listObject_t_auxInfo_offset)] 
                            ;R1=listObjectCount(&semaphoreObjectPtr->waitList)
            
            CMP     R1, #0  ;if(listObjectCount(&semaphoreObjectPtr->waitList) > 0)
            
            BLE     no_thread_waiting_for_semaphore
            
            ;some thread is waiting for the semaphore.
            ;remove the waiting thread from waitlist and put that into 
            ;readyList.
            ADD     R0, R0, #semaphoreObject_t_waitList_offset  
                                ;R0=&semaphoreObjectPtr->waitList.
            
            STMFD   SP!, {R12,R14}  ;save return address of this function before
                                ;making function call.
            
            ;waitingThreadObjectPtr = 
            ;               listObjectDelete(semaphoreObjectPtr->waitList);
            BL      waitlistObjectDelete 
                                ;After this function call R0 holds 
                                ;waitingThreadObjectPtr.
            
            STMFD   SP!, {R0,R12}       ;save waitingThreadObjectPtr to make 
                                    ;function call.
            
            MOV     R1, R0          ;R1=waitingThreadObjectPtr
            
            LDR     R0, =readyList  ;R0=&readyList
            
            ;listObjectInsert(readyList, waitingThreadObjectPtr);
            BL      waitlistObjectInsert
            
            LDR     R0, [SP]        ;We get R0=waitingThreadObjectPtr
            
            LDR     R1, [R0, #(threadObject_t_R_offset+4)]  ;R1=waitTime
            
            CMP     R1, #0          ;if(waitTime >= 0)
            
            BLGE    deleteFromTimerList
            ;deleteFromTimerList(waitingThreadObjectPtr) 
            ;(when waitTime greater than 0, this threadObject will be in 
            ;timerList).
            
            LDMFD   SP!, {R0, R12}  ;R0 = waitingThreadObjectPtr,
            LDMFD   SP!, {R12, R14}  ;R14=return address of this function.
            
            LDR     R1, =runningThreadObjectPtr ;R1=&runningThreadObjectPtr
            
            LDR     R1, [R1]
            
            LDR     R2, [R0, #threadObject_t_priority_offset]   
                                        ;R2=waitingThreadObjectPtr->priority
            
            LDR     R3, [R1, #threadObject_t_priority_offset]   
                                        ;R3=runningThread.priority.
            
            CMP     R2, R3  ;if(waitingThreadObjectPtr->priority < 
                            ;                       runningThread.priority)
            
            BGE     waiting_thread_not_higer_priority
            
            MRS     R2, CPSR
            
            AND     R2, R2, #0x1F   ;keep the mode bits only.
            
            CMP     R2, #IRQ_MODE   ;if(mode == IRQ_MODE)
            
            BEQ     called_from_interrrupt_service_routine
            ;This function is from interrupt service routine. 
            ;context switch should not be done when called from interrupt
            ;service routine. IRQ handler will do the context switch anyway.
            
            
            ;This function is called form user/system mode thread.
            ;waiting thread has higher priority. Insert running thread 
            ;into ready list and call scheduler.
            
            STMIA   R1, {R0-R14}    ;save registers for running thread.
            
            STR     R14, [R1, #(15*4)]  ;saving the new start point as 
                                        ;return address.
            
            LDR     R2, =oldCPSR
            
            LDR     R2, [R2]            ;get the original status.
            
            SET_STATE_OF_PC_IN_CPSR R14, R2 ;keep the correct mode of the 
                                            ;CPSR for the starting position 
                                            ;of the new PC.
            
            STR     R2, [R1, #threadObject_t_cpsr_offset]   ;save status.
            
            LDR     R0, =readyList          ;R0=&readyList.
            
            ;listObjectInsert(&readyList, &runningThread);
            BL      waitlistObjectInsert
            
            B       scheduler
            
            
no_thread_waiting_for_semaphore
waiting_thread_not_higer_priority           
called_from_interrrupt_service_routine

            INTERRUPTS_RESTORE oldCPSR, R2
            
            BX      LR
            
        

            END


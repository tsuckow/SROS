            INCLUDE rtosAsm.h
            
            IMPORT  runningThreadObjectPtr
            IMPORT  waitlistObjectInsert
            IMPORT  waitlistObjectDelete
            IMPORT  readyList
            IMPORT  scheduler
            IMPORT  oldCPSR

            IMPORT  insertIntoTimerList
            IMPORT  deleteFromTimerList

            EXPORT  mailboxObjectPend
            EXPORT  mailboxObjectPost
        
        
;The below code section implement mailboxObjectPost(), mailboxObjectPend()
;functions.     
        
            AREA mailboxObjectCode, CODE
            
;mailboxObjectPend() function retieve a message from mailbox. The below pseudo
;code show the functionality of the mailboxObjectPend().
;int32 mailboxObjectPend(mailboxObject_t *mailboxObjectPtr,
;                 int32 waitTime,   //Second parameter should be 
;                                   //waitTime for HROS implementation.
;                                   //(similar to mutex, semaphore functions).
;                 void *message)
;{
;   int32 returnValue;
;
;   interruptsDisable();
;   if(mailboxObjectPtr->emptyBufferSize <= 
;       mailboxObjectPtr->mailboxBufferSize - mailboxObjectPtr->messageSize)
;   {
;       //content is available in mailbox. take one message.
;       memcpy(message, 
;               &mailboxObjectPtr->mailboxBuffer[readIndex], 
;               mailboxObjectPtr->messageSize);
;
;       mailboxObjectPtr->readIndex += mailboxObjectPtr->messageSize;
;       mailboxObjectPtr->emptyBufferSize += mailboxObjectPtr->messageSize;
;       
;       assert(mailboxObjectPtr->readIndex <= 
;                               mailboxObjectPtr->mailboxBufferSize);
;       if(mailboxObjectPtr->readIndex == mailboxObjectPtr->mailboxBufferSize)
;       {
;           mailboxObjectPtr->readIndex = 0;
;       }
;       returnValue = 1;
;
;       //if any thread waiting for this mailbox to become empty.
;       if(listObjectCount(&mailboxObjectPtr->waitList) > 0)
;       {
;           waitingThreadObjectPtr = 
;                       listObjectDelete(&mailboxObjectPtr->waitList);
;           assert(waitingThreadObjectPtr != NULL);
;           listObjectInsert(readyList, waitingThreadObjectPtr);
;           if(waitingThreadObjectPtr->waitTime >= 0)
;           {
;               deleteFromTimerList(waitingThreadObjectPtr);
;           }
;           if(waitingThreadObjectPtr->priority < runningThread.priority &&
;               this function not called from interrupt service routine)
;           {
;               get the context same as the end of this function
;               and insert into the running threadObject.
;               listObjectInsert(&readyList, &runningThreadObject);
;               jump to scheduler();
;           }
;       }
;   }
;   else
;   {
;       if(waitTime)
;       {
;           get the context of starting of the function into running 
;           threadObject.
;           listObjectInsert(mailboxObjectPtr->waitList, &runningThreadObject);
;           if(waitTime > 0)
;           {
;               insertIntoTimerList(&runningThread, mailboxObjectPtr->waitList);
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
;with non zero waitTime
mailboxObjectPend

        INTERRUPTS_SAVE_DISABLE oldCPSR, R3, R12

        LDR         R12, [R0, #mailboxObject_t_mailboxBufferSize_offset]    
                                    ;R12=mailboxObjectPtr->mailboxBufferSize
        
        LDR         R3, [R0, #mailboxObject_t_messageSize_offset]       
                                    ;R3=mailboxObjectPtr->messageSize
        
        SUB         R12, R12, R3    
        ;R12=mailboxObjectPtr->mailboxBufferSize-
        ;                               mailboxObjectPtr->messageSize
        
        LDR         R3, [R0, #mailboxObject_t_emptyBufferSize_offset]   
                                    ;R3=mailboxObjectPtr->emptyBufferSize
        
        CMP         R3, R12     
        ;if(mailboxObjectPtr->emptyBufferSize <= 
        ;mailboxObjectPtr->mailboxBufferSize - mailboxObjectPtr->messageSize)
        
        BGT         message_not_available_in_the_mailbox
        
        ;message available in the mailbox.
        ADD         R12, R0, #mailboxObject_t_mailboxBuffer_offset  
                                ;R12=&&mailboxObjectPtr->mailboxBuffer[0]
        
        LDR         R12, [R12]  ;R12=&mailboxObjectPtr->mailboxBuffer[0]

        LDR         R3, [R0, #mailboxObject_t_readIndex_offset]     
                                ;R3=mailboxObjectPtr->readIndex
        
        ADD         R12, R12, R3    
        ;R12=&mailboxObjectPtr->mailboxBuffer[mailboxObjectPtr->readIndex]
        
        LDR         R3, [R0, #mailboxObject_t_messageSize_offset]   
                                ;R8=mailboxObjectPtr->messageSize
        
        ;memcpy(message, 
        ;       &mailboxObjectPtr->mailboxBuffer[readIndex], 
        ;       mailboxObjectPtr->messageSize);
        MEMCPY      R2, R12, R3, R1

        LDR         R2, [R0, #mailboxObject_t_readIndex_offset]     
                                ;R2=mailboxObjectPtr->readIndex
        
        LDR         R1, [R0, #mailboxObject_t_messageSize_offset]   
                                ;R1=mailboxObjectPtr->messageSize
        
        ADD         R2, R2, R1  
        ;R2=mailboxObjectPtr->readIndex+mailboxObjectPtr->messageSize
        
        LDR         R3, [R0, #mailboxObject_t_emptyBufferSize_offset]   
                                ;R3=mailboxObjectPtr->emptyBufferSize
        
        ADD         R3, R3, R1  
        ;R3=mailboxObjectPtr->emptyBufferSize+mailboxObjectPtr->messageSize
        
        STR         R3, [R0, #mailboxObject_t_emptyBufferSize_offset] 
        ;mailboxObjectPtr->emptyBufferSize += mailboxObjectPtr->messageSize
        
        LDR         R3, [R0, #mailboxObject_t_mailboxBufferSize_offset] 
        ;R3=mailboxObjectPtr->mailboxBufferSize
        
        CMP         R2, R3  
        ;if(mailboxObjectPtr->readIndex+mailboxObjectPtr->messageSize == 
        ;mailboxObjectPtr->mailboxBufferSize)
        
        MOVEQ       R2, #0  
        ;if(mailboxObjectPtr->readIndex+mailboxObjectPtr->messageSize == 
        ;mailboxObjectPtr->mailboxBufferSize) then R2=0
        
        STR         R2, [R0, #mailboxObject_t_readIndex_offset] 
        ;mailboxObjectPtr->readIndex += mailboxObjectPtr->messageSize 
        ;(with modulo buffer size)
        
        ;check if any thread is waiting for the mailbox to become empty
        LDR         R3, [R0, #(mailboxObject_t_waitList_offset+ \
                                            listObject_t_auxInfo_offset)]   
        ;R3=listObjectCount(&mailboxObjectPtr->waitList)
        
        CMP         R3, #0  
        ;if(listObjectCount(&mailboxObjectPtr->waitList) > 0)
        
        MOVLE       R0, #1  ;returnValue=1.
        
        BLE         no_thread_is_waiting
        
        ;some thread is waiting for the space in mailbox.
        
        ADD     R0, R0, #mailboxObject_t_waitList_offset    
                                    ;R0=&mailboxObjectPtr->waitList
        
        STMFD   SP!, {R14}          ;save the return address of this function 
                                    ;first to make function call from here.
        
        ;waitingThreadObjectPtr = 
        ;                   listObjectDelete(&mailboxObjectPtr->waitList);
        BL      waitlistObjectDelete    
                        ;After this function R0 = waitingThreadObjectPtr
        
        STMFD   SP!, {R0}           
                        ;save waitingThreadObjectPtr to make function call.
        
        MOV     R1, R0  ;R1=waitingThreadObjectPtr
        
        LDR     R0, =readyList  ;R0=&readyList
        
        ;listObjectInsert(readyList, waitingThreadObjectPtr);
        BL      waitlistObjectInsert
                
        LDR     R0, [SP]        ;We get R0=waitingThreadObjectPtr
                
        LDR     R1, [R0, #(threadObject_t_R_offset+4)]  
                                ;R1=waitTime
                
        CMP     R1, #0          ;if(waitTime >= 0)
                
        BLGE    deleteFromTimerList
                                ;deleteFromTimerList(waitingThreadObjectPtr)
                                ;(when waitTime greater than or equal to 0, 
                                ;this threadObject will be in timerList).
                
        
        LDMFD   SP!, {R0, R14}  
                    ;R0=waitingThreadObjectPtr, 
                    ;R14=return address of this function.
        
        LDR     R2, =runningThreadObjectPtr
        
        LDR     R2, [R2]
        
        LDR     R1, [R0, #threadObject_t_priority_offset]   
                                        ;R1=waitingThreadObjectPtr->priority
        
        LDR     R3, [R2, #threadObject_t_priority_offset]   
                                        ;R3=runningThread.priority
        
        CMP     R1, R3  
        ;if(waitingThreadObjectPtr->priority < runningThread.priority)
        
        MOVGE   R0, #1   ;returnValue = 1
        
        BGE     waiting_thread_is_not_of_higher_priority;
        
        MRS     R1, CPSR
        
        AND     R1, R1, #0x1F       ;keep mode bits only.
        
        CMP     R1, #IRQ_MODE
        
        MOVEQ   R0, #1              ;returnValue=1.
        
        BEQ     called_from_interrupt_service_routine 
        ;This function is called from interrupt service routine. 
        ;context switch should not be done when called from interrupt service
        ;routine. IRQ handler will do the context switch.
        
        ;This functin is called from user/system mode thread.
        ;waiting thread is of higher priority.
        ;insert the running thread into readyList and call scheduler.
        MOV     R0, #1          ;This is the returnValue of the function.
        
        ASSERT  threadObject_t_R_offset = 0
        
        STMIA   R2, {R0-R14}    ;save R0-R14 of running thread.
        
        STR     R14, [R2, #(15*4)]  ;set PC as the return address of
                                    ;this function.
        
        LDR     R1, =oldCPSR
        
        LDR     R1, [R1]    ;get original status.
        
        SET_STATE_OF_PC_IN_CPSR R14, R1 
                            ;make correct CPSR value (with state of PC stored).
        
        STR     R1, [R2, #threadObject_t_cpsr_offset]   ;save status.
        
        LDR     R0, =readyList  ;R0=&readyList.
        
        MOV     R1, R2          ;R1=&runningThreadObject
        
        ;listObjectInsert(&readyList, &runningThread);
        BL      waitlistObjectInsert
        
        B       scheduler
        

message_not_available_in_the_mailbox

        CMP     R1, #0
        
        MOVEQ   R0, #0          ;returnValue is zero.
                
        BEQ     waitTime_is_zero
                
        ;waitTime is non zero
                
        LDR     R3, =runningThreadObjectPtr
        
        LDR     R3, [R3]
        
        ASSERT  threadObject_t_R_offset = 0
        
        STMIA   R3, {R0-R14}    ;save the context of running thread.
        
        ADR     R1, mailboxObjectPend   
        ;R1=program counter to start the thread.
        
        STR     R1, [R3, #(15*4)] ;save PC.
        
        LDR     R1, =oldCPSR
        
        LDR     R1, [R1]        ;get original status.
        
        STR     R1, [R3, #threadObject_t_cpsr_offset]   ;save status.

        MOV     R1, R3          ;R1=runningThread
        
        ADD     R0, R0, #mailboxObject_t_waitList_offset    
                                ;R0=&mailboxObjectPtr->waitList.
        
        ;listObjectInsert(&mailboxObjectPtr->waitList, &runningThreadObject);
        BL      waitlistObjectInsert
                
        ;insert the running thread into the timerList if waitTime>0
                
        LDR     R0, =runningThreadObjectPtr     ;R0 =&&runningThreadObject
                
        LDR     R0, [R0]                        ;R0=&runningThreadObject
                
        LDR     R1, [R0, #threadObject_t_R_offset] 
        ;R1=R0 of running thread=mailboxObjectPtr
                
        ADD     R1, R1, #mailboxObject_t_waitList_offset    
                                                ;R1=&mailboxObjectPtr->waitList
                
        LDR     R2, [R0, #(threadObject_t_R_offset+4)]  
                                                ;R2=waitTime
                
        CMP     R2, #0                          ;if(waitTime > 0)

        BLGT    insertIntoTimerList             
        ;insertIntoTimerList(&runningThread, waitList). 
        ;R1 register of threadObject alwasy holds the waitTime.
                
                
        B       scheduler
        
        
        
waiting_thread_is_not_of_higher_priority
called_from_interrupt_service_routine       
no_thread_is_waiting
waitTime_is_zero

        INTERRUPTS_RESTORE      oldCPSR, R3
                
        BX      LR              ;return returnValue.
                
                
;mailboxObjectPost() function keep a message into the mailbox. The 
;pseudo code of mailboxObjectPost() function is shown below.                            
;int32 mailboxObjectPost(mailboxObject_t *mailboxObjectPtr,
;                 int32 waitTime,
;                 void *message)
;{
;   int32 returnValue;
;
;   interruptsDisable();
;   if(mailboxObjectPtr->emptyBufferSize >= mailboxObjectPtr->messageSize)
;   {
;       //content will fit into mailbox. keep the message.
;       memcpy(&mailboxObjectPtr->mailboxBuffer[writeIndex], 
;               message, 
;               mailboxObjectPtr->messageSize);
;
;       mailboxObjectPtr->writeIndex += mailboxObjectPtr->messageSize;
;       mailboxObjectPtr->emptyBufferSize -= mailboxObjectPtr->messageSize;
;
;       assert(mailboxObjectPtr->writeIndex <= 
;                               mailboxObjectPtr->mailboxBufferSize);
;
;       if(mailboxObjectPtr->writeIndex == 
;                               mailboxObjectPtr->mailboxBufferSize)
;       {
;           mailboxObjectPtr->writeIndex = 0;
;       }
;       returnValue = 1;
;
;       //if any thread waiting for this mailbox to become full.
;       if(listObjectCount(&mailboxObjectPtr->waitList) > 0)
;       {
;           waitingThreadObjectPtr = 
;                   listObjectDelete(&mailboxObjectPtr->waitList);
;           assert(waitingThreadObjectPtr != NULL);
;           listObjectInsert(readyList, waitingThreadObjectPtr);
;           if(waitingThreadObjectPtr->waitTime >= 0)
;           {
;               deleteFromTimerList(waitingThreadObjectPtr);
;           }
;           if(waitingThreadObjectPtr->priority < runningThread.priority &&
;               this function is not called from interrupt service routine)
;           {
;               get the context same as the end of this function and keep it
;               into running threadObject.
;               listObjectInsert(&readyList, &runningThreadObject);
;               jump to scheduler();
;           }
;       }
;   }
;   else
;   {
;       if(waitTime)
;       {
;           get the context same as the starting of this function and keep
;           it into running threadObject
;           listObjectInsert(&mailboxObjectPtr->waitList, &runningThreadObject);
;           if(waitTime > 0)
;           {
;               insertIntoTimerList(&runningThread, 
;                       &mailboxObjectPtr->waitList);
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
;with non zero waitTime

mailboxObjectPost

        INTERRUPTS_SAVE_DISABLE     oldCPSR, R3, R12
        
        LDR         R3, [R0, #mailboxObject_t_emptyBufferSize_offset]   
                                    ;R3=mailboxObjectPtr->emptyBufferSize
        
        LDR         R12, [R0, #mailboxObject_t_messageSize_offset]      
                                    ;R12=mailboxObjectPtr->messageSize
        
        CMP         R3, R12     
        ;if(mailboxObjectPtr->emptyBufferSize >= 
        ;                           mailboxObjectPtr->messageSize)
        
        BLT         enough_space_not_available_in_the_mailbox
        
        ;enough space available for the message to keep.
        
        ADD         R12, R0, #mailboxObject_t_mailboxBuffer_offset  
                                    ;R12=&&mailboxObjectPtr->mailboxBuffer[0]
        
        LDR         R12, [R12]
        
        LDR         R3, [R0, #mailboxObject_t_writeIndex_offset]    
                                    ;R3=writeIndex
        
        ADD         R12, R12, R3
        ;&mailboxObjectPtr->mailboxBuffer[writeIndex]
        
        LDR         R3, [R0, #mailboxObject_t_messageSize_offset]   
                                    ;R3=mailboxObjectPtr->messageSize
        
        ;memcpy(&mailboxObjectPtr->mailboxBuffer[writeIndex], 
        ;       message, 
        ;       mailboxObjectPtr->messageSize)
        
mailboxObjectPostCopy   MEMCPY      R12, R2, R3, R1
        
        LDR         R2, [R0, #mailboxObject_t_writeIndex_offset]    
                                    ;R2=mailboxObjectPtr->writeIndex
        
        LDR         R1, [R0, #mailboxObject_t_messageSize_offset]       
                                    ;R1=mailboxObjectPtr->messageSize
        
        LDR         R3, [R0, #mailboxObject_t_emptyBufferSize_offset]   
                                    ;R3=mailboxObjectPtr->emptyBufferSize
        
        LDR         R12, [R0, #mailboxObject_t_mailboxBufferSize_offset]    
                                    ;R12=mailboxObjectPtr->mailboxBufferSize
        
        ADD         R2, R2, R1      
        ;R2=mailboxObjectPtr->writeIndex+mailboxObjectPtr->messageSize
        
        CMP         R2, R12
        
        MOVEQ       R2, #0  
        ;if(mailboxObjectPtr->writeIndex+mailboxObjectPtr->messageSize == 
        ;mailboxObjectPtr->mailboxBufferSize) then R2=0
                
        STR         R2, [R0, #mailboxObject_t_writeIndex_offset]    
        ;mailboxObjectPtr->writeIndex += mailboxObjectPtr->messageSize 
        ;(with modulo bufferSize)
        
        SUB         R3, R3, R1  
        ;R3=mailboxObjectPtr->emptyBufferSize - mailboxObjectPtr->messageSize;
        
        STR         R3, [R0, #mailboxObject_t_emptyBufferSize_offset]   
        ;mailboxObjectPtr->emptyBufferSize -= mailboxObjectPtr->messageSize
        
        ;check if any thread is waiting for the mailbox to become filled.               
        LDR         R3, [R0, #(mailboxObject_t_waitList_offset+ \
                                                listObject_t_auxInfo_offset)]   
        ;R3=listObjectCount(&mailboxObjectPtr->waitList)
        
        CMP         R3, #0  
        ;if(listObjectCount(&mailboxObjectPtr->waitList) > 0)
        
        MOVLE       R0, #1          ;returnValue=1
        
        BLE         mailboxObjectPost_no_thread_is_waiting
        
        ;some thread(s) is waiting for contents in mailbox.
        ADD     R0, R0, #mailboxObject_t_waitList_offset    
                                    ;R0=&mailboxObjectPtr->waitList
        
        STMFD   SP!, {R14}          ;Save the return address of this function
                                    ;to make function call from here.
        
        ;waitingThreadObjectPtr = 
        ;               listObjectDelete(&mailboxObjectPtr->waitList);
        BL      waitlistObjectDelete    ;After this function R0 = 
                                    ;waitingThreadObjectPtr
        
        STMFD   SP!, {R0}           ;save waitingThreadObjectPtr to make 
                                    ;function call.
        
        MOV     R1, R0              ;R1=waitingThreadObjectPtr
        
        LDR     R0, =readyList      ;R0=&readyList
        
        ;listObjectInsert(readyList, waitingThreadObjectPtr);
        BL      waitlistObjectInsert
                
        LDR     R0, [SP]            ;We get R0=waitingThreadObjectPtr
                
        LDR     R1, [R0, #(threadObject_t_R_offset+4)]  
                                    ;R1=waitTime
                
        CMP     R1, #0              ;if(waitTime >= 0)
                
        BLGE    deleteFromTimerList ;deleteFromTimerList(waitingThreadObjectPtr)
                                    ;(when waitTime greater or equal to 0, this 
                                    ;threadObject will be in timerList).
        
        
        LDMFD   SP!, {R0, R14}      ;R0=waitingThreadObjectPtr. 
                                    ;R14=return address of this function.
        
        LDR     R2, =runningThreadObjectPtr
        
        LDR     R2, [R2]
        
        LDR     R1, [R0, #threadObject_t_priority_offset]   
                                    ;R1=waitingThreadObjectPtr->priority
        
        LDR     R3, [R2, #threadObject_t_priority_offset]   
                                    ;R3=runningThread.priority
        
        CMP     R1, R3          
        ;if(waitingThreadObjectPtr->priority < runningThread.priority)
        
        MOVGE   R0, #1              ;returnValue=1
        
        BGE     mailboxObjectPost_waiting_thread_is_not_of_higher_priority;
        
        MRS     R1, CPSR
        
        AND     R1, R1, #0x1F       ;keep only mode bits.
        
        CMP     R1, #IRQ_MODE
        
        MOVEQ   R0, #1              ;returnValue=1
        
        BEQ     mailboxObjectPost_called_from_interrupt_service_routine
        
        
        ;This thread is called form user/system mode thread.
        ;waiting thread is of higher priority.
        ;insert the running thread into readyList and jump to scheduler.
        MOV     R0, #1      ;returnValue=1
        
        STMIA   R2, {R0-R14}        ;save R0-R12 of running thread.
        
        STR     R14, [R2, #(15*4)]  
                                    ;save PC as return address of this function.
        
        LDR     R1, =oldCPSR
        
        LDR     R1, [R1]            ;get original status.
        
        SET_STATE_OF_PC_IN_CPSR R14, R1 
                                    ;make correct CPSR for the PC stored.
        
        STR     R1, [R2, #threadObject_t_cpsr_offset]   
                                    ;save status.
        
        LDR     R0, =readyList      ;R0=&readyList.
        
        MOV     R1, R2              ;R1=&runningThread
        
        ;listObjectInsert(&readyList, &runningThreadObject);
        BL      waitlistObjectInsert
        
        B       scheduler
        
        

enough_space_not_available_in_the_mailbox

        CMP     R1, #0
        
        MOVEQ   R0, #0              ;returnValue = 0
                
        BEQ     mailboxObjectPost_waitTime_is_zero
                
        ;waitTime is non zero
        LDR     R3, =runningThreadObjectPtr
        
        LDR     R3, [R3]
        
        STMIA   R3, {R0-R14}        ;save the context of running thread.
        
        ADR     R1, mailboxObjectPost   
                                    ;R1=program counter to start the thread.                

        STR     R1, [R3, #(15*4)]   ;save PC.
        
        LDR     R1, =oldCPSR
        
        LDR     R1, [R1]            ;get original status.
        
        STR     R1, [R3, #threadObject_t_cpsr_offset]   
                                    ;save status.
        
        MOV     R1, R3              ;R1=runningThread
        
        ADD     R0, R0, #mailboxObject_t_waitList_offset    
                                    ;R0=&mailboxObjectPtr->waitList.
        
        ;listObjectInsert(&mailboxObjectPtr->waitList, &runningThreadObject);
        BL      waitlistObjectInsert
                
        ;insert the running thread into the timerList if waitTime>0
                
        LDR     R0, =runningThreadObjectPtr     
                                    ;R0 =&&runningThreadObject
                
        LDR     R0, [R0]            ;R0=&runningThreadObject
                
        LDR     R1, [R0, #threadObject_t_R_offset] 
                                    ;R1=R0 of running thread=mailboxObjectPtr
                
        ADD     R1, R1, #mailboxObject_t_waitList_offset    
                                    ;R1=&mailboxObjectPtr->waitList
                
        LDR     R2, [R0, #(threadObject_t_R_offset+4)]  
                                    ;R2=waitTime
                
        CMP     R2, #0              ;if(waitTime > 0)

        BLGT    insertIntoTimerList 
        ;insertIntoTimerList(&runningThread, waitList). 
        ;R1 register of threadObject alwasy holds the waitTime.
                
        B       scheduler
                
                
mailboxObjectPost_waiting_thread_is_not_of_higher_priority
mailboxObjectPost_called_from_interrupt_service_routine
mailboxObjectPost_no_thread_is_waiting
mailboxObjectPost_waitTime_is_zero

        INTERRUPTS_RESTORE  oldCPSR, R3
        
        BX      LR                  ;return returnValue.
                        

        
        END

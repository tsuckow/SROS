            INCLUDE rtosAsm.h
            
            IMPORT  runningThreadObjectPtr
            IMPORT  listObjectInsert
            IMPORT  listObjectDelete
            IMPORT  readyList
            IMPORT  irq_interrupt_service_routine
            IMPORT  is_thread_switch_needed
            IMPORT  __main

            IMPORT  insertIntoTimerList
            IMPORT  deleteFromTimerList
            
            EXPORT  scheduler
            EXPORT  rtosInitAsm
            EXPORT  block
            EXPORT  sleep
            EXPORT  irq_interrupt_handler
            EXPORT  interrupt_disable
            EXPORT  interrupt_restore
            EXPORT  threadObjectCreate
            EXPORT  oldCPSR

            
            AREA srosData, DATA
            
oldCPSR DCD 0
            
            
            GBLS    R13_irq
            GBLS    R14_irq
            GBLS    SPSR_irq
            
R13_irq     SETS    "R13"
R14_irq     SETS    "R14"
SPSR_irq    SETS    "SPSR"      

;The below section is vector table of ARM processor.
;This code section has to be placed at 0x00000000 for low vectors
;or at 0xFFFF0000 for high vectors.

            AREA    vectorTable, CODE

            B       reset_interrupt_handler         
                                ;0x0000 for reset interrupt
            B       reset_interrupt_handler         
                                ;0x0004 for Undefined instructions interrupt
            B       reset_interrupt_handler         
                                ;0x0008 for SWI interrupts.
            B       reset_interrupt_handler         
                                ;0x000c for instruction fetchabort.
            B       reset_interrupt_handler         
                                ;0x0010 for data abort.
            B       reset_interrupt_handler         
                                ;0x0014 reserved.
            B       irq_interrupt_handler           
                                ;0x0018 for irq interrupts.
            B       reset_interrupt_handler         
                                ;0x001c for fiq interrupts.



            AREA    interrupt_disable_code, CODE

interrupt_disable
            INTERRUPTS_SAVE_DISABLE oldCPSR, R0, R1
            
            BX  LR

            AREA    interrupt_restore_code, CODE
        
interrupt_restore
            INTERRUPTS_RESTORE  oldCPSR, R0
        
            BX  LR
                
;The below code section changes the processor mode to IRQ mode
;i.e (kernel mode).
;This code section also initializes the current mode (superviser mode)
;stack pointer to IRQ mode stack pointer. This function copies the 
;return address in superviser mode to IRQ mode LR so that it can use
;it for returning.

            AREA    rtosInitAsm_code, CODE
rtosInitAsm
            ;This function changes the processor mode to IRQ mode.
            MRS     R0, CPSR            ;get the status.
            
            BIC     R0, R0, #0x1F       ;remove mode bits.
            
            ORR     R0, R0, #IRQ_MODE   ;make mode as IRQ mode.
            
            ;before writing the mode into CPSR, save R13, R14 and keep 
            ;the same R13, R14 into IRQ mode.
            MOV     R1, R13             ;get the stack pointerof superviser 
                                        ;mode.
            
            MOV     R2, R14             ;save the return address to return
                                        ;later.
            
            MSR     CPSR_c, R0          ;write the status register to change
                                        ;the processor mode.
            
            MOV     R13, R1             ;initialize the stack pointer for IRQ
                                        ;mode.
            
            MOV     R14, R2             ;Get the return address into LR.
            
            BX      LR                  ;return using the return address.


;This code section is code section for block() function. This block function
;keep the runnning threadObject into the readyList and jump to scheduler to
;start the highest priority ready thread. If the running thread is the highest
;priority ready thread then calling block() function does not result in 
;context switch and do not have any effect in the system.
;Note: As interrupt service routine is not a thread, this function should
;not be called from interrupt service routine.

            AREA    block_code, CODE
block
            INTERRUPTS_SAVE_DISABLE oldCPSR, R2, R3     ;disable interrupts
            
            ;creating context for the current running thread.
            ;take the context as the end of the block() function.
            
            LDR     R1, =runningThreadObjectPtr     
                                        ;R1=&runningThreadObjectPtr
            
            LDR     R1, [R1]            ;R1=&runningThreadObject
            
            ASSERT  threadObject_t_R_offset = 0
            
            STMIA   R1, {R0-R14}            
                                        ;saved registers R0-R14 in 
                                        ;the running threadObject.
            
            STR     R14, [R1, #(15*4)]      
                                        ;save the return address as the 
                                        ;starting point (i.e. PC) when the
                                        ;thread starts later.
            
            LDR     R4, =oldCPSR
            
            LDR     R4, [R4]                
                                        ;get current status of the thread
                                        ;when it enters this function.
            
            SET_STATE_OF_PC_IN_CPSR R14, R4
                                        ;This macro keep the correct state of
                                        ;later starting point of the thread
                                        ;in R4
            
            STR     R4, [R1, #threadObject_t_cpsr_offset]
                                        ;save the correct status of the 
                                        ;thread into the threadObject CPSR
            
            ;insert the running thread into readyList.
            
            LDR     R0, =readyList

            BL      listObjectInsert 
                                        ;insert the running threadObject 
                                        ;into the readyList.
                                    
            ;jump to scheduler
            
            B       scheduler
            
;The below code section implement sleep() function. This function should not 
;be called from interrupt servicer routine. The pseudo code of the sleep()
;function is shown below.
;void sleep(int waitTime)
;{
;   interrupts_disable();
;   collect context equivalent to end of the function into the 
;   running threadObject and keep it into the timerList;
;   Jump to Scheduler();
;}

            
            AREA    sleep_code, CODE
            
sleep
            INTERRUPTS_SAVE_DISABLE oldCPSR, R2, R3
                                            ;disable interrupts.

            ;keep the context of the running thread into the 
            ;running threadObject.
            
            MOV     R1, R0                  ;R1=waitTime. waitTime should be 
                                            ;always in R1 register 
                                            ;(similar to mutex, semaphore, 
                                            ;mailbox function calls).
            
            LDR     R0, =runningThreadObjectPtr     
                                            ;R0=&runningThreadObjectPtr
            
            LDR     R0, [R0]
            
            ASSERT  threadObject_t_R_offset = 0
            
            STMIA   R0, {R0-R14}            ;saved all registers R0-R14 in the
                                            ;ready thread.
            
            STR     R14, [R0, #(15*4)]      ;save the return address as the 
                                            ;starting point of the PC when the
                                            ;thread starts.
            
            LDR     R4, =oldCPSR
            
            LDR     R4, [R4]                ;get current status of the thread.
            
            SET_STATE_OF_PC_IN_CPSR R14, R4 ;This macro keep the state of 
                                            ;PC in R4
            
            STR     R4, [R1, #threadObject_t_cpsr_offset] 
                                            ;save the current status of the 
                                            ;thread.
            
            ;insert the running thread into timerList.
            
            MOV     R1, #0                  ;wait list is null. 
                                            ;Running thread will only wait in 
                                            ;timer list.
            
            BL      insertIntoTimerList     
            ;insertIntoTimerList(&runningThread, NULL);
            
            ;jump to scheduler
            
            B       scheduler
            





            AREA    schuduler_code, CODE


;The below code section is code for scheduler. The scheduler first disables
;interrupts and set the mode to kernel mode (irq mode)
;and loads the context of the highest priority ready thread in the system.
;As starting of the highest priority read thread is also done in the 
;interrupt handler code, the below code section just jump to interrupt 
;handler code section to reuse the code in interrupt handler.
;The pseudo code of the scheduler is shown below.
;void scheduler(void)
;{
;   threadObject_t *threadObjectPtr;
;
;   disableInterrupts();
;   change the processor mode to kernel mode; (if it is not in kernel mode).
;   threadObjectPtr = listObjectDelete(&readyList);
;   
;   load the context in the threadObjectPtr.
;   start running from the PC in the threadObjectPtr.
;}

            AREA    schuduler_code, CODE

scheduler       
scheduler INTERRUPTS_DISABLE R0     ;disable interrupts.

        ;change to kernel mode.
        ;This is necessary as we do not have SPSR in system mdoe. 
        ;So go to IRQ mode to load SPSR and copy that into CPSR.
        SET_IRQ_MODE    R0

        ;make a jump to the interrupt handler code section which has
        ;the functionality of starting the highest priority thread
        ;from readyList.
        B       start_high_priority_thread
        
;The below code section is the reset interrupt handler code section.
;The reset interrupt handler just jump to the entry point of the embedded
;application.

        AREA    reset_interrupt_handler_code, CODE
        
reset_interrupt_handler

        B       __main          ;branch to entry point. If the embedded
                                ;application entry point is not __main
                                ;__main has to be replaced by the entry 
                                ;point.
        

;The below code section implement the irq_interrupt_handler.
;The irq interrupt handler just call irq_interrupt_service_routine().
;Note that irq_interrupt_service_routine() should not use interrupt
;key word of C language. The irq_interrupt_service_routine() should
;be developed like normal C function. The saving and restoring of 
;callee preserve register in the calling convention i.e.R0-R3, R12 
;are done by the interrupt handler.
;The irq_interrupt_handler do context switch if needed after the 
;irq_interrupt_service_routine() returns. Note that any SROS call that 
;can block should not be called in irq_interrupt_service_routine().
;After the irq_interrupt_service_routine() returns, irq_interrupt_handler
;do context switch if needed. Note that instead of jumping to schuduler()
;irq_interrupt_handler() implemented the code to start the highest priority
;ready thread in the system. (Infact schuduler() function is also using the
;same code that is irq_interrupt_handler_code section.
;The pseudo code of the irq_interrupt_handler() is shown below.
;void irq_interrupt_handler(void)
;{
;   irq_interrupt_service_routine();
;   if (running thread priority higher than highest 
;               thread priority in the readyList)
;   {
;       return to the interrupted thread.
;   }
;   else
;   {
;       Get the context exactly equal to the position when 
;       interrupt happened in the running thread, Save that
;       context into the running threadObject.
;       Insert the running threadObject into readyList. 
;       jump to scheduler tostart the highest priority ready thread.
;   }
;}
        
        AREA    irq_interrupt_handler_code, CODE
        
irq_interrupt_handler

        ;R13_irq, R14_irq, spsr_irq are active here. cpsr of the interrupted 
        ;thread is stored in spsr_irq.
        ;So we are operating on irq stack here.

        SUB     $R14_irq, $R14_irq, #4              
                                ;calculate the actual address to be returned.
        
        STMFD   $R13_irq!, {R0-R3, R12, $R14_irq}       
                                ;save the interrupted thread registers.
                                ;This step is necessary as the
                                ;irq_interrupt_service_routine() may destroy
                                ;those registers.
                                        
        BL      irq_interrupt_service_routine
                                ;call the user defined 
                                ;irq_interrupt_service_routine().
        
        BL      is_thread_switch_needed
                                ;check if context switch is necessary.
                                ;If irq_interrupt_service_routine() has
                                ;triggered a higher priority thread than
                                ;running thread to ready state, 
                                ;then context switch will become necessary.
        
        CMP R0, #0              ;if(is_thread_switch_needed()==0)
        
        LDMEQFD $R13_irq!, {R0-R3, R12, PC}^        
                                ;thread switch is not needed. So returning 
                                ;to the interrupted (i.e. running) thread.
                                ;SPSR_irq copied to CPSR. This is LDM (3) 
                                ;instruction.
        
        ;context switch is necessary. So
        ;save the current thread context first
        LDR     R0, =runningThreadObjectPtr
        
        LDR     R0, [R0]        ;R0=&runningThreadObject
        
        MRS     R1, $SPSR_irq   ;interrupted thread CPSR is on SPSR_irq. 
                                ;So get that.
        
        ASSERT  threadObject_t_R_offset = 0
        
        STR     R1, [R0, #threadObject_t_cpsr_offset]   
                                ;save interrupted thread CPSR.
        
        LDMFD   $R13_irq!, {R2, R3}             
                                ;get interrupted thread R0, R1 into R2, R3 
                                ;respectively.
        
        STMIA   R0!, {R2, R3}   ;save interrupted thread R0, R1. 
                                ;R0=&runningThread+8
        
        LDMFD   $R13_irq!, {R2, R3, R12, $R14_irq} 
                                ;load the interrupted thread registers that
                                ;we have saved on the stack.
                                ;(NOTE:R14 loaded is R14_irq as we are in 
                                ;IRQ mode).
        
        STR     $R14_irq, [R0, #(15*4-8)]       
                                ;save the R14_irq as the starting point of 
                                ;execution of the interrupted thread.
        
        STMIA   R0, {R2-R14}^                   
                                ;Save the interrupted thread registers.
                                ;save user/system mode registers. 
                                ;This instruction 
                                ;loads always user mode registers even though
                                ; we are in IRQ mode. (STM (2) instruction).
                                ;Note that previously R0=&runningThread.R[2]
        
        ;now insert the runningThread into readyList.
        ;listObjectInsert(listObject_t *listNodePtr, void *newElement)
        
        SUB     R1, R0, #(2*4)          
                                ;R1=&runningThread
        
        LDR     R0, =readyList          
                                ;R0=&readyList.
        
        BL      listObjectInsert        
                                ;insert the interrupted threadObject into the 
                                ;readyList.
        
        ;Now we are ready to load the context of the highest priority 
        ;threadObject from the readyList.

start_high_priority_thread
        
        ;get the new thread object to be started.
        ;threadObject = void *listObjectDelete(listObject_t *listObjectPtr);

        LDR     R0, =readyList
        
        BL      listObjectDelete
                                ;get the high priority thread to be run. 
                                ;After this function R0 holds the 
                                ;&threadObject
        
        LDR     R1, =runningThreadObjectPtr
        
        STR     R0, [R1]        ;store runninThreadObject pointer.
        
        LDR     R12, [R0, #threadObject_t_cpsr_offset]  
                                ;get the cpsr of the threadObject.
        
        MSR     $SPSR_irq._fsxc, R12                        
                                ;save the cpsr into SPSR (SPSR will be copied
                                ;into CPSR at exit of this function).
        
        ASSERT  threadObject_t_R_offset = 0
        
        LDR     $R14_irq, [R0, #(15*4)]                 
                                ;get PC value into R14_irq (R14_irq will be 
                                ;copied into PC at exit of this function).
        
        LDMIA   R0, {R0-R14}^   ;load saved R0-R14 of high priority thread 
                                ;into user mode R0-R14 registers. (LDM (2) 
                                ;instruction)
        
        NOP                     ;can not use banked registers after user 
                                ;mode LDM.
        
        
        MOVS    PC, $R14_irq    ;PC=R14_irq, CPSR=SPSR_irq
                                ;After this instruction the highest priority
                                ;ready thread in the system will start running
        
;The below code section create a new thread in the system. The new thread
;creation is done by saving appropriate context for the new thread in to the
;readyList.
;If the new thread created has higher priorty than running thread, context
;switch will happen. (if context switch is allowed).
;The pseudo code of the threadObjectCreate() function is shown below.
;void threadObjectCreate(threadObject_t *threadObjectPtr, 
;                       void (*functionPtr)(void*, ...), 
;                       int32 arg1, 
;                       int32 arg2, 
;                       int32 arg3, 
;                       int32 arg4, 
;                       int32* stackPointer, 
;                       uint32 priority, 
;                       uint32 cpsr, 
;                       int8 *threadObjectName)
;{
;   threadObjectPtr->R[15] = (int32)(functionPtr);
;   threadObjectPtr->R[0] = arg1;
;   threadObjectPtr->R[1] = arg2;
;   threadObjectPtr->R[2] = arg3;
;   threadObjectPtr->R[3] = arg4;
;   threadObjectPtr->R[13] = (int32)(stackPointer);
;   threadObjectPtr->R[14] = scheduler;
;   threadObjectPtr->priority = priority;
;   threadObjectPtr->threadObjectName = threadObjectName;
;   interruptDisable();
;
;   listObjectInsert(&readyList, threadObjectPtr);
;   
;   if(priority < runningThreadObjectPtr->priority &&
;           context switch is allowed)
;   {
;       get the context of running thread functionally equivalent to end of
;       this function.
;       listObjectInsert(&readyList, 
;                       runningThreadObjectPtr);
;       jump to scheduler().
;   }
;   
;   interruptsRestore();
;}
        
        AREA    threadObjectCreate_code, CODE

threadObjectCreate

            GBLS    threadObjectPtrR0
            GBLS    functionPtrR1
            GBLS    arg1R2
            GBLS    arg2R3
                        
threadObjectPtrR0   SETS    "R0"
functionPtrR1       SETS    "R1"
arg1R2              SETS    "R2"
arg2R3              SETS    "R3"
arg3_offset         EQU     0
arg4_offset         EQU     4
stackPointer_offset EQU     8
priority_offset     EQU     12
cpsr_offset         EQU     16
threadObjectName_offset EQU 20

            ASSERT  threadObject_t_R_offset = 0
            
            STR     $functionPtrR1, [$threadObjectPtrR0, #(15*4)]   
                                        ;threadObjectPtr->R[15]=functionPtr
            
            STR     $arg1R2, [$threadObjectPtrR0, #(0*4)]   
                                        ;threadObjectPtr->R[0] = arg1
            
            STR     $arg2R3, [$threadObjectPtrR0, #(1*4)] 
                                        ;threadObjectPtr->R[1] = arg2
            
            LDR     R12, [SP, #arg3_offset]     
                                        ;R12=arg3
            
            STR     R12, [$threadObjectPtrR0, #(2*4)]   
                                        ;threadObjectPtr->R[2]=arg3
            
            LDR     R12, [SP, #arg4_offset]     
                                        ;R12=arg4
            
            STR     R12, [$threadObjectPtrR0, #(3*4)]   
                                        ;threadObjectPtr->r[3]=arg4
            
            LDR     R12, [SP, #stackPointer_offset]     
                                        ;R12=stackPointer
            
            STR     R12, [$threadObjectPtrR0, #(13*4)]  
                                        ;threadObjectPtr->R[13]=stackPointer.
            
            LDR     R12, =scheduler
            
            STR     R12, [$threadObjectPtrR0, #(14*4)]  
                                        ;threadObjectPtr->R[14]=scheduler
            
            LDR     R12, [SP, #priority_offset]         
                                        ;R12=priority.
            
            STR     R12, [$threadObjectPtrR0, #threadObject_t_priority_offset]  
                                        ;threadObjectPtr->priority=priority.
            
            LDR     R1, [SP, #cpsr_offset]  
                                        ;R1=cpsr
            
            STR     R1, [$threadObjectPtrR0, #threadObject_t_cpsr_offset]   
                                        ;save CPSR
            
            LDR     R1, [SP, #threadObjectName_offset]  
                                        ;R1=threadObjectName
            
            STR     R1, [$threadObjectPtrR0, \
                            #threadObject_t_threadObjectName_offset]    
                                        ;save name pointer.
            
            MOV     R1, #0      ;R1=0
            
            STR     R1, [$threadObjectPtrR0, #threadObject_t_waitListTimer_offset]  
            ;waitListTimer=0 as the current thread object is not in timer list.
            
            STR     R1, [$threadObjectPtrR0, #threadObject_t_waitListResource_offset]   
            ;waitListResource should be 0 before inserting into any list.
                        
            INTERRUPTS_SAVE_DISABLE oldCPSR, R1, R2
            
            MOV     R1, R0              ;R1=threadObjectPtr
            
            LDR     R0, =readyList      ;R0=readyList
            
            STMFD   SP!, {LR}
            
            ;listObjectInsert(&readyList, threadObject);
            BL      listObjectInsert

            ;check if scheduler is started. If scheduler is not started
            ;then runningThreadObjectPtr = 0.
            
            LDR     R0, =runningThreadObjectPtr     
                                        ;R0=&runningThreadObjectPtr
            
            LDR     R0, [R0]            ;R0=runningThreadObjectPtr
            
            CMP     R0, #0              ;if(runningThreadObjectPtr == 0) 
            
            BEQ     schuduler_is_not_started        
                                        ;if(runningThreadObjectPtr == 0) 
                                        ;then just return
            
            ;if called from the interrupt service routine, then just return.
            MRS     R1, CPSR            ;get the current status
            
            AND     R1, R1, #0x1F       ;keep only mode bits.
            
            CMP     R1, #IRQ_MODE       ;check weather we are in kernel mode.
            
            BEQ     called_from_interrupt_service_routine
                                        ;This function is called from 
                                        ;interrupt service routine.
                                        ;So just return.
                                                    
            BL      is_thread_switch_needed
            
            CMP     R0, #0
            
            BEQ     context_switch_not_needed
            
            INTERRUPTS_RESTORE oldCPSR, R1          
                                        ;restore the original interrupts 
                                        ;status.
            
            BL      block               ;context switch is needed. 
                                        ;Just call block
                                        ;block function keep the 
                                        ;running thread into readyList
                                        ;and start the highest priority 
                                        ;thread available in the readyList.
            
            LDMFD   SP!, {PC}           ;return         
            
schuduler_is_not_started
called_from_interrupt_service_routine   
context_switch_not_needed           

            INTERRUPTS_RESTORE oldCPSR, R1          
                                        ;get original interrupts status.
            
            
            LDMFD   SP!, {PC}           ;return
            
            
        
        

            END

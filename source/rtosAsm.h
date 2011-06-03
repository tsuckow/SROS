                            IF :LNOT::DEF: __rtosAsm_h__
                            
                            GBLS    __rtosAsm_h__
__rtosAsm_h__               SETS    "1"

USER_MODE               EQU     2_10000
SYSTEM_MODE             EQU     2_11111
FIQ_MODE                EQU     2_10001
IRQ_MODE                EQU     2_10010
SVC_MODE                EQU     2_10011
ABT_MODE                EQU     2_10111
UND_MODE                EQU     2_11011

;How many timer ticks is a thread quantum when first created
timeQuantumDuration EQU 20



            MACRO
$lable      INTERRUPTS_DISABLE  $scratchRegister
            
            MRS     $scratchRegister, CPSR
            
            ;disable 6th (F), 7th (I)bits. (bit count starts from 0)
            ORR     $scratchRegister, $scratchRegister, #0x000000C0 ;set F, I bits.
            
            MSR     CPSR_c, $scratchRegister
            
            MEND
            




            MACRO   
$lable      INTERRUPTS_SAVE_DISABLE $cpsrSaveMemoryAddress, $scratchRegister1, $scratchRegister2

            MRS     $scratchRegister1, CPSR
            
            MOV     $scratchRegister2, $scratchRegister1
            
            ;disable 6th (F), 7th (I)bits. (bit count starts from 0)
            ORR     $scratchRegister1, $scratchRegister1, #0x000000C0   ;clear F, I bits.
            
            MSR     CPSR_c, $scratchRegister1
            
            LDR     $scratchRegister1, =$cpsrSaveMemoryAddress
            
            STR     $scratchRegister2, [$scratchRegister1]
            
            
            MEND
            
            
            MACRO
$lable      INTERRUPTS_RESTORE  $cpsrSaveMemoryAddress, $scratchRegister

            LDR     $scratchRegister, =$cpsrSaveMemoryAddress   ;get the oldCPSR address into register.
            
            LDR     $scratchRegister, [$scratchRegister] ;load the old CPSR
            
            MSR     CPSR_c, $scratchRegister    ;restore the old CPSR.
            
            MEND
            
            
            MACRO
$label      MEMCPY  $destAddressRegister, $sourceAddressRegister, $noOfBytesRegister, $scratchRegister

$label.loop
            LDRB    $scratchRegister, [$sourceAddressRegister], #1
            
            STRB    $scratchRegister, [$destAddressRegister], #1
            
            SUBS    $noOfBytesRegister, $noOfBytesRegister, #1
            
            BGT     $label.loop
            
            MEND
            
            MACRO
            SET_IRQ_MODE    $scratchRegister
            
            MRS     $scratchRegister, CPSR
            
            BIC     $scratchRegister, $scratchRegister, #0x1F   ;keep only mode bits.
            
            ORR     $scratchRegister, $scratchRegister, #IRQ_MODE
            
            MSR     CPSR_c, $scratchRegister
            
            MEND
            
            
            MACRO
            SET_STATE_OF_PC_IN_CPSR $pcRegister, $cpsrRegister
            
            AND     $pcRegister, $pcRegister, #0x1      ;$pcRegister = the mode of the PC when the thread starts next time (0-ARM, 1-Thumb)

            ORR     $cpsrRegister, $cpsrRegister, $pcRegister, LSL #5       ;set the appropriate mode for the next PC.  5 is THUMB bit position in CPSR.    
            
            MEND    
            
            
        
listNode_t_element_offset       EQU 0
listNode_t_auxInfo_offset       EQU 4
listNode_t_nextListNode_offset  EQU 8
listNode_t_size                 EQU 12

listObject_t_element_offset     EQU 0
listObject_t_auxInfo_offset     EQU 4
listObject_t_nextListNode_offset    EQU 8
listObject_t_size               EQU 12
        
        
mutexObject_t_mutex_offset      EQU     0
;mutexObject_t_waitList_offset   EQU     4
;mutexObject_t_size              EQU     (4+listObject_t_size)
        
threadObject_t_R_offset                 EQU     0
threadObject_t_cpsr_offset              EQU     64
threadObject_t_priority_offset          EQU     68
threadObject_t_waitListResource_offset  EQU     72
threadObject_t_waitListTimer_offset     EQU     76
threadObject_t_threadObjectName_offset  EQU     80
threadObject_t_timeQuantum_offset       EQU     84
threadObject_t_innatePriority_offset     EQU     88
threadObject_t_promotee_offset          EQU     92
threadObject_t_promoterList_offset      EQU     96
threadObject_t_size                     EQU     96+listObject_t_size

mailboxObject_t_mailboxBuffer_offset    EQU     0
mailboxObject_t_readIndex_offset        EQU     4
mailboxObject_t_writeIndex_offset       EQU     8
mailboxObject_t_mailboxBufferSize_offset EQU    12
mailboxObject_t_emptyBufferSize_offset  EQU     16
mailboxObject_t_messageSize_offset      EQU     20
mailboxObject_t_waitList_offset         EQU     24
mailboxObject_t_size                    EQU     (24+listObject_t_size)
        
semaphoreObject_t_count_offset              EQU     0
semaphoreObject_t_waitList_offset           EQU     4
semaphoreObject_t_size                      EQU     (4+listObject_t_size)       
        
        
        
        
        
        
        
        
        
        
        
            ENDIF


            END

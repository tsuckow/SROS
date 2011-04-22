            IMPORT ||Image$$all$$ZI$$Limit||

            EXPORT __user_initial_stackheap
            EXPORT stackInit
            
            AREA    userInitialStackHeapCode, CODE
__user_initial_stackheap    
stackInit
            LDR     R0, =||Image$$all$$ZI$$Limit||
            ADD     R0, R0, #8
            BIC     R0, R0, #8      ;To align to 8 byte boundary.
            LDR     R2, =0x18000000
            
            LDR     R3, =||Image$$all$$ZI$$Limit||
            LDR     R1, =0x18000000

;           LDR     R0, =||Image$$all$$ZI$$Limit||

            BX      LR
            
            END
                                    
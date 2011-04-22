#include <stdio.h>
#include <stdlib.h>
#include "rtos.h"

#define MAILBOX_SIZE    1
mailboxObject_t testMailbox;
int32           mailboxBuffer[MAILBOX_SIZE];


threadObject_t thread1, thread2;
void function1(void);
void function2(void);
int32 stack1[1000], stack2[1000];

int main(void)
{
    rtosInit();
    
    threadObjectCreate(&thread1,
                        (void *)function1,
                        0,
                        0,
                        0,
                        0,
                        &stack1[1000],
                        10,
                        INITIAL_CPSR_ARM_FUNCTION,
                        "thread1");
                        
    threadObjectCreate(&thread2,
                        (void *)function2,
                        0,
                        0,
                        0,
                        0,
                        &stack2[1000],
                        20,
                        INITIAL_CPSR_ARM_FUNCTION,
                        "thread2");
                        
    mailboxObjectInit(&testMailbox,
                        (void *)mailboxBuffer,
                        4*MAILBOX_SIZE,
                        4);
    
    srand(1);
                        
    scheduler();            //This function will never return.
}                       
                        
                        
void function1(void)
{
    int waitTime;
    int32 message = 0;
    
    while(1)
    {
        waitTime = rand() % 5 - 2;
        
        printf("posting message %d in thread1 with waitTime=%d\n", message, waitTime);
        if(mailboxObjectPost(&testMailbox, waitTime, &message))
        {
            printf("posting message %d in thread1 with waitTime %d is successful\n", message, waitTime);
        }
        else
        {
            printf("posting message %d in thread1 with waitTime %d failed\n", message, waitTime);
        }
        
        message++;      
    }
}

void function2(void)
{
    int waitTime;
    int32 message;

    while(1)
    {
        waitTime = rand() % 5 - 2;
        
        if(mailboxObjectPend(&testMailbox, waitTime, &message))
        {
            printf("retrieving message from mailbox with waitTime %d succeded. message=%d\n", waitTime, message);
        }
        else
        {
            printf("retrieving message from mailbox with waitTime %d failed\n", waitTime);
        }       
    }

}
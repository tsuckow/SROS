#include <stdio.h>
#include <stdlib.h>
#include "rtos.h"

mutexObject_t   testMutex;

threadObject_t thread1, thread2, thread3;
void function1(void);
void function2(void);
void function3(void);
int32 stack1[1000], stack2[1000], stack3[1000];

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
                        1,
                        INITIAL_CPSR_ARM_FUNCTION,
                        "thread1");
                        
    threadObjectCreate(&thread2,
                        (void *)function2,
                        0,
                        0,
                        0,
                        0,
                        &stack2[1000],
                        2,
                        INITIAL_CPSR_ARM_FUNCTION,
                        "thread2");
                        
    threadObjectCreate(&thread3,
                        (void *)function3,
                        0,
                        0,
                        0,
                        0,
                        &stack3[1000],
                        3,
                        INITIAL_CPSR_ARM_FUNCTION,
                        "thread3");
                        
    mutexObjectInit(&testMutex, 0);
    
    srand(1);
                        
    scheduler();            //This function will never return.
}                       
                        
                        
void function1(void)
{
    int choice;
    int waitTime;
    
    while(1) 
    {
        choice = rand() % 2 + 1;
        waitTime = rand() % 3 - 1;
        
        switch(choice)
        {
        case 1:
            printf("trying to lock testMutex in thread1 with waitTime %d\n", waitTime);
            if(mutexObjectLock(&testMutex, waitTime))
            {
                printf("testMutex got locked in thread1 with waitTime %d\n", waitTime);
            }
            else
            {
                printf("testMutex did not get locked in thread1 with waitTime %d\n", waitTime);
            }
            break;
            
        case 2:
            printf("trying to release testMutex in thread1\n");
            mutexObjectRelease(&testMutex);
            printf("testMutex got released in thread1\n");
            break;
        }
    }
}
                    
            

void function2(void)
{
    int choice;
    int waitTime;
    
    while(1) 
    {
        choice = rand() % 2 + 1;
        waitTime = rand() % 3 - 1;
        
        switch(choice)
        {
        case 1:
            printf("trying to lock testMutex in thread2 with waitTime %d\n", waitTime);
            if(mutexObjectLock(&testMutex, waitTime))
            {
                printf("testMutex got locked in thread2 with waitTime %d\n", waitTime);
            }
            else
            {
                printf("testMutex did not get locked in thread2 with waitTime %d\n", waitTime);
            }
            break;
            
        case 2:
            printf("trying to release testMutex in thread2\n");
            mutexObjectRelease(&testMutex);
            printf("testMutex got released in thread2\n");
            break;
        }
    }
}
                
                                
void function3(void)
{
    while(1)
    {
        printf("trying to release testMutex in thread3\n");
        mutexObjectRelease(&testMutex);
        printf("testMutex got released in thread3\n");
    }
}



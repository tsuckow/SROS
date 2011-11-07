#ifndef __rtos__
#define __rtos__

#include "typeDef.h"

#ifdef __cplusplus
extern "C"
{
#endif

#define     INITIAL_CPSR_ARM_FUNCTION   0x0000005F
#define     INITIAL_CPSR_THUMB_FUNCTION 0x0000007F
#define     INITIAL_CPSR_ARM_DISABLED_INTERRUPTS_FUNCTION 0x000000DF
#define     INITIAL_CPSR_THUMB_DISABLED_INTERRUPTS_FUNCTION 0x000000FF

extern volatile int64 srostime;  //This gloable variable is incremented after every timer tick. At the starting of the system this variable is initialized to 0.

//Work around to make sure that threadObject_t have *listObject_t inside it, 
//and listObject_t has *threadObject_t inside it.
struct _threadObject_;
struct _listObject_;

typedef struct _listObject_
{
    struct _threadObject_ *element;

    int32 auxInfo;

    struct _listObject_ *nextListNode;

}listNode_t;

typedef listNode_t listObject_t;

typedef struct _threadObject_
{
    int32 R[16];
    uint32 cpsr;

    uint32 priority;

    struct _listObject_ *waitListResource;

    struct _listObject_ *waitListTimer;

    char   *threadObjectName;

    uint32 timeQuantum;

    uint32 innatePriority;

    struct _threadObject_ * promotee;

    listObject_t promoterList;
	
	uint8 libspace[96];
}threadObject_t;


typedef struct
{
    int32 mutex;

    listObject_t waitList;

    threadObject_t * owner;

    uint32 mode;

}mutexObject_t;

typedef struct
{
    uint32 count;

    listObject_t waitList;

}semaphoreObject_t;

typedef struct
{
    int8 *mailboxBuffer;
    int32 readIndex;
    int32 writeIndex;
    int32 mailboxBufferSize;
    int32 emptyBufferSize;
    int32 messageSize;

    listObject_t waitList;

}mailboxObject_t;


listNode_t *listNodeAlloc(void);

void listNodeFree(listNode_t *listNodePtr);

void listObjectModuleInit(void);

void listObjectInit(listObject_t *listObjectPtr);

void listObjectInsert(listObject_t *listNodePtr, threadObject_t *newThreadObject);

void waitlistObjectInsert(listObject_t *listNodePtr, threadObject_t *newThreadObject);

threadObject_t *listObjectPeek(listObject_t *listObjectPtr);
threadObject_t *listObjectPeekWaitlist(listObject_t *listObjectPtr, listObject_t *waitlist );

threadObject_t *waitlistObjectDelete(listObject_t *listObjectPtr);

void listObjectDeleteMiddle(listObject_t *waitList, threadObject_t *threadObjectToBeDeleted);
void waitlistObjectDeleteMiddle(listObject_t *waitList, threadObject_t *threadObjectToBeDeleted);

int32 listObjectCount(listObject_t *listObjectPtr);

void threadObjectCreate(threadObject_t *threadObjectPtr, 
                        void *functionPtr, 
                        int32 arg1, 
                        int32 arg2, 
                        int32 arg3, 
                        int32 arg4, 
                        int32* stackPointer, 
                        uint32 priority, 
                        uint32 cpsr,
                        char   *threadObjectName);
                        
void threadObjectDestroy(threadObject_t *threadObjectPtr);

void mutexObjectInit(mutexObject_t *mutexObjectPtr, int32 initialFlag);

void mutexObjectInitEx(mutexObject_t *mutexObjectPtr, int32 initialFlag, int32 mode);

int32 mutexObjectLock(mutexObject_t *mutexObjectPtr, int32 waitFlag);

void mutexObjectRelease(mutexObject_t *mutexObjectPtr);

void semaphoreObjectInit(semaphoreObject_t *semaphoreObjectPtr, uint32 initialCount);

int32 semaphoreObjectPend(semaphoreObject_t *semaphoreObjectPtr, int32 waitFlag);

void semaphoreObjectPost(semaphoreObject_t *semaphoreObjectPtr);


void mailboxObjectInit(mailboxObject_t *mailboxObjectPtr, 
                       int8 *mailboxBuffer, 
                       int32 mailboxBufferSize, 
                       int32 messageSize);

int32 mailboxObjectPend(mailboxObject_t *mailboxObjectPtr,
                  int32 waitFlag,
                  void *message);

int32 mailboxObjectPost(mailboxObject_t *mailboxObjectPtr,
                  int32 waitFlag,
                  void *message);

void scheduler(void);       //This function never returns.
void rtosInit(void);
void block(void);
void timerTick(void);
void sleep(int32 noOfTicks);
void timerTick(void);
void yield(void);
void irq_interrupt_handler(void);

int isSROSRunning(void);


#ifdef __cplusplus
}
#endif

#endif

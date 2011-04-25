#include "rtos.h"
#include "assert.h"

#define MAX_THREADS_IN_THE_SYSTEM   100
#define MAX_LIST_NODES              2*MAX_THREADS_IN_THE_SYSTEM
listNode_t listNodes[MAX_LIST_NODES];
uint32     listNodesAvailableCount;
listNode_t *listNodesAvailable[MAX_LIST_NODES];

listObject_t readyList;
listObject_t timerList;
int64        time;
threadObject_t *runningThreadObjectPtr;
threadObject_t idleThread;
int32          idleStack[5];

extern void rtosInitAsm(void);
extern void interrupt_disable(void);
extern void interrupt_restore(void);

/*
Description:
This function 
initializes the pool unallocated listNodes in the 
"listNodesAvailable" global array. 
initializes the "listNodesAvailableCount" which count the number of
listNodes in the pool.
*/
void listObjectModuleInit(void)
{
    int32 i;

    assert(MAX_LIST_NODES > 0);

    listNodesAvailableCount = MAX_LIST_NODES;

    for(i=0; i<MAX_LIST_NODES; i++)
    {
        listNodesAvailable[i] = &listNodes[i];
    }
}

/*
Description:
This function just return the last available listNode from the 
pool (i.e."listNodesAvailable" array) and decrement the counter 
(i.e."listNodesAvailableCount")that count the number of listNodes in the pool.
*/
listNode_t *listNodeAlloc()
{
    assert(listNodesAvailableCount > 0);

    return listNodesAvailable[--listNodesAvailableCount];
}

/*
Description:
This function just add the freed listNode to the pool of available
listNodes and increment the counter(i.e."listNodesAvailableCount") that
count the number of listNodes in the pool.
*/
void listNodeFree(listNode_t *listNodePtr)
{
    listNodesAvailable[listNodesAvailableCount++] = listNodePtr;

    assert(listNodesAvailableCount <= MAX_LIST_NODES);
}

/*
Description:
This function initilizes the listObject. ListObject is the dummy listNode
in the beginning of list in the linked list data structure. The dummy node 
contain number of list nodes in the "auxInfo" field. This function initializes the
listObject. (i.e. initializes the dummy first node in the linked list).
*/
void listObjectInit(listObject_t *listObjectPtr)
{
    //The list object is the dummy head at the beginning of the linked list. 
    //It is an invalid node. 
    //It holds the number of list nodes in auxInfo field.
    assert(listObjectPtr != 0);
    listObjectPtr->element = 0;
    listObjectPtr->auxInfo = 0;
    listObjectPtr->nextListNode = 0;
}

/*
Description:
This function insert a new listNode into the linked list. The linked
list hold the threadObjects as it's elements. It take "newThreadObject"
and insert it at appropriate place in the list according to the priority.
All the threadObjects in the list are stored in the descending order of
priority. (Note lower the priority number, higher the priority).
In each list node, the "priority" field of threadObject is noted into
the auxInfo field of the listNode.
*/
void listObjectInsert(listObject_t *listNodePtr, 
                    threadObject_t *newThreadObject)
{
    listNode_t *newListNodePtr;
    uint32 newThreadObjectPriority;
    
    assert(newThreadObject != 0);
    assert(newThreadObject->waitListResource == 0);
    assert(listNodePtr != 0);
    
    //note the list pointer into the threadObject.
    newThreadObject->waitListResource = listNodePtr;
    
    newThreadObjectPriority = newThreadObject->priority;
    //listObject first element is dummy head. Its auxInfo hold 
    //the number of list nodes available in the list.
    //So the count is increased when inserting an element.
    listNodePtr->auxInfo++;

    //parse the list till we reach the correct place for the newThreadObject.
    while(listNodePtr->nextListNode != 0 && 
        listNodePtr->nextListNode->auxInfo <= newThreadObjectPriority)
    {
        listNodePtr = listNodePtr->nextListNode;
    }

    //allocate and initialize the new node.
    newListNodePtr = listNodeAlloc();
    newListNodePtr->element = newThreadObject;
    newListNodePtr->auxInfo = newThreadObjectPriority;

    //insert into the list.
    newListNodePtr->nextListNode = listNodePtr->nextListNode;
    listNodePtr->nextListNode = newListNodePtr;
}

/*
Description:
This function delete the first listNode from the linked list
and return the threadObject (i.e. "element") in the listNode.
*/
threadObject_t *listObjectDelete(listObject_t *listObjectPtr)
{
    threadObject_t *element;
    
    listNode_t *freedListNodePtr;

    assert(listObjectPtr != 0);
    assert(listObjectPtr->nextListNode != 0);
    assert(listObjectPtr->auxInfo > 0);

    //decrement the number of listNodes counter.
    listObjectPtr->auxInfo--;

    //Note the element to be freed.
    freedListNodePtr = listObjectPtr->nextListNode;
    element = freedListNodePtr->element;

    //adjust the link from dummy head to the second listNode 
    //in the list (as first one is removed).
    listObjectPtr->nextListNode = freedListNodePtr->nextListNode;

    //free the removed listNode.
    listNodeFree(freedListNodePtr);
    
    assert(element->waitListResource == listObjectPtr);
    
    //make the waitListResource pointer in the thread object equal to null.
    element->waitListResource = 0;

    //return the threadObject (i.e. element) available
    //in the first listNode (which is deleted).

    return element;
}

/*
Description:
This function delete the node that is holding the threadObject given as input.
The node that is holding the threadObject can be anywhere in the listObject.
*/
void listObjectDeleteMiddle(listObject_t *waitList, 
                            threadObject_t *threadObjectToBeDeleted)
{
    listObject_t *listNodePtr, *freedListNodePtr;
    int i;
    
    assert(threadObjectToBeDeleted != 0);
    assert(threadObjectToBeDeleted->waitListResource == waitList);
    assert(waitList->auxInfo > 0);
    
    listNodePtr = waitList;
    for(i=0; i<waitList->auxInfo; i++)
    {
        if(listNodePtr->nextListNode->element == threadObjectToBeDeleted)
        {
            freedListNodePtr = listNodePtr->nextListNode;
            
            listNodePtr->nextListNode = freedListNodePtr->nextListNode;
            
            listNodeFree(freedListNodePtr);
            
            waitList->auxInfo--;
            
            //make the waitListResource pointer in the thread object equal
            //to null.
            threadObjectToBeDeleted->waitListResource = 0;

            break;
        }
        else
        {
            listNodePtr = listNodePtr->nextListNode;
        }
    }
    
    
    return;
}

/*
Description:
This function just return the number of listNodes available in the linked list.
The number of listNodes in the list are maintained in the dummy header "auxInfo"
field. So this function just return the value in the "auxInfo" field of 
the dummy head.
*/
int32 listObjectCount(listObject_t *listObjectPtr)
{
    return listObjectPtr->auxInfo;
}

/*
Description:
This function implement the idle loop to execute in the idle thread.
*/
void idleFunction(void)
{
    while(1)
    {
        ;
    }
}

/*
Description:
This function initializes the SROS.
It initializes the list module to create unallocated pool of listNodes.
Initalizes the "readyList" which hold the threadObjects waiting 
for the CPU time.
Initializes the "timerList" that hold the threadObjects waiting for
timeout.
Intialize the system time to 0.
Initializes the "runningThreadObjectPtr" (which always hold the 
running threadObject address) to NULL.
Create the Idle thread in the sytem.
*/
void rtosInit(void)
{
    listObjectModuleInit();
    
    listObjectInit(&readyList);
    
    listObjectInit(&timerList);
    
    time = 0;
    
    runningThreadObjectPtr = 0;
    
    rtosInitAsm();
    
    threadObjectCreate(&idleThread,
                        (void *)idleFunction,
                        0,
                        0,
                        0,
                        0,
                        &idleStack[5],
                        127,
                        INITIAL_CPSR_ARM_FUNCTION,
                        "idleThread"
                        );
                        
    return;
}
            
/*
Description:
This function check weather a context switch is needed.
This function return 1 (denoting context switch is needed) when 
the currently running thread in the system has lower priority than 
highest priority thread available in the readyList. Otherwise this function 
return 0. Note that lower the priority number higher the thread priority.
*/
int is_thread_switch_needed(void)
{
    //check if the runningThreadObject has less priority than 
    //highest priority thread in the ready list. If so return 1
    //else return 0.
    
    int returnValue = 0;
    
    if(readyList.auxInfo > 0)   //if the number of threads in the ready list > 0
    {
        if((readyList.nextListNode)->auxInfo < runningThreadObjectPtr->priority)
        {
            returnValue = 1;
        }
    }
    
    return returnValue;
}

/*
Description:
This function inserts the given threadObject into new node of the timerList.
The threadObject should hold the timeout value in R1 register. The
threadObject is inserted at an appropriate place depending on the timeout
value. (all the threadObjects with lower than the new threadObject timeout 
are preceding it in the timerList).
*/
void insertIntoTimerList(threadObject_t *newThreadObject, 
                         listObject_t *waitList)
{
    int32 waitTime;
    listNode_t *listNodePtr, *newListNodePtr;
    
    assert(newThreadObject != 0);
    assert(newThreadObject->waitListTimer == 0);
    
    //always the waitTime is in R1 register.
    waitTime = newThreadObject->R[1];
    
    assert(waitTime > 0);
    
    listNodePtr = &timerList;
    
    //note the timer list pointer into the threadObject.
    newThreadObject->waitListTimer = listNodePtr;
    
    //parse the list past the low waiting time nodes.
    while(listNodePtr->nextListNode != 0 && \
            listNodePtr->nextListNode->element->R[1] < waitTime)
    {
        waitTime = waitTime - listNodePtr->nextListNode->element->R[1];
        listNodePtr = listNodePtr->nextListNode;
    }
    
    //allocate and initialize the new node.
    newListNodePtr = listNodeAlloc();
    newThreadObject->R[1] = waitTime;
    newListNodePtr->element = newThreadObject;
    newListNodePtr->auxInfo = (int32)(waitList);    
    //In the timer list each node auxInfo field hold the waitList of 
    //mutexObject or semaphoreObject or mailboxObject.

    //insert into list
    newListNodePtr->nextListNode = listNodePtr->nextListNode;
    listNodePtr->nextListNode = newListNodePtr;
    
    //subtract the waiting time for the following list nodes after 
    //newListNodePtr
    if(newListNodePtr->nextListNode != 0)
    {
        newListNodePtr->nextListNode->element->R[1] -= \
                                    newListNodePtr->element->R[1];
    }
    
    //listObject first element is dummy node. It's auxInfo field holds 
    //the number of nodes in the list.
    timerList.auxInfo++;
}

/*
Description:
This function delete the node that is holding the given threadObject from the
timerList.
*/
void deleteFromTimerList(threadObject_t *threadObjectToBeDeleted)
{
    listObject_t *listNodePtr, *freedListNodePtr;
    int i;
    
    assert(threadObjectToBeDeleted != 0);
    assert(threadObjectToBeDeleted->waitListTimer == &timerList);

    listNodePtr = &timerList;
    for(i=0; i<timerList.auxInfo; i++)
    {
        if(listNodePtr->nextListNode->element == threadObjectToBeDeleted)
        {
            freedListNodePtr = listNodePtr->nextListNode;
            
            listNodePtr->nextListNode = freedListNodePtr->nextListNode;
            
            //add wait time for the next thread object.
            if(listNodePtr->nextListNode != 0)
            {
                listNodePtr->nextListNode->element->R[1] += \
                                        freedListNodePtr->element->R[1];
            }
            
            listNodeFree(freedListNodePtr);
            
            timerList.auxInfo--;            
            //decrease the count by 1.(auxInfo field hold the number of 
            //elements in the list).
            
            //make the timerList pointer in the thread object equal to null.
            threadObjectToBeDeleted->waitListTimer = 0;

            break;
        }
        else
        {
            listNodePtr = listNodePtr->nextListNode;
        }
    }
    
    return;
}

/*
Description:
This function is the timer interrupt service routine. This function should be
called for every timer interrupt. (i.e. timer tick). This function updates
the timeouts of threads which are waiting for timeout at each timer tick.
When ever the number of ticks for timeout for a threadObject is finished,
then that threadObject will be moved to readyList (and the threadObject is 
removed from any waitList if it is in).
*/
void timerTick(void)
{
    listObject_t *freedListNodePtr;
    
    time++;
    //decrease the waiting time by 1.
    if(timerList.auxInfo > 0)
    {
        timerList.nextListNode->element->R[1]--;
        while(timerList.auxInfo > 0)
        {
            if(timerList.nextListNode->element->R[1] <= 0)  //is waitTime == 0
            {
                //delete the threadObject from the list.
                freedListNodePtr = timerList.nextListNode;
                
                timerList.nextListNode = freedListNodePtr->nextListNode;
                
                //delete the threadObject from the waitList of resource 
                //(mutex/semaphore/mailBox).
                if(freedListNodePtr->auxInfo != 0)
                {
                    listObjectDeleteMiddle((listObject_t *)(freedListNodePtr->auxInfo),
                                            freedListNodePtr->element);
                }
                
                assert(freedListNodePtr->element->waitListTimer == &timerList);
                
                //make the timerList pointer in the thread object equal to null.
                freedListNodePtr->element->waitListTimer = 0;
                
                //insert the threadObject into readyList.
                listObjectInsert(&readyList, freedListNodePtr->element);
                
                //free the listNode.
                listNodeFree(freedListNodePtr);
                
                timerList.auxInfo--;
            }
            else
            {
                break;
            }
        }   
    }
    
    return;
}       

/*
Description:
This function remove the threadObject from the system.
This function remove the threadObject from the any waitList or readyList if 
it is waiting for a resource. This function remove the threadObject from 
timerList if it is waiting for timeout.
*/
void threadObjectDestroy(threadObject_t *threadObjectPtr)
{
    interrupt_disable();
    
    assert((threadObjectPtr->waitListResource != 0) || \
                        (threadObjectPtr->waitListTimer != 0));
    
    if(threadObjectPtr->waitListResource != 0)
    {
        assert(threadObjectPtr->waitListResource->auxInfo > 0);
        
        listObjectDeleteMiddle(threadObjectPtr->waitListResource, \
                                threadObjectPtr);
    }
    
    if(threadObjectPtr->waitListTimer != 0)
    {
        assert(timerList.auxInfo > 0);
        
        deleteFromTimerList(threadObjectPtr);
    }
    
    interrupt_restore();
}

/*
Description:
This function initializes the mailboxObject.
"mailboxBuffer" is the memory space where messages are stored.
"mailboxBufferSize" is the size of the "mailboxBuffer"
"messageSize" is the size of each message.
*/
void mailboxObjectInit(mailboxObject_t *mailboxObjectPtr, 
                       int8 *mailboxBuffer, 
                       int32 mailboxBufferSize, 
                       int32 messageSize)
{
    mailboxObjectPtr->mailboxBuffer = mailboxBuffer;
    mailboxObjectPtr->readIndex = 0;
    mailboxObjectPtr->writeIndex = 0;
    mailboxObjectPtr->mailboxBufferSize = mailboxBufferSize;
    mailboxObjectPtr->emptyBufferSize = mailboxBufferSize;
    mailboxObjectPtr->messageSize = messageSize;

    listObjectInit(&mailboxObjectPtr->waitList);

    assert(mailboxObjectPtr->mailboxBufferSize % messageSize == 0);
}

/*
Description:
This function initializes the mutexObject. The initial status of mutex
is initialized with the "initialFlag" which can be either 0 or 1.
*/
void mutexObjectInit(mutexObject_t *mutexObjectPtr, int32 initialFlag)
{
    assert(initialFlag == 0 || initialFlag == 1);

    mutexObjectPtr->mutex = initialFlag;

    listObjectInit(&mutexObjectPtr->waitList);
}

/*
This funciton initializes the semaphoreObject. The initial count of the
semaphore is initialized with the "initialCount" passed to this function.
*/
void semaphoreObjectInit(semaphoreObject_t *semaphoreObjectPtr, 
                        uint32 initialCount)
{
    semaphoreObjectPtr->count = initialCount;

    listObjectInit(&(semaphoreObjectPtr->waitList));
}

void internal_yield(threadObject_t * runningThread)
{
   listObjectInsert(&readyList, runningThread)
}

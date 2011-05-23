#ifndef __rtosimpl__
#define __rtosimpl__

#include "rtos.h"

extern threadObject_t *runningThreadObjectPtr;

void insertIntoTimerList(threadObject_t *newThreadObject, listObject_t *waitList);

#endif


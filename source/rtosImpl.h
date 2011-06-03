#ifndef __rtosimpl__
#define __rtosimpl__

#include "rtos.h"

extern threadObject_t *runningThreadObjectPtr;
extern listObject_t readyList;

void insertIntoTimerList(threadObject_t *newThreadObject, listObject_t *waitList);
void deleteFromTimerList(threadObject_t *threadObjectToBeDeleted);

#endif


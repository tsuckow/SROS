#include <stdio.h>
#include <stdlib.h>
#include "listObject.h"
#include "fw_type_def.h"


#define MAX_LIST_NODES 100
extern listObject_t *listNodesAvailable[MAX_LIST_NODES];

int main(void)
{
	listObject_t listObject;

	int x[MAX_LIST_NODES];	
	int pointersSum, sum, i;
	
	int a=1, b=2, c=3, d=4, e=5, f=6, g=7, h=8;
	


	listObjectModuleInit();

	listObjectInit(&listObject);

	listObjectInsert(&listObject, &a, 1);

	listObjectInsert(&listObject, &b, 2);

	listObjectInsert(&listObject, &c, 3);

	listObjectInsert(&listObject, &d, 3);

	listObjectInsert(&listObject, &e, 2);

	listObjectInsert(&listObject, &f, 1);
	
	listObjectInsert(&listObject, &g, 0);

	listObjectInsert(&listObject, &h, 8);

	printf("%d ", *(int *)listObjectDelete(&listObject));

	printf("%d ", *(int *)listObjectDelete(&listObject));

	printf("%d ", *(int *)listObjectDelete(&listObject));

	printf("%d ", *(int *)listObjectDelete(&listObject));

	printf("%d ", *(int *)listObjectDelete(&listObject));

	printf("%d ", *(int *)listObjectDelete(&listObject));

	printf("%d ", *(int *)listObjectDelete(&listObject));

	printf("%d ", *(int *)listObjectDelete(&listObject));
	
	printf("\n");
	
	pointersSum = 0;
	sum = 0;
	for(i=0; i<MAX_LIST_NODES; i++)
	{
		pointersSum += (int32)listNodesAvailable[i];
	}
	
	for(i=0; i<MAX_LIST_NODES; i++)
	{
		x[i] = i;
		listObjectInsert(&listObject, &x[i], MAX_LIST_NODES-i);
		sum += x[i];
	}
	
	for(i=0; i<MAX_LIST_NODES; i++)
	{
		sum -= *(int *)listObjectDelete(&listObject);
	}
	
	for(i=0; i<MAX_LIST_NODES; i++)
	{
		pointersSum -= (int32)listNodesAvailable[i];
	}
	
	if(sum != 0  || pointersSum != 0)
	{
		printf("error in listObject code\n");
	}
	else
	{
		printf("list object code passed the test\n");
	}
	
		


}
#include <stdio.h>
#include <camkes.h>

void post_init(void)
{
}

void irq_handle(void) 
{
    int error;


    printf("slave irq\n");
    printf("data=%s\n", (char*)reg2);

    strcpy((char*)reg2, "Hello Linux!");
    *((char*)reg1) = 1;

    // clear irq flag
    *((char*)reg0) = 0;
    // acknowledge irq
    error = irq_acknowledge();
}


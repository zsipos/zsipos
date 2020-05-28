#include <stdio.h>
#include <camkes.h>

void irq_handle(void) {
    int error;

    // clear irq flag
    *((char*)reg0) = 0;

    printf("slave irq\n");
    printf("data=%s\n", (char*)reg2);

    strcpy((char*)reg2, "Hello Linux!");
    *((char*)reg1) = 1;

    // acknowledge irq
    error = irq_acknowledge();
}


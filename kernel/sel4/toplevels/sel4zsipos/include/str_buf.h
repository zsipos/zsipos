/* @TAG(DATA61_BSD) */

/*
 * CAmkES tutorial part 2: events and dataports
 */

#ifndef __STR_BUF_H__
#define __STR_BUF_H__

#include <camkes/dataport.h>

#define NUM_STRINGS 5
#define STR_LEN 256

/* for a typed dataport containing strings */
typedef struct {
    int n;
    char str[NUM_STRINGS][STR_LEN];
} str_buf_t;

#define MAX_PTRS 20

/* for a typed dataport containing dataport pointers */
typedef struct {
    int n;
    dataport_ptr_t ptr[MAX_PTRS];
} ptr_buf_t;

#endif
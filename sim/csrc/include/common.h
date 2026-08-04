#ifndef __COMMON_H__
#define __COMMON_H__

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>

#include <assert.h>
#include <stdlib.h>

#include "utils.h"
#include "macro.h"
#include "config.h"

typedef uint64_t word_t;
typedef word_t vaddr_t;
typedef word_t paddr_t;
typedef uint16_t ioaddr_t;

#define NPC_RUNNING  0
#define NPC_END      1
#define NPC_QUIT     2
#define NPC_ABORT    3

#endif

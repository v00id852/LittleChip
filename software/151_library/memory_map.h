#include "types.h"

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))

#define GPIO_FIFO_EMPTY (*((volatile uint32_t*)0x80000020) & 0x01)
#define GPIO_FIFO_DATA (*((volatile uint32_t*)0x80000024))
#define SWITCHES (*((volatile uint32_t*)0x80000028) & 0x03)
#define LED_CONTROL (*((volatile uint32_t*)0x80000030))

#define CONV2D_START      (*((volatile uint32_t*) 0x80000040))
#define CONV2D_IDLE       (*((volatile uint32_t*) 0x80000044) & 0x02)
#define CONV2D_DONE       (*((volatile uint32_t*) 0x80000044) & 0x01)

#define CONV2D_FM_DIM     (*((volatile uint32_t*) 0x80000048))
#define CONV2D_WT_OFFSET  (*((volatile uint32_t*) 0x8000004c))
#define CONV2D_IFM_OFFSET (*((volatile uint32_t*) 0x80000050))
#define CONV2D_OFM_OFFSET (*((volatile uint32_t*) 0x80000054))

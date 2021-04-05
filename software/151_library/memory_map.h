#include "types.h"

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))

#define GPIO_FIFO_EMPTY (*((volatile uint32_t*)0x80000020) & 0x01)
#define GPIO_FIFO_DATA (*((volatile uint32_t*)0x80000024))
#define SWITCHES (*((volatile uint32_t*)0x80000028) & 0x03)
#define LED_CONTROL (*((volatile uint32_t*)0x80000030))

#define DMA_START     (*((volatile uint32_t*) 0x80000030))
#define DMA_IDLE      (*((volatile uint32_t*) 0x80000034) & 0x02)
#define DMA_DONE      (*((volatile uint32_t*) 0x80000034) & 0x01)
#define DMA_DIR       (*((volatile uint32_t*) 0x80000038))
#define DMA_SRC_ADDR  (*((volatile uint32_t*) 0x8000003c))
#define DMA_DST_ADDR  (*((volatile uint32_t*) 0x80000040))
#define DMA_LEN       (*((volatile uint32_t*) 0x80000044))

// TODO(tan): define addresses for accelerator memory-mapped registers

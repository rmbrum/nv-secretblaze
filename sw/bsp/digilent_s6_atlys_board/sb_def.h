/*
 *
 *    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
 *    contact: adac@lirmm.fr
 *
 *    This file is part of SecretBlaze.
 *
 *    SecretBlaze is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    SecretBlaze is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _SB_DEF_H
#define _SB_DEF_H

/**
 * \file sb_def.h
 * \brief SecretBlaze defines for Spartan-6 ATLYS Board
 * \author Lyonel Barthe
 * \version 1.0
 * \date 08/2012 
 */

/* GENERAL */
static const char CPU_VER[]            = "SecretBlaze v1.7";
static const char CPU_CHIP[]           = "FPGA-SPARTAN6";

/* CLOCK SETTINGS */
#define FREQ_CORE_HZ                   100000000  /* cclk - default is 100 MHz */
#define C_S_CLK_DIV                    2          /* sclk - default is 50 MHz */
#define M_C_CLK_DIV                    4          /* mclk - default is 400 MHz */

/* CACHE SETTINGS */
#define SB_ICACHE_BYTE_SIZE            0x00004000 /* default is 16 KB */
#define SB_DCACHE_BYTE_SIZE            0x00004000 /* default is 16 KB */
#define SB_ICACHE_LINE_WORD_SIZE       8
#define SB_DCACHE_LINE_WORD_SIZE       8
#define SB_ICACHE_LINE_BYTE_SIZE       SB_ICACHE_LINE_WORD_SIZE*4 
#define SB_DCACHE_LINE_BYTE_SIZE       SB_DCACHE_LINE_WORD_SIZE*4

#define SB_IC_BASE_ADDRESS             0x10000000
#define SB_IC_HIGH_ADDRESS             (SB_IC_BASE_ADDRESS+SB_ICACHE_BYTE_SIZE-1)
#define SB_DC_BASE_ADDRESS             0x10004000
#define SB_DC_HIGH_ADDRESS             (SB_DC_BASE_ADDRESS+SB_DCACHE_BYTE_SIZE-1)

/**
 * \def SB_DCACHE_USE_WRITEBACK
 * If defined, the data cache uses a write-back policy.
 */
#define SB_DCACHE_USE_WRITEBACK  

/**
 * \def SB_CACHE_OPT_MACRO
 * If defined, use optimized macro for the write-back cache.
 */ 
/* #define SB_CACHE_OPT_MACRO */    

/* MEMORY MAP */
#define CACHEABLE_MEMORY_BYTE_SIZE     (0x08000000) /* default is 128 MB */
#define CACHEABLE_MEMORY_BASE_ADDRESS  (0x10000000)
#define CACHEABLE_MEMORY_HIGH_ADDRESS  (0x1FFFFFFF) /* unconstrained */

#define UART_IP_BASE_ADDRESS           (0x20000000)
#define UART_IP_HIGH_ADDRESS           (0x2FFFFFFF) /* unconstrained */
#define GPIO_IP_BASE_ADDRESS           (0x30000000)
#define GPIO_IP_HIGH_ADDRESS           (0x3FFFFFFF) /* unconstrained */
#define INTC_IP_BASE_ADDRESS           (0x40000000)
#define INTC_IP_HIGH_ADDRESS           (0x4FFFFFFF) /* unconstrained */
#define TIMER_IP_BASE_ADDRESS          (0x50000000)
#define TIMER_IP_HIGH_ADDRESS          (0x5FFFFFFF) /* unconstrained */

/* INTC */
#define INTC_STATUS_REG          (INTC_IP_BASE_ADDRESS + 0x0)
#define INTC_ACK_REG             (INTC_IP_BASE_ADDRESS + 0x4)
#define INTC_MASK_REG            (INTC_IP_BASE_ADDRESS + 0x8)
#define INTC_ARM_REG             (INTC_IP_BASE_ADDRESS + 0xc)
#define INTC_POL_REG             (INTC_IP_BASE_ADDRESS + 0x10)

#define INTC_ID_0                0   /* uart rx id */
#define INTC_ID_1                1   /* uart tx id */
#define INTC_ID_2                2   /* timer 1 id */
#define INTC_ID_3                3   /* timer 2 id */
#define INTC_ID_4                4
#define INTC_ID_5                5
#define INTC_ID_6                6
#define INTC_ID_7                7

#define INTC_ID_0_BIT            (1<<0)	
#define INTC_ID_1_BIT            (1<<1)
#define INTC_ID_2_BIT            (1<<2)
#define INTC_ID_3_BIT            (1<<3)
#define INTC_ID_4_BIT            (1<<4)
#define INTC_ID_5_BIT            (1<<5)
#define INTC_ID_6_BIT            (1<<6)
#define INTC_ID_7_BIT            (1<<7)
#define INTC_ID_BANK             (INTC_ID_0_BIT|INTC_ID_1_BIT|INTC_ID_2_BIT|INTC_ID_3_BIT \
                                 |INTC_ID_4_BIT|INTC_ID_5_BIT|INTC_ID_6_BIT|INTC_ID_7_BIT)

/**
 * \def MAX_ISR
 * Nb of interrupt sources  
 */ 
#define MAX_ISR 8

/**
 * \def DONT_USE_GCC_INTERRUPT_ATTRIBUTE
 * If defined, don't generate default function entry and exit sequences for the interrupt handler.
 */ 
/* #define DONT_USE_GCC_INTERRUPT_ATTRIBUTE */

/**
 * \def INTC_FORCE_ONLY_HIGHEST_PRIORITY
 * If defined, execute only the highest priority handler before leaving the interrupt.
 */ 
/* #define INTC_FORCE_ONLY_HIGHEST_PRIORITY */

/**
 * \def INTC_FORCE_ACK_FIRST
 * If defined, clear the interrupt ack register before entering the interrupt handler.
 */ 
/* #define INTC_FORCE_ACK_FIRST */
								  
/* UART */
#define UART_STATUS_REG          (UART_IP_BASE_ADDRESS + 0x0)
#define UART_DATA_RX_REG         (UART_IP_BASE_ADDRESS + 0x4)
#define UART_CONTROL_REG         (UART_IP_BASE_ADDRESS + 0x8)
#define UART_DATA_TX_REG         (UART_IP_BASE_ADDRESS + 0xc)

#define RX_READY_FLAG_BIT        (1<<0)
#define TX_BUSY_FLAG_BIT         (1<<1)
#define SEND_TX_BIT              (1<<0)
#define UART_DATA_MASK           (0xFF)

/* GPIO */
#define GPIO_LED_REG             (GPIO_IP_BASE_ADDRESS + 0x0)
#define GPIO_BUT_REG             (GPIO_IP_BASE_ADDRESS + 0x4)

#define GPIO_LED0_BIT            (1<<0)
#define GPIO_LED1_BIT            (1<<1)
#define GPIO_LED2_BIT            (1<<2)
#define GPIO_LED3_BIT            (1<<3)
#define GPIO_LED4_BIT            (1<<4)
#define GPIO_LED5_BIT            (1<<5)
#define GPIO_LED6_BIT            (1<<6)
#define GPIO_LED7_BIT            (1<<7)
#define GPIO_LED_BANK            (GPIO_LED0_BIT|GPIO_LED1_BIT|GPIO_LED2_BIT|GPIO_LED3_BIT \
                                 |GPIO_LED4_BIT|GPIO_LED5_BIT|GPIO_LED6_BIT|GPIO_LED7_BIT)
                                 
#define GPIO_BUT0_BIT            (1<<0)
#define GPIO_BUT1_BIT            (1<<1)
#define GPIO_BUT2_BIT            (1<<2)
#define GPIO_BUT3_BIT            (1<<3)
#define GPIO_BUT4_BIT            (1<<4)
#define GPIO_BUT5_BIT            (1<<5)
#define GPIO_BUT6_BIT            (1<<6)
#define GPIO_BUT7_BIT            (1<<7)
#define GPIO_BUT_BANK            (GPIO_BUT0_BIT|GPIO_BUT1_BIT|GPIO_BUT2_BIT|GPIO_BUT3_BIT \
                                 |GPIO_BUT4_BIT|GPIO_BUT5_BIT|GPIO_BUT6_BIT|GPIO_BUT7_BIT)

/* TIMER */
#define TIMER_1_CONTROL_REG      (TIMER_IP_BASE_ADDRESS + 0x0)
#define TIMER_1_THRESHOLD_REG    (TIMER_IP_BASE_ADDRESS + 0x4)
#define TIMER_1_COUNTER_REG      (TIMER_IP_BASE_ADDRESS + 0x8)
#define TIMER_2_CONTROL_REG      (TIMER_IP_BASE_ADDRESS + 0xc)
#define TIMER_2_THRESHOLD_REG    (TIMER_IP_BASE_ADDRESS + 0x10)
#define TIMER_2_COUNTER_REG      (TIMER_IP_BASE_ADDRESS + 0x14)

#define TIMER_ENABLE_BIT         (1<<0)
#define TIMER_RESET_BIT          (1<<1)

#endif /* _SB_DEF_H */


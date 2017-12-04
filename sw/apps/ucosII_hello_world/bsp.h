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
 
/**
 * \file bsp.h
 * \brief Board Support Package 
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 22/07/2011 
 *
 */
 
#ifndef __BSP_H__
#define __BSP_H__

#include "sb_def.h"
#include "sb_intc.h"
#include "sb_timer.h"
#include "ucos_ii.h"

/* PARAMETER */

#define BSP_TMR_VAL               FREQ_CORE_HZ/(C_S_CLK_DIV*OS_TICKS_PER_SEC)

/* PROTOTYPES */

/**
 * \fn void BSP_InitIntCtrl
 * \brief Interrupt controller initialization for uCOSII operating system
 */
extern void BSP_InitIntCtrl(void);

/**
 * \fn void BSP_InitIO
 * \brief IO initialization for uCOSII operating system
 */
extern void BSP_InitIO(void);

/**
 * \fn void BSP_TmrInit
 * \brief Timer initialization for uCOSII operating system
 */
extern void BSP_TmrInit(void);

/**
 * \fn void BSP_IntDisAll
 * \brief Disable all interrupts from the interrupt controller
 */
static __inline__ void BSP_IntDisAll(void)
{
  /* clear arm register */
  intc_set_arm(0x0);
}

/**
 * \fn void BSP_IntHandler
 * \brief This function is called by OS_CPU_ISR() in os_cpu_a.s to service all active 
 *        interrupts from the interrupt controller. It is defined in sb_intc.c as an 
 *        alias of the main interrupt handler in order to preserve the original code.
 *        Note also that the DONT_USE_GCC_INTERRUPT_ATTRIBUTE variable should be defined 
 *        during the compilation.       
 */
extern void BSP_IntHandler(void);

    

#endif /* __BSP_H__ */



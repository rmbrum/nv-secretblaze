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

#include "bsp.h"

/**
 * \fn void BSP_TmrInit
 * \brief Timer initialization for uCOSII operating system
 */
void BSP_TmrInit(void)
{

  /* set the timer's period */
  timer_1_init(BSP_TMR_VAL);
  
  /* reset the timer */
  timer_1_reset();
  
  /* start the timer */
  timer_1_enable();
}

/**
 * \fn void BSP_InitIntCtrl
 * \brief Interrupt controller initialization for uCOSII operating system
 */
void BSP_InitIntCtrl(void)
{

  /* init interrupt controller */
  intc_init();

  /* attack timer handler */
  intc_attach_handler(INTC_ID_2,(sb_interrupt_handler)(&OSTimeTick),(void *)0);     
  
  /* enable interrupts from the first timer */
  intc_set_mask(0xFB);
  intc_set_arm(0x4);
}

/**
 * \fn void BSP_InitIO
 * \brief IO initialization for uCOSII operating system
 */
void BSP_InitIO(void)    
{

  /* interrupt controller initialization */
  BSP_InitIntCtrl();                       
  
  /* timer initialization */     
  BSP_TmrInit();                              
}



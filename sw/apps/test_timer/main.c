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

#include "sb_types.h"
#include "sb_uart.h"
#include "sb_msr.h"
#include "sb_intc.h"
#include "sb_timer.h"

#include "e_printf.h" /* embedded printf */

/**
 * \file main.c
 * \brief Timer testbench 
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 10/01/2010
 */

#define MASK_ID32     0xF3
#define ARM_ID32     (INTC_ID_3_BIT | INTC_ID_2_BIT)

#define TIMER_1_VALUE 0x200000
#define TIMER_2_VALUE 0x600000

/* timer 1 handler */
static void timer_1_handler(void* baseadd_p)
{
  e_printf("Youhou I'm the timer 1!\n");
} 

/* timer 2 handler */
static void timer_2_handler(void* baseadd_p)
{
  e_printf("Youhou I'm the timer 2!\n");
}

int main(void )
{

  e_printf("\nThis is the timer demo!\n");

  /* set IE bit */
  __sb_enable_interrupt();

  /* init interrupt controller */
  intc_init();
	
  /* attach handler */
  intc_attach_handler(INTC_ID_2,(sb_interrupt_handler)(&timer_1_handler),(void *)0); 
  intc_attach_handler(INTC_ID_3,(sb_interrupt_handler)(&timer_2_handler),(void *)0); 
  	
  /* mask setting */
  intc_set_mask(MASK_ID32);
	
  /* arm it */
  intc_set_arm(ARM_ID32);

  /* init timer */
  timer_1_init(TIMER_1_VALUE);
  timer_1_enable();
  timer_2_init(TIMER_2_VALUE);
  timer_2_enable();
  	
  /* wait for interrupts */
  while(sb_true)
  {		

  }

  return 0;
}


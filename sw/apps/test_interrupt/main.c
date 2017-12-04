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

#include "e_printf.h" /* embedded printf */

/**
 * \file main.c
 * \brief Interrupt testbench 
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 10/01/2010
 */

#define ARM_ID0_ID1  (INTC_ID_0_BIT|INTC_ID_1_BIT)
#define MASK_ID0_ID1 0xFC

volatile sb_int32_t i = 0;

/* rx handler */
static void uart_rx_handler(void* baseadd_p)
{
  i++;
	
  /* stop it */
  if(i == 100)
  {
    intc_set_arm(0x0);
    e_printf("\n"); 
    e_printf("IT disable!");
  } 
} 

/* tx handler */
static void uart_tx_handler(void* baseadd_p)
{
  sb_int32_t j;
  for(j=0;j<0x1FFFF;j++) {}; /* this is just a demo, you should never do that */
  e_printf("\n%d",i);
}


int main(void)
{

  e_printf("Test IT\n!");

  /* set IE bit */
  __sb_enable_interrupt();

  /* init interrupt controller */
  intc_init();
	
  /* attach handlers */
  intc_attach_handler(INTC_ID_0,(sb_interrupt_handler)(&uart_rx_handler),(void *)0); 
  intc_attach_handler(INTC_ID_1,(sb_interrupt_handler)(&uart_tx_handler),(void *)0);
	
  /* mask setting */
  intc_set_mask(MASK_ID0_ID1);
	
  /* arm it */
  intc_set_arm(ARM_ID0_ID1);
	
  /* wait for interrupts */
  while(sb_true)
  {		

  }

  return 0;
}


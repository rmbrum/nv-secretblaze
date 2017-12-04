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

#include "sb_intc.h"

/**
 * \fn void intc_init(void)
 * \brief Interrupt controller initialization
 */
void intc_init(void)
{
  sb_int32_t i;
	
  /* reset hardware settings */
  WRITE_REG32(INTC_ARM_REG,0x0);           /* clear all interrupts */
  WRITE_REG32(INTC_MASK_REG,INTC_ID_BANK); /* mask all interrupts */
  WRITE_REG32(INTC_POL_REG,INTC_ID_BANK);  /* set active-high interrupts */
	
  /* reset priority table */
  for(i=0;i<MAX_ISR;i++)
  {
    /* default priority = id */
    it_priority_table[i] = i;
  }
}

/**
 * \fn void intc_attach_handler(const sb_uint32_t interrupt_id, sb_interrupt_handler handler, void *callback)
 * \brief Update the arm register
 * \param[in] interrupt_id Interrupt source ID
 * \param[in] handler Handler to attach
 * \param[in,out] callback Handler arg
 */
void intc_attach_handler(const sb_uint32_t interrupt_id, sb_interrupt_handler handler, void *callback)
{
  it_vector_table[interrupt_id].it_handler = handler;
  it_vector_table[interrupt_id].callback = callback;
}

/**
 * \fn void primary_int_handler(void) 
 * \brief Processor primary handler
 */
void primary_int_handler(void)
{
  sb_vector_table_entry *int_entry;
  sb_uint32_t i;
  sb_uint32_t int_status;
  sb_uint32_t int_mask;
  sb_uint32_t int_id;
		
  /* read status reg */
  int_status = READ_REG32(INTC_STATUS_REG);
	
  /* service all interrupts with priority */
  for(i=0;i<MAX_ISR;i++)
  {
    /* get id from priority table */
    int_id = it_priority_table[i];
    int_mask = (1<<int_id);

    /* interrupt active */
    if(int_status & int_mask)
    {

#ifdef INTC_FORCE_ACK_FIRST
      /* ack interrupt */
      WRITE_REG32(INTC_ACK_REG,(int_status & int_mask));
#endif
      /* run handler */				
      int_entry = &(it_vector_table[int_id]);          
      int_entry->it_handler(int_entry->callback); 

#ifndef INTC_FORCE_ACK_FIRST 			
      /* ack interrupt */
      WRITE_REG32(INTC_ACK_REG,(int_status & int_mask));
#endif 

#ifdef INTC_FORCE_ONLY_HIGHEST_PRIORITY
      break;
#endif
    }		
  }	
}

/* alias for the uCOSII operating system */
void BSP_IntHandler(void) __attribute__((alias("primary_int_handler"))); 


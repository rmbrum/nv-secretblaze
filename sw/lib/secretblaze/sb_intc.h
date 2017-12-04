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

#ifndef _SB_INTC_H
#define _SB_INTC_H

/**
 * \file sb_intc.h
 * \brief Interrupt Controller primitives 
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 09/05/2010 
 */
 
#include "sb_types.h"
#include "sb_io.h"
#include "sb_def.h"

/* INTERRUPT TYPE DEFINITIONS */

/**
 * \typedef void (*sb_interrupt_handler)
 * Interrupt handler definition
 */
typedef void (*sb_interrupt_handler) (void *callback); /* by def, an handler is a pointer to a function */

/**
 * \typedef sb_vector_table_entry
 * Vector table entry
 */
typedef struct  
{
  sb_interrupt_handler it_handler; /* handler */
  void *callback;                  /* handler arg */ 
} sb_vector_table_entry;

/* TABLES */

/**
 * Global interrupt vector table
 */
sb_vector_table_entry it_vector_table[MAX_ISR];  /* interrupt vector table */

/**
 * Global interrupt vector priority table
 */
sb_uint32_t it_priority_table[MAX_ISR];          /* priority table */
                                                 /* between 0 and MAX_ISR - 1 (highest to lowest) */

/* INLINE FUNCTIONS */

/**
 * \fn void intc_set_priority(const sb_uint32_t interrupt_id, const sb_uint32_t interrupt_priority)
 * \brief Update the priority table
 * \param[in] interrupt_id Interrupt source ID
 * \param[in] interrupt_priority Priority level (between 0 and MAX_ISR - 1 ; highest to lowest)
 */
static __inline__ void intc_set_priority(const sb_uint32_t interrupt_id, const sb_uint32_t interrupt_priority)
{
  it_priority_table[interrupt_priority] = interrupt_id;
}

/**
 * \fn void intc_set_mask(const sb_uint32_t mask_it)
 * \brief Update the mask register
 * \param[in] mask_it The new mask setting
 */
static __inline__ void intc_set_mask(const sb_uint32_t mask_it)
{
  WRITE_REG32(INTC_MASK_REG,mask_it);
}

/**
 * \fn void intc_set_pol(const sb_uint32_t pol_it)
 * \brief Update the polarity register
 * \param[in] pol_it The new polarity setting
 */
static __inline__ void intc_set_pol(const sb_uint32_t pol_it)
{
  WRITE_REG32(INTC_POL_REG,pol_it);
}

/**
 * \fn void intc_set_arm(const sb_uint32_t arm_it)
 * \brief Update the arm register
 * \param[in] arm_it The new arm setting
 */
static __inline__ void intc_set_arm(const sb_uint32_t arm_it)
{
  WRITE_REG32(INTC_ARM_REG,arm_it);
}

/* PROTOTYPES */

/**
 * \fn void intc_init(void)
 * \brief Interrupt controller initialization
 */
extern void intc_init(void);

/**
 * \fn void intc_attach_handler(const sb_uint32_t interrupt_id, sb_interrupt_handler handler, void *callback)
 * \brief Update the arm register
 * \param[in] interrupt_id Interrupt source ID
 * \param[in] handler Handler to attach
 * \param[in,out] callback Handler arg
 */
extern void intc_attach_handler(const sb_uint32_t interrupt_id, sb_interrupt_handler handler, void *callback); 

#ifdef DONT_USE_GCC_INTERRUPT_ATTRIBUTE

/**
 * \fn void primary_int_handler(void) 
 * \brief Processor primary handler
 */
extern void primary_int_handler(void);

#else

/**
 * \fn void primary_int_handler(void) __attribute__((interrupt_handler))
 * \brief Processor primary handler
 */
extern void primary_int_handler(void) __attribute__((interrupt_handler)); 

#endif

#endif /* _SB_INTC_H */


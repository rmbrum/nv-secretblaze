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

#ifndef _SB_MSR_H
#define _SB_MSR_H

/**
 * \file sb_msr.h
 * \brief Machine Status Register primitives
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 25/04/2010 
 */
 
#include "sb_types.h"

/* MSR MAP */

#define CC_BIT  (1<<31)
#define DCE_BIT (1<<7)
#define DZO_BIT (1<<6)
#define ICE_BIT (1<<5)
#define C_BIT   (1<<2)
#define IE_BIT  (1<<1)

/* INLINE FUNCTIONS */

/**
 * \fn sb_uint32_t __sb_read_msr(void)
 * \brief Read the MSR register
 * \return MSR value
 */
static __inline__ sb_uint32_t __sb_read_msr(void)
{
  sb_uint32_t msr;
   
  __asm__ __volatile__ ("mfs	%0, rmsr" : "=r" (msr));
  
  return msr;
}                                                

/**
 * \fn void __sb_enable_icache(void)
 * \brief Enable the instruction cache
 */
static __inline__ void __sb_enable_icache(void)
{
   __asm__ __volatile__ ("msrset r0, %0; NOP;"   \
                                 :               \
                                 : "i" (ICE_BIT) \
                                 : "memory");    \
}                                                
 
/**
 * \fn void __sb_disable_icache(void)
 * \brief Disable the instruction cache
 */
static __inline__ void __sb_disable_icache(void)
{
   __asm__ __volatile__ ("msrclr r0, %0; NOP;"   \
                                 :               \
                                 : "i" (ICE_BIT) \
                                 : "memory");    \
}                                                

/**
 * \fn void __sb_enable_dcache(void)
 * \brief Enable the data cache
 */
static __inline__ void __sb_enable_dcache(void)
{
   __asm__ __volatile__ ("msrset r0, %0; NOP;"   \
                                 :               \
                                 : "i" (DCE_BIT) \
                                 : "memory");    \
}                                                
 
/**
 * \fn void __sb_disable_dcache(void)
 * \brief Disable the data cache
 */
static __inline__ void __sb_disable_dcache(void)
{
   __asm__ __volatile__ ("msrclr r0, %0; NOP;"   \
                                 :               \
                                 : "i" (DCE_BIT) \
                                 : "memory");    \
}                                                

/**
 * \fn void __sb_enable_interrupt(void)
 * \brief Enable external interrupt
 */
static __inline__ void __sb_enable_interrupt(void)
{
   __asm__ __volatile__ ("msrset r0, %0; NOP;"  \
                                 :              \
                                 : "i" (IE_BIT) \
                                 : "memory");   \
}                                               
 
/**
 * \fn void __sb_disable_interrupt(void)
 * \brief Disable external interrupt
 */
static __inline__ void __sb_disable_interrupt(void)
{
   __asm__ __volatile__ ("msrclr r0, %0; NOP;"  \
                                 :              \
                                 : "i" (IE_BIT) \
                                 : "memory");   \
}                                               

#endif /* _SB_MSR_H */


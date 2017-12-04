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

#ifndef _SB_CACHE_H
#define _SB_CACHE_H

/**
 * \file sb_cache.h
 * \brief Cache primitives 
 * \author LIRMM - Lyonel Barthe
 * \version 1.1
 * \date 11/10/2010 
 */
 
#include "sb_types.h"
#include "sb_def.h"      

/* INLINE FUNCTIONS */
  								       
/**
 * \fn void __sb_flush_dcache_line(const sb_uint32_t adr)
 * \brief Flush a DC line
 * \param[in] adr Address of the line to flush
 */  
static __inline__ void __sb_flush_dcache_line(const sb_uint32_t adr)
{
  __asm__ __volatile__ ("wdc.flush %0, r0;"      \
                                   :             \
                                   : "r" (adr)); \
}

#if defined (SB_DCACHE_USE_WRITEBACK) && defined(SB_CACHE_OPT_MACRO)
/**
 * \fn void __sb_flush_all_dcache(void)
 * \brief Flush all the data cache 
 */
static __inline__ void __sb_flush_all_dcache(void)
{

  do {									
    sb_uint32_t base = SB_DC_BASE_ADDRESS;				
    sb_uint32_t length = SB_DCACHE_BYTE_SIZE-SB_DCACHE_LINE_BYTE_SIZE;	
    sb_uint32_t step = -SB_DCACHE_LINE_BYTE_SIZE;			
    
    __asm__ __volatile__ (" 1: wdc.flush %0, %1;                       \
                               bgtid     %1, 1b;                       \
                               addk      %1, %1, %2;"                  \
                                         : : "r" (base), "r" (length), \
                                             "r" (step) : "memory");   \
  } while(0);
	
}

#elif defined(SB_DCACHE_USE_WRITEBACK)
/**
 * \fn void __sb_flush_all_dcache(void)
 * \brief Flush all the data cache 
 */
static __inline__ void __sb_flush_all_dcache(void)
{
  sb_uint32_t i;

  for(i=SB_DC_BASE_ADDRESS;i<=SB_DC_HIGH_ADDRESS;i+=SB_DCACHE_LINE_BYTE_SIZE)
  {
    __asm__ __volatile__ ("wdc.flush %0, r0;"    \
                                     :           \
                                     : "r" (i)); \
  }
}

#else
  /* not implemented for write-through policy */

#endif

/**
 * \fn void __sb_invalidate_dcache_line(const sb_uint32_t adr)
 * \brief Invalidate a DC line
 * \param[in] adr Address of the line to invalidate
 */  
static __inline__ void __sb_invalidate_dcache_line(const sb_uint32_t adr)
{
  __asm__ __volatile__ ("wdc %0, r0;"      \
                             :             \
                             : "r" (adr)); \
}

/**
 * \fn void __sb_invalidate_all_dcache(void)
 * \brief Invalidate all the data cache 
 */
static __inline__ void __sb_invalidate_all_dcache(void)
{
  sb_uint32_t i;

  for(i=SB_DC_BASE_ADDRESS;i<=SB_DC_HIGH_ADDRESS;i+=SB_DCACHE_LINE_BYTE_SIZE)
  {
    __asm__ __volatile__ ("wdc %0, r0;"    \
                               :           \
                               : "r" (i)); \
  }
}

/**
 * \fn void __sb_invalidate_icache_line(const sb_uint32_t adr)
 * \brief Invalidate an IC line
 * \param[in] adr Address of the line to invalidate
 */  
static __inline__ void __sb_invalidate_icache_line(const sb_uint32_t adr)
{
  __asm__ __volatile__ ("wic %0, r0;"      \
                             :             \
                             : "r" (adr)); \

  /* fill up the pipeline with NOPs because WIC is executed with a latency of 4 clock cycles */
  __asm__ __volatile__ ("NOP;");
  __asm__ __volatile__ ("NOP;");
  __asm__ __volatile__ ("NOP;");
  __asm__ __volatile__ ("NOP;");
}


/**
 * \fn void __sb_invalidate_all_icache(void)
 * \brief Invalidate all the instruction cache 
 */
static __inline__ void __sb_invalidate_all_icache(void)
{
  sb_uint32_t i;

  for(i=SB_IC_BASE_ADDRESS;i<=SB_IC_HIGH_ADDRESS;i+=SB_ICACHE_LINE_BYTE_SIZE)
  {
    __asm__ __volatile__ ("wic %0, r0;"    \
                               :           \
                               : "r" (i)); \
  }

  /* fill up the pipeline with NOPs because WIC is executed with a latency of 4 clock cycles */
  /* safe implementation there (all NOPs are not necessary) because the loop uses some instructions after the WIC */
  __asm__ __volatile__ ("NOP;");
  __asm__ __volatile__ ("NOP;");
  __asm__ __volatile__ ("NOP;");
  __asm__ __volatile__ ("NOP;");
}
 
#endif /* _SB_CACHE_H */


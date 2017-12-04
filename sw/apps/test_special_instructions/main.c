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
 * \file main.c
 * \brief Special Instructions testbench
 * \author LIRMM - Lyonel Barthe
 * \version 1.1
 * \date 11/10/2010
 */

#include "sb_io.h"
#include "sb_types.h"
#include "sb_uart.h"

#include "e_printf.h" /* embedded printf */

int main(void)
{
  volatile sb_int32_t m1,m2,m3;
  volatile sb_uint32_t um1,um2;
  volatile sb_int64_t m4;
  volatile sb_uint64_t um3;

  /* divu rd, r1, r2 */
  e_printf("div inst\n"); 
  um1 = 0x1;
  um2 = 0x8000001;
  um3 = um1/um2; 
  if(um3 == 0) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* div rd, r1, r2 */
  e_printf("div inst\n"); 
  m1 = -1023;
  m2 = -511;
  m3 = m1/m2; 
  if(m3 == 2) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* divu rd, r1, r2 */
  e_printf("divu inst\n");
  um1 = 19903994;
  um2 = 2451;  
  um3 = um1/um2;
  if(um3 == 8120) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* div rd, r1, r2 */
  e_printf("div inst\n"); 
  m1 = -1023;
  m2 = 0;
  m3 = m1/m2; 
  if(m3 == 0) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* div rd, r1, r2 */
  e_printf("div inst\n"); 
  m1 = -2147483648;
  m2 = -1;
  m3 = m1/m2; 
  if(m3 == -2147483648) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* check cmp instructions */
  e_printf("cmp inst\n"); 
  m1 = -1;
  m2 = -1;
  __asm__ __volatile__ ("cmpu %0, %1, %2;"           \
                              : "=r" (m3)            \
                              : "r" (m1), "r" (m2)); \
  if(((m3 >> 24) & 0x80) == 0x00) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* check cmp instructions */
  e_printf("cmp inst\n"); 
  m1 = 0x7FFFFFFF;
  m2 = 0x80000000;
  __asm__ __volatile__ ("cmpu %0, %1, %2;"             \
                              : "=r" (m3)              \
                              : "r" (um1), "r" (um2)); \
  if(((m3 >> 24) & 0x80) == 0x80) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* check cmpu instructions */
  e_printf("cmpu inst\n"); 
  um1 = 0xFFFFFFFF;
  um2 = 0x0FFFFFFF;
  __asm__ __volatile__ ("cmpu %0, %1, %2;"             \
                              : "=r" (m3)              \
                              : "r" (um1), "r" (um2)); \
  if(((m3 >> 24) & 0x80) == 0x80) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* check cmpu instructions */
  e_printf("cmpu inst\n"); 
  um1 = 0xFFFFFFFF;
  um2 = 0xFFFFFFFF;
  __asm__ __volatile__ ("cmpu %0, %1, %2;"             \
                              : "=r" (m3)              \
                              : "r" (um1), "r" (um2)); \
  if(((m3 >> 24) & 0x80) == 0x00) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* check cmpu instructions */
  e_printf("cmpu inst\n"); 
  um1 = 0x7FFFFFFF;
  um2 = 0x80000000;
  __asm__ __volatile__ ("cmpu %0, %1, %2;"             \
                              : "=r" (m3)              \
                              : "r" (um1), "r" (um2)); \
  if(((m3 >> 24) & 0x80) == 0x00) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* bsll */
  e_printf("bsll inst\n");   
  m1 = 0x0000FF00;
  m2 = 8;
  m3 = (m1 << m2);
  if(m3 == 0xFF0000) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  } 
  
  /* mul rd, r1, r2 */
  e_printf("mul inst\n"); 
  m1 = -1023;
  m2 = -511;
  m3 = m1*m2; 
  if(m3 == 522753) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* muli rd, r1, imm */
  e_printf("muli inst\n"); 
  m1 = -2500;
  m3 = m1*5191; 
  if(m3 == -12977500) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* mulh rd, r1, r2 */
  e_printf("mulh inst\n");
  m1 = -240909;
  m2 = -103994;  
  m4 = (sb_int64_t)m1*m2;
  if(m4 == 25053090546) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* mulhu rd, r1, r2 */
  e_printf("mulhu inst\n");
  um1 = 240909;
  um2 = 19903994;  
  um3 = (sb_uint64_t)um1*um2;
  if(um3 == 4795051290546) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* mulhsu rd, r1, r2 */
  e_printf("mulhsu inst\n");
  m1 = -240909;
  um2 = 19903994;  
  m4 = (sb_uint64_t)((sb_int64_t)m1*um2);
  if(m4 == -4795051290546) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* pcmpeq rd, r1, r2 */
  e_printf("pcmpeq inst\n");
  m1 = 240909;
  m2 = 240909;  
  m1 = (m1 == m2);
  if(m1 == 1) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* pcmpne rd, r1, r2 */
  e_printf("pcmpne inst\n");
  m1 = 240909;
  m2 = 140909;  
  m1 = (m1 != m2);
  if(m1 == 1) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* clz rd, r1 */
  e_printf("clz inst\n");
  m1 = 0;
  __asm__ __volatile__ ("clz %0, %1;"     \
                             : "=r" (m2)  \
                             : "r" (m1)); \
  if(m2 == 32) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* clz rd, r1 */
  e_printf("clz inst\n");
  m1 = 0xFFFFFFFF;
  __asm__ __volatile__ ("clz %0, %1;"     \
                             : "=r" (m2)  \
                             : "r" (m1)); \
  if(m2 == 0) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  /* clz rd, r1 */
  e_printf("clz inst\n");
  m1 = 4830239;
  __asm__ __volatile__ ("clz %0, %1;"     \
                             : "=r" (m2)  \
                             : "r" (m1)); \
  if(m2 == 9) 
  {
    e_printf("ok!\n");    
  }
  else
  {
    e_printf("failed!\n");    
  }

  return 0;
}


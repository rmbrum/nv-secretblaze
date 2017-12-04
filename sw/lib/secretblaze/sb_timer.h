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

#ifndef _SB_TIMER_H
#define _SB_TIMER_H

/**
 * \file sb_timer.h
 * \brief Timer primitives
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 11/05/2010 
 */
 
#include "sb_types.h"
#include "sb_io.h"
#include "sb_def.h"

/* INLINE FUNCTIONS */

/**
 * \fn void timer_1_init(const sb_uint32_t threshold)
 * \brief Timer 1 initialization
 * \param[in] threshold Threshold value
 */
static __inline__ void timer_1_init(const sb_uint32_t threshold)
{
  WRITE_REG32(TIMER_1_CONTROL_REG,TIMER_RESET_BIT);
  WRITE_REG32(TIMER_1_THRESHOLD_REG,threshold);
}

/**
 * \fn void timer_2_init(const sb_uint32_t threshold)
 * \brief Timer 2 initialization
 * \param[in] threshold Threshold value
 */
static __inline__ void timer_2_init(const sb_uint32_t threshold)
{
  WRITE_REG32(TIMER_2_CONTROL_REG,TIMER_RESET_BIT);
  WRITE_REG32(TIMER_2_THRESHOLD_REG,threshold);
}

/**
 * \fn void timer_1_reset(void)
 * \brief Force reset timer 1
 */
static __inline__ void timer_1_reset(void)
{
  WRITE_REG32(TIMER_1_CONTROL_REG,TIMER_RESET_BIT);
}

/**
 * \fn void timer_2_reset(void)
 * \brief Force reset timer 2
 */
static __inline__ void timer_2_reset(void)
{
  WRITE_REG32(TIMER_2_CONTROL_REG,TIMER_RESET_BIT);
}

/**
 * \fn void timer_1_enable(void)
 * \brief Enable timer 1
 */
static __inline__ void timer_1_enable(void)
{
  WRITE_REG32(TIMER_1_CONTROL_REG,TIMER_ENABLE_BIT);
}

/**
 * \fn void timer_2_enable(void)
 * \brief Enable timer 2
 */
static __inline__ void timer_2_enable(void)
{
  WRITE_REG32(TIMER_2_CONTROL_REG,TIMER_ENABLE_BIT);
}


/**
 * \fn void timer_1_disable(void)
 * \brief Disable timer 1
 */
static __inline__ void timer_1_disable(void)
{
  WRITE_REG32(TIMER_1_CONTROL_REG,0x0);
}

/**
 * \fn void timer_2_disable(void)
 * \brief Disable timer 2
 */
static __inline__ void timer_2_disable(void)
{
  WRITE_REG32(TIMER_2_CONTROL_REG,0x0);
}

/**
 * \fn sb_uint32_t timer_1_getval(void)
 * \brief This function returns the value of the first timer's counter
 * \return Counter value
 */
static __inline__ sb_uint32_t timer_1_getval(void)
{
  return READ_REG32(TIMER_1_COUNTER_REG);
}

/**
 * \fn sb_uint32_t timer_2_getval(void)
 * \brief This function returns the value of the second timer's counter
 * \return Counter value
 */
static __inline__ sb_uint32_t timer_2_getval(void)
{
  return READ_REG32(TIMER_2_COUNTER_REG);
}

#endif /* _SB_TIMER_H */


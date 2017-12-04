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

#ifndef _SB_UART_H
#define _SB_UART_H

/**
 * \file sb_uart.h
 * \brief UART primitives
 * \author LIRMM - Lyonel Barthe
 * \version 1.1
 * \date 25/04/2010
 */
 
#include "sb_types.h"
#include "sb_io.h"
#include "sb_def.h"

/* INLINE FUNCTIONS */

/**
 * \fn void uart_read(sb_uint8_t *const data)
 * \brief Read data from RX buffer
 * \param[in,out] data The pointer to the data
 */
static __inline__ void uart_read(sb_uint8_t *const data)
{
  *data = (sb_uint8_t)READ_REG32(UART_DATA_RX_REG);
}

/**
 * \fn void uart_write(const sb_uint8_t data)
 * \brief Write data to TX buffer
 * \param[in] data The data to write
 */
static __inline__ void uart_write(const sb_uint8_t data)
{
  WRITE_REG32(UART_DATA_TX_REG,data);
}

/**
 * \fn void uart_send(void)
 * \brief Start a TX transfert
 */
static __inline__ void uart_send(void)
{
  WRITE_REG32(UART_CONTROL_REG,SEND_TX_BIT);
}

/* PROTOTYPES */

/**
 * \fn void uart_put(const sb_uint8_t c)
 * \brief Put byte through the TX line
 * \param[in] c The byte
 */
extern void uart_put(const sb_uint8_t c);

/**
 * \fn void uart_get(sb_uint8_t *const in)
 * \brief Get byte from the RX line 
 * \param[in,out] in The pointer to the data
 */
extern void uart_get(sb_uint8_t *const in);

/**
 * \fn void uart_wait_rx_ready(void)
 * \brief Poll the RX ready flag, return when new RX data.
 */
extern void uart_wait_rx_ready(void);

/**
 * \fn void uart_wait_tx_done(void)
 * \brief Poll the TX busy flag, return when TX transfert is finished.
 */
extern void uart_wait_tx_done(void);

#endif /* _SB_UART_H */


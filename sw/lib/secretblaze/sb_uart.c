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

#include "sb_uart.h"

/**
 * \fn void uart_put(const sb_uint8_t c)
 * \brief Put byte through the TX line
 * \param[in] c The byte
 */
void uart_put(const sb_uint8_t c)
{
  uart_write(c);
  uart_send();
  uart_wait_tx_done();
}

/**
 * \fn void uart_get(sb_uint8_t *const in)
 * \brief Get byte from the RX line 
 * \param[in,out] in The pointer to the data
 */
void uart_get(sb_uint8_t *const in)
{
  uart_wait_rx_ready();
  uart_read(in);
}

/**
 * \fn void uart_wait_rx_ready(void)
 * \brief Poll the RX ready flag, return when new RX data.
 */
void uart_wait_rx_ready(void)
{
  sb_uint32_t flag = (READ_REG32(UART_STATUS_REG) & RX_READY_FLAG_BIT);
  while(flag != RX_READY_FLAG_BIT)
  {
    flag = (READ_REG32(UART_STATUS_REG) & RX_READY_FLAG_BIT);
  }
}

/**
 * \fn void uart_wait_tx_done(void)
 * \brief Poll the TX busy flag, return when TX transfert is finished.
 */
void uart_wait_tx_done(void)
{
  sb_uint32_t flag = (READ_REG32(UART_STATUS_REG) & TX_BUSY_FLAG_BIT);
  while(flag == TX_BUSY_FLAG_BIT)
  {
    flag = (READ_REG32(UART_STATUS_REG) & TX_BUSY_FLAG_BIT);
  }
}


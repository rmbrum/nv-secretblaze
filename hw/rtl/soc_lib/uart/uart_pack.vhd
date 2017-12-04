--
--    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
--    contact: adac@lirmm.fr
--
--    This file is part of SecretBlaze.
--
--    SecretBlaze is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    SecretBlaze is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
--

-----------------------------------------------------------------
-----------------------------------------------------------------
--                                                             
--! @file uart_pack.vhd                                					
--! @brief UART Package    				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 12/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The package implements useful UART defines & tools.
--

--! UART Package
package uart_pack is
	
  -- //////////////////////////////////////////
  --               UART SETTINGS
  -- //////////////////////////////////////////
  
  --
  -- UART SETTINGS
  -- 

  constant UART_DATA_W       : natural := 8;                                             --! 8 bit data mode only
  constant RX_BAUD_COUNTER_S : natural := USER_UART_CLK_MHZ*10**6/USER_UART_BAUD_RATE/2; --! rx baud counter size
  constant TX_BAUD_COUNTER_S : natural := USER_UART_CLK_MHZ*10**6/USER_UART_BAUD_RATE;   --! tx baud counter size
  constant RX_BAUD_COUNTER_W : natural := log2(RX_BAUD_COUNTER_S);                       --! rx baud counter width
  constant TX_BAUD_COUNTER_W : natural := log2(TX_BAUD_COUNTER_S);                       --! tx baud counter width

  --
  -- UART TYPE/SUBTYPES
  -- 

  subtype rx_baud_counter_t   is std_ulogic_vector(RX_BAUD_COUNTER_W - 1 downto 0); --! rx baud counter type
  subtype tx_baud_counter_t   is std_ulogic_vector(TX_BAUD_COUNTER_W - 1 downto 0); --! tx baud counter type
  subtype uart_data_t         is std_ulogic_vector(UART_DATA_W - 1 downto 0);       --! UART data type
  subtype uart_data_counter_t is std_ulogic_vector(log2(UART_DATA_W) - 1 downto 0); --! UART baud counter type

  type rx_fsm_t               is (RX_IDLE, RX_START, RX_SYNC, RX_SHIFT, RX_STOP);   --! UART rx fsm type
  type tx_fsm_t               is (TX_IDLE, TX_START, TX_SEND, TX_STOP);             --! UART tx fsm type

  -- //////////////////////////////////////////
  --      UART WB SLAVE INTERFACE SETTINGS
  -- //////////////////////////////////////////

  --
  -- GENERAL SETTINGS/TYPES/SUBTYPES
  -- 

  constant UART_NB_INT : natural := 2; 

  subtype uart_int_vector_t is std_ulogic_vector(UART_NB_INT - 1 downto 0); --! UART interrupt type 

  --
  -- MEMORY MAP DEFINES
  --

  constant MAX_SLV_UART_W : natural := 8;                     --! UART WISHBONE read data bus max width

  subtype wb_uart_reg_adr_t is std_ulogic_vector(1 downto 0); --! UART register memory map type
  constant STATUS_OFF  : wb_uart_reg_adr_t := "00"; -- base + 0x0
  constant RX_DAT_OFF  : wb_uart_reg_adr_t := "01"; -- base + 0x4
  constant CONTROL_OFF : wb_uart_reg_adr_t := "10"; -- base + 0x8
  constant TX_DAT_OFF  : wb_uart_reg_adr_t := "11"; -- base + 0xc
  
  -- //////////////////////////////////////////
  --              UART IO STRUCTURES
  -- //////////////////////////////////////////

  type uart_i_t is record
    rx_i : std_ulogic;
    -- for future ext 
  end record;

  type uart_o_t is record
    tx_o : std_ulogic;
    -- for future ext
  end record;

end uart_pack;


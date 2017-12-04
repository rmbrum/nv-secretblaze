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
--! @file uart_top.vhd                                					
--! @brief UART Top Level Entity      				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 12/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_lib;
use wb_lib.wb_pack.all;

library soc_lib;
use soc_lib.uart_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

--
--! The module implements the top level entity of the UART controller
--! with its WISHBONE slave interface. 
--

--! UART Top Level Entity
entity uart_top is

  port
    (
      uart_i     : in uart_i_t;           --! UART general inputs
      uart_o     : out uart_o_t;          --! UART general outputs
      uart_int_o : out uart_int_vector_t; --! UART interrupt vector outputs
      wb_bus_i   : in wb_slave_bus_i_t;   --! WISHBONE slave inputs
      wb_bus_o   : out wb_slave_bus_o_t   --! WISHBONE slave outputs  
    );

end uart_top;

--! UART Top Level Architecture
architecture be_uart_top of uart_top is

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  signal rx_dat_o_s   : uart_data_t;
  signal tx_dat_i_s   : uart_data_t;
  signal tx_send_i_s  : std_ulogic;
  signal tx_busy_o_s  : std_ulogic;
  signal rx_ready_o_s : std_ulogic;  
  signal rst_n_s      : std_ulogic;

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  rst_n_s <= not(wb_bus_i.rst_i);

  UART_CTR: entity soc_lib.uart_controller(be_uart_controller)
    port map
    ( 
      rx_i           => uart_i.rx_i,		
      tx_o           => uart_o.tx_o,			
      tx_dat_i       => tx_dat_i_s,		
      rx_dat_o       => rx_dat_o_s,		
      tx_send_i      => tx_send_i_s,		
      tx_busy_o      => tx_busy_o_s,		
      rx_ready_o     => rx_ready_o_s,			
      clk_i          => wb_bus_i.clk_i,		
      rst_n_i        => rst_n_s
    ); 

  WB_SLV_UART: entity soc_lib.uart_slave_wb_bus(be_uart_slave_wb_bus)
    port map
    (
      uart_int_o     => uart_int_o,
      wb_bus_i       => wb_bus_i,
      wb_bus_o       => wb_bus_o,
      tx_dat_in_o    => tx_dat_i_s,		
      rx_dat_out_i   => rx_dat_o_s,		
      tx_send_in_o   => tx_send_i_s,		
      tx_busy_out_i  => tx_busy_o_s,		
      rx_ready_out_i => rx_ready_o_s  
    );

end be_uart_top;


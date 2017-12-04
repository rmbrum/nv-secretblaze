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
--! @file sram_top.vhd                                					
--! @brief SRAM Top Level Entity      				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 1/10/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_lib;
use wb_lib.wb_pack.all;

library soc_lib;
use soc_lib.sram_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The module implements the top level entity of a basic 
--! 32-bit SRAM controller with its WISHBONE slave interface.
--

--! SRAM Top Level Entity
entity sram_top is

  generic
    (
      M_S_CLK_DIV  : real := USER_M_S_CLK_DIV --! memory/core clock ratio
    );

  port
    (
      sram_in_o    : out sram_i_t;            --! SRAM interface control inputs 
      sram_data_io : inout sram_io_t;         --! SRAM interface data in/out
      wb_bus_i     : in wb_slave_bus_i_t;     --! WISHBONE slave inputs
      wb_bus_o     : out wb_slave_bus_o_t;    --! WISHBONE slave outputs
      clk_i        : in std_ulogic;           --! internal controller clock
      rst_n_i      : in std_ulogic            --! active-low reset signal   
    );

end sram_top;

--! SRAM Top Level Architecture
architecture be_sram_top of sram_top is
  
  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  signal we_i_s    : std_ulogic;
  signal re_i_s    : std_ulogic;
  signal sel_i_s   : sram_sel_t;
  signal adr_i_s   : sram_adr_t;
  signal dat_i_s   : sram_data_t;
  signal dat_o_s   : sram_data_t;
  signal ready_o_s : std_ulogic;
   
begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  SRAM_CTR: entity soc_lib.sram_controller(be_sram_controller)
    generic map
    (
      M_S_CLK_DIV  => M_S_CLK_DIV 
    )
    port map
    (
      sram_in_o    => sram_in_o, 
      sram_data_io => sram_data_io,
      we_i         => we_i_s,
      re_i         => re_i_s,
      sel_i        => sel_i_s,
      adr_i        => adr_i_s,
      dat_i        => dat_i_s,
      dat_o        => dat_o_s,
      ready_o      => ready_o_s,
      clk_i        => clk_i,
      rst_n_i      => rst_n_i
    );

  WB_SLV_SRAM: entity soc_lib.sram_slave_wb_bus(be_sram_slave_wb_bus)
    generic map
    (
      M_S_CLK_DIV  => M_S_CLK_DIV 
    )
    port map
    (
      wb_bus_i     => wb_bus_i,
      wb_bus_o     => wb_bus_o,
      we_in_o      => we_i_s,                                       
      re_in_o      => re_i_s, 
      sel_in_o     => sel_i_s,                                             
      adr_in_o     => adr_i_s, 
      dat_in_o     => dat_i_s,                         
      dat_out_i    => dat_o_s,     
      ready_out_i  => ready_o_s
    );

end be_sram_top;


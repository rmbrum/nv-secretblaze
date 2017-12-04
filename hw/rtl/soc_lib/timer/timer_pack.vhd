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
--! @file timer_pack.vhd                                					
--! @brief TIMER Package    				
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
-- Version 0.1 10/05/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The package implements useful defines & tools for the TIMER IP.
--

--! Timer Package
package timer_pack is
	
  -- //////////////////////////////////////////
  --               TIMER SETTINGS
  -- //////////////////////////////////////////

  constant TIMER_DATA_W : natural := USER_TIMER_DATA_W;                 --! TIMER data width
  
  subtype timer_data_t is std_ulogic_vector(TIMER_DATA_W - 1 downto 0); --! TIMER data type
  subtype timer_int_vector_t is std_ulogic_vector(1 downto 0);          --! TIMER interrupt type

  -- //////////////////////////////////////////
  --      TIMER WB SLAVE INTERFACE SETTINGS
  -- //////////////////////////////////////////

  --
  -- MEMORY MAP DEFINES
  --

  constant MAX_SLV_TIMER_W : natural := USER_MAX_SLV_TIMER_W;           --! TIMER WISHBONE read data bus max width

  subtype wb_timer_reg_adr_t is std_ulogic_vector(2 downto 0); --! TIMER register memory map type
  constant CONTROL_1_OFF   : wb_timer_reg_adr_t := "000"; -- base + 0x0
  constant THRESHOLD_1_OFF : wb_timer_reg_adr_t := "001"; -- base + 0x4
  constant COUNTER_1_OFF   : wb_timer_reg_adr_t := "010"; -- base + 0x8
  constant CONTROL_2_OFF   : wb_timer_reg_adr_t := "011"; -- base + 0xc
  constant THRESHOLD_2_OFF : wb_timer_reg_adr_t := "100"; -- base + 0x10
  constant COUNTER_2_OFF   : wb_timer_reg_adr_t := "101"; -- base + 0x14

end timer_pack;


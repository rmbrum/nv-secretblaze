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
--! @file gpio_pack.vhd                                					
--! @brief GPIO Package    				
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
--! The package implements useful defines & tools for GPIO IP.
--

--! GPIO Package
package gpio_pack is
	
  -- //////////////////////////////////////////
  --               GPIO SETTINGS
  -- //////////////////////////////////////////
  
  constant GPO_W : natural := USER_GPO_W; --! GPO register width 
  constant GPI_W : natural := USER_GPI_W; --! GPI register width 

  subtype gpo_data_t is std_ulogic_vector(GPO_W - 1 downto 0); --! GPO data type
  subtype gpi_data_t is std_ulogic_vector(GPI_W - 1 downto 0); --! GPI data type

  -- //////////////////////////////////////////
  --      GPIO WB SLAVE INTERFACE SETTINGS
  -- //////////////////////////////////////////

  --
  -- MEMORY MAP DEFINES
  --

  constant MAX_SLV_GPIO_W : natural := USER_MAX_SLV_GPIO_W; --! GPIO WISHBONE read data buffer max width

  subtype wb_gpio_reg_adr_t is std_ulogic_vector(0 downto 0); --! GPIO register memory map type
  constant GPO_OFF      : wb_gpio_reg_adr_t := "0";         -- base + 0x0
  constant GPI_OFF      : wb_gpio_reg_adr_t := "1";         -- base + 0x4

  -- //////////////////////////////////////////
  --              GPIO IO STRUCTURES
  -- //////////////////////////////////////////
  
  type gpio_i_t is record
    gpi_i : gpi_data_t;
    -- for future ext 
  end record;

  type gpio_o_t is record
    gpo_o : gpo_data_t;
    -- for future ext
  end record;
  
end gpio_pack;


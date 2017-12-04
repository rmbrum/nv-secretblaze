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
--! @file intc_pack.vhd                                		
--! @brief INTC Package    				
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

library sb_lib;
use sb_lib.sb_core_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The package implements useful defines & tools for INTC.
--

--! INTC Package
package intc_pack is
	
  -- //////////////////////////////////////////
  --               INTC SETTINGS
  -- //////////////////////////////////////////
  
  constant INTC_NB_SOURCES : natural := USER_INTC_NB_SOURCES; --! by default, 8 sources are supported
 
  constant INTC_ID_0       : natural := 0;  --! interrupt id 0
  constant INTC_ID_1       : natural := 1;  --! interrupt id 1
  constant INTC_ID_2       : natural := 2;  --! interrupt id 2
  constant INTC_ID_3       : natural := 3;  --! interrupt id 3
  constant INTC_ID_4       : natural := 4;  --! interrupt id 4
  constant INTC_ID_5       : natural := 5;  --! interrupt id 5
  constant INTC_ID_6       : natural := 6;  --! interrupt id 6
  constant INTC_ID_7       : natural := 7;  --! interrupt id 7
  constant INTC_ID_8       : natural := 8;  --! interrupt id 8
  constant INTC_ID_9       : natural := 9;  --! interrupt id 9
  constant INTC_ID_10      : natural := 10; --! interrupt id 10
  constant INTC_ID_11      : natural := 11; --! interrupt id 11
  constant INTC_ID_12      : natural := 12; --! interrupt id 12
  constant INTC_ID_13      : natural := 13; --! interrupt id 13
  constant INTC_ID_14      : natural := 14; --! interrupt id 14
  constant INTC_ID_15      : natural := 15; --! interrupt id 15
  constant INTC_ID_16      : natural := 16; --! interrupt id 16
  constant INTC_ID_17      : natural := 17; --! interrupt id 17
  constant INTC_ID_18      : natural := 18; --! interrupt id 18
  constant INTC_ID_19      : natural := 19; --! interrupt id 19
  constant INTC_ID_20      : natural := 20; --! interrupt id 20
  constant INTC_ID_21      : natural := 21; --! interrupt id 21
  constant INTC_ID_22      : natural := 22; --! interrupt id 22
  constant INTC_ID_23      : natural := 23; --! interrupt id 23
  constant INTC_ID_24      : natural := 24; --! interrupt id 24
  constant INTC_ID_25      : natural := 25; --! interrupt id 25
  constant INTC_ID_26      : natural := 26; --! interrupt id 26
  constant INTC_ID_27      : natural := 27; --! interrupt id 27
  constant INTC_ID_28      : natural := 28; --! interrupt id 28
  constant INTC_ID_29      : natural := 29; --! interrupt id 29
  constant INTC_ID_30      : natural := 30; --! interrupt id 30
  constant INTC_ID_31      : natural := 31; --! interrupt id 31

  subtype intc_data_t is std_ulogic_vector(INTC_NB_SOURCES - 1 downto 0); --! INTC data type

  -- //////////////////////////////////////////
  --      INTC WB SLAVE INTERFACE SETTINGS
  -- //////////////////////////////////////////

  --
  -- MEMORY MAP DEFINES
  --

  constant MAX_SLV_INTC_W : natural := USER_MAX_SLV_INTC_W; --! INTC WISHBONE read data bus max width

  subtype wb_intc_reg_adr_t is std_ulogic_vector(2 downto 0); --! INTC register memory map type
  constant STATUS_OFF   : wb_intc_reg_adr_t := "000"; -- base + 0x0
  constant ACK_OFF      : wb_intc_reg_adr_t := "001"; -- base + 0x4
  constant MASK_OFF     : wb_intc_reg_adr_t := "010"; -- base + 0x8
  constant ARM_OFF      : wb_intc_reg_adr_t := "011"; -- base + 0xc
  constant POL_OFF      : wb_intc_reg_adr_t := "100"; -- base + 0x10

  -- //////////////////////////////////////////
  --              INTC IO STRUCTURES
  -- //////////////////////////////////////////

  type intc_i_t is record
    int_sources_i : intc_data_t;
    -- for future ext 
  end record;
  
  type intc_o_t is record
    cpu_int_o     : int_status_t;
    -- for future ext 
  end record;

end intc_pack;


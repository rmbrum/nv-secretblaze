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
--! @file wb_pack.vhd                                					
--! @brief WISHBONE Bus Package    				
--! @author Lyonel Barthe
--! @version 1.1
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
-- 
-- Version 1.1 08/2012 by Lyonel Barthe
-- Added BURST_LENGTH tag signal
--
-- Version 1.0b 30/06/2010 by Lyonel Barthe
-- Added STALL_I signal (WB Rev 4)
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 12/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
--! The package implements useful defines and settings of the WISHBONE bus entity.
--

--! WB Bus Package
package wb_pack is

  -- //////////////////////////////////////////
  --             WISHBONE BUS DEFINES
  -- //////////////////////////////////////////

  --
  -- WB CONSTANTS
  --
 
  constant WB_BUS_DATA_W   : natural := 32; --! WISHBONE data bus width
  constant WB_BUS_ADR_W    : natural := 32; --! WISHBONE address bus width
  constant WB_WORD_ADR_OFF : natural := 2;  --! WISHBONE 32-bit word offset for addressing
  
  --
  -- WB DATA TYPES/SUBTYPES
  --

  subtype wb_bus_data_t is std_ulogic_vector(WB_BUS_DATA_W - 1 downto 0);   --! WISHBONE data type
  subtype wb_bus_adr_t  is std_ulogic_vector(WB_BUS_ADR_W - 1 downto 0);    --! WISHBONE address type
  subtype wb_bus_sel_t  is std_ulogic_vector(WB_BUS_DATA_W/8 - 1 downto 0); --! WISHBONE byte addressable memory type
  constant WB_BYTE_3_SEL        : wb_bus_sel_t := "0001";
  constant WB_BYTE_2_SEL        : wb_bus_sel_t := "0010";
  constant WB_BYTE_1_SEL        : wb_bus_sel_t := "0100";
  constant WB_BYTE_0_SEL        : wb_bus_sel_t := "1000";
  constant WB_HALFWORD_1_SEL    : wb_bus_sel_t := "0011";
  constant WB_HALFWORD_0_SEL    : wb_bus_sel_t := "1100";
  constant WB_WORD_SEL          : wb_bus_sel_t := "1111";

  subtype wb_bus_cti_t is std_ulogic_vector(2 downto 0);                    --! WISHBONE cycle type identifier
  constant WB_CLASSIC_CYCLE     : wb_bus_cti_t := "000";                    --! WISHBONE classic cycle identifier
  constant WB_CONST_BURST_CYCLE : wb_bus_cti_t := "001";                    --! WISHBONE constant address burst cycle identifier
  constant WB_INC_BURST_CYCLE   : wb_bus_cti_t := "010";                    --! WISHBONE incrementing burst cycle identifier
  constant WB_END_OF_BURST      : wb_bus_cti_t := "111";                    --! WISHBONE end of burst cycle identifier

  subtype wb_bus_bte_t is std_ulogic_vector(1 downto 0);                    --! WISHBONE burst type extension
  constant WB_LINEAR_BURST      : wb_bus_bte_t := "00";                     --! WISHBONE linear burst extension 
  constant WB_4_BEAT_BURST      : wb_bus_bte_t := "01";                     --! WISHBONE 4-beat wrap burst extension
  constant WB_8_BEAT_BURST      : wb_bus_bte_t := "10";                     --! WISHBONE 8-beat wrap burst extension
  constant WB_16_BEAT_BURST     : wb_bus_bte_t := "11";                     --! WISHBONE 16-beat wrap burst extension

  subtype wb_bus_bl_t is std_ulogic_vector(5 downto 0);                     --! WISHBONE burst length tag 
  
  type wb_memory_map_t is array(natural range <>) of wb_bus_adr_t;          --! WISHBONE memory map type


  -- //////////////////////////////////////////
  --           WISHBONE BUS STRUCTURES
  -- //////////////////////////////////////////

  type wb_master_bus_i_t is record
    clk_i   : std_ulogic;
    rst_i   : std_ulogic;
    dat_i   : wb_bus_data_t;
    ack_i   : std_ulogic;
    err_i   : std_ulogic;
    rty_i   : std_ulogic;
    stall_i : std_ulogic;
  end record;

  type wb_master_bus_o_t is record
    cyc_o : std_ulogic;
    stb_o : std_ulogic;
    we_o  : std_ulogic;                                  
    sel_o : wb_bus_sel_t;
    adr_o : wb_bus_adr_t;   
    dat_o : wb_bus_data_t;
    cti_o : wb_bus_cti_t;
    bte_o : wb_bus_bte_t; 
    bl_o  : wb_bus_bl_t;
  end record;

  type wb_slave_bus_i_t is record
    clk_i : std_ulogic;
    rst_i : std_ulogic;
    cyc_i : std_ulogic;
    stb_i : std_ulogic;
    we_i  : std_ulogic;                                  
    sel_i : wb_bus_sel_t;
    adr_i : wb_bus_adr_t;
    dat_i : wb_bus_data_t;
    cti_i : wb_bus_cti_t;
    bte_i : wb_bus_bte_t; 
    bl_i  : wb_bus_bl_t;     
  end record;

  type wb_slave_bus_o_t is record
    dat_o   : wb_bus_data_t;
    ack_o   : std_ulogic;
    err_o   : std_ulogic;
    rty_o   : std_ulogic;
    stall_o : std_ulogic;
  end record;

  type wb_slave_vector_i_t is array(natural range <>) of wb_slave_bus_i_t;    --! WISHBONE input slave vector type
  type wb_slave_vector_o_t is array(natural range <>) of wb_slave_bus_o_t;    --! WISHBONE output slave vector type

  type wb_master_vector_i_t is array(natural range <>) of wb_master_bus_i_t;  --! WISHBONE input master vector type
  type wb_master_vector_o_t is array(natural range <>) of wb_master_bus_o_t;  --! WISHBONE output master vector type
	
end wb_pack;


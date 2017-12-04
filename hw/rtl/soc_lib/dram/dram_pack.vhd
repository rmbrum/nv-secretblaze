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
--! @file dram_pack.vhd                                		
--! @brief DRAM Package    				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 08/2012 by Lyonel Barthe
-- Stable version
--

library ieee;
use ieee.std_logic_1164.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The package implements useful defines & tools for the DRAM controller (DDR2 chips).
--

--! DRAM Package
package dram_pack is

  -- //////////////////////////////////////////
  --               DRAM SETTINGS
  -- //////////////////////////////////////////

  --
  -- DRAM DEFINES
  --

  constant DRAM_BYTE_S : natural := USER_DRAM_BYTE_S;
  constant DRAM_DATA_W : natural := USER_DRAM_DATA_PIN_W;
  constant DRAM_ROW_W  : natural := USER_DRAM_ROW_W;
  constant DRAM_ADR_W  : natural := USER_DRAM_ADR_W;
 
  --
  -- DRAM TYPES/SUBTYPES
  -- 
  
  subtype dram_data_t  is std_logic_vector(DRAM_DATA_W - 1 downto 0);    --! DRAM data type
  subtype dram_adr_t   is std_logic_vector(DRAM_ADR_W - 1 downto 0);     --! DRAM external address type
  subtype dram_row_t   is std_logic_vector(DRAM_ROW_W - 1 downto 0);     --! DRAM external brank address type
  
  type wb_dram_fsm_ctr_t is (WB_DRAM_IDLE, WB_DRAM_WRITE, WB_DRAM_READ); --! WISHBONE DRAM controller 
    
  --
  -- MIG DEFINES
  --
  
  subtype mig_inst_t is std_logic_vector(2 downto 0);    --! Xilinx's MIG instruction type 
  constant MIG_INST_WRITE      : mig_inst_t := "000";
  constant MIG_INST_READ       : mig_inst_t := "001";
  constant MIG_INST_AUTO_WRITE : mig_inst_t := "010";
  constant MIG_INST_AUTO_READ  : mig_inst_t := "011";
  constant MIG_INST_REFRESH    : mig_inst_t := "100";   

  --
  -- MIG TYPES/SUBTYPES
  --
  
  subtype mig_adr_t is std_logic_vector(29 downto 0);    --! Xilinx's MIG address type  
  subtype mig_mask_t is std_logic_vector(3 downto 0);    --! Xilinx's MIG mask type
  subtype mig_data_t is std_logic_vector(31 downto 0);   --! Xilinx's MIG data type
  subtype mig_counter_t is std_logic_vector(6 downto 0); --! Xilinx's MIG counter type
  subtype mig_bl_t is std_logic_vector(5 downto 0);      --! Xilinx's MIG brust length type
  
  -- //////////////////////////////////////////
  --              DRAM IO STRUCTURES
  -- //////////////////////////////////////////
  
  type dram_i_t is record
    ddr2clk_p_i   : std_logic;
    ddr2clk_n_i   : std_logic;
    ddr2clke_i    : std_logic;
    ddr2rasn_i    : std_logic;
    ddr2casn_i    : std_logic;
    ddr2wen_i     : std_logic;
    ddr2ba_i      : dram_row_t;
    ddr2a_i       : dram_adr_t;          
    ddr2ldm_i     : std_logic;
    ddr2udm_i     : std_logic;
    ddr2odt_i     : std_logic;   
  end record;
  
  
  type dram_io_t is record
    ddr2dq_io     : dram_data_t;         
    ddr2rzq_io    : std_logic;
    ddr2zio_io    : std_logic;
    ddr2udqs_p_io : std_logic;
    ddr2udqs_n_io : std_logic;
    ddr2ldqs_p_io : std_logic;
    ddr2ldqs_n_io : std_logic;                
  end record;    

end dram_pack;


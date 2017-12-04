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
--! @file sram_pack.vhd                                		
--! @brief SRAM Package    				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 22/09/2010 by Lyonel Barthe
-- Stable version
--

library ieee;
use ieee.std_logic_1164.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The package implements useful defines & tools for the SRAM controller.
--

--! SRAM Package
package sram_pack is

  -- //////////////////////////////////////////
  --               SRAM SETTINGS
  -- //////////////////////////////////////////

  --
  -- SRAM DEFINES
  --

  constant SRAM_DATA_W    : natural := 32;                 --! 32-bit data controller (only)
  constant SRAM_BYTE_S    : natural := USER_SRAM_BYTE_S;   --! SRAM byte size (default is 1 MB)
  constant SRAM_WORD_S    : natural := SRAM_BYTE_S/4;      --! SRAM word size
  constant SRAM_BYTE_W    : natural := log2(SRAM_BYTE_S);  --! SRAM physical address width
  constant SRAM_WORD_W    : natural := log2(SRAM_WORD_S);  --! SRAM physical word address width
  constant SRAM_BTB_LAT   : natural := 3;                  --! SRAM back-to-back latency
  constant SRAM_LAT_M_S_1 : natural := 4;                  --! SRAM read/write latencies when sclki = mclki (==BTB+1)
  constant SRAM_LAT_M_S_2 : natural := 2;                  --! SRAM read/write latencies when sclki = 2*mclki (==(BTB+1)/2)

  --
  -- SRAM TYPES/SUBTYPES
  -- 

  subtype sram_data_t  is std_ulogic_vector(SRAM_DATA_W - 1 downto 0);   --! SRAM data type
  subtype sram_adr_t   is std_ulogic_vector(SRAM_WORD_W - 1 downto 0);   --! SRAM physical word address type
  subtype sram_sel_t   is std_ulogic_vector(SRAM_DATA_W/8 - 1 downto 0); --! SRAM byte sel type
  subtype sram_lat_m_s_1_counter_t is std_ulogic_vector(2 downto 0);     --! SRAM latency counter type (sclki = mclki)
  subtype sram_lat_m_s_2_counter_t is std_ulogic_vector(1 downto 0);     --! SRAM latency counter type (sclki = 2*mclki)

  type wb_sram_fsm_ctr_t is (WB_SRAM_IDLE, WB_SRAM_BUSY);                                  --! WISHBONE SRAM control fsm type
  type sram_fsm_ctr_t    is (SRAM_IDLE,SRAM_READ_1,SRAM_READ_2,SRAM_WRITE_1,SRAM_WRITE_2); --! SRAM controller fsm type

  -- //////////////////////////////////////////
  --              SRAM IO STRUCTURES
  -- //////////////////////////////////////////

  type sram_i_t is record
    ce1_n_i : std_ulogic;
    ce2_n_i : std_ulogic;
    we_n_i  : std_ulogic;
    oe_n_i  : std_ulogic;
    ub1_n_i : std_ulogic;
    lb1_n_i : std_ulogic;
    ub2_n_i : std_ulogic;
    lb2_n_i : std_ulogic;
    a_i     : sram_adr_t;
  end record;

  subtype sram_io_t is std_logic_vector(SRAM_DATA_W - 1 downto 0); -- use resolve type

end sram_pack;


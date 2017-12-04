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
--! @file sb_lmemory.vhd                            					
--! @brief SecretBlaze Local Memory 				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 21/01/2012 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_memory_unit_pack.all;

library tool_lib;

library config_lib;
use config_lib.sb_config.all;

--
--! The module implements the local memory of the SecretBlaze processor,
--! which is shared for both instructions and data using dual-port RAM.
--
  
--! SecretBlaze Local Memory Entity
entity sb_lmemory is

  generic
    (
      LM_TYPE     : string  := USER_LM_TYPE;   --! LM implementation type 
      LM_FILE_1   : string  := USER_LM_FILE_1; --! LM init file LSB
      LM_FILE_2   : string  := USER_LM_FILE_2; --! LM init file LSB+
      LM_FILE_3   : string  := USER_LM_FILE_3; --! LM init file MSB-
      LM_FILE_4   : string  := USER_LM_FILE_4  --! LM init file MSB
    );

  port
    (
      dm_l_bus_i  : in dm_bus_i_t;             --! data L1 bus inputs (local memory side)
      dm_l_bus_o  : out dm_bus_o_t;            --! data L1 bus outputs (local memory side)
      im_l_bus_i  : in im_bus_i_t;             --! instruction L1 bus inputs (local memory side)
      im_l_bus_o  : out im_bus_o_t;            --! instruction L1 bus outputs (local memory side)
      halt_core_i : in std_ulogic;             --! core stall control signal
      clk_i       : in std_ulogic              --! core clock
    );

end sb_lmemory;

--! SecretBlaze Local Memory Architecture
architecture be_sb_lmemory of sb_lmemory is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal lm_ena_s : std_ulogic;
  signal lm_we_s  : std_ulogic_vector(3 downto 0);

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////
  
  MEM: entity tool_lib.dpram4x8(be_dpram4x8)
    generic map
    (
      RAM_TYPE   => LM_TYPE,
      MEM_FILE_1 => LM_FILE_1,
      MEM_FILE_2 => LM_FILE_2,
      MEM_FILE_3 => LM_FILE_3,               
      MEM_FILE_4 => LM_FILE_4,
      RAM_WORD_S => LM_WORD_S
    )
    port map
    (    
      ena_i      => lm_ena_s,           
      we_i       => lm_we_s,                                                            -- data port
      adr_1_i    => dm_l_bus_i.adr_i(LM_WORD_W + WORD_ADR_OFF - 1 downto WORD_ADR_OFF), -- data port
      adr_2_i    => im_l_bus_i.adr_i(LM_WORD_W + WORD_ADR_OFF - 1 downto WORD_ADR_OFF), -- instruction port
      dat_i      => dm_l_bus_i.dat_i,                                                   -- data port
      dat_1_o    => dm_l_bus_o.dat_o,                                                   -- data port 
      dat_2_o    => im_l_bus_o.dat_o,                                                   -- instruction port
      clk_i      => clk_i
    );

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN INTERNAL SIGNALS
  --

  lm_ena_s <= (dm_l_bus_i.ena_i or im_l_bus_i.ena_i) and not(halt_core_i);
  lm_we_s  <= dm_l_bus_i.sel_i when (dm_l_bus_i.ena_i = '1' and dm_l_bus_i.we_i = '1') else (others => '0');
    
end be_sb_lmemory;


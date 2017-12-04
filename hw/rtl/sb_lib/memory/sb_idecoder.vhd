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
--! @file sb_idecoder.vhd                            					
--! @brief SecretBlaze Instruction Decoder 				
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

library config_lib;
use config_lib.sb_config.all;

--
--! The module implements the memory decoder of the instruction memory
--! sub-system for local memory, and cache accesses.
--
  
--! SecretBlaze Instruction Decoder Entity
entity sb_idecoder is

  generic
    (
      USE_ICACHE     : boolean := USER_USE_ICACHE --! if true, it will implement the data cache
    );

  port
    (
      im_bus_i       : in im_bus_i_t;             --! instruction L1 bus inputs (core side)
      im_bus_o       : out im_bus_o_t;            --! instruction L1 bus outputs (core side)
      im_l_bus_in_o  : out im_bus_i_t;            --! instruction L1 bus inputs (local memory side) 
      im_l_bus_out_i : in im_bus_o_t;             --! instruction L1 bus outputs (local memory side)
      im_c_bus_in_o  : out im_bus_i_t;            --! instruction L1 bus inputs (data cache side) 
      im_c_bus_out_i : in im_bus_o_t;             --! instruction L1 bus outputs (data cache side)
      halt_ic_i      : in std_ulogic;             --! instruction cache stall control signal
      halt_core_i    : in std_ulogic;             --! core stall control signal
      clk_i          : in std_ulogic              --! core clock
    );

end sb_idecoder;

--! SecretBlaze Instruction Decoder Architecture
architecture be_sb_idecoder of sb_idecoder is

  -- //////////////////////////////////////////
  --               INTERNAL REG
  -- //////////////////////////////////////////

  signal im_mux_sel_r   : im_mux_sel_t;  --! instruction memory sel mux reg

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal im_l_bus_ena_s : std_ulogic;
  signal im_c_bus_ena_s : std_ulogic;
  signal im_dat_o_s     : im_bus_data_t;

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  --
  -- CORE -> LOCAL MEMORY
  --
  
  im_l_bus_in_o.ena_i <= im_l_bus_ena_s;
  im_l_bus_in_o.adr_i <= im_bus_i.adr_i;
  
  --
  -- CORE -> IC
  --
  
  im_c_bus_in_o.ena_i <= im_c_bus_ena_s;
  im_c_bus_in_o.adr_i <= im_bus_i.adr_i;
  
  --
  -- LM/IC -> CORE
  --
  
  im_bus_o.dat_o      <= im_dat_o_s;

  --
  -- ADDRESS DECODER
  --
  --! This process implements the decode logic for the
  --! instruction cache and local memory. Memory bounds are 
  --! not checked for a faster and smaller implementation. 
  COMB_INST_MEM_DEC: process(im_bus_i)

    alias im_bus_dec_adr_a:std_ulogic_vector(SB_ADDRESS_DEC_W - 1 downto 0) is
      im_bus_i.adr_i(L1_IM_ADR_BUS_W - 1 downto L1_IM_ADR_BUS_W - SB_ADDRESS_DEC_W); 

  begin

    -- cache access 
    if(USE_ICACHE = true and im_bus_dec_adr_a >= IC_CMEM_BASE_ADR(L1_IM_ADR_BUS_W - 1 downto L1_IM_ADR_BUS_W - SB_ADDRESS_DEC_W)) then
      im_l_bus_ena_s <= '0';
      im_c_bus_ena_s <= im_bus_i.ena_i;
		
      -- local memory
    else
      im_l_bus_ena_s <= im_bus_i.ena_i;
      im_c_bus_ena_s <= '0';
		
    end if;
    
  end process COMB_INST_MEM_DEC;

  GEN_INST_MEM_WO_MUX: if(USE_ICACHE = false) generate
  begin

    im_dat_o_s <= im_l_bus_out_i.dat_o;

  end generate GEN_INST_MEM_WO_MUX;

  GEN_INST_MEM_MUX: if(USE_ICACHE = true) generate
  begin

    --
    -- INST OUT -> IN MUX
    --
    --! This process implements the mux logic used to select
    --! the result according to the memory operation.
    COMB_INST_MEM_MUX: process(im_l_bus_out_i,
                               im_c_bus_out_i,
                               im_mux_sel_r)
    begin

      case im_mux_sel_r is

        when IM_LM =>
          im_dat_o_s <= im_l_bus_out_i.dat_o;

        when IM_IC =>
          im_dat_o_s <= im_c_bus_out_i.dat_o;

        when others =>
          im_dat_o_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
          report "im unit: illegal mux control code" severity warning;        

      end case;

    end process COMB_INST_MEM_MUX;

  end generate GEN_INST_MEM_MUX;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  GEN_INST_MEM_MUX_REG: if(USE_ICACHE = true) generate
  begin

    --
    -- INST MEMORY MUX REG
    --
    --! This process implements the instruction memory mux sel reg.
    CYCLE_INST_MEM_MUX_REG: process(clk_i)
    begin
      
      -- clock event
      if(clk_i'event and clk_i = '1') then
      
        if(im_l_bus_ena_s = '1' and halt_core_i = '0') then
          im_mux_sel_r <= IM_LM;
        end if;

        if(im_c_bus_ena_s = '1' and halt_ic_i = '0') then
          im_mux_sel_r <= IM_IC;
        end if;

      end if;

    end process CYCLE_INST_MEM_MUX_REG;

  end generate GEN_INST_MEM_MUX_REG;
    
end be_sb_idecoder;


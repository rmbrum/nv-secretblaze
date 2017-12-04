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
--! @file sb_ddecoder.vhd                            					
--! @brief SecretBlaze Data Decoder 				
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
--! The module implements the memory decoder of the data memory
--! sub-system for local memory, io, and cache accesses.
--
  
--! SecretBlaze Data Decoder Entity
entity sb_ddecoder is

  generic
    (
      USE_DCACHE      : boolean := USER_USE_DCACHE --! if true, it will implement the data cache
    );

  port
    (
      dm_bus_i        : in dm_bus_i_t;             --! data L1 bus inputs (core side)
      dm_bus_o        : out dm_bus_o_t;            --! data L1 bus outputs (core side)
      dm_l_bus_in_o   : out dm_bus_i_t;            --! data L1 bus inputs (local memory side) 
      dm_l_bus_out_i  : in dm_bus_o_t;             --! data L1 bus outputs (local memory side)
      dm_io_bus_in_o  : out dm_bus_i_t;            --! data L1 bus inputs (io side) 
      dm_io_bus_out_i : in dm_bus_o_t;             --! data L1 bus outputs (io side)
      dm_c_bus_in_o   : out dm_bus_i_t;            --! data L1 bus inputs (data cache side) 
      dm_c_bus_out_i  : in dm_bus_o_t;             --! data L1 bus outputs (data cache side)
      halt_dc_i       : in std_ulogic;             --! data cache stall control signal
      halt_io_i       : in std_ulogic;             --! io unit stall control signal
      halt_core_i     : in std_ulogic;             --! core stall control signal
      clk_i           : in std_ulogic              --! core clock
    );

end sb_ddecoder;

--! SecretBlaze Data Decoder Architecture
architecture be_sb_ddecoder of sb_ddecoder is

  -- //////////////////////////////////////////
  --               INTERNAL REG
  -- //////////////////////////////////////////

  signal dm_mux_sel_r    : dm_mux_sel_t;  --! data memory sel mux reg

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal dm_l_bus_ena_s  : std_ulogic;
  signal dm_io_bus_ena_s : std_ulogic;
  signal dm_c_bus_ena_s  : std_ulogic;
  signal dm_dat_o_s      : dm_bus_data_t;

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  --
  -- CORE -> LM
  --
  
  dm_l_bus_in_o.ena_i  <= dm_l_bus_ena_s;
  dm_l_bus_in_o.sel_i  <= dm_bus_i.sel_i;
  dm_l_bus_in_o.we_i   <= dm_bus_i.we_i;
  dm_l_bus_in_o.adr_i  <= dm_bus_i.adr_i;
  dm_l_bus_in_o.dat_i  <= dm_bus_i.dat_i;  
  
  --
  -- CORE -> IO
  --
  
  dm_io_bus_in_o.ena_i <= dm_io_bus_ena_s;
  dm_io_bus_in_o.sel_i <= dm_bus_i.sel_i;
  dm_io_bus_in_o.we_i  <= dm_bus_i.we_i;
  dm_io_bus_in_o.adr_i <= dm_bus_i.adr_i;
  dm_io_bus_in_o.dat_i <= dm_bus_i.dat_i; 
  
  --
  -- CORE -> DC
  --
  
  dm_c_bus_in_o.ena_i  <= dm_c_bus_ena_s;
  dm_c_bus_in_o.sel_i  <= dm_bus_i.sel_i;
  dm_c_bus_in_o.we_i   <= dm_bus_i.we_i;
  dm_c_bus_in_o.adr_i  <= dm_bus_i.adr_i;
  dm_c_bus_in_o.dat_i  <= dm_bus_i.dat_i; 
  
  --
  -- LM/IO/DC -> CORE
  --
  
  dm_bus_o.dat_o       <= dm_dat_o_s;

  --
  -- ADDRESS DECODER
  --
  --! This process implements the decode logic for the
  --! data cache, I/O accesses and local memory. Memory 
  --! bounds are not checked for a faster and smaller 
  --! implementation. 
  COMB_DATA_MEM_DEC: process(dm_bus_i)

    alias dm_bus_dec_adr_a:std_ulogic_vector(SB_ADDRESS_DEC_W - 1 downto 0) is
      dm_bus_i.adr_i(L1_DM_ADR_BUS_W - 1 downto L1_DM_ADR_BUS_W - SB_ADDRESS_DEC_W); 

  begin
		
    -- i/o 
    if(dm_bus_dec_adr_a >= IO_MAP_BASE_ADR(L1_DM_ADR_BUS_W - 1 downto L1_DM_ADR_BUS_W - SB_ADDRESS_DEC_W)) then
      dm_l_bus_ena_s  <= '0';
      dm_io_bus_ena_s <= dm_bus_i.ena_i;
      dm_c_bus_ena_s  <= '0';
      	
      -- cache access
    elsif(USE_DCACHE = true and dm_bus_dec_adr_a >= DC_CMEM_BASE_ADR(L1_DM_ADR_BUS_W - 1 downto L1_DM_ADR_BUS_W - SB_ADDRESS_DEC_W)) then
      dm_l_bus_ena_s  <= '0';
      dm_io_bus_ena_s <= '0';
      dm_c_bus_ena_s  <= dm_bus_i.ena_i;
	  
      -- local memory
    else
      dm_l_bus_ena_s  <= dm_bus_i.ena_i;
      dm_io_bus_ena_s <= '0';
      dm_c_bus_ena_s  <= '0';
	 
    end if;
    
  end process COMB_DATA_MEM_DEC;

  --
  -- DATA OUT -> IN MUX
  --
  --! This process implements the mux logic used to select
  --! the result according to the memory operation.
  COMB_DATA_MEM_MUX: process(dm_l_bus_out_i,
                             dm_io_bus_out_i,
                             dm_c_bus_out_i,
                             dm_mux_sel_r)
  begin

    case dm_mux_sel_r  is
      
      when DM_LM =>
        dm_dat_o_s   <= dm_l_bus_out_i.dat_o;

      when DM_IO =>
        dm_dat_o_s   <= dm_io_bus_out_i.dat_o;

      when DM_DC =>
        if(USE_DCACHE = true) then
          dm_dat_o_s <= dm_c_bus_out_i.dat_o;
			 
        else
          dm_dat_o_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
          report "dm unit: illegal mux control code because the data cache is not implemented" severity warning;
			 
        end if;     
        
      when others =>
        dm_dat_o_s   <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
        report "dm unit: illegal mux control code" severity warning;
        
    end case;

  end process COMB_DATA_MEM_MUX;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- DATA MEMORY MUX REG
  --
  --! This process implements the data memory mux sel reg.
  CYCLE_DATA_MEM_MUX_REG: process(clk_i)
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
    
      if(dm_l_bus_ena_s = '1' and halt_core_i = '0') then
        dm_mux_sel_r <= DM_LM;
      end if;

      if(dm_io_bus_ena_s = '1' and halt_io_i = '0') then
        dm_mux_sel_r <= DM_IO;
      end if;

      if(USE_DCACHE = true and dm_c_bus_ena_s = '1' and halt_dc_i = '0') then
        dm_mux_sel_r <= DM_DC; 
      end if;

    end if;

  end process CYCLE_DATA_MEM_MUX_REG;
    
end be_sb_ddecoder;


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
--! @file sb_dmemory_unit.vhd                            					
--! @brief SecretBlaze Data Memory Unit 				
--! @author Lyonel Barthe
--! @version 1.3
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.3 21/01/2012 by Lyonel Barthe
-- New version with unified data and instruction local memory
-- Changed coding style for more readability
--
-- Version 1.2 02/09/2011 by Lyonel Barthe
-- Changed WISHBONE stalls management
-- Added the halt_dc_req control signal
--
-- Version 1.1 01/09/2011 by Lyonel Barthe
-- Changed coding style for IO sync signal
--
-- Version 1.0b 18/01/2011 by Lyonel Barthe & Remi Busseuil
-- Fixed a bug with IO operations
--
-- Version 1.0a 03/11/2010 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_memory_unit_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.sb_config.all;
use config_lib.soc_config.all;

--
--! The module implements the management unit of the data memory sub-system.
--
  
--! SecretBlaze Data Memory Unit Entity
entity sb_dmemory_unit is

  generic
    (
      C_S_CLK_DIV      : real    := USER_C_S_CLK_DIV;   --! core/system clock ratio
      USE_DCACHE       : boolean := USER_USE_DCACHE;    --! if true, it will implement the data cache
      DC_MEM_TYPE      : string  := USER_DC_MEM_TYPE;   --! DC memory implementation type  
      DC_TAG_TYPE      : string  := USER_DC_TAG_TYPE;   --! DC tag implementation type  
      DC_MEM_FILE_1    : string  := USER_DC_MEM_FILE_1; --! DC memory init file LSB
      DC_MEM_FILE_2    : string  := USER_DC_MEM_FILE_2; --! DC memory init file LSB+
      DC_MEM_FILE_3    : string  := USER_DC_MEM_FILE_3; --! DC memory init file MSB-
      DC_MEM_FILE_4    : string  := USER_DC_MEM_FILE_4; --! DC memory init file MSB  
      DC_TAG_FILE      : string  := USER_DC_TAG_FILE;   --! DC tag init file
      USE_WRITEBACK    : boolean := USER_USE_WRITEBACK  --! if true, use write-back policy
    );

  port
    (
      dwb_bus_i        : in wb_master_bus_i_t;          --! data WISHBONE master bus inputs
      dwb_bus_o        : out wb_master_bus_o_t;         --! data WISHBONE master bus outputs
      dwb_grant_i      : in std_ulogic;                 --! data WISHBONE grant signal input
      dwb_next_grant_i : in std_ulogic;                 --! data WISHBONE next grant signal input
      dm_bus_i         : in dm_bus_i_t;                 --! data L1 bus inputs (core side)
      dm_bus_o         : out dm_bus_o_t;                --! data L1 bus outputs (core side)
      dm_l_bus_in_o    : out dm_bus_i_t;                --! data L1 bus inputs (local memory side)
      dm_l_bus_out_i   : in dm_bus_o_t;                 --! data L1 bus outputs (local memory side)
      wdc_i            : in wdc_control_t;              --! wdc control input
      dc_busy_o        : out std_ulogic;                --! data cache busy signal
      io_busy_o        : out std_ulogic;                --! io busy signal
      halt_dc_i        : in std_ulogic;                 --! data cache stall control signal
      halt_dc_req_i    : in std_ulogic;                 --! data cache stall request process control signal
      halt_io_i        : in std_ulogic;                 --! io unit stall control signal
      halt_core_i      : in std_ulogic;                 --! core stall control signal
      clk_i            : in std_ulogic;                 --! core clock
      rst_n_i          : in std_ulogic                  --! active-low reset signal 
    );

end sb_dmemory_unit;

--! SecretBlaze Data Memory Unit Architecture
architecture be_sb_dmemory_unit of sb_dmemory_unit is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  --
  -- CONTROL SIGNALS
  --
  
  signal dc_burst_done_s : std_ulogic; 
  signal dc_req_done_s   : std_ulogic;
  
  --
  -- CORE <-> INTERNAL BUSSES
  --
        
  signal dm_io_bus_in_s  : dm_bus_i_t;
  signal dm_io_bus_out_s : dm_bus_o_t;
  signal dm_c_bus_in_s   : dm_bus_i_t;
  signal dm_c_bus_out_s  : dm_bus_o_t;
  
  --
  -- CACHE <-> WB BUSSES
  --

  signal dc_bus_in_s     : dc_bus_i_t;
  signal dc_bus_out_s    : dc_bus_o_t;

begin

  -- //////////////////////////////////////////
  --             COMPONENTS LINK
  -- //////////////////////////////////////////

  DDECODER: entity sb_lib.sb_ddecoder(be_sb_ddecoder)
    generic map
    (
      USE_DCACHE            => USE_DCACHE
    )    
    port map
    (
      dm_bus_i              => dm_bus_i,
      dm_bus_o              => dm_bus_o,
      dm_l_bus_in_o         => dm_l_bus_in_o,
      dm_l_bus_out_i        => dm_l_bus_out_i,
      dm_io_bus_in_o        => dm_io_bus_in_s,
      dm_io_bus_out_i       => dm_io_bus_out_s,
      dm_c_bus_in_o         => dm_c_bus_in_s,
      dm_c_bus_out_i        => dm_c_bus_out_s,
      halt_dc_i             => halt_dc_i,
      halt_io_i             => halt_io_i,
      halt_core_i           => halt_core_i,
      clk_i                 => clk_i    
    );

  DWB_INTERFACE: entity sb_lib.sb_dwb_interface(be_sb_dwb_interface)  
    generic map
    (
      C_S_CLK_DIV           => C_S_CLK_DIV,
      USE_DCACHE            => USE_DCACHE,
      USE_WRITEBACK         => USE_WRITEBACK
    )
    port map
    (
      dwb_bus_i             => dwb_bus_i,
      dwb_bus_o             => dwb_bus_o,
      dwb_grant_i           => dwb_grant_i,
      dm_io_bus_i           => dm_io_bus_in_s,
      dm_io_bus_o           => dm_io_bus_out_s,
      dc_bus_i              => dc_bus_in_s,
      dc_bus_o              => dc_bus_out_s,
      dc_req_done_i         => dc_req_done_s,
      dc_burst_done_i       => dc_burst_done_s,
      io_busy_o             => io_busy_o,
      halt_io_i             => halt_io_i,
      halt_core_i           => halt_core_i,
      clk_i                 => clk_i,
      rst_n_i               => rst_n_i    
    );
        
  GEN_DCACHE: if(USE_DCACHE = true) generate 

    DCACHE: entity sb_lib.sb_dcache(be_sb_dcache)
      generic map
      (
        C_S_CLK_DIV         => C_S_CLK_DIV,
        DC_MEM_TYPE         => DC_MEM_TYPE,
        DC_TAG_TYPE         => DC_TAG_TYPE,
        DC_MEM_FILE_1       => DC_MEM_FILE_1,
        DC_MEM_FILE_2       => DC_MEM_FILE_2,
        DC_MEM_FILE_3       => DC_MEM_FILE_3,
        DC_MEM_FILE_4       => DC_MEM_FILE_4,
        DC_TAG_FILE         => DC_TAG_FILE,
        USE_WRITEBACK       => USE_WRITEBACK
      )
      port map
      (
        dm_c_bus_i          => dm_c_bus_in_s,
        dm_c_bus_o          => dm_c_bus_out_s,
        wdc_i               => wdc_i,
        dc_bus_in_o         => dc_bus_in_s,  
        dc_bus_out_i        => dc_bus_out_s,
        dc_bus_next_grant_i => dwb_next_grant_i,
        dc_busy_o           => dc_busy_o,
        dc_req_done_o       => dc_req_done_s,
        dc_burst_done_o     => dc_burst_done_s,
        halt_dc_i           => halt_dc_i,
        halt_dc_req_i       => halt_dc_req_i,
        clk_i               => clk_i,
        rst_n_i             => rst_n_i  
      );

  end generate GEN_DCACHE;
    
end be_sb_dmemory_unit;



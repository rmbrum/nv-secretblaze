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
--! @file sb_memory_unit_controller.vhd                            					
--! @brief SecretBlaze Memory Unit Controller  				
--! @author Lyonel Barthe
--! @version 1.2b
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.2b 16/01/2011 by Lyonel Barthe / Remi Busseuil
-- Fixed halt_xc_s signals for non-standard cache modes
--
-- Version 1.2 02/09/2011 by Lyonel Barthe
-- WISHBONE stalls are now correctly supported 
-- by only stalling cache output interfaces
-- Added halt_ic_req and halt_dc_req control signals
--
-- Version 1.1 24/02/2011 by Lyonel Barthe
-- Fixed a bug with io / data cache management
-- New coding style with halt_io and halt_dc
--
-- Version 1.0 03/11/2010 by Lyonel Barthe
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

--
--! The whole memory architecture of the processor is managed
--! by a memory sub-system controller. The purpose of the 
--! controller is to distribute proper stall signals whenever
--! the memory latency cannot be hidden, which ensures the
--! synchronization between the datapath and the memories of
--! the processor. Hence, stalls happen, for instance, when
--! a data is not available from a cache memory (cache-miss),
--! or when an I/O operation is not completed. Note that, to
--! provide a simplified design model, the control process is
--! achieved through the use of busy signals specifying the 
--! type of memory operation that cannot be performed within
--! one clock cycle.
--
  
--! SecretBlaze Memory Unit Controller Entity
entity sb_memory_unit_controller is

  generic
    (
      USE_DCACHE    : boolean := USER_USE_DCACHE; --! if true, it will implement the data cache
      USE_ICACHE    : boolean := USER_USE_ICACHE  --! if true, it will implement the instruction cache
    );

  port
    (
      ic_busy_i     : in std_ulogic;              --! instruction cache busy signal 
      dc_busy_i     : in std_ulogic;              --! data cache busy signal 
      io_busy_i     : in std_ulogic;              --! IO busy signal 
      iwb_stall_i   : in std_ulogic;              --! instruction WISHBONE stall signal 
      dwb_stall_i   : in std_ulogic;              --! data WISHBONE stall signal 
      halt_sb_i     : in std_ulogic;              --! halt processor signal 
      halt_ic_o     : out std_ulogic;             --! instruction cache memory unit halt control signal
      halt_ic_req_o : out std_ulogic;             --! instruction cache memory unit halt request process control signal
      halt_dc_o     : out std_ulogic;             --! data cache memory unit halt control signal 
      halt_dc_req_o : out std_ulogic;             --! data cache memory unit halt request process control signal
      halt_io_o     : out std_ulogic;             --! io control unit halt control signal
      halt_core_o   : out std_ulogic              --! halt core signal signal
    );

end sb_memory_unit_controller;

--! SecretBlaze Memory Unit Controller Architecture
architecture be_sb_memory_unit_controller of sb_memory_unit_controller is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal halt_ic_s     : std_ulogic;
  signal halt_ic_req_s : std_ulogic;
  signal halt_dc_s     : std_ulogic;
  signal halt_dc_req_s : std_ulogic;
  signal halt_io_s     : std_ulogic;
  signal halt_core_s   : std_ulogic;

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////
 
  --
  -- ASSIGN OUTPUTS
  --

  halt_ic_o     <= halt_ic_s;
  halt_ic_req_o <= halt_ic_req_s;
  halt_dc_o     <= halt_dc_s;
  halt_dc_req_o <= halt_dc_req_s;
  halt_io_o     <= halt_io_s;
  halt_core_o   <= halt_core_s;
  
  --
  -- STALL CONTROL PROCESS
  -- 
  --! This process generates stall control signals
  --! for each part of the memory sub-system. 
  COMB_MEM_STALL_CONTROL: process(ic_busy_i,
                                  dc_busy_i,
                                  io_busy_i,
                                  iwb_stall_i,
                                  dwb_stall_i,
                                  halt_sb_i)
  
  begin

    --
    -- CORE MANAGEMENT
    --

    -- The core is always stalled:
    --   - when the processor is put in sleep mode, and
    --   - when a data or an instruction is not available
    -- Internal L1 memories are stalled as the core of the processor.
    if(USE_ICACHE = true and USE_DCACHE = true) then
      halt_core_s <= (io_busy_i or dc_busy_i or ic_busy_i or halt_sb_i);

    elsif(USE_ICACHE = true and USE_DCACHE = false) then
      halt_core_s <= (io_busy_i or ic_busy_i or halt_sb_i);

    elsif(USE_ICACHE = false and USE_DCACHE = true) then
      halt_core_s <= (io_busy_i or dc_busy_i or halt_sb_i);

    else
      halt_core_s <= (io_busy_i or halt_sb_i);

    end if;

    --
    -- DATA MEMORY MANAGEMENT
    --
    
    -- The data cache is stalled: 
    --   - when the processor is put in sleep mode,
    --   - when an io operation is not finished,
    --   - when an instruction is not available and 
    --     the data cache entity is not busy
    -- In the last case, the arbiter decides which part 
    -- of the memory unit can continue without being stalled.
    if(USE_ICACHE = true and USE_DCACHE = true) then
      halt_dc_s <= ((ic_busy_i and not(dc_busy_i)) or io_busy_i or halt_sb_i);
      
    elsif(USE_ICACHE = false and USE_DCACHE = true) then
      halt_dc_s <= (io_busy_i or halt_sb_i);

    end if;
    
    -- The data cache request process is stalled 
    -- when the slave device is not ready.
    halt_dc_req_s <= dwb_stall_i;
    
    -- The io unit is stalled: 
    --   - when the processor is put in sleep mode,
    --   - when a data cache operation is not finished,
    --   - when an instruction is not available and 
    --     the io entity is not busy 
    -- In the last case, the arbiter decides which part 
    -- of the memory unit can continue without being stalled.
    if(USE_ICACHE = true and USE_DCACHE = true) then
      halt_io_s <= ((ic_busy_i and not(io_busy_i)) or dc_busy_i or halt_sb_i);

    elsif(USE_ICACHE = true and USE_DCACHE = false) then
      halt_io_s <= ((ic_busy_i and not(io_busy_i)) or halt_sb_i);

    elsif(USE_ICACHE = false and USE_DCACHE = true) then
      halt_io_s <= (dc_busy_i or halt_sb_i);

    else
      halt_io_s <= halt_sb_i;

    end if;

    --
    -- INSTRUCTION MEMORY MANAGEMENT
    --

    -- The instruction cache is stalled: 
    --   - when the processor is put in sleep mode,
    --   - when a data is not available (cache or io) and 
    --     the instruction cache is not busy
    -- In the last case, the arbiter decides which part 
    -- of the memory unit can continue without being stalled.
    if(USE_ICACHE = true and USE_DCACHE = true) then
      halt_ic_s <= (((dc_busy_i or io_busy_i) and not(ic_busy_i)) or halt_sb_i);
      
    elsif(USE_ICACHE = true and USE_DCACHE = false) then
      halt_ic_s <= ((io_busy_i and not(ic_busy_i)) or halt_sb_i);

    end if;
    
    -- The instruction cache request process is stalled 
    -- when the slave device is not ready.
    halt_ic_req_s <= iwb_stall_i;

  end process COMB_MEM_STALL_CONTROL;

end be_sb_memory_unit_controller;


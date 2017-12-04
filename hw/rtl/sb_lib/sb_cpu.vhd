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
--! @file sb_cpu.vhd                                         					
--! @brief SecretBlaze Processor Top Level Entity
--! @author Lyonel Barthe
--! @version 1.68
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.68 08/2012 by Lyonel Barthe
-- Added reference design for Digilent ATLYS board 
-- Added DDR2 wrapper for Xilinx's MIG controller (Spartan-6)
--
-- Version 1.67c 21/06/2012 by Lyonel Barthe
-- Fixed the rsb_type_s control signal for the wdc
-- instruction in the decode stage 
-- Tested with the new mb-gcc version (ISE 14)
-- Up to 1.35 DMIPS/MHz (O2 -fno-inline)
--
-- Version 1.67b 28/03/2012 by Lyonel Barthe / Mohamed Amine Boussadi 
-- Changed names of source operands to prevent confusion 
--
-- Version 1.67 4/02/2012 by Lyonel Barthe
-- Shared local memory implementation
-- Changed coding style of the memory unit
--
-- Version 1.66 16/01/2012 by Lyonel Barthe 
-- One signal was missing in a sensitivity list (data cache)
-- Fixed a bug for non-standard cache modes (memory unit controller)
--
-- Version 1.65 28/10/2011 by Lyonel Barthe
-- More comments
-- Fixed some scripts
--
-- Version 1.64 01/09/2011 by Lyonel Barthe
-- Fixed the halt_sb signal to secure memory operations
-- Changed coding style for IO sync signal
-- Fixed WB stall signals
-- Fixed write-through FSM
-- Fixed the control of SPR
--
-- Version 1.63 22/07/2011 by Lyonel Barthe
-- Stable version successfully tested
-- with the ucosII operating system 
--
-- Version 1.62b 01/06/2011 by Lyonel Barthe
-- Readded the padding constant & changed coding style
-- to fix a bug with a large cacheable memory space
--
-- Version 1.62 31/05/2011 by Lyonel Barthe / Remi Busseuil
-- Removed the padding constant to fix a bug with a large
-- cacheable memory space
--
-- Version 1.61 27/05/2011 by Lyonel Barthe
-- Changed coding style of the memory unit
--
-- Version 1.60 16/05/2011 by Lyonel Barthe
-- Optional BTC with a dynamic branch prediction scheme
-- Changed the implementation of branches
-- Up to 1.29 DMIPS/MHz (O2 -fno-inline)
--
-- Version 1.50 04/05/2011 by Lyonel Barthe
-- Stable version successfully tested
-- with the Open-Scale operating system
--
-- Version 1.43 29/03/2011 by Lyonel Barthe
-- Changed the implementation of the compare unit
-- Fixed a bug with signed numbers
-- Better timing delays 
-- Performance: 97 MHz / 1520 LUTs for the smallest implementation using Spartan 3 (-4) technology
--
-- Version 1.42c 28/03/2011 by Lyonel Barthe
-- Fixed a bug with the CMPU instruction
--
-- Version 1.42b 22/03/2011 by Lyonel Barthe
-- Fixed a bug with the WIC instruction
--
-- Version 1.42 18/03/2011 by Lyonel Barthe
-- Optional pipelined CLZ implementation 
-- Removed partial FW for bs instructions
--
-- Version 1.41c 17/03/2011 by Lyonel Barthe
-- Added the CLZ instruction
--
-- Version 1.41b 10/03/2011 by Lyonel Barthe
-- Changed coding style for MSR 
-- Data registers are no longer initialized during reset
-- Fixed the memory MUX sel 
-- Optional block/distributed ram implementations for memories
--
-- Version 1.41 24/02/2011 by Lyonel Barthe
-- Fixed some bugs (cache management, SPR)
--
-- Version 1.40 22/02/2011 by Lyonel Barthe
-- Optional pipelined mult implementation using 17x17 signed multipliers
-- Optional pipelined bs implementation 
-- Some optimizations (core)
--
-- Version 1.31b 16/02/2011 by Lyonel Barthe
-- Fixed a missed flush signal (memory access stage)
--
-- Version 1.31 15/02/2011 by Lyonel Barthe
-- Removed bypassing method for the RF, now fully synchronous
-- Re-added optional BRAM implementation for Xilinx's FPGAs (although not recommended)
-- Performance: 90 MHz / 1460 LUTs for the smallest implementation using Spartan 3 (-4) technology
--
-- Version 1.30 10/02/2011 by Lyonel Barthe
-- New hazard controller implementation to improve timing performance
-- Removed optional BRAM implementation of the register file (waste BRAMs + bad timings)
-- Performance: 90 MHz / 1560 LUTs for the smallest implementation using Spartan 3 (-4) technology
--
-- Version 1.25 15/01/2011 by Lyonel Barthe
-- Added the support of divide instructions
-- Added some forward trade-offs
-- Added write-through policy for the data cache 
-- Fixed some bugs (IO management) 
--
-- Version 1.10 01/12/2011 by Lyonel Barthe
-- Added the support of pattern and mult instructions
-- Added some hardware optimizations (PC retiming, hardware multiplexing)
-- Fixed some bugs (cache management, stall memory unit)
--
-- Version 1.0 26/10/2010 by Lyonel Barthe
-- Stable version with optional data and instruction cache memories
--
-- Version 0.2 01/06/2010 by Lyonel Barthe
-- Added interrupt support 
-- Added the support of a single cycle barrel shifter 
-- Added a basic memory management unit
-- Fixed some bugs (core)
--
-- Version 0.1 9/04/2010 by Lyonel Barthe
-- Initial Release 
-- Bare core of the processor  
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

library config_lib;
use config_lib.sb_config.all;
use config_lib.soc_config.all;

--
--! This is the top level entity of the SecretBlaze processor.
--! SecretBlaze's key features:
--!  - in-order 32-bit RISC processor
--!  - single issue 5-stage pipelined architecture
--!  - modified harvard architecture 
--!  - most MicroBlaze's integer instructions
--!  - optional external interrupt support 
--!  - optional single cycle or pipelined barrel shifter instructions 
--!  - optional single cycle or pipelined hw multiplications 
--!  - optional multi-cycle divisions (latency 2-34)
--!  - optional pattern instructions 
--!  - optional single cycle or pipelined CLZ instruction 
--!  - optional MSR instructions 
--!  - optional datapath tradeoffs (partial forwarding schemes, etc.)
--!  - 32x32 bit register file 
--!  - static branch prediction (not-taken scheme)
--!  - optional dynamic branch prediction scheme with a branch target cache
--!  - register/data forwarding  
--!  - pipeline interlock for RAW load hazards 
--!  - big endian memory accesses (byte, halfword, word)
--!  - WISHBONE pipelined interfaces (rev B4)
--!  - always data-size aligned memory accesses
--!  - optional instruction and data cache memories (direct-mapped, burst protocol)
--!  - optional write-back policy for the data cache
--!  - a simplified memory management unit handling I/O and cache accesses (blocking scheme)
--      

--! SecretBlaze Processor Top Level Entity
entity sb_cpu is

  generic
    (
      RF_TYPE          : string  := USER_RF_TYPE;          --! register file implementation type 
      USE_BTC          : boolean := USER_USE_BTC;          --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
      BTC_MEM_TYPE     : string  := USER_BTC_MEM_TYPE;     --! BTC memory implementation type
      BTC_MEM_FILE     : string  := USER_BTC_MEM_FILE;     --! BTC memory init file 
      BTC_TAG_FILE     : string  := USER_BTC_TAG_FILE;     --! BTC tag memory init file 
      LM_TYPE          : string  := USER_LM_TYPE;          --! LM implementation type 
      LM_FILE_1        : string  := USER_LM_FILE_1;        --! LM init file LSB
      LM_FILE_2        : string  := USER_LM_FILE_2;        --! LM init file LSB+
      LM_FILE_3        : string  := USER_LM_FILE_3;        --! LM init file MSB-
      LM_FILE_4        : string  := USER_LM_FILE_4;        --! LM init file MSB
      C_S_CLK_DIV      : real    := USER_C_S_CLK_DIV;      --! core/system clock ratio
      USE_PC_RET       : boolean := USER_USE_PC_RET;       --! if true, use program counter with retiming
      USE_DCACHE       : boolean := USER_USE_DCACHE;       --! if true, it will implement the data cache
      DC_MEM_TYPE      : string  := USER_DC_MEM_TYPE;      --! DC memory implementation type 
      DC_TAG_TYPE      : string  := USER_DC_TAG_TYPE;      --! DC tag implementation type 
      DC_MEM_FILE_1    : string  := USER_DC_MEM_FILE_1;    --! DC memory init file LSB
      DC_MEM_FILE_2    : string  := USER_DC_MEM_FILE_2;    --! DC memory init file LSB+
      DC_MEM_FILE_3    : string  := USER_DC_MEM_FILE_3;    --! DC memory init file MSB-
      DC_MEM_FILE_4    : string  := USER_DC_MEM_FILE_4;    --! DC memory init file MSB  
      DC_TAG_FILE      : string  := USER_DC_TAG_FILE;      --! DC tag init file
      USE_WRITEBACK    : boolean := USER_USE_WRITEBACK;    --! if true, use write-back policy
      USE_ICACHE       : boolean := USER_USE_ICACHE;       --! if true, it will implement the instruction cache
      IC_MEM_TYPE      : string  := USER_IC_MEM_TYPE;      --! IC memory implementation type 
      IC_TAG_TYPE      : string  := USER_IC_TAG_TYPE;      --! IC tag implementation type 
      IC_MEM_FILE      : string  := USER_IC_MEM_FILE;      --! IC memory init file
      IC_TAG_FILE      : string  := USER_IC_TAG_FILE;      --! IC tag init file  
      USE_INT          : boolean := USER_USE_INT;          --! if true, it will implement the interrupt mechanism
      USE_SPR          : boolean := USER_USE_SPR;          --! if true, it will implement SPR instructions
      USE_MULT         : natural := USER_USE_MULT;         --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
      USE_PIPE_MULT    : boolean := USER_USE_PIPE_MULT;    --! if true, it will implement a pipelined 32-bit multiplier using 17x17 signed multipliers
      USE_BS           : natural := USER_USE_BS;           --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
      USE_PIPE_BS      : boolean := USER_USE_PIPE_BS;      --! it true, it will implement a pipelined barrel shifter
      USE_DIV          : boolean := USER_USE_DIV;          --! if true, it will implement divide instructions
      USE_PAT          : boolean := USER_USE_PAT;          --! if true, it will implement pattern instructions
      USE_CLZ          : boolean := USER_USE_CLZ;          --! if true, it will implement the count leading zeros instruction
      USE_PIPE_CLZ     : boolean := USER_USE_PIPE_CLZ;     --! it true, it will implement a pipelined clz instruction
      STRICT_HAZ       : boolean := USER_STRICT_HAZ;       --! if true, it will implement a strict hazard controller which checks the type of the instruction
      FW_IN_MULT       : boolean := USER_FW_IN_MULT;       --! if true, it will implement the data forwarding for the inputs of the MULT unit
      FW_LD            : boolean := USER_FW_LD             --! if true, it will implement the full data forwarding for LOAD instructions
    );
  port
    (
      iwb_bus_i        : in wb_master_bus_i_t;             --! instruction WISHBONE master bus inputs
      iwb_bus_o        : out wb_master_bus_o_t;            --! instruction WISHBONE master bus outputs
      iwb_grant_i      : in std_ulogic;                    --! instruction WISHBONE grant signal input
      iwb_next_grant_i : in std_ulogic;                    --! instruction WISHBONE next grant signal input
      dwb_bus_i        : in wb_master_bus_i_t;             --! data WISHBONE master bus inputs
      dwb_bus_o        : out wb_master_bus_o_t;            --! data WISHBONE master bus outputs
      dwb_grant_i      : in std_ulogic;                    --! data WISHBONE grant signal input
      dwb_next_grant_i : in std_ulogic;                    --! data WISHBONE next grant signal input
      int_i            : in int_status_t;                  --! external interrupt signal      
      halt_sb_i        : in std_ulogic;                    --! halt processor signal
      clk_i            : in std_ulogic;                    --! core clock
      rst_n_i          : in std_ulogic                     --! active-low reset signal 
    );

end sb_cpu;

--! SecretBlaze Processor Top Level Architecture
architecture be_sb_cpu of sb_cpu is

  -- //////////////////////////////////////////
  --                INTERNAL REG
  -- //////////////////////////////////////////
  
  signal halt_sb_r     : std_ulogic; --! halt processor reg

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- CONTROL SIGNALS
  --

  signal halt_core_s  : std_ulogic;
  signal mem_busy_s   : std_ulogic;
 
  --
  -- L1 BUSSES
  --

  signal im_bus_in_s  : im_bus_i_t;
  signal im_bus_out_s : im_bus_o_t;
  signal dm_bus_in_s  : dm_bus_i_t;
  signal dm_bus_out_s : dm_bus_o_t;
  signal wdc_s        : wdc_control_t;
  signal wic_s        : wic_control_t;

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  CORE: entity sb_lib.sb_core(be_sb_core)
    generic map
    (
      RF_TYPE            => RF_TYPE,
      USE_BTC            => USE_BTC,
      BTC_MEM_FILE       => BTC_MEM_FILE,
      BTC_TAG_FILE       => BTC_TAG_FILE,
      BTC_MEM_TYPE       => BTC_MEM_TYPE,
      USE_PC_RET         => USE_PC_RET,
      USE_DCACHE         => USE_DCACHE,
      USE_WRITEBACK      => USE_WRITEBACK,
      USE_ICACHE         => USE_ICACHE,
      USE_INT            => USE_INT,
      USE_SPR            => USE_SPR,
      USE_MULT           => USE_MULT,
      USE_PIPE_MULT      => USE_PIPE_MULT,
      USE_BS             => USE_BS,
      USE_PIPE_BS        => USE_PIPE_BS,
      USE_DIV            => USE_DIV,
      USE_PAT            => USE_PAT,
      USE_CLZ            => USE_CLZ,
      USE_PIPE_CLZ       => USE_PIPE_CLZ,
      STRICT_HAZ         => STRICT_HAZ,
      FW_IN_MULT         => FW_IN_MULT,
      FW_LD              => FW_LD
    )
    port map
    (
      im_bus_out_i       => im_bus_out_s,
      im_bus_in_o        => im_bus_in_s,
      dm_bus_out_i       => dm_bus_out_s,
      dm_bus_in_o        => dm_bus_in_s,
      wdc_in_o           => wdc_s,
      wic_in_o           => wic_s,
      int_i              => int_i,
      halt_core_i        => halt_core_s,
      clk_i              => clk_i,
      rst_n_i            => rst_n_i
    );
	  
  MEMORY_UNIT: entity sb_lib.sb_memory_unit(be_sb_memory_unit)
    generic map
    (
      LM_TYPE            => LM_TYPE,
      LM_FILE_1          => LM_FILE_1,
      LM_FILE_2          => LM_FILE_2,
      LM_FILE_3          => LM_FILE_3,
      LM_FILE_4          => LM_FILE_4,
      C_S_CLK_DIV        => C_S_CLK_DIV,
      USE_DCACHE         => USE_DCACHE,
      DC_MEM_TYPE        => DC_MEM_TYPE,
      DC_TAG_TYPE        => DC_TAG_TYPE,
      DC_MEM_FILE_1      => DC_MEM_FILE_1,
      DC_MEM_FILE_2      => DC_MEM_FILE_2,
      DC_MEM_FILE_3      => DC_MEM_FILE_3,
      DC_MEM_FILE_4      => DC_MEM_FILE_4,
      DC_TAG_FILE        => DC_TAG_FILE,
      USE_WRITEBACK      => USE_WRITEBACK,
      USE_ICACHE         => USE_ICACHE,
      IC_MEM_TYPE        => IC_MEM_TYPE,
      IC_TAG_TYPE        => IC_TAG_TYPE,
      IC_MEM_FILE        => IC_MEM_FILE,
      IC_TAG_FILE        => IC_TAG_FILE
    )
    port map
    (
      iwb_bus_i          => iwb_bus_i,
      iwb_bus_o          => iwb_bus_o,
      iwb_grant_i        => iwb_grant_i,
      iwb_next_grant_i   => iwb_next_grant_i,
      dwb_bus_i          => dwb_bus_i,
      dwb_bus_o          => dwb_bus_o,
      dwb_grant_i        => dwb_grant_i,
      dwb_next_grant_i   => dwb_next_grant_i,
      im_bus_i           => im_bus_in_s,
      im_bus_o           => im_bus_out_s,
      dm_bus_i           => dm_bus_in_s,
      dm_bus_o           => dm_bus_out_s,
      wdc_i              => wdc_s,
      wic_i              => wic_s,
      mem_busy_o         => mem_busy_s,
      halt_core_o        => halt_core_s,
      halt_sb_i          => halt_sb_r,
      clk_i              => clk_i,
      rst_n_i            => rst_n_i
    );
  
  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- HALT PROCESSOR REGISTERED INPUT
  --
  --! This process implements the halt register, which generates
  --! the halt_sb_i signal to put the processor into the sleep 
  --! mode. Note that it cannot be active during a memory operation 
  --! to avoid losing data when updating caches and the io buffer. 
  CYCLE_HALT_IN_REG: process(clk_i) 
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
      
      -- sync reset
      if(rst_n_i = '0') then
        halt_sb_r <= '0';
      
        -- cannot be active during a memory operation 
      elsif(mem_busy_s = '0') then
        halt_sb_r <= halt_sb_i;

      end if;
      
    end if;

  end process CYCLE_HALT_IN_REG; 

end architecture be_sb_cpu;


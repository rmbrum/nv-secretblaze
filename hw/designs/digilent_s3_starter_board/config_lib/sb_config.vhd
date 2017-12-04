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
--! @file sb_config.vhd                                					
--! @brief SecretBlaze Configuration Package   				
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

library ieee;
use ieee.std_logic_1164.all;

--
--! Configuration file of the SecretBlaze processor.
--
--! SecretBlaze Configuration Package
package sb_config is

  -- //////////////////////////////////////////
  --            SECRETBLAZE SETTINGS
  -- //////////////////////////////////////////

  -- Note that "distributed" and "block" keywords are used for Xilinx's FPGAs

  --
  -- CORE SETTINGS
  --

  constant USER_RF_TYPE             : string  := "distributed";      --! register file implementation type 
--  constant USER_RF_TYPE             : string  := "block";            --! register file implementation type 
  constant USER_USE_BTC             : boolean := true;               --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
  constant USER_BTC_S               : natural := 512;                --! BTC size (> 4096 is useless)
--  constant USER_BTC_MEM_TYPE        : string  := "distributed";      --! BTC memory implementation type
  constant USER_BTC_MEM_TYPE        : string  := "block";            --! BTC memory implementation type
  constant USER_USE_INT             : boolean := true;               --! if true, it will implement the interrupt mechanism
  constant USER_USE_SPR             : boolean := true;               --! if true, it will implement SPR instructions
  constant USER_USE_MULT            : natural := 2;                  --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
  constant USER_USE_PIPE_MULT       : boolean := true;               --! if true, it will implement a pipelined 32-bit multiplier using 17x17 signed multipliers
  constant USER_USE_BS              : natural := 1;                  --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt (2 is not suited for FPGA devices)
  constant USER_USE_PIPE_BS         : boolean := true;               --! it true, it will implement a pipelined barrel shifter
  constant USER_USE_DIV             : boolean := true;               --! if true, it will implement divide instructions
  constant USER_USE_PAT             : boolean := true;               --! if true, it will implement pattern instructions 
  constant USER_USE_CLZ             : boolean := true;               --! if true, it will implement the count leading zeros instruction 
  constant USER_USE_PIPE_CLZ        : boolean := true;               --! it true, it will implement a pipelined CLZ unit

  --
  -- DATAPATH TRADEOFFS 
  --

  constant USER_STRICT_HAZ          : boolean := true;               --! if true, it will implement a strict hazard controller which checks the type of the instruction (better CPI, but can lead to lower fMAX)
  constant USER_FW_IN_MULT          : boolean := true;               --! if true, it will implement the data forwarding for the inputs of the MULT unit (better CPI, but can lead to lower fMAX)
  constant USER_FW_LD               : boolean := false;              --! if true, it will implement the full data forwarding for LOAD instructions (better CPI, but can lead to lower fMAX)

  --
  -- MEMORY SUB-SYSTEM SETTINGS
  --

  constant USER_PC_W                : natural := 32;                 --! program counter width (default is max)
  constant USER_USE_PC_RET          : boolean := true;               --! if true, use program counter with retiming
  constant USER_PC_LOW_W            : natural := 20;                 --! program counter low address width (retiming mode)

  constant USER_LM_BYTE_S           : natural := 16384;              --! local memory byte size (default is 16 KB)
  constant USER_LM_TYPE             : string  := "block";            --! local memory implementation type 
--  constant USER_LM_TYPE             : string  := "distributed";      --! local memory implementation type 

  constant USER_USE_ICACHE          : boolean := true;               --! if true, it will implement the instruction cache 
  constant USER_IC_BYTE_S           : natural := 8192;               --! IC byte cache size (default is 8 KB)
  constant USER_IC_LINE_WORD_S      : natural := 8;                  --! IC nb of words per line
  constant USER_IC_CACHEABLE_MEM_S  : natural := 1048576;            --! IC cacheable memory size (default is 1 MB)
  constant USER_IC_MEM_TYPE         : string  := "block";            --! IC memory implementation type 
  constant USER_IC_TAG_TYPE         : string  := "block";            --! IC tag implementation type 
--  constant USER_IC_MEM_TYPE         : string  := "distributed";     --! IC memory implementation type 
--  constant USER_IC_TAG_TYPE         : string  := "distributed";     --! IC tag implementation type 

  constant USER_USE_DCACHE          : boolean := true;               --! if true, it will implement the data cache 
  constant USER_USE_WRITEBACK       : boolean := true;               --! if true, use write-back cache line policy 
  constant USER_DC_BYTE_S           : natural := 8192;               --! DC byte cache size (default is 8 KB)
  constant USER_DC_LINE_WORD_S      : natural := 8;                  --! DC nb of words per line
  constant USER_DC_CACHEABLE_MEM_S  : natural := 1048576;            --! DC cacheable memory size (default is 1 MB)
  constant USER_DC_MEM_TYPE         : string  := "block";            --! DC memory implementation type 
  constant USER_DC_TAG_TYPE         : string  := "block";            --! DC tag implementation type 
--  constant USER_DC_MEM_TYPE         : string  := "distributed";     --! DC memory implementation type 
--  constant USER_DC_TAG_TYPE         : string  := "distributed";     --! DC tag implementation type 

  --   
  --   Default Memory Map
  --
  --    ------------------------------- 
  --   | 0x00000000 |                  |                 
  --   |            |    Local RAM     |                 
  --   | 0x00003FFF |                  |                 
  --    -------------------------------   
  --   | 0x00004000 |                  |                 
  --   |            |     Not used     |                 
  --   | 0x0FFFFFFF |                  |                 
  --    ------------------------------- 
  --   | 0x10000000 |                  |                 
  --   |            |  Cacheable RAM   |                 
  --   | 0x100FFFFF |                  |                 
  --    -------------------------------   
  --   | 0x10100000 |                  |                 
  --   |            |     Not used     |                 
  --   | 0x1FFFFFFF |                  |                 
  --    ------------------------------- 
  --   | 0x20000000 |                  |    
  --   |            |    IO mapping    |    
  --   | 0xFFFFFFFF |                  |         
  --    ------------------------------- 
  --
  
  constant USER_SB_BOOT_ADR         : std_ulogic_vector(USER_PC_W - 1 downto 0) := X"0000_0000"; --! default reset boot vector
  constant USER_SB_INT_ADR_WO_CACHE : std_ulogic_vector(31 downto 0) := X"0000_0010"; --! default interrupt vector without instruction cache
  constant USER_SB_INT_ADR_W_CACHE  : std_ulogic_vector(31 downto 0) := X"1000_0010"; --! default interrupt vector with instruction cache 

  constant USER_SB_ADDRESS_DEC_W    : natural := 4;                                   --! set the width of the SecretBlaze address decoder (starting from MSB)
  constant USER_DC_CMEM_BASE_ADR    : std_ulogic_vector(31 downto 0) := X"1000_0000"; --! DC cacheable memory base address
  constant USER_IC_CMEM_BASE_ADR    : std_ulogic_vector(31 downto 0) := X"1000_0000"; --! IC cacheable memory base address
  constant USER_IO_MAP_BASE_ADR     : std_ulogic_vector(31 downto 0) := X"2000_0000"; --! IO mapping base address 
  
  --
  -- INIT FILES
  --

  constant USER_FILE_PATH           : string := "../designs/digilent_s3_starter_board/config_lib/ram_init_files/"; --! filepath
  constant USER_BTC_MEM_FILE        : string := USER_FILE_PATH & "null_mem.data";   --! BTC memory init file
  constant USER_BTC_TAG_FILE        : string := USER_FILE_PATH & "btc_mem.data";    --! BTC tag memory init file
  constant USER_LM_FILE_1           : string := USER_FILE_PATH & "local_mem1.data"; --! local memory init file LSB
  constant USER_LM_FILE_2           : string := USER_FILE_PATH & "local_mem2.data"; --! local memory init file LSB+
  constant USER_LM_FILE_3           : string := USER_FILE_PATH & "local_mem3.data"; --! local memory init file MSB-
  constant USER_LM_FILE_4           : string := USER_FILE_PATH & "local_mem4.data"; --! local memory init file MSB  
  constant USER_DC_MEM_FILE_1       : string := USER_FILE_PATH & "null_mem.data";   --! DC memory init file LSB
  constant USER_DC_MEM_FILE_2       : string := USER_FILE_PATH & "null_mem.data";   --! DC memory init file LSB+
  constant USER_DC_MEM_FILE_3       : string := USER_FILE_PATH & "null_mem.data";   --! DC memory init file MSB-
  constant USER_DC_MEM_FILE_4       : string := USER_FILE_PATH & "null_mem.data";   --! DC memory init file MSB  
  constant USER_DC_TAG_FILE         : string := USER_FILE_PATH & "null_mem.data";   --! DC tag init file
  constant USER_IC_MEM_FILE         : string := USER_FILE_PATH & "null_mem.data";   --! IC memory init file
  constant USER_IC_TAG_FILE         : string := USER_FILE_PATH & "null_mem.data";   --! IC tag init file  

end sb_config;


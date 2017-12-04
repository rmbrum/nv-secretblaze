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
--! @file sb_memory_unit_pack.vhd                                					
--! @brief Memory Unit Package    				
--! @author Lyonel Barthe
--! @version 1.1b
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1b 01/06/2011 by Lyonel Barthe
-- Readded the padding constants 
--
-- Version 1.1 31/05/2011 by Lyonel Barthe / Remi Busseuil
-- Removed cache padding constants
--
-- Version 1.0 29/04/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.sb_config.all;

--
--! The package implements SecretBlaze's memory unit settings and defines.
--! Although memory settings could be easily customized (cache byte size, 
--! cache line size, memory mapping etc.), it is highly recommend to use 
--! the original configuration. If you do so, don't forget to update linker 
--! files as well as low-level drivers.
--

--! SecretBlaze Memory Unit Package
package sb_memory_unit_pack is
    
  --   
  --   SecretBlaze's Default Memory Map
  --
  --    ------------------------------- -----------------
  --   | 0x00000000 |                  |                 |
  --   |            |    Local RAM     |                 |
  --   | 0x00003FFF |                  |                 |
  --    -------------------------------    Internal RAM  |
  --   | 0x00004000 |                  |                 |
  --   |            |     Not used     |                 |
  --   | 0x0FFFFFFF |                  |                 |
  --    ------------------------------- -----------------
  --   | 0x10000000 |                  |                 |
  --   |            |  Cacheable RAM   |                 |
  --   | 0x100FFFFF |                  |                 |
  --    -------------------------------    External RAM  |
  --   | 0x10100000 |                  |                 |
  --   |            |     Not used     |                 |
  --   | 0x1FFFFFFF |                  |                 |
  --    ------------------------------- -----------------
  --   | 0x20000000 |                  |                 |
  --   |            |    IO mapping    |       IO        |
  --   | 0xFFFFFFFF |                  |                 |
  --    ------------------------------- -----------------
  --

  -- //////////////////////////////////////////
  --            GENERAL MEMORY SETTINGS
  -- //////////////////////////////////////////

  --
  -- By default, the processor uses a partial address decoder 
  -- for embedded requirements!!!
  -- 

  constant SB_ADDRESS_DEC_W : natural      := USER_SB_ADDRESS_DEC_W;  --! set the width of the SecretBlaze's address decoder (starting from MSB)
  constant DC_CMEM_BASE_ADR : dm_bus_adr_t := USER_DC_CMEM_BASE_ADR;  --! DC cacheable memory base address
  constant IC_CMEM_BASE_ADR : im_bus_adr_t := USER_IC_CMEM_BASE_ADR;  --! IC cacheable memory base address
  constant IO_MAP_BASE_ADR  : dm_bus_adr_t := USER_IO_MAP_BASE_ADR;   --! IO mapping base address 

  type dm_mux_sel_t is (DM_IO,DM_DC,DM_LM);                           --! data memory mux sel type
  type im_mux_sel_t is (IM_IC,IM_LM);                                 --! instruction memory mux sel type
  
  -- //////////////////////////////////////////
  --            LOCAL MEMORY SETTINGS
  -- //////////////////////////////////////////
  
  --
  -- LOCAL MEMORY DEFINES
  --

  constant LM_BYTE_S : natural := USER_LM_BYTE_S;   --! local memory byte size 
  constant LM_BYTE_W : natural := log2(LM_BYTE_S);  --! local memory physical address width 
  constant LM_WORD_S : natural := USER_LM_BYTE_S/4; --! local memory word size
  constant LM_WORD_W : natural := log2(LM_WORD_S);  --! local memory physical word address width 

  -- //////////////////////////////////////////
  --              DATA CACHE SETTINGS
  -- //////////////////////////////////////////

  --
  -- CACHE FORMAT
  --            
  -- ADR
  -- +-----------------------------------------------------------+         
  -- |       Unused      |   Tag   |   Index   |   Line offset   |
  -- +-----------------------------------------------------------+
  --
  -- DATA RAM
  -- +-----------------------------------------------------------+         
  -- |    Word 0   |               ...             |   Word N-1  |
  -- +-----------------------------------------------------------+
  --
  -- TAG RAM
  -- +-----------------------------------------------------------+         
  -- | Dirty Bit | Valid Bit |               Tag                 |
  -- +-----------------------------------------------------------+
  -- Note: dirty bit for write-back policy only
  -- 
  
  --
  -- DC DEFINES
  --

  constant DC_BYTE_S          : natural := USER_DC_BYTE_S;                            --! DC byte cache size (default is 8 KB)
  constant DC_BYTE_W          : natural := log2(DC_BYTE_S);                           --! DC physical address width 
  constant DC_WORD_S          : natural := DC_BYTE_S/4;                               --! DC word cache size
  constant DC_WORD_W          : natural := log2(DC_WORD_S);                           --! DC physical word address width
  constant DC_CACHEABLE_MEM_S : natural := USER_DC_CACHEABLE_MEM_S;                   --! DC cacheable memory size (default is 1 MB)
  constant DC_CACHEABLE_MEM_W : natural := 
    eval_cache_mem_w(DC_CACHEABLE_MEM_S,to_integer(unsigned(USER_DC_CMEM_BASE_ADR))); --! DC cacheable memory width
  constant DC_LINE_WORD_S     : natural := USER_DC_LINE_WORD_S;                       --! DC nb of words per line
  constant DC_LINE_BYTE_S     : natural := DC_LINE_WORD_S*4;                          --! DC nb of bytes per line
  constant DC_LINE_WORD_W     : natural := log2(DC_LINE_WORD_S);                      --! DC line word width  
  constant DC_LINE_BYTE_W     : natural := log2(DC_LINE_BYTE_S);                      --! DC line byte width
  constant DC_TOTAL_LINES_S   : natural := DC_BYTE_S/DC_LINE_BYTE_S;                  --! DC nb of cache lines
  constant DC_TOTAL_LINES_W   : natural := log2(DC_TOTAL_LINES_S);                    --! DC cache line width
  constant DC_TAG_W           : natural := DC_CACHEABLE_MEM_W - DC_BYTE_W;            --! DC cache tag width
  constant DC_FLAG_W          : natural := 1 + bool_to_nat(USER_USE_WRITEBACK);       --! DC tag flag width (valid only for write-through / valid & dirty for write-back)
  constant DC_TAG_RAM_W       : natural := DC_TAG_W + DC_FLAG_W;                      --! DC tag ram width
  constant DC_VALID_BIT_OFF   : natural := DC_TAG_W;                                  --! DC valid bit offset
  constant DC_DIRTY_BIT_OFF   : natural := DC_TAG_W + 1;                              --! DC dirty bit offset
  constant DC_BUS_ADR_PADDING : std_ulogic_vector(L1_DM_DATA_BUS_W - 1 downto DC_CACHEABLE_MEM_W) --! DC bus address padding
    := DC_CMEM_BASE_ADR(L1_DM_DATA_BUS_W - 1 downto DC_CACHEABLE_MEM_W);      
  
  --
  -- DC DATA TYPES/SUBTYPES
  --

  subtype dc_bus_adr_t      is dm_bus_adr_t;                                      --! DC address bus type
  subtype dc_bus_data_t     is dm_bus_data_t;                                     --! DC data bus type
  subtype dc_bus_sel_t      is dm_bus_sel_t;                                      --! DC sel bus type
  subtype dc_word_adr_t     is std_ulogic_vector(DC_WORD_W - 1 downto 0);         --! DC physical word address type
  subtype dc_counter_t      is std_ulogic_vector(DC_LINE_WORD_W - 1 downto 0);    --! DC word line counter type
  subtype dc_index_adr_t    is std_ulogic_vector(DC_TOTAL_LINES_W - 1 downto 0);  --! DC line physical address type  
  subtype dc_tag_t          is std_ulogic_vector(DC_TAG_W - 1 downto 0);          --! DC tag type
  subtype dc_tag_ram_data_t is std_ulogic_vector(DC_TAG_RAM_W - 1 downto 0);      --! DC tag data type

  subtype dc_tag_status_t is std_ulogic;                                          --! DC tag status type
  constant DC_HIT     : dc_tag_status_t := '1'; 
  constant DC_MISS    : dc_tag_status_t := '0'; 

  subtype dc_tag_valid_t is std_ulogic;                                           --! DC tag valid type
  constant DC_VALID   : dc_tag_valid_t := '1';
  constant DC_N_VALID : dc_tag_valid_t := '0';

  subtype dc_tag_dirty_t is std_ulogic;                                           --! DC tag dirty type       
  constant DC_DIRTY   : dc_tag_dirty_t := '1';
  constant DC_N_DIRTY : dc_tag_dirty_t := '0';

  --
  -- DC CONTROL/STATUS TYPES/SUBTYPES
  --
  
  type dc_fsm_t is (DC_IDLE,DC_READ,DC_WRITE,DC_FETCH,DC_COPY,DC_END_FETCH,DC_FLUSH,DC_INVALID); --! DC fsm type

  --
  -- DC STRUCTURES
  --

  type dc_bus_i_t is record
    ena_i : std_ulogic;
    we_i  : std_ulogic;
    adr_i : dc_bus_adr_t;
    dat_i : dc_bus_data_t;
    sel_i : dc_bus_sel_t; -- write-through policy only
  end record;

  type dc_bus_o_t is record
    dat_o : dc_bus_data_t;
    ack_o : std_ulogic;
  end record;

  -- //////////////////////////////////////////
  --         INSTRUCTION CACHE SETTINGS
  -- //////////////////////////////////////////
  
  --
  -- CACHE FORMAT
  --            
  -- ADR
  -- +-----------------------------------------------------------+         
  -- |       Unused      |   Tag   |   Index   |   Line offset   |
  -- +-----------------------------------------------------------+
  --
  -- DATA RAM
  -- +-----------------------------------------------------------+         
  -- |    Word 0   |               ...             |   Word N-1  |
  -- +-----------------------------------------------------------+
  --
  -- TAG RAM
  -- +-----------------------------------------------------------+         
  -- | Valid Bit |                      Tag                      |
  -- +-----------------------------------------------------------+
  --
  
  --
  -- IC DEFINES
  --

  constant IC_BYTE_S              : natural := USER_IC_BYTE_S;                        --! IC byte cache size (default is 8 KB)
  constant IC_BYTE_W              : natural := log2(IC_BYTE_S);                       --! IC physical address width 
  constant IC_WORD_S              : natural := IC_BYTE_S/4;                           --! IC word cache size
  constant IC_WORD_W              : natural := log2(IC_WORD_S);                       --! IC physical word address width
  constant IC_CACHEABLE_MEM_S     : natural := USER_IC_CACHEABLE_MEM_S;               --! IC cacheable memory size (default is 1 MB)
  constant IC_CACHEABLE_MEM_W     : natural := 
    eval_cache_mem_w(IC_CACHEABLE_MEM_S,to_integer(unsigned(USER_IC_CMEM_BASE_ADR))); --! IC cacheable memory width
  constant IC_LINE_WORD_S         : natural := USER_IC_LINE_WORD_S;                   --! IC nb of words per line
  constant IC_LINE_BYTE_S         : natural := IC_LINE_WORD_S*4;                      --! IC nb of bytes per line
  constant IC_LINE_WORD_W         : natural := log2(IC_LINE_WORD_S);                  --! IC line word width  
  constant IC_LINE_BYTE_W         : natural := log2(IC_LINE_BYTE_S);                  --! IC line byte width
  constant IC_TOTAL_LINES_S       : natural := IC_BYTE_S/IC_LINE_BYTE_S;              --! IC nb of cache lines (index)
  constant IC_TOTAL_LINES_W       : natural := log2(IC_TOTAL_LINES_S);                --! IC cache index width
  constant IC_TAG_W               : natural := IC_CACHEABLE_MEM_W - IC_BYTE_W;        --! IC cache tag width
  constant IC_FLAG_W              : natural := 1;                                     --! IC tag flag width (valid bit only)
  constant IC_TAG_RAM_W           : natural := IC_TAG_W + IC_FLAG_W;                  --! IC tag ram width
  constant IC_VALID_BIT_OFF       : natural := IC_TAG_W;                              --! IC valid bit offset  
  constant IC_BUS_ADR_PADDING     : std_ulogic_vector(L1_IM_DATA_BUS_W - 1 downto IC_CACHEABLE_MEM_W) --! IC bus address padding
    := IC_CMEM_BASE_ADR(L1_IM_DATA_BUS_W - 1 downto IC_CACHEABLE_MEM_W);
      
  --
  -- IC DATA TYPES/SUBTYPES
  --

  subtype ic_bus_adr_t      is im_bus_adr_t;                                          --! IC address bus type
  subtype ic_bus_data_t     is im_bus_data_t;                                         --! IC data bus type
  subtype ic_word_adr_t     is std_ulogic_vector(IC_WORD_W - 1 downto 0);             --! IC physical word address type
  subtype ic_counter_t      is std_ulogic_vector(IC_LINE_WORD_W - 1 downto 0);        --! IC word line counter type
  subtype ic_index_adr_t    is std_ulogic_vector(IC_TOTAL_LINES_W - 1 downto 0);      --! IC line address type 
  subtype ic_tag_t          is std_ulogic_vector(IC_TAG_W - 1 downto 0);              --! IC tag type
  subtype ic_tag_ram_data_t is std_ulogic_vector(IC_TAG_RAM_W - 1 downto 0);          --! IC tag data type

  subtype ic_tag_status_t is std_ulogic;                                              --! IC tag status type
  constant IC_HIT     : ic_tag_status_t := '1';
  constant IC_MISS    : ic_tag_status_t := '0'; 

  subtype ic_tag_valid_t is std_ulogic;                                               --! IC tag valid type
  constant IC_VALID   : ic_tag_valid_t := '1';
  constant IC_N_VALID : ic_tag_valid_t := '0';

  --
  -- IC CONTROL/STATUS TYPES/SUBTYPES
  --
  
  type ic_fsm_t is (IC_IDLE,IC_READ,IC_FETCH,IC_END_FETCH,IC_INVALID,IC_END_INVALID); --! IC fsm type
 
  --
  -- IC STRUCTURES
  --

  type ic_bus_i_t is record
    ena_i : std_ulogic;
    adr_i : ic_bus_adr_t;
  end record;

  type ic_bus_o_t is record
    dat_o : ic_bus_data_t;
    ack_o : std_ulogic;
  end record;
  
end package sb_memory_unit_pack;


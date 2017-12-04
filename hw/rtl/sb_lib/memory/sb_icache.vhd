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
--! @file sb_icache.vhd                                					
--! @brief Direct-Mapped Instruction Cache Implementation   				
--! @author Lyonel Barthe
--! @version 1.4
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.4 02/09/2011 by Lyonel Barthe
-- The cache request process can be independently
-- halted to support WISHBONE stall control signals 
--
-- Version 1.3b 01/06/2011 by Lyonel Barthe
-- Readded the padding constant & changed coding style
-- to fix a bug with a large cacheable memory space
--
-- Version 1.3 31/05/2011 by Lyonel Barthe / Remi Busseuil
-- Removed the padding constant to fix a bug with a large
-- cacheable memory space
--
-- Version 1.2b 22/03/2010 by Lyonel Barthe
-- Fixed a bug with the WIC instruction
--
-- Version 1.2 23/12/2010 by Lyonel Barthe
-- Separate control signals implementation
--
-- Version 1.1b 7/10/2010 by Lyonel Barthe
-- Added the wic instruction
--
-- Version 1.1a 20/09/2010 by Lyonel Barthe
-- Changed coding style with stall signals
-- Added counters for the synchronization with sclk
-- Added reset signals for such new counters
--
-- Version 1.0 1/07/2010 by Lyonel Barthe
-- Major Clean-Up
-- Dual-port RAMs implementation
--
-- Version 0.1 29/04/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_memory_unit_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.sb_config.all;
use config_lib.soc_config.all;

--
--! For improved performance, the SecretBlaze has an optional instruction cache memory
--! that hold copies of the most frequently used instructions. The proposed implementation 
--! is a direct-mapped cache with one-cycle hit latency. The size of the physical memory, 
--! the size of the cacheable memory as well as the size of a cache block are configurable 
--! through VHDL generic statements. Like local on-chip memories, the cache is implemented 
--! with dual-port synchronous RAMs to allow simultaneous read/write operations.
--!
--! Each cache entry consists of a tag field, an instruction field, and a valid bit.
--

--! SecretBlaze Instruction Cache Entity
entity sb_icache is

  generic
    (
      C_S_CLK_DIV         : real    := USER_C_S_CLK_DIV; --! core/system clock ratio
      IC_MEM_TYPE         : string  := USER_IC_MEM_TYPE; --! IC memory implementation type  
      IC_TAG_TYPE         : string  := USER_IC_TAG_TYPE; --! IC tag implementation type  
      IC_MEM_FILE         : string  := USER_IC_MEM_FILE; --! IC memory init file
      IC_TAG_FILE         : string  := USER_IC_TAG_FILE  --! IC tag init file  
    ); 
  
  port
    (
      im_c_bus_i          : in im_bus_i_t;               --! instruction L1 bus inputs (cache side)
      im_c_bus_o          : out im_bus_o_t;              --! instruction L1 bus outputs (cache side)
      wic_i               : in wic_control_t;            --! wic control input
      wic_adr_i           : in im_bus_adr_t;             --! wic address input
      ic_bus_in_o         : out ic_bus_i_t;              --! external instruction cache bus inputs 
      ic_bus_out_i        : in ic_bus_o_t;               --! external instruction cache bus outputs 
      ic_bus_next_grant_i : in std_ulogic;               --! instruction cache bus next grant signal
      ic_busy_o           : out std_ulogic;              --! instruction cache busy signal 
      ic_req_done_o       : out std_ulogic;              --! instruction cache request done flag
      ic_burst_done_o     : out std_ulogic;              --! instruction cache burst done flag                  
      halt_ic_i           : in std_ulogic;               --! instruction cache stall control signal
      halt_ic_req_i       : in std_ulogic;               --! instruction cache stall request process control signal
      clk_i               : in std_ulogic;               --! core clock
      rst_n_i             : in std_ulogic                --! active-low reset signal
    );
  
end sb_icache;

--! SecretBlaze Instruction Cache Architecture
architecture be_sb_icache of sb_icache is

  -- //////////////////////////////////////////
  --              INTERNAL REGS
  -- //////////////////////////////////////////

  signal ic_ena_r                    : std_ulogic;                                                 --! IC ena reg
  signal ic_current_state_r          : ic_fsm_t;                                                   --! IC fsm reg
  signal ic_tag_r                    : ic_tag_t;                                                   --! IC tag reg
  signal ic_block_counter_r          : ic_counter_t;                                               --! IC word per line counter reg
  signal ic_ack_counter_r            : ic_counter_t;                                               --! IC ack counter reg
  signal ic_req_done_r               : std_ulogic;                                                 --! IC request done flag reg
  signal ic_word_adr_r               : ic_word_adr_t;                                              --! IC word address reg
  signal ic_wic_index_adr_r          : ic_index_adr_t;                                             --! IC wic index address reg
  signal ic_sync_block_r             : std_ulogic_vector(log2(natural(C_S_CLK_DIV)) - 1 downto 0); --! IC sync block counter
  signal ic_sync_ack_r               : std_ulogic_vector(log2(natural(C_S_CLK_DIV)) - 1 downto 0); --! IC sync ack counter
    
  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- CACHE CONTROL SIGNALS
  --
  
  signal ic_busy_s                   : std_ulogic;
  signal ic_tag_status_s             : ic_tag_status_t;
  signal ic_valid_flag_s             : ic_tag_valid_t;
  signal ic_next_state_s             : ic_fsm_t;
  signal ic_req_done_s               : std_ulogic;
  signal ic_line_req_done_s          : std_ulogic;
  signal ic_burst_done_s             : std_ulogic;
  signal ic_bus_sync_block_s         : std_ulogic; -- indicate a valid block on the bus (request process)
  signal ic_bus_sync_ack_s           : std_ulogic; -- indicate a valid ack from the bus (ack process)

  --
  -- IC BUS
  --

  signal ic_bus_ena_s                : std_ulogic;
  signal ic_bus_adr_s                : ic_bus_adr_t;

  --
  -- DATA & TAG L1 BUSSES
  --
  
  signal ic_data_ram_ena_with_halt_s : std_ulogic;
  signal ic_tag_ram_ena_with_halt_s  : std_ulogic;
  signal ic_data_ram_ena_s           : std_ulogic;
  signal ic_data_ram_we_s            : std_ulogic;
  signal ic_data_ram_adr_wr_s        : ic_word_adr_t;
  signal ic_data_ram_adr_rd_s        : ic_word_adr_t;
  signal ic_data_ram_dat_i_s         : ic_bus_data_t;
  signal ic_data_ram_dat_o_s         : ic_bus_data_t;
  signal ic_tag_ram_ena_s            : std_ulogic;
  signal ic_tag_ram_we_s             : std_ulogic;
  signal ic_tag_ram_adr_wr_s         : ic_index_adr_t;
  signal ic_tag_ram_adr_rd_s         : ic_index_adr_t;
  signal ic_tag_ram_dat_i_s          : ic_tag_ram_data_t;
  signal ic_tag_ram_dat_o_s          : ic_tag_ram_data_t;

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  TAG_RAM: entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => IC_TAG_TYPE,
      MEM_FILE => IC_TAG_FILE,
      RAM_W    => IC_TAG_RAM_W, 
      RAM_S    => IC_TOTAL_LINES_S
    ) 
    port map
    (
      ena_i    => ic_tag_ram_ena_with_halt_s,
      we_i     => ic_tag_ram_we_s,
      adr_1_i  => ic_tag_ram_adr_wr_s,
      adr_2_i  => ic_tag_ram_adr_rd_s,
      dat_i    => ic_tag_ram_dat_i_s,
      dat_1_o  => open,
      dat_2_o  => ic_tag_ram_dat_o_s,
      clk_i    => clk_i
    );

  INST_MEM: entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE => IC_MEM_TYPE,
      MEM_FILE => IC_MEM_FILE,
      RAM_W    => L1_IM_DATA_BUS_W,
      RAM_S    => IC_WORD_S
    )
    port map
    (
      ena_i    => ic_data_ram_ena_with_halt_s,           
      we_i     => ic_data_ram_we_s,   
      adr_1_i  => ic_data_ram_adr_wr_s,
      adr_2_i  => ic_data_ram_adr_rd_s,
      dat_i    => ic_data_ram_dat_i_s,
      dat_1_o  => open,
      dat_2_o  => ic_data_ram_dat_o_s,
      clk_i    => clk_i
    );
  
  -- //////////////////////////////////////////
  --               COMB PROCESS
  -- //////////////////////////////////////////
  
  --
  -- ASSIGN OUTPUTS
  --

  --
  -- CONTROL SIGNALS
  --
  
  ic_busy_o                   <= ic_busy_s;
  ic_req_done_o               <= ic_req_done_s;
  ic_burst_done_o             <= ic_burst_done_s;
  
  --
  -- INTERNAL BUS
  --
  
  im_c_bus_o.dat_o            <= ic_data_ram_dat_o_s;
    
  --
  -- EXTERNAL BUS
  --
  
  ic_bus_in_o.ena_i           <= ic_bus_ena_s;
  ic_bus_in_o.adr_i           <= ic_bus_adr_s;  

  --
  -- ASSIGN INTERNAL SIGNALS
  --

  ic_data_ram_ena_with_halt_s <= (ic_data_ram_ena_s and not(halt_ic_i));
  ic_tag_ram_ena_with_halt_s  <= (ic_tag_ram_ena_s  and not(halt_ic_i)); 

  --
  -- CACHE VALID FLAG
  --

  ic_valid_flag_s             <= ic_tag_ram_dat_o_s(IC_VALID_BIT_OFF);   							 

  --
  -- SYNC SIGNALS FOR CCLK = SCLK
  --

  GEN_IC_CONTROL_SIGNALS_NO_DIV: if(C_S_CLK_DIV = 1.0) generate
  begin

    ic_bus_sync_ack_s         <= ic_bus_out_i.ack_o;
    ic_bus_sync_block_s       <= '1' when (ic_bus_ena_s = '1' and ic_req_done_r = '0' and ic_bus_next_grant_i = '1') else '0';
    ic_line_req_done_s        <= '1' when (to_integer(unsigned(ic_block_counter_r)) = IC_LINE_WORD_S - 1) else '0';

  end generate GEN_IC_CONTROL_SIGNALS_NO_DIV;

  --
  -- SYNC SIGNALS FOR CCLK > SCLK
  --

  GEN_IC_CONTROL_SIGNALS_DIV: if(C_S_CLK_DIV > 1.0) generate
  begin

    ic_bus_sync_ack_s         <= '1' when to_integer(unsigned(ic_sync_ack_r))   = (natural(C_S_CLK_DIV) - 1) else '0';
    ic_bus_sync_block_s       <= '1' when to_integer(unsigned(ic_sync_block_r)) = (natural(C_S_CLK_DIV) - 1) else '0';
    ic_line_req_done_s        <= '1' when ((to_integer(unsigned(ic_block_counter_r)) = IC_LINE_WORD_S - 1) and ic_bus_sync_block_s = '1') else '0';

  end generate GEN_IC_CONTROL_SIGNALS_DIV;

  --
  -- INSTRUCTION CACHE CONTROL SIGNALS
  --

  ic_req_done_s               <= (ic_req_done_r or ic_line_req_done_s);
  ic_burst_done_s             <= '1' when ((to_integer(unsigned(ic_ack_counter_r)) = IC_LINE_WORD_S - 1) and ic_bus_sync_ack_s = '1') else '0';

  --
  -- TAG COMP
  --
  --! This process implements the cache hit signal. If the tag from 
  --! the cpu address is equal to the tag stored into the tag memory, 
  --! then the data is available from the data memory (cache-hit). 
  --! Otherwise, the data is not available (cache-miss).
  COMB_IC_TAG_STATUS: process(ic_tag_r,
                              ic_tag_ram_dat_o_s)

    alias ic_tag_a is ic_tag_ram_dat_o_s(ic_tag_t'length - 1 downto 0);

  begin
    
    -- cache-hit
    if(ic_tag_a = ic_tag_r) then
      ic_tag_status_s <= IC_HIT;

      -- cache-miss
    else
      ic_tag_status_s <= IC_MISS;

    end if;  
    
  end process COMB_IC_TAG_STATUS;

  --
  -- IC FSM LOGIC
  --
  --! This process implements the control logic of the
  --! instruction cache. It consists of 6 states: 
  --!  - IC_IDLE default state, waiting for a cache operation,
  --!  - IC_READ read state of the instruction cache,
  --!  - IC_FETCH fetch state to refill a cache line from the main memory,
  --!  - IC_END_FETCH finish fetch state, resume read process,
  --!  - IC_INVALID invalid a cache line, and
  --!  - IC_END_INVALID finish invalid, resume read process.
  COMB_IC_FSM: process(im_c_bus_i,
                       wic_i,
                       ic_ena_r,
                       ic_current_state_r,
                       ic_tag_status_s,
                       ic_valid_flag_s,
                       ic_burst_done_s)

  begin

    -- default control assignments 
    ic_next_state_s        <= ic_current_state_r;
    ic_busy_s              <= '0';

    --
    -- IC FSM CONTROL LOGIC
    --

    case ic_current_state_r is

      -- IDLE
      when IC_IDLE =>
        -- invalid
        if(wic_i = WIC_INVALID) then
          ic_next_state_s <= IC_INVALID;

          -- read memory operation
        elsif(im_c_bus_i.ena_i = '1') then
          ic_next_state_s <= IC_READ;

        end if;

      -- READ 
      when IC_READ => 
        -- hit and valid / (previous) read done
        if(ic_tag_status_s = IC_HIT and ic_valid_flag_s = IC_VALID) then
          -- (next) invalid
          if(wic_i = WIC_INVALID) then
            ic_next_state_s <= IC_INVALID;

            -- (next) read memory operation
          elsif(im_c_bus_i.ena_i = '1') then

            -- idle
          else
            ic_next_state_s <= IC_IDLE;

          end if;

          -- miss or invalid
        else
          ic_busy_s         <= '1';        
          ic_next_state_s   <= IC_FETCH;   
			 
        end if;

      -- FETCH
      when IC_FETCH =>
        ic_busy_s         <= '1';     

        -- cache line fetched
        if(ic_burst_done_s = '1') then
          ic_next_state_s <= IC_END_FETCH;
        end if;
 
      -- FINISH FETCH
      when IC_END_FETCH =>
        ic_busy_s       <= '1';
        ic_next_state_s <= IC_READ;  

      -- INVALID
      when IC_INVALID =>
        ic_busy_s         <= '1';
        -- resume from a read operation
        if(ic_ena_r = '1') then
          ic_next_state_s <= IC_END_INVALID;
     
          -- idle
        else
          ic_next_state_s <= IC_IDLE;

        end if;

      -- FINISH INVALID
      when IC_END_INVALID =>
        ic_busy_s       <= '1';
        ic_next_state_s <= IC_READ;

      -- UNDEFINED FSM CODE
      when others =>
        -- force reset state / safe implementation
        ic_next_state_s <= IC_IDLE;
        report "inst cache fsm process: illegal fsm code" severity warning;

    end case;
    
  end process COMB_IC_FSM;

  --
  -- CACHE DATA AND TAG MEMORY CONTROL
  --
  --! This process implements the control of the instruction cache memory 
  --! as well as the tag memory.
  COMB_IC_MEMORY_CONTROL: process(im_c_bus_i,
                                  ic_word_adr_r,
                                  ic_ack_counter_r,
                                  ic_bus_out_i,
                                  ic_tag_r,
                                  ic_ena_r,
                                  ic_tag_status_s,
                                  ic_valid_flag_s,
                                  ic_bus_sync_ack_s,
                                  ic_burst_done_s,
                                  ic_wic_index_adr_r,
                                  ic_current_state_r)

    --
    -- Direct Mapped : mapping is [line address] MOD [nb of lines]
    --            
    -- +-----------------------------------------------------------+         
    -- |       Unused      |   Tag   |   Index   |   Line offset   |
    -- +-----------------------------------------------------------+
    --
    -- Use one valid bit per line 
    --

    alias im_c_bus_word_adr_a:ic_word_adr_t is im_c_bus_i.adr_i(IC_BYTE_W - 1 downto WORD_ADR_OFF);
    alias im_c_bus_index_adr_a:ic_index_adr_t is im_c_bus_i.adr_i(IC_BYTE_W - 1 downto IC_BYTE_W - IC_TOTAL_LINES_W);
    alias ic_bus_index_adr_a is ic_word_adr_r(IC_WORD_W - 1 downto IC_WORD_W - IC_TOTAL_LINES_W);
    alias ic_index_reg_a is ic_word_adr_r(IC_WORD_W - 1 downto IC_WORD_W - IC_TOTAL_LINES_W); 

  begin

    -- data ram default settings
    ic_data_ram_ena_s    <= '0';                                   -- deactivated
    ic_data_ram_we_s     <= '0';                                   -- read mode
    ic_data_ram_adr_rd_s <= im_c_bus_word_adr_a;                   -- im bus read address 
    ic_data_ram_adr_wr_s <= ic_bus_index_adr_a & ic_ack_counter_r; -- fetch write address
    ic_data_ram_dat_i_s  <= ic_bus_out_i.dat_o;                    -- ic bus data

    -- tag ram default settings
    ic_tag_ram_ena_s     <= '0';                                   -- deactivated
    ic_tag_ram_we_s      <= '0';                                   -- read mode
    ic_tag_ram_adr_rd_s  <= im_c_bus_index_adr_a;                  -- im bus read address 
    ic_tag_ram_adr_wr_s  <= ic_index_reg_a;                        -- registered index address 
    ic_tag_ram_dat_i_s   <= IC_VALID & ic_tag_r;                   -- fetch registered tag 


    case ic_current_state_r is

      -- IDLE
      when IC_IDLE =>
        -- read memory operation
        if(im_c_bus_i.ena_i = '1') then
          ic_tag_ram_ena_s  <= '1'; 
          ic_data_ram_ena_s <= '1';
        end if;

      -- READ 
      when IC_READ => 
        -- hit and valid / (previous) read done
        if(ic_tag_status_s = IC_HIT and ic_valid_flag_s = IC_VALID) then
          -- (next) read memory operation
          if(im_c_bus_i.ena_i = '1') then
            ic_tag_ram_ena_s  <= '1';
            ic_data_ram_ena_s <= '1';
          end if;   
        end if;

      -- FETCH
      when IC_FETCH =>
        -- data valid / update data ram
        if(ic_bus_sync_ack_s = '1') then
          ic_data_ram_ena_s  <= '1';
          ic_data_ram_we_s   <= '1';  
        end if;

        -- line fetched / update tag ram
        if(ic_burst_done_s = '1') then
          ic_tag_ram_ena_s   <= '1';              
          ic_tag_ram_we_s    <= '1';              
        end if;
 
      -- FINISH FETCH
      when IC_END_FETCH =>   
        -- resume old read request
        ic_data_ram_ena_s    <= '1'; 
        ic_data_ram_adr_rd_s <= ic_word_adr_r;     
        ic_tag_ram_ena_s     <= '1';                       
        ic_tag_ram_adr_rd_s  <= ic_bus_index_adr_a; 

      -- INVALID
      when IC_INVALID =>
        -- invalidate cache line
        ic_tag_ram_ena_s     <= '1';
        ic_tag_ram_we_s      <= '1';
        ic_tag_ram_adr_wr_s  <= ic_wic_index_adr_r;
        ic_tag_ram_dat_i_s   <= (others => '0');

      -- FINISH INVALID
      when IC_END_INVALID =>
        -- resume old read request 
        ic_data_ram_ena_s    <= '1'; 
        ic_data_ram_adr_rd_s <= ic_word_adr_r;     
        ic_tag_ram_ena_s     <= '1';                       
        ic_tag_ram_adr_rd_s  <= ic_bus_index_adr_a; 

      -- UNDEFINED FSM CODE
      when others =>

    end case;
    
  end process COMB_IC_MEMORY_CONTROL;

  --
  -- CACHE BUS CONTROL
  --
  --! This process implements the control of the instruction cache bus module. 
  COMB_IC_CACHE_BUS_CONTROL: process(ic_valid_flag_s,
                                     ic_current_state_r,
                                     ic_word_adr_r,
                                     ic_tag_r,
                                     ic_req_done_r,
                                     ic_block_counter_r,
                                     ic_tag_status_s)

    --
    -- Direct Mapped : mapping is [line address] MOD [nb of lines]
    --            
    -- +-----------------------------------------------------------+         
    -- |       Unused      |   Tag   |   Index   |   Line offset   |
    -- +-----------------------------------------------------------+
    --
    -- Use one valid bit per line 
    --

    alias ic_bus_index_adr_a is ic_word_adr_r(IC_WORD_W - 1 downto IC_WORD_W - IC_TOTAL_LINES_W);

  begin

    -- cache bus default settings
    ic_bus_ena_s <= '0';                                    -- deactivated                           
    ic_bus_adr_s <= IC_BUS_ADR_PADDING & ic_tag_r           -- fetch address
                                       & ic_bus_index_adr_a 
                                       & ic_block_counter_r 
                                       & WORD_0_PADDING; 

    case ic_current_state_r is

      -- IDLE
      when IC_IDLE =>

      -- READ 
      when IC_READ => 
        -- miss or invalid 
        if((ic_tag_status_s = IC_MISS or ic_valid_flag_s = IC_N_VALID)) then
          ic_bus_ena_s <= '1';           
        end if;

      -- FETCH
      when IC_FETCH =>
        -- request process
        if(ic_req_done_r = '0') then
          ic_bus_ena_s <= '1'; 
  
          -- request done 
        else
          ic_bus_ena_s <= '0'; 

        end if;
 
      -- FINISH FETCH
      when IC_END_FETCH =>   

      -- INVALID
      when IC_INVALID =>

      -- FINISH INVALID
      when IC_END_INVALID =>

      -- UNDEFINED FSM CODE
      when others =>

    end case;
    
  end process COMB_IC_CACHE_BUS_CONTROL;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- L1 BUS REGISTERED INPUTS
  --
  --! This process implements IC L1 bus input registers.
  CYCLE_IC_L1_IN_REG: process(clk_i)		
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then

      if(halt_ic_i = '0' and ic_busy_s = '0') then
        ic_ena_r           <= im_c_bus_i.ena_i;
        ic_word_adr_r      <= im_c_bus_i.adr_i(IC_BYTE_W - 1 downto WORD_ADR_OFF);
        ic_wic_index_adr_r <= wic_adr_i(IC_BYTE_W - 1 downto IC_BYTE_W - IC_TOTAL_LINES_W);
        ic_tag_r           <= im_c_bus_i.adr_i(IC_CACHEABLE_MEM_W - 1 downto IC_CACHEABLE_MEM_W - IC_TAG_W);
      end if;
      
    end if;

  end process CYCLE_IC_L1_IN_REG;

  --
  -- IC FSM 
  --
  --! This process implements the instruction cache fsm reg.
  CYCLE_IC_FSM: process(clk_i)		
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0') then
         ic_current_state_r <= IC_IDLE;
         
      elsif(halt_ic_i = '0') then
         ic_current_state_r <= ic_next_state_s;
         
      end if;
      
    end if;
    
  end process CYCLE_IC_FSM;

  --
  -- BLOCK COUNTER 
  --
  --! This process implements the block counter used for the burst process 
  --! during the fetch state.
  CYCLE_IC_BLOCK_COUNTER: process(clk_i)
  begin
  
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0' or (ic_line_req_done_s = '1' and halt_ic_i = '0' and halt_ic_req_i = '0')) then
        ic_block_counter_r <= (others =>'0');
        
      elsif(halt_ic_i = '0' and halt_ic_req_i = '0' and ic_bus_sync_block_s = '1') then
        ic_block_counter_r <= std_ulogic_vector(unsigned(ic_block_counter_r) + 1);
        
      end if;
      
    end if;

  end process CYCLE_IC_BLOCK_COUNTER;  

  --
  -- ACK COUNTER 
  --
  --! This process implements the ack counter used for the burst process 
  --! during the fetch state.
  CYCLE_IC_ACK_COUNTER: process(clk_i)
  begin
  
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0' or (ic_burst_done_s = '1' and halt_ic_i = '0')) then
        ic_ack_counter_r <= (others =>'0');
        
      elsif(halt_ic_i = '0' and ic_bus_sync_ack_s = '1') then
        ic_ack_counter_r <= std_ulogic_vector(unsigned(ic_ack_counter_r) + 1);
        
      end if;
      
    end if;

  end process CYCLE_IC_ACK_COUNTER;  

  --
  -- REQ DONE FLAG
  --
  --! This process implements the request done flag register.
  CYCLE_IC_REQ_FLAG: process(clk_i)		
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0' or (ic_burst_done_s = '1' and halt_ic_i = '0' and halt_ic_req_i = '0')) then
         ic_req_done_r <= '0';
         
      elsif(halt_ic_i = '0' and halt_ic_req_i = '0') then
         ic_req_done_r <= ic_req_done_s;
         
      end if;
      
    end if;
    
  end process CYCLE_IC_REQ_FLAG;

  GEN_IC_CYCLE_SYNC_DIV: if(C_S_CLK_DIV > 1.0) generate
  begin

    --
    -- SYNC BLOCK COUNTER 
    --
    --! This process implements the sync block counter used to 
    --! synchronize the core clock with the bus clock.
    CYCLE_IC_SYNC_BLOCK_COUNTER: process(clk_i)
    begin

      -- clock event
      if(clk_i'event and clk_i = '1') then

        -- sync reset
        if(rst_n_i = '0' or (ic_line_req_done_s = '1' and halt_ic_i = '0' and halt_ic_req_i = '0')) then
          ic_sync_block_r   <= (others =>'0');
          
        elsif(halt_ic_i = '0' and halt_ic_req_i = '0' and ic_bus_ena_s = '1' and ic_bus_next_grant_i = '1') then
          ic_sync_block_r <= std_ulogic_vector(unsigned(ic_sync_block_r) + 1);
          
        end if;
          
      end if;

    end process CYCLE_IC_SYNC_BLOCK_COUNTER;

    --
    -- SYNC ACK COUNTER 
    --
    --! This process implements the sync ack counter used to 
    --! synchronize the core clock with the bus clock.
    CYCLE_IC_SYNC_ACK_COUNTER: process(clk_i)
    begin

      -- clock event
      if(clk_i'event and clk_i = '1') then

        -- sync reset
        if(rst_n_i = '0' or (ic_burst_done_s = '1' and halt_ic_i = '0')) then
          ic_sync_ack_r <= (others =>'0');
          
        elsif(halt_ic_i = '0' and ic_bus_out_i.ack_o = '1') then
          ic_sync_ack_r <= std_ulogic_vector(unsigned(ic_sync_ack_r) + 1);
          
        end if;
          
      end if;

    end process CYCLE_IC_SYNC_ACK_COUNTER;

  end generate GEN_IC_CYCLE_SYNC_DIV;

end architecture be_sb_icache;


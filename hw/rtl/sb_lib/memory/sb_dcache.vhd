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
--! @file sb_dcache.vhd                                					
--! @brief Direct-Mapped Data Cache Implementation   				
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
-- halted to support WB stall control signals 
-- Fixed write-through FSM
--
-- Version 1.3b 01/06/2011 by Lyonel Barthe
-- Readded the padding constant & changed coding style
-- to fix a bug with a large cacheable memory space
--
-- Version 1.3 31/05/2011 by Lyonel Barthe / Remi Busseuil
-- Removed the padding constant to fix a bug with a large
-- cacheable memory space
--
-- Version 1.2 23/12/2010 by Lyonel Barthe
-- Separate control signals implementation
-- Optional write-through support (no write-buffer)
--
-- Version 1.1b 7/10/2010 by Lyonel Barthe
-- Added the flush instruction 
-- Added the wdc instruction
--
-- Version 1.1a 20/09/2010 by Lyonel Barthe
-- Changed coding style with stall signals
-- Added counters for the synchronization with sclk
-- Added reset signals for such new counters
-- Added a prefetch mechanism for copy back stage  
--
-- Version 1.0 24/06/2010 by Lyonel Barthe
-- Clean Up Version
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
--! For improved performance, the SecretBlaze has an optional data cache memory
--! that hold copies of the most frequently used data. The proposed implementation 
--! is a direct-mapped cache with one-cycle hit latency. The data cache can use either 
--! a write-through policy with a no-write allocate approach or a write-back policy 
--! with a write allocate approach ideally suited for embedded applications. The size 
--! of the physical memory, the size of the cacheable memory as well as the size of a 
--! cache block are configurable through VHDL generic statements. Like local on-chip 
--! memories, the cache is implemented with dual-port synchronous RAMs to allow 
--! simultaneous read/write operations.
--!
--! Each cache entry consists of a tag field, a data field, and a valid bit. It also 
--! implements a dirty bit to indicate a modified block when the write-back policy 
--! is used.
--

--! SecretBlaze Data Cache Entity
entity sb_dcache is

  generic
    (
      C_S_CLK_DIV         : real    := USER_C_S_CLK_DIV;   --! core clock/system clock ratio
      DC_MEM_TYPE         : string  := USER_DC_MEM_TYPE;   --! DC memory implementation type  
      DC_TAG_TYPE         : string  := USER_DC_TAG_TYPE;   --! DC tag implementation type  
      DC_MEM_FILE_1       : string  := USER_DC_MEM_FILE_1; --! DC memory init file LSB
      DC_MEM_FILE_2       : string  := USER_DC_MEM_FILE_2; --! DC memory init file LSB+
      DC_MEM_FILE_3       : string  := USER_DC_MEM_FILE_3; --! DC memory init file MSB-
      DC_MEM_FILE_4       : string  := USER_DC_MEM_FILE_4; --! DC memory init file MSB  
      DC_TAG_FILE         : string  := USER_DC_TAG_FILE;   --! DC tag init file
      USE_WRITEBACK       : boolean := USER_USE_WRITEBACK  --! if true, use write-back policy
    );
  
  port
    (
      dm_c_bus_i          : in dm_bus_i_t;                 --! data L1 bus inputs (cache side)
      dm_c_bus_o          : out dm_bus_o_t;                --! data L1 bus outputs (cache side)
      wdc_i               : in wdc_control_t;              --! wdc control input
      dc_bus_in_o         : out dc_bus_i_t;                --! data cache bus inputs
      dc_bus_out_i        : in dc_bus_o_t;                 --! data cache bus outputs 
      dc_bus_next_grant_i : in std_ulogic;                 --! data cache bus next grant signal
      dc_busy_o           : out std_ulogic;                --! data cache busy signal 
      dc_req_done_o       : out std_ulogic;                --! data cache req done flag
      dc_burst_done_o     : out std_ulogic;                --! data cache burst done flag              
      halt_dc_i           : in std_ulogic;                 --! data cache stall signal input
      halt_dc_req_i       : in std_ulogic;                 --! data cache stall request process control signal
      clk_i               : in std_ulogic;                 --! core clock
      rst_n_i             : in std_ulogic                  --! active-low reset signal
    );
  
end sb_dcache;

--! SecretBlaze Data Cache Architecture
architecture be_sb_dcache of sb_dcache is

  -- //////////////////////////////////////////
  --              INTERNAL REGS
  -- //////////////////////////////////////////

  signal dc_current_state_r          : dc_fsm_t;                                                   --! DC fsm reg
  signal dc_tag_r                    : dc_tag_t;                                                   --! DC tag reg
  signal dc_block_counter_r          : dc_counter_t;                                               --! DC word per line counter reg
  signal dc_next_block_counter_r     : dc_counter_t;                                               --! DC word per line + 1 counter reg (only if USE_WRITEBACK is true)
  signal dc_ack_counter_r            : dc_counter_t;                                               --! DC ack counter reg
  signal dc_req_done_r               : std_ulogic;                                                 --! DC request done flag reg   
  signal dc_word_adr_r               : dc_word_adr_t;                                              --! DC word address reg
  signal dc_dat_i_r                  : dc_bus_data_t;                                              --! DC data to write reg
  signal dc_sel_r                    : dc_bus_sel_t;                                               --! DC write control reg
  signal dc_we_r                     : std_ulogic;                                                 --! DC write ena reg (only if USE_WRITEBACK is true)
  signal dc_wdc_r                    : wdc_control_t;                                              --! DC wdc control reg (only if USE_WRITEBACK is true)
  signal dc_sync_block_r             : std_ulogic_vector(log2(natural(C_S_CLK_DIV)) - 1 downto 0); --! DC sync block counter
  signal dc_sync_ack_r               : std_ulogic_vector(log2(natural(C_S_CLK_DIV)) - 1 downto 0); --! DC sync ack counter
  signal halt_dc_req_i_r             : std_ulogic;                                                 --! DC halt request register (only if USE_WRITEBACK is true)
  
  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- CONTROL SIGNALS
  --
  
  signal dc_busy_s                   : std_ulogic;
  signal dc_tag_status_s             : dc_tag_status_t;
  signal dc_tag_haz_cond_s           : hazard_status_t;
  signal dc_next_state_s             : dc_fsm_t;
  signal dc_req_done_s               : std_ulogic;
  signal dc_dirty_flag_s             : dc_tag_dirty_t;
  signal dc_valid_flag_s             : dc_tag_valid_t;
  signal dc_line_req_done_s          : std_ulogic;
  signal dc_burst_done_s             : std_ulogic;
  signal dc_force_prefetch_s         : std_ulogic;
  signal dc_bus_sync_block_s         : std_ulogic; -- indicate a valid block on the bus (request process)
  signal dc_bus_sync_ack_s           : std_ulogic; -- indicate a valid ack from the bus (ack process)
  signal dc_single_req_done_s        : std_ulogic;
  signal dc_single_copy_done_s       : std_ulogic;
  signal dc_single_copy_s            : std_ulogic;

  --
  -- DC BUS
  --

  signal dc_bus_ena_s                : std_ulogic;
  signal dc_bus_adr_s                : dc_bus_adr_t;
  signal dc_bus_we_s                 : std_ulogic;
  signal dc_bus_dat_i_s              : dc_bus_data_t;
  signal dc_bus_sel_s                : dc_bus_sel_t;
  
  --
  -- DATA & TAG RAM BUSSES
  --

  signal dc_data_ram_ena_with_halt_s : std_ulogic;  
  signal dc_data_ram_ena_s           : std_ulogic;
  signal dc_data_ram_we_s            : dc_bus_sel_t;
  signal dc_data_ram_adr_wr_s        : dc_word_adr_t;
  signal dc_data_ram_adr_rd_s        : dc_word_adr_t;
  signal dc_data_ram_dat_i_s         : dc_bus_data_t;
  signal dc_data_ram_dat_1_o_s       : dc_bus_data_t;
  signal dc_data_ram_dat_2_o_s       : dc_bus_data_t;
  signal dc_tag_ram_ena_with_halt_s  : std_ulogic;
  signal dc_tag_ram_ena_s            : std_ulogic;
  signal dc_tag_ram_we_s             : std_ulogic;
  signal dc_tag_ram_adr_wr_s         : dc_index_adr_t;
  signal dc_tag_ram_adr_rd_s         : dc_index_adr_t;
  signal dc_tag_ram_dat_i_s          : dc_tag_ram_data_t;
  signal dc_tag_ram_dat_o_s          : dc_tag_ram_data_t;

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  TAG_RAM: entity tool_lib.dpram(be_dpram)
    generic map
    (
      RAM_TYPE   => DC_TAG_TYPE,
      MEM_FILE   => DC_TAG_FILE,
      RAM_W      => DC_TAG_RAM_W, 
      RAM_S      => DC_TOTAL_LINES_S
    ) 
    port map
    (
      ena_i      => dc_tag_ram_ena_with_halt_s,
      we_i       => dc_tag_ram_we_s,
      adr_1_i    => dc_tag_ram_adr_wr_s,
      adr_2_i    => dc_tag_ram_adr_rd_s,
      dat_i      => dc_tag_ram_dat_i_s,
      dat_1_o    => open,
      dat_2_o    => dc_tag_ram_dat_o_s,
      clk_i      => clk_i
    );

  DATA_MEM: entity tool_lib.dpram4x8(be_dpram4x8)
    generic map
    (
      RAM_TYPE   => DC_MEM_TYPE,
      MEM_FILE_1 => DC_MEM_FILE_1,
      MEM_FILE_2 => DC_MEM_FILE_2,
      MEM_FILE_3 => DC_MEM_FILE_3,               
      MEM_FILE_4 => DC_MEM_FILE_4,
      RAM_WORD_S => DC_WORD_S
    )
    port map
    (
      ena_i      => dc_data_ram_ena_with_halt_s,           
      we_i       => dc_data_ram_we_s,   
      adr_1_i    => dc_data_ram_adr_wr_s,
      adr_2_i    => dc_data_ram_adr_rd_s,
      dat_i      => dc_data_ram_dat_i_s,
      dat_1_o    => dc_data_ram_dat_1_o_s,
      dat_2_o    => dc_data_ram_dat_2_o_s,
      clk_i      => clk_i
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
  
  dc_busy_o                   <= dc_busy_s;
  dc_req_done_o               <= dc_req_done_s;
  dc_burst_done_o             <= dc_burst_done_s;
  
  --
  -- INTERNAL BUS
  --
  
  dm_c_bus_o.dat_o            <= dc_data_ram_dat_2_o_s;
  
  --
  -- EXTERNAL BUS
  --
  
  dc_bus_in_o.ena_i           <= dc_bus_ena_s;
  dc_bus_in_o.we_i            <= dc_bus_we_s;
  dc_bus_in_o.dat_i           <= dc_bus_dat_i_s;
  dc_bus_in_o.adr_i           <= dc_bus_adr_s;
  dc_bus_in_o.sel_i           <= dc_bus_sel_s;

  --
  -- ASSIGN INTERNAL SIGNALS
  --
                            
  dc_data_ram_ena_with_halt_s <= dc_data_ram_ena_s and not(halt_dc_i); 
  dc_tag_ram_ena_with_halt_s  <= dc_tag_ram_ena_s  and not(halt_dc_i); 

  --
  -- DATA CACHE FLAG(S)
  --

  dc_valid_flag_s             <= dc_tag_ram_dat_o_s(DC_VALID_BIT_OFF);   	
						 
  GEN_DC_WRITE_BACK_DIRTY_FLAG: if(USE_WRITEBACK = true) generate

    dc_dirty_flag_s           <= dc_tag_ram_dat_o_s(DC_DIRTY_BIT_OFF); 

  end generate GEN_DC_WRITE_BACK_DIRTY_FLAG;

  --
  -- SYNC SIGNALS FOR CCLK = SCLK
  --

  GEN_DC_SYNC_SIGNALS_NO_DIV: if(C_S_CLK_DIV = 1.0) generate
  begin

    dc_bus_sync_ack_s         <= dc_bus_out_i.ack_o;
    dc_bus_sync_block_s       <= '1' when (dc_bus_ena_s = '1' and dc_req_done_r = '0' and dc_bus_next_grant_i = '1') else '0';
    dc_force_prefetch_s       <= '1' when (to_integer(unsigned(dc_block_counter_r)) /= 0 and halt_dc_req_i_r = '0') else '0'; 
    dc_line_req_done_s        <= '1' when (to_integer(unsigned(dc_block_counter_r)) = DC_LINE_WORD_S - 1) else '0';

  end generate GEN_DC_SYNC_SIGNALS_NO_DIV;

  --
  -- SYNC SIGNALS FOR CCLK > SCLK
  --

  GEN_DC_SYNC_SIGNALS_DIV: if(C_S_CLK_DIV > 1.0) generate
  begin

    dc_bus_sync_ack_s         <= '1' when to_integer(unsigned(dc_sync_ack_r))   = (natural(C_S_CLK_DIV) - 1) else '0';
    dc_bus_sync_block_s       <= '1' when to_integer(unsigned(dc_sync_block_r)) = (natural(C_S_CLK_DIV) - 1) else '0';
    dc_force_prefetch_s       <= '1' when (to_integer(unsigned(dc_block_counter_r)) /= 0 and to_integer(unsigned(dc_sync_block_r)) = 0 and halt_dc_req_i_r = '0') else '0';
    dc_line_req_done_s        <= '1' when ((to_integer(unsigned(dc_block_counter_r)) = DC_LINE_WORD_S - 1) and dc_bus_sync_block_s = '1') else '0';

  end generate GEN_DC_SYNC_SIGNALS_DIV;

  --
  -- WRITE BACK DATA CACHE CONTROL SIGNALS
  --

  GEN_DC_WRITE_BACK_CONTROL_SIGNALS: if(USE_WRITEBACK = true) generate

    dc_req_done_s             <= (dc_req_done_r or dc_line_req_done_s);
    dc_burst_done_s           <= '1' when ((to_integer(unsigned(dc_ack_counter_r)) = DC_LINE_WORD_S - 1) and dc_bus_sync_ack_s = '1') else '0';

  end generate GEN_DC_WRITE_BACK_CONTROL_SIGNALS;

  --
  -- WRITE THROUGH DATA CACHE CONTROL SIGNALS
  --

  GEN_DC_WRITE_THROUGH_CONTROL_SIGNALS: if(USE_WRITEBACK = false) generate

    dc_single_req_done_s      <= '1' when (dc_single_copy_s = '1' and dc_bus_sync_block_s = '1') else '0';
    dc_single_copy_done_s     <= '1' when (dc_single_copy_s = '1' and dc_bus_sync_ack_s = '1') else '0';
    dc_req_done_s             <= (dc_req_done_r or dc_line_req_done_s or dc_single_req_done_s);
    dc_burst_done_s           <= '1' when (((to_integer(unsigned(dc_ack_counter_r)) = DC_LINE_WORD_S - 1) and dc_bus_sync_ack_s = '1') or 
                                           (dc_single_copy_done_s = '1')) else '0';

  end generate GEN_DC_WRITE_THROUGH_CONTROL_SIGNALS;

  --
  -- TAG COMP
  --
  --! This process implements the cache hit signal. If the tag from 
  --! the cpu address is equal to the tag stored into the tag memory, 
  --! then the data is available from the data memory (cache-hit). 
  --! Otherwise, the data is not available (cache-miss).
  COMB_DC_TAG_STATUS: process(dc_tag_r,
                              dc_tag_ram_dat_o_s)

    alias dc_tag_a is dc_tag_ram_dat_o_s(dc_tag_t'length - 1 downto 0);

  begin

    -- cache-hit
    if(dc_tag_a = dc_tag_r) then
      dc_tag_status_s <= DC_HIT;

      -- cache-miss
    else
      dc_tag_status_s <= DC_MISS;

    end if;   

  end process COMB_DC_TAG_STATUS;
  
  GEN_DC_TAG_HAZARD_COMP: if(USE_WRITEBACK = true) generate  

    --
    -- HAZARD COMP
    --
    --! A read after write hazard happens when the write tag address is 
    --! equal to the read tag address. This process implements the 
    --! comparator required to detect such hazard.
    COMB_DC_TAG_HAZARD_COMP: process(dm_c_bus_i,
                                     dc_word_adr_r)

      alias read_tag_index_adr_a:dc_index_adr_t is dm_c_bus_i.adr_i(DC_BYTE_W - 1 downto DC_BYTE_W - DC_TOTAL_LINES_W);
      alias write_tag_index_adr_a is dc_word_adr_r(DC_WORD_W - 1 downto DC_WORD_W - DC_TOTAL_LINES_W);

    begin

      -- RAW hazard condition
      if(read_tag_index_adr_a = write_tag_index_adr_a) then
        dc_tag_haz_cond_s <= HAZARD_DETECTED;

        -- no hazard
      else
        dc_tag_haz_cond_s <= HAZARD_N_DETECTED;
        
      end if;

    end process COMB_DC_TAG_HAZARD_COMP;

  end generate GEN_DC_TAG_HAZARD_COMP;

  --
  -- DC FSM LOGIC
  --
  --! This process implements the control logic of the data cache. 
  --! It consists of 8 states:
  --!  - DC_IDLE default state, waiting for a cache operation,
  --!  - DC_READ read state of the data cache,
  --!  - DC_WRITE write state of the data cache,
  --!  - DC_FETCH fetch state to refill a cache line from the main memory,
  --!  - DC_COPY copy back state to update a data (or a cache line) in the main memory,
  --!  - DC_END_FETCH finish fetch state, resume read/write process,
  --!  - DC_INVALID invalid a cache line, and
  --!  - DC_FLUSH flush a cache line (write-back cache only).
  COMB_DC_FSM: process(dm_c_bus_i,
                       wdc_i,
                       dc_wdc_r,
                       dc_current_state_r,
                       dc_block_counter_r,
                       dc_next_block_counter_r,
                       dc_force_prefetch_s,
                       dc_tag_status_s,
                       dc_dirty_flag_s,
                       dc_valid_flag_s,
                       dc_req_done_r,
                       dc_bus_next_grant_i,
                       dc_line_req_done_s,
                       dc_burst_done_s,
                       dc_we_r,
                       dc_tag_haz_cond_s)

  begin

    -- default control assignments 
    dc_next_state_s  <= dc_current_state_r;
    dc_busy_s        <= '0';
    dc_single_copy_s <= '0';
  
    --
    -- DC FSM CONTROL LOGIC
    -- 

    case dc_current_state_r is

      -- IDLE
      when DC_IDLE =>
        case wdc_i is

          -- flush
          when WDC_FLUSH =>
            if(USE_WRITEBACK = true) then
              dc_next_state_s <= DC_FLUSH;

              -- USE_WRITETHROUGH
            else
              report "data cache: illegal WDC flush instruction because write-back policy is not implemented" severity warning;

            end if;

          -- invalid
          when WDC_INVALID =>
            dc_next_state_s   <= DC_INVALID;

          -- memory operation
          when others =>

            -- read
            if((dm_c_bus_i.ena_i and not(dm_c_bus_i.we_i)) = '1') then
              dc_next_state_s <= DC_READ;
            end if;

            -- write 
            if((dm_c_bus_i.ena_i and dm_c_bus_i.we_i) = '1') then
              dc_next_state_s <= DC_WRITE;
            end if;

         end case;
        
      -- READ 
      when DC_READ =>
        -- hit and valid / (previous) read done
        if(dc_tag_status_s = DC_HIT and dc_valid_flag_s = DC_VALID) then
          case wdc_i is

            -- (next) flush
            when WDC_FLUSH => 
              if(USE_WRITEBACK = true) then
                dc_next_state_s   <= DC_FLUSH;
              
                -- USE_WRITETHROUGH
              else
                report "data cache: illegal WDC flush instruction because write-back policy is not implemented" severity warning;

              end if;

            -- (next) invalid
            when WDC_INVALID =>    
              dc_next_state_s     <= DC_INVALID;

            when others =>

              -- (next) memory operation
              if(dm_c_bus_i.ena_i = '1') then
                -- read
                if(dm_c_bus_i.we_i = '0') then
                  dc_next_state_s <= DC_READ;

                  -- write
                else
                  dc_next_state_s <= DC_WRITE;

                end if;

                -- idle
              else
                dc_next_state_s   <= DC_IDLE;

              end if;

           end case;

          -- miss or invalid
        else
          dc_busy_s           <= '1';    
          if(USE_WRITEBACK = true) then
            -- dirty and valid / copy back the current cache line
            if(dc_dirty_flag_s = DC_DIRTY and dc_valid_flag_s = DC_VALID) then
              dc_next_state_s <= DC_COPY;
          
              -- fetch the new cache line
            else
              dc_next_state_s <= DC_FETCH;        

            end if;

            -- USE_WRITETHROUGH
          else
            -- fetch the new cache line
            dc_next_state_s <= DC_FETCH;   

          end if;
  
        end if;

      -- WRITE 
      when DC_WRITE =>
        if(USE_WRITEBACK = true) then
          -- hit and valid / (previous) write accepted
          if(dc_tag_status_s = DC_HIT and dc_valid_flag_s = DC_VALID) then
            case wdc_i is

              -- (next) flush
              when WDC_FLUSH =>
                -- RAW hazard detected
                if(dc_tag_haz_cond_s = HAZARD_DETECTED) then
                  dc_busy_s       <= '1'; 
                  dc_next_state_s <= DC_IDLE;

                else
                  dc_next_state_s <= DC_FLUSH;

                end if;

              -- (next) invalid
              when WDC_INVALID =>
                dc_next_state_s <= DC_INVALID;

              -- (next) memory operation
              when others =>

                -- (next) memory operation
                if(dm_c_bus_i.ena_i = '1') then
                  -- read
                  if(dm_c_bus_i.we_i = '0') then
                    -- RAW hazard detected
                    if(dc_tag_haz_cond_s = HAZARD_DETECTED) then
                      dc_busy_s       <= '1'; 
                      dc_next_state_s <= DC_IDLE;

                    else
                      dc_next_state_s <= DC_READ;

                    end if;

                    -- write
                  else
                    dc_next_state_s <= DC_WRITE;

                  end if;

                  -- idle
                else
                  dc_next_state_s <= DC_IDLE;

                end if;

             end case;

            -- miss or invalid
          else
            dc_busy_s         <= '1';    
            -- dirty and valid / copy back the current cache line
            if(dc_dirty_flag_s = DC_DIRTY and dc_valid_flag_s = DC_VALID) then
              dc_next_state_s <= DC_COPY;
          
              -- fetch the new cache line
            else
              dc_next_state_s <= DC_FETCH;        

            end if;
            
          end if;

          -- USE_WRITETHROUGH / always copy back 
        else
          dc_busy_s        <= '1';    
          dc_next_state_s  <= DC_COPY;
          dc_single_copy_s <= '1';

        end if;

      -- FETCH
      when DC_FETCH =>
        dc_busy_s         <= '1';        
        -- cache line fetched
        if(dc_burst_done_s = '1') then
          dc_next_state_s <= DC_END_FETCH;           
        end if;
 
      -- FINISH FETCH
      when DC_END_FETCH =>
        dc_busy_s           <= '1';
        if(USE_WRITEBACK = true) then
          -- finish read operation
          if(dc_we_r = '0') then
            dc_next_state_s <= DC_READ;

            -- finish write operation
          else
            dc_next_state_s <= DC_WRITE;

          end if;

          -- USE_WRITETHROUGH
        else
          -- finish read operation
          dc_next_state_s   <= DC_READ;  

        end if;
                    
      -- COPY
      when DC_COPY =>
        dc_busy_s             <= '1';        
        if(USE_WRITEBACK = true) then
          -- cache line copied 
          if(dc_burst_done_s = '1') then
            -- resume from a flush instruction
            if(dc_wdc_r = WDC_FLUSH) then
              dc_next_state_s <= DC_INVALID;

              -- resume from a cache miss
            else
              dc_next_state_s <= DC_FETCH;

            end if;
          end if;

          -- USE_WRITETHROUGH
        else
          dc_single_copy_s  <= '1';
          -- cache block copied 
          if(dc_burst_done_s = '1') then
            dc_next_state_s <= DC_IDLE;
          end if;

        end if;

      -- FLUSH        
      when DC_FLUSH =>
        if(USE_WRITEBACK = true) then
          dc_busy_s         <= '1';
          -- dirty and valid / copy back the current cache line
          if(dc_dirty_flag_s = DC_DIRTY and dc_valid_flag_s = DC_VALID) then
            dc_next_state_s <= DC_COPY;

          else
            dc_next_state_s <= DC_IDLE;

          end if;

          -- USE_WRITETHROUGH
        else
          -- force reset state / safe implementation
          dc_next_state_s   <= DC_IDLE;
          report "data cache: illegal flush state because write-back policy is not implemented" severity warning;

        end if;

      -- INVALID
      when DC_INVALID =>
        dc_busy_s       <= '1'; 
        dc_next_state_s <= DC_IDLE;

      -- UNDEFINED FSM CODE
      when others =>
        -- force reset state / safe implementation
        dc_next_state_s <= DC_IDLE;
        report "data cache fsm process: illegal fsm code" severity warning;

    end case;
    
  end process COMB_DC_FSM;

  --
  -- CACHE DATA AND TAG MEMORY CONTROL
  --
  --! This process implements the control of the data cache memory 
  --! as well as the tag memory.
  COMB_DC_MEMORY_CONTROL: process(dm_c_bus_i,
                                  dc_word_adr_r,
                                  dc_ack_counter_r,
                                  dc_bus_out_i,
                                  dc_tag_r,
                                  dc_tag_status_s,
                                  dc_valid_flag_s,
                                  dc_current_state_r,
                                  dc_dat_i_r, 
                                  wdc_i, 
                                  dc_dirty_flag_s, 
                                  dc_block_counter_r, 
                                  dc_sel_r,
                                  dc_next_block_counter_r,											 
                                  dc_burst_done_s,
                                  dc_bus_sync_ack_s,
                                  dc_we_r)

    --
    -- Direct Mapped : mapping is [line address] MOD [nb of lines]
    --            
    -- +-----------------------------------------------------------+         
    -- |       Unused      |   Tag   |   Index   |   Line offset   |
    -- +-----------------------------------------------------------+
    --
    -- Use one valid bit per line 
    -- Use one dirty bit per line (write-back policy only)
    --

    alias dm_c_bus_word_adr_a:dc_word_adr_t is dm_c_bus_i.adr_i(DC_BYTE_W - 1 downto WORD_ADR_OFF);
    alias dm_c_bus_index_adr_a:dc_index_adr_t is dm_c_bus_i.adr_i(DC_BYTE_W - 1 downto DC_BYTE_W - DC_TOTAL_LINES_W);
    alias dc_bus_index_adr_a is dc_word_adr_r(DC_WORD_W - 1 downto DC_WORD_W - DC_TOTAL_LINES_W);
    alias dc_index_reg_a is dc_word_adr_r(DC_WORD_W - 1 downto DC_WORD_W - DC_TOTAL_LINES_W); 

  begin

    -- data ram default settings
    dc_data_ram_ena_s    <= '0';                                          -- deactivated
    dc_data_ram_we_s     <= (others =>'0');                               -- read mode
    dc_data_ram_adr_rd_s <= dm_c_bus_word_adr_a;                          -- L1 bus read address
    dc_data_ram_adr_wr_s <= dc_word_adr_r;                                -- registered write address
    dc_data_ram_dat_i_s  <= dc_dat_i_r;                                   -- registered data to write 

    -- tag ram default settings
    dc_tag_ram_ena_s     <= '0';                                          -- deactivated
    dc_tag_ram_we_s      <= '0';                                          -- read mode
    dc_tag_ram_adr_rd_s  <= dm_c_bus_index_adr_a;                         -- L1 bus read address
    dc_tag_ram_adr_wr_s  <= dc_index_reg_a;                               -- registered index address
    if(USE_WRITEBACK = true) then
      dc_tag_ram_dat_i_s <= DC_N_DIRTY & DC_VALID & dc_tag_r;             -- fetch registered tag 

      -- USE_WRITETHROUGH
    else
      dc_tag_ram_dat_i_s <= DC_VALID & dc_tag_r;                          -- fetch registered tag 

    end if;

    case dc_current_state_r is

      -- IDLE
      when DC_IDLE =>
        case wdc_i is

          -- flush
          when WDC_FLUSH =>
            if(USE_WRITEBACK = true) then
              dc_tag_ram_ena_s  <= '1';
            end if;

          -- invalid
          when WDC_INVALID =>

          -- memory operation
          when others =>

            -- read
            if((dm_c_bus_i.ena_i and not(dm_c_bus_i.we_i)) = '1') then
              dc_tag_ram_ena_s  <= '1';
              dc_data_ram_ena_s <= '1';
            end if;

            -- write 
            if((dm_c_bus_i.ena_i and dm_c_bus_i.we_i) = '1') then
              dc_tag_ram_ena_s  <= '1';
            end if;

         end case;

      -- READ 
      when DC_READ => 
        -- hit and valid / (previous) read done
        if(dc_tag_status_s = DC_HIT and dc_valid_flag_s = DC_VALID) then
          -- (next) memory operation
          case wdc_i is

            -- (next) flush
            when WDC_FLUSH => 
              if(USE_WRITEBACK = true) then
                dc_tag_ram_ena_s  <= '1';
              end if;

            -- (next) invalid
            when WDC_INVALID =>    

            -- (next) memory operation
            when others =>

              -- read
              if((dm_c_bus_i.ena_i and not(dm_c_bus_i.we_i)) = '1') then
                dc_tag_ram_ena_s  <= '1';
                dc_data_ram_ena_s <= '1';
              end if;

              -- write 
              if((dm_c_bus_i.ena_i and dm_c_bus_i.we_i) = '1') then
                dc_tag_ram_ena_s  <= '1';
              end if;

           end case;

          -- not(hit and valid)
        else
          if(USE_WRITEBACK = true) then
            -- dirty and valid / copy back the current cache line
            if(dc_dirty_flag_s = DC_DIRTY and dc_valid_flag_s = DC_VALID) then
              dc_data_ram_ena_s     <= '1';
              dc_data_ram_adr_rd_s  <= dc_bus_index_adr_a & dc_block_counter_r;    
            end if;
          end if;
  
        end if;

      -- WRITE 
      when DC_WRITE => 
        -- hit and valid / (previous) write accepted
        if(dc_tag_status_s = DC_HIT and dc_valid_flag_s = DC_VALID) then
          -- update data ram
          dc_data_ram_ena_s      <= '1'; 
          dc_data_ram_we_s       <= dc_sel_r;
          -- update tag ram
          dc_tag_ram_ena_s       <= '1';
          dc_tag_ram_we_s        <= '1';
          if(USE_WRITEBACK = true) then
            dc_tag_ram_dat_i_s   <= DC_DIRTY & DC_VALID & dc_tag_r;

            -- USE_WRITETHROUGH
          else
            dc_tag_ram_dat_i_s   <= DC_VALID & dc_tag_r;

          end if;

          -- (next) memory operation 
          -- data ram and tag ram already enabled
          -- use default settings

          -- not(hit and valid)
        else
          if(USE_WRITEBACK = true) then
            -- dirty and valid / copy back the current cache line
            if(dc_dirty_flag_s = DC_DIRTY and dc_valid_flag_s = DC_VALID) then
              dc_data_ram_ena_s    <= '1';
              dc_data_ram_adr_rd_s <= dc_bus_index_adr_a & dc_block_counter_r;
            end if;
          end if;

        end if;

      -- FETCH
      when DC_FETCH =>
        -- data valid / update data ram
        if(dc_bus_sync_ack_s = '1') then
          dc_data_ram_ena_s    <= '1';
          dc_data_ram_we_s     <= (others => '1');  
          dc_data_ram_adr_wr_s <= dc_bus_index_adr_a & dc_ack_counter_r;
          dc_data_ram_dat_i_s  <= dc_bus_out_i.dat_o;
        end if;

        -- line fetched / update tag ram
        if(dc_burst_done_s = '1') then
          dc_tag_ram_ena_s     <= '1';              
          dc_tag_ram_we_s      <= '1';              
        end if;

      -- COPY
      when DC_COPY =>
        if(USE_WRITEBACK = true) then
          -- next data from the data memory
          dc_data_ram_ena_s    <= '1';
          dc_data_ram_adr_rd_s <= dc_bus_index_adr_a & dc_block_counter_r;      -- block address
          dc_data_ram_adr_wr_s <= dc_bus_index_adr_a & dc_next_block_counter_r; -- prefetch block address        
        end if;
 
      -- FINISH FETCH
      when DC_END_FETCH =>   
        -- resume old request
        dc_tag_ram_ena_s      <= '1'; 
        dc_tag_ram_adr_rd_s   <= dc_bus_index_adr_a; 
        dc_data_ram_adr_rd_s  <= dc_word_adr_r;      

        if(USE_WRITEBACK = true) then
          -- finish read operation
          if(dc_we_r = '0') then
            dc_data_ram_ena_s <= '1';
          end if;

          -- USE_WRITETHROUGH
        else
          -- finish read operation
          dc_data_ram_ena_s   <= '1';

        end if;

      -- FLUSH
      when DC_FLUSH =>
        if(USE_WRITEBACK = true) then
          -- dirty and valid / copy back the current cache line
          if(dc_dirty_flag_s = DC_DIRTY and dc_valid_flag_s = DC_VALID) then
            dc_data_ram_ena_s    <= '1';
            dc_data_ram_adr_rd_s <= dc_bus_index_adr_a & dc_block_counter_r;
          end if;
        end if;

      -- INVALID
      when DC_INVALID =>
        -- invalidate cache line
        dc_tag_ram_ena_s   <= '1';
        dc_tag_ram_we_s    <= '1';
        dc_tag_ram_dat_i_s <= (others => '0'); 

      -- UNDEFINED FSM CODE
      when others =>

    end case;
    
  end process COMB_DC_MEMORY_CONTROL;

  --
  -- CACHE BUS CONTROL
  --
  --! This process implements the control of the external data cache bus module. 
  COMB_DC_CACHE_BUS_CONTROL: process(dc_valid_flag_s,
                                     dc_current_state_r,
                                     dc_word_adr_r,
                                     dc_tag_r,
                                     dc_req_done_r,
                                     dc_dat_i_r,
                                     dc_block_counter_r,
                                     dc_tag_status_s,
                                     dc_data_ram_dat_2_o_s,
                                     dc_dirty_flag_s,
                                     dc_burst_done_s,
                                     dc_force_prefetch_s, 
                                     dc_data_ram_dat_1_o_s,
                                     dc_sel_r,
                                     dc_tag_ram_dat_o_s)

    --
    -- Direct Mapped : mapping is [line address] MOD [nb of lines]
    --            
    -- +-----------------------------------------------------------+         
    -- |       Unused      |   Tag   |   Index   |   Line offset   |
    -- +-----------------------------------------------------------+
    --
    -- Use one valid bit per line 
    -- Use one dirty bit per line (write-back policy only)
    --

    alias dc_bus_index_adr_a is dc_word_adr_r(DC_WORD_W - 1 downto DC_WORD_W - DC_TOTAL_LINES_W);

  begin

    -- cache bus default settings
    dc_bus_ena_s     <= '0';                                          -- deactivated                                 
    dc_bus_we_s      <= '0';                                          -- read mode
    dc_bus_adr_s     <= DC_BUS_ADR_PADDING & dc_tag_r                 -- fetch address
                                           & dc_bus_index_adr_a 
                                           & dc_block_counter_r 
                                           & WORD_0_PADDING; 
    dc_bus_sel_s     <= (others => '1');                              -- word sel                 

    if(USE_WRITEBACK = true) then
      dc_bus_dat_i_s <= dc_data_ram_dat_2_o_s;                        -- data from memory 

      -- USE_WRITETHROUGH
    else
      dc_bus_dat_i_s <= dc_dat_i_r;                                   -- data registered

    end if;

    case dc_current_state_r is

      -- IDLE
      when DC_IDLE =>

      -- READ 
      when DC_READ => 
        -- miss or invalid
        if((dc_tag_status_s = DC_MISS or dc_valid_flag_s = DC_N_VALID)) then
          if(USE_WRITEBACK = true) then
            -- not updated or invalid / fetch the new cache line
            if(dc_dirty_flag_s = DC_N_DIRTY or dc_valid_flag_s = DC_N_VALID) then     
              dc_bus_ena_s <= '1';        
            end if;

            -- USE_WRITETHROUGH
          else
            -- fetch the new cache line    
            dc_bus_ena_s   <= '1';  

          end if;
        end if;

      -- WRITE 
      when DC_WRITE => 
        if(USE_WRITEBACK = true) then
          -- miss or invalid
          if((dc_tag_status_s = DC_MISS or dc_valid_flag_s = DC_N_VALID)) then
            -- not updated or invalid / fetch the new cache line
            if(dc_dirty_flag_s = DC_N_DIRTY or dc_valid_flag_s = DC_N_VALID) then     
              dc_bus_ena_s <= '1';        
            end if;     
          end if;

          -- USE_WRITETHROUGH
        else
          -- single copy 
          dc_bus_ena_s <= '1';
          dc_bus_we_s  <= '1';
          dc_bus_sel_s <= dc_sel_r;                                     
          dc_bus_adr_s <= DC_BUS_ADR_PADDING & dc_tag_r  
                                             & dc_word_adr_r
                                             & WORD_0_PADDING; 
        end if;

      -- FETCH
      when DC_FETCH =>
        -- request process
        if(dc_req_done_r = '0') then
          dc_bus_ena_s <= '1'; 
  
          -- request done 
        else
          dc_bus_ena_s <= '0'; 

        end if;

      -- COPY
      when DC_COPY =>
        -- request process
        if(dc_req_done_r = '0') then
          dc_bus_ena_s     <= '1'; 

          -- request done 
        else
          dc_bus_ena_s     <= '0'; 

        end if;

        -- we enable signal
        if(dc_burst_done_s = '1') then
          dc_bus_we_s      <= '0';

        else
          dc_bus_we_s      <= '1';

        end if;

        if(USE_WRITEBACK = true) then
          -- use when necessary prefetch data to remove the memory latency 
          if(dc_force_prefetch_s = '1') then
            dc_bus_dat_i_s <= dc_data_ram_dat_1_o_s; 
          end if;
          dc_bus_adr_s     <= DC_BUS_ADR_PADDING & dc_tag_ram_dat_o_s(dc_tag_t'length - 1 downto 0) 
                                                 & dc_bus_index_adr_a 
                                                 & dc_block_counter_r 
                                                 & WORD_0_PADDING;                      

          -- USE_WRITETHROUGH
        else
          dc_bus_sel_s     <= dc_sel_r;                                     
          dc_bus_adr_s     <= DC_BUS_ADR_PADDING & dc_tag_r  
                                                 & dc_word_adr_r
                                                 & WORD_0_PADDING;                      

        end if;

      -- FINISH FETCH
      when DC_END_FETCH =>   

      -- FLUSH
      when DC_FLUSH =>

      -- INVALID
      when DC_INVALID =>

      -- UNDEFINED FSM CODE
      when others =>

    end case;
    
  end process COMB_DC_CACHE_BUS_CONTROL;

  --//////////////////////////////////////////
  --              CYCLE PROCESS
  --//////////////////////////////////////////

  --
  -- DC L1 BUS REGISTERS
  --
  --! This process implements DC L1 bus input registers.
  CYCLE_DC_L1_IN_REG: process(clk_i)		
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0') then
        if(USE_WRITEBACK = true) then
          dc_wdc_r    <= WDC_NOP;
        end if;
    
      elsif(halt_dc_i = '0' and dc_busy_s = '0') then
        dc_dat_i_r    <= dm_c_bus_i.dat_i;
        dc_word_adr_r <= dm_c_bus_i.adr_i(DC_BYTE_W - 1 downto WORD_ADR_OFF);
        dc_tag_r      <= dm_c_bus_i.adr_i(DC_CACHEABLE_MEM_W - 1 downto DC_CACHEABLE_MEM_W - DC_TAG_W);
        dc_sel_r      <= dm_c_bus_i.sel_i;
        if(USE_WRITEBACK = true) then
          dc_we_r     <= dm_c_bus_i.we_i;
          dc_wdc_r    <= wdc_i;
        end if;
        
      end if;
      
    end if;
    
  end process CYCLE_DC_L1_IN_REG;

  --
  -- DC FSM 
  --
  --! This process implements the data cache fsm reg.
  CYCLE_DC_FSM: process(clk_i)		
  begin
      
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0') then
       dc_current_state_r <= DC_IDLE;
       
      elsif(halt_dc_i = '0') then
       dc_current_state_r <= dc_next_state_s;
         
      end if;
      
    end if;
    
  end process CYCLE_DC_FSM;
  
  GEN_DC_HALT_REQ_REG: if(USE_WRITEBACK = true) generate 

    --
    -- HALT DC REG 
    --
    --! This process implements the halt dc request reg. It is used to remember 
    --! if the cache request process was previously stalled. Such register was 
    --! added to properly control the prefetch mechanism of the cache entity to 
    --! deal with WISHBONE stall signals.
    CYCLE_DC_HALT_REQ_REG: process(clk_i)
    begin
    
      -- clock event
      if(clk_i'event and clk_i = '1') then

        -- sync reset
        if(rst_n_i = '0') then
           halt_dc_req_i_r <= '0';
           
        elsif(halt_dc_i = '0') then
           halt_dc_req_i_r <= halt_dc_req_i;
           
        end if;
        
      end if;  
    
    end process CYCLE_DC_HALT_REQ_REG;

  end generate GEN_DC_HALT_REQ_REG;

  --
  -- BLOCK COUNTER 
  --
  --! This process implements the block counter used for the burst process 
  --! during a block request.
  CYCLE_DC_BLOCK_COUNTER: process(clk_i)
  begin
  
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0' or (((USE_WRITEBACK = false and dc_single_req_done_s = '1') or 
                             dc_line_req_done_s = '1') and halt_dc_i = '0' and halt_dc_req_i = '0')) then
        dc_block_counter_r <= (others =>'0');
        
      elsif(halt_dc_i = '0' and halt_dc_req_i = '0' and dc_bus_sync_block_s = '1') then
        dc_block_counter_r <= std_ulogic_vector(unsigned(dc_block_counter_r) + 1);
        
      end if;
      
    end if;

  end process CYCLE_DC_BLOCK_COUNTER;  

  GEN_DC_NEXT_BLOCK_COUNTER: if(USE_WRITEBACK = true) generate

    --
    -- NEXT BLOCK COUNTER 
    --
    --! This process implements the block counter + 1 used for prefetching data.
    CYCLE_DC_NEXT_BLOCK_COUNTER: process(clk_i)
      constant one_c : std_ulogic_vector(0 downto 0) := "1";
    begin
    
      -- clock event
      if(clk_i'event and clk_i = '1') then

        -- sync reset
        if(rst_n_i = '0' or (dc_line_req_done_s = '1' and halt_dc_i = '0' and halt_dc_req_i = '0')) then
          dc_next_block_counter_r <= std_ulogic_vector(resize(unsigned(one_c),dc_counter_t'length));
          
        elsif(halt_dc_i = '0' and halt_dc_req_i = '0' and dc_bus_sync_block_s = '1') then
          dc_next_block_counter_r <= std_ulogic_vector(unsigned(dc_next_block_counter_r) + 1);
          
        end if;
        
      end if;

    end process CYCLE_DC_NEXT_BLOCK_COUNTER;  

  end generate GEN_DC_NEXT_BLOCK_COUNTER;

  --
  -- ACK COUNTER 
  --
  --! This process implements the ack counter used for the burst 
  --! process during the fetch state.
  CYCLE_DC_ACK_COUNTER: process(clk_i)
  begin
  
    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0' or (dc_burst_done_s = '1' and halt_dc_i = '0')) then
        dc_ack_counter_r <= (others =>'0');
        
      elsif(halt_dc_i = '0' and dc_bus_sync_ack_s = '1') then
        dc_ack_counter_r <= std_ulogic_vector(unsigned(dc_ack_counter_r) + 1);
        
      end if;
      
    end if;

  end process CYCLE_DC_ACK_COUNTER;  

  --
  -- REQ DONE FLAG
  --
  --! This process implements the request done flag register.
  CYCLE_DC_REQ_FLAG : process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset
      if(rst_n_i = '0' or (dc_burst_done_s = '1' and halt_dc_i = '0' and halt_dc_req_i = '0')) then
        dc_req_done_r <= '0';
        
      elsif(halt_dc_i = '0' and halt_dc_req_i = '0' ) then
        dc_req_done_r <= dc_req_done_s;
        
      end if;

    end if;

  end process CYCLE_DC_REQ_FLAG;

  GEN_DC_CYCLE_SYNC_DIV: if(C_S_CLK_DIV > 1.0) generate
  begin

    --
    -- SYNC BLOCK COUNTER 
    --
    --! This process implements the sync block counter used 
    --! to synchronize the core clock with the bus clock.
    CYCLE_DC_SYNC_BLOCK_COUNTER: process(clk_i)
    begin

      -- clock event
      if(clk_i'event and clk_i = '1') then

        -- sync reset
        if(rst_n_i = '0' or (((USE_WRITEBACK = false and dc_single_req_done_s = '1') or 
                               dc_line_req_done_s = '1') and halt_dc_i = '0' and halt_dc_req_i = '0')) then
          dc_sync_block_r <= (others =>'0');
          
        elsif(halt_dc_i = '0' and halt_dc_req_i = '0' and dc_bus_ena_s = '1' and dc_bus_next_grant_i = '1') then
          dc_sync_block_r <= std_ulogic_vector(unsigned(dc_sync_block_r) + 1);
          
        end if;
          
      end if;

    end process CYCLE_DC_SYNC_BLOCK_COUNTER;

    --
    -- SYNC ACK COUNTER 
    --
    --! This process implements the sync ack counter used to 
    --! synchronize the core clock with the bus clock.
    CYCLE_DC_SYNC_ACK_COUNTER: process(clk_i)
    begin

      -- clock event
      if(clk_i'event and clk_i = '1') then

        -- sync reset
        if(rst_n_i = '0' or (dc_burst_done_s = '1' and halt_dc_i = '0')) then
          dc_sync_ack_r <= (others =>'0');
          
        elsif(halt_dc_i = '0' and dc_bus_out_i.ack_o = '1') then
          dc_sync_ack_r <= std_ulogic_vector(unsigned(dc_sync_ack_r) + 1);
          
        end if;
          
      end if;

    end process CYCLE_DC_SYNC_ACK_COUNTER;

  end generate GEN_DC_CYCLE_SYNC_DIV;
  
end architecture be_sb_dcache;


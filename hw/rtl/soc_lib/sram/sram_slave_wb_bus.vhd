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
--! @file sram_slave_wb_bus.vhd                                					
--! @brief SRAM WISHBONE Bus Slave Interface  				
--! @author Lyonel Barthe
--! @version 1.2
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.2 22/10/2010 by Lyonel Barthe
-- Changed to a very basic implementation 
-- Removed write/read FIFOs 
-- Two implementations:
--  - when mclki >= 4*sclk_i, stalls are not required
--  - when mclki < 4*sclk_i, stalls are required
-- Don't use the handshaking protocol anymore 
-- Avoid the overhead due to the clock synchronization between 
-- the wb interface and the sram controller, and also because 
-- of timing issues
-- Use instead latency counters
--
-- Version 1.1 4/10/2010 by Lyonel Barthe
-- New version for asynchronous SRAM with sync FIFOs
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 12/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

library soc_lib;
use soc_lib.sram_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The module implements the WISHBONE bus slave interface of the SRAM
--! controller. According to clock settings, the controller will be able 
--! or not to perform read/write operations within one WISHBONE clock cycle. 
--! WISHBONE stall signal is used to stop the request of the master device 
--! when such operations cannot be done within one clock cycle. Note that
--! inputs and outputs are registered to deal with timing issues and
--! clock synchronization problems. This is a safe implementation made
--! for ISSI IS61LV25616AL components. The module supports pipelined 
--! read/write mode.
--

--! SRAM WISHBONE Bus Slave Interface Entity
entity sram_slave_wb_bus is

  generic
    (
      M_S_CLK_DIV : real := USER_M_S_CLK_DIV --! memory/system clock ratio
    );

  port
    (
      wb_bus_i    : in wb_slave_bus_i_t;     --! WISHBONE slave inputs
      wb_bus_o    : out wb_slave_bus_o_t;    --! WISHBONE slave outputs
      we_in_o     : out std_ulogic;          --! write enable signal
      re_in_o     : out std_ulogic;          --! read enable signal
      sel_in_o    : out sram_sel_t;          --! byte sel signal
      adr_in_o    : out sram_adr_t;          --! read/write address signal
      dat_in_o    : out sram_data_t;         --! data to write
      dat_out_i   : in sram_data_t;          --! data read
      ready_out_i : in std_ulogic            --! ack signal
    );
  
end sram_slave_wb_bus;

--! SRAM WISHBONE Bus Slave Interface Architecture
architecture be_sram_slave_wb_bus of sram_slave_wb_bus is

  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////

  signal wb_ack_o_r               : std_ulogic;               --! WISHBONE read/write ack reg
  signal wb_dat_o_r               : wb_bus_data_t;            --! WISHBONE data out reg
  signal wb_cyc_i_r               : std_ulogic;               --! WISHBONE cyc reg
  signal wb_stb_i_r               : std_ulogic;               --! WISHBONE stb reg
  signal wb_sel_i_r               : wb_bus_sel_t;             --! WISHBONE byte sel reg
  signal wb_dat_i_r               : wb_bus_data_t;            --! WISHBONE data in reg
  signal wb_we_i_r                : std_ulogic;               --! WISHBONE we reg
  signal wb_sram_adr_i_r          : sram_adr_t;               --! WISHBONE (SRAM) adr reg 
  signal wb_sram_ctr_state_r      : wb_sram_fsm_ctr_t;        --! WISHBONE SRAM fsm reg (only if M_S_CLK_DIV < 4.0)
  signal sram_lat_m_s_1_counter_r : sram_lat_m_s_1_counter_t; --! SRAM latency counter (only if M_S_CLK_DIV = 1.0)
  signal sram_lat_m_s_2_counter_r : sram_lat_m_s_2_counter_t; --! SRAM latency counter (only if M_S_CLK_DIV = 2.0)

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- CONTROL SIGNALS
  --
 
  signal wb_sram_ctr_next_state_s : wb_sram_fsm_ctr_t;   
  signal inc_lat_counter_s        : std_ulogic;
  signal rst_lat_counter_s        : std_ulogic;
  signal sram_done_s              : std_ulogic;

  --
  -- WB SIGNALS
  -- 

  signal wb_we_s                  : std_ulogic;
  signal wb_re_s                  : std_ulogic;
  signal wb_ack_s                 : std_ulogic;
  signal wb_stall_s               : std_ulogic;
  
  --
  -- SRAM CTR SIGNALS
  --

  signal re_in_s                  : std_ulogic;
  signal we_in_s                  : std_ulogic;
  signal sel_in_s                 : sram_sel_t;
  signal dat_in_s                 : sram_data_t;
  signal adr_in_s                 : sram_adr_t;
     
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  --
  -- WB SIGNALS
  --

  wb_bus_o.ack_o   <= wb_ack_o_r;
  wb_bus_o.dat_o   <= wb_dat_o_r;
  wb_bus_o.err_o   <= '0';           
  wb_bus_o.rty_o   <= '0';           
  wb_bus_o.stall_o <= wb_stall_s;   
  
  -- 
  -- SRAM CONTROLLER OUTPUTS
  --

  adr_in_o         <= adr_in_s;
  we_in_o          <= we_in_s;      
  re_in_o          <= re_in_s; 
  sel_in_o         <= sel_in_s;
  dat_in_o         <= dat_in_s;

  --
  -- MCLK >= 4*SCLK
  --

  GEN_COMB_SRAM_CTR_WITHOUT_STALLS: if(M_S_CLK_DIV >= 4.0) generate

    --
    -- ASSIGN SRAM CONTROLLER SIGNALS
    --

    adr_in_s      <= wb_sram_adr_i_r;
    we_in_s       <= (wb_cyc_i_r and wb_stb_i_r and wb_we_i_r);      
    re_in_s       <= (wb_cyc_i_r and wb_stb_i_r and not(wb_we_i_r)); 
    sel_in_s      <= wb_sel_i_r;
    dat_in_s      <= wb_dat_i_r;
  
    --
    -- ASSIGN WB CONTROL SIGNALS
    -- 
  
    wb_ack_s      <= wb_cyc_i_r and wb_stb_i_r; -- basic pipelined ack
                                                -- because read/write operations are done within one sclk cycle
    wb_stall_s    <= '0';                       -- not required

  end generate GEN_COMB_SRAM_CTR_WITHOUT_STALLS;

  --
  -- MCLK < 4*SCLK
  --

  GEN_COMB_SRAM_CTR_WITH_STALLS: if(M_S_CLK_DIV < 4.0 and M_S_CLK_DIV >= 1.0) generate

    --
    -- ASSIGN SRAM CONTROLLER SIGNALS
    --
  
    adr_in_s      <= wb_sram_adr_i_r;
    dat_in_s      <= wb_dat_i_r;
    sel_in_s      <= wb_sel_i_r;

    --
    -- SYNC SIGNALS FOR MCLK = SCLK
    --
   
    GEN_COMB_SRAM_DONE_M_S_1: if(M_S_CLK_DIV = 1.0) generate

      wb_ack_s    <= '1' when (to_integer(unsigned(sram_lat_m_s_1_counter_r)) = (SRAM_LAT_M_S_1 - 1)) else '0';
      sram_done_s <= '1' when (to_integer(unsigned(sram_lat_m_s_1_counter_r)) = SRAM_LAT_M_S_1) else '0';

    end generate GEN_COMB_SRAM_DONE_M_S_1;

    --
    -- SYNC SIGNALS FOR MCLK = 2*SCLK
    --

    GEN_COMB_SRAM_DONE_M_S_2: if(M_S_CLK_DIV = 2.0) generate

      wb_ack_s    <= '1' when (to_integer(unsigned(sram_lat_m_s_2_counter_r)) = (SRAM_LAT_M_S_2 - 1)) else '0';
      sram_done_s <= '1' when (to_integer(unsigned(sram_lat_m_s_2_counter_r)) = SRAM_LAT_M_S_2) else '0';

    end generate GEN_COMB_SRAM_DONE_M_S_2;
    
    --
    -- WISHBONE FSM CONTROL LOGIC
    --
    --! This process implements the control logic
    --! between WISHBONE requests and the SRAM controller,
    --! providing stall signals when necessary.
    COMB_SRAM_WB_FSM: process(wb_sram_ctr_state_r,
                              wb_cyc_i_r,
                              wb_stb_i_r,
                              wb_we_i_r,
                              sram_done_s)
    begin

      -- default assignments
      wb_sram_ctr_next_state_s <= wb_sram_ctr_state_r;
      wb_stall_s               <= '0';
      we_in_s                  <= '0';
      re_in_s                  <= '0';
      inc_lat_counter_s        <= '0';
      rst_lat_counter_s        <= '1';

      case wb_sram_ctr_state_r is 

        when WB_SRAM_IDLE =>
          -- bus request
          if(wb_cyc_i_r = '1' and wb_stb_i_r = '1') then
            wb_stall_s               <= '1'; 
            inc_lat_counter_s        <= '1';
            rst_lat_counter_s        <= '0';
            wb_sram_ctr_next_state_s <= WB_SRAM_BUSY;

            -- write
            if(wb_we_i_r = '1') then
              we_in_s <= '1';

              -- read
            else
              re_in_s <= '1';

            end if;

          end if;

        when WB_SRAM_BUSY =>
          wb_stall_s        <= '1';
          inc_lat_counter_s <= '1';
          rst_lat_counter_s <= '0';

          if(sram_done_s = '1') then
            wb_stall_s               <= '0';
            inc_lat_counter_s        <= '0';
            rst_lat_counter_s        <= '1';
            wb_sram_ctr_next_state_s <= WB_SRAM_IDLE;
          end if;

        when others =>
          wb_sram_ctr_next_state_s <= WB_SRAM_IDLE; -- force a reset / safe implementation
          report "wb sram fsm process: illegal state" severity warning;

      end case;

    end process COMB_SRAM_WB_FSM;
  
  end generate GEN_COMB_SRAM_CTR_WITH_STALLS;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- WB SLAVE BUS REGISTERED INPUTS
  --
  --! This process implements WISHBONE slave input registers.
  CYCLE_SRAM_WB_SLV_IN_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_cyc_i_r      <= '0';
        wb_stb_i_r      <= '0';
        
      elsif(wb_stall_s = '0') then
        wb_sram_adr_i_r <= wb_bus_i.adr_i(SRAM_WORD_W + WB_WORD_ADR_OFF - 1 downto WB_WORD_ADR_OFF);
        wb_dat_i_r      <= wb_bus_i.dat_i;
        wb_cyc_i_r      <= wb_bus_i.cyc_i;
        wb_stb_i_r      <= wb_bus_i.stb_i;
        wb_sel_i_r      <= wb_bus_i.sel_i;
        wb_we_i_r       <= wb_bus_i.we_i;
        
      end if;
      
    end if;

  end process CYCLE_SRAM_WB_SLV_IN_REG;

  --
  -- WB SLAVE BUS REGISTERED OUTPUTS
  --
  --! This process implements WISHBONE slave output registers.
  CYCLE_SRAM_WB_SLV_OUT_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_ack_o_r <= '0';
          
      else
        wb_ack_o_r <= wb_ack_s;
        wb_dat_o_r <= dat_out_i;
        
      end if;
      
    end if;

  end process CYCLE_SRAM_WB_SLV_OUT_REG;

  --
  -- MCLK < 4*SCLK
  --
  
  GEN_CYCLE_SRAM_CTR_WITH_STALLS: if(M_S_CLK_DIV < 4.0 and M_S_CLK_DIV >= 1.0) generate
  begin

    --
    -- WB SRAM FSM REGISTER
    -- 
    --! This process implements the WISHBONE SRAM control register.
    CYCLE_SRAM_WB_CTR_FSM_REG: process(wb_bus_i.clk_i)
    begin

      -- clock event 
      if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
        -- sync reset
        if(wb_bus_i.rst_i = '1') then
          wb_sram_ctr_state_r <= WB_SRAM_IDLE;
          
        else
          wb_sram_ctr_state_r <= wb_sram_ctr_next_state_s;
          
        end if;
      
      end if;

    end process CYCLE_SRAM_WB_CTR_FSM_REG;

    GEN_SRAM_LAT_COUNTER_M_S_1: if(M_S_CLK_DIV = 1.0) generate

      --
      -- SRAM LATENCY COUNTER
      -- 
      --! This process implements the sram latency counter
      --! used to synchronize the sram controller and the
      --! WISHBONE interface. 
      CYCLE_SRAM_LAT_M_S_1_COUNTER: process(wb_bus_i.clk_i)
      begin

        -- clock event 
        if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
        
          -- sync reset
          if(wb_bus_i.rst_i = '1' or rst_lat_counter_s = '1') then
            sram_lat_m_s_1_counter_r <= (others => '0');
            
          elsif(inc_lat_counter_s = '1') then
            sram_lat_m_s_1_counter_r <= std_ulogic_vector(unsigned(sram_lat_m_s_1_counter_r) + 1);
            
          end if;
        
        end if;

      end process CYCLE_SRAM_LAT_M_S_1_COUNTER;

    end generate GEN_SRAM_LAT_COUNTER_M_S_1;

    GEN_SRAM_LAT_COUNTER_M_S_2: if(M_S_CLK_DIV = 2.0) generate

      --
      -- SRAM LATENCY COUNTER
      -- 
      --! This process implements the sram latency counter
      --! used to synchronize the sram controller and the
      --! WISHBONE interface. 
      CYCLE_SRAM_LAT_M_S_2_COUNTER: process(wb_bus_i.clk_i)
      begin

        -- clock event 
        if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
        
          -- sync reset
          if(wb_bus_i.rst_i = '1' or rst_lat_counter_s = '1') then
            sram_lat_m_s_2_counter_r <= (others => '0');
            
          elsif(inc_lat_counter_s = '1') then
            sram_lat_m_s_2_counter_r <= std_ulogic_vector(unsigned(sram_lat_m_s_2_counter_r) + 1);
            
          end if;
        
        end if;

      end process CYCLE_SRAM_LAT_M_S_2_COUNTER;

    end generate GEN_SRAM_LAT_COUNTER_M_S_2;

  end generate GEN_CYCLE_SRAM_CTR_WITH_STALLS;

end be_sram_slave_wb_bus;


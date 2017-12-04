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
--! @file sram_controller.vhd                                					
--! @brief 32-bit Asynchronous SRAM Controller 			
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 30/09/2010 by Lyonel Barthe
-- Stable version
-- SRAM controller main coding style from the book 
-- "FPGA PROTOTYPING BY VHDL EXAMPLES"
-- by Pong P. Chu
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

library soc_lib;
use soc_lib.sram_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The module implements a basic asynchronous SRAM controller
--! providing large timing margins (safe implementation / not
--! optimized / inputs and outputs are registered). It was made
--! for ISSI IS61LV25616AL components. Read/write operations 
--! require 2 clock cycles to complete, but back-back operations
--! require 3 clock cycles. It should work for any kind of SRAMs
--! as long as timing constraints are not violated. 
--

--! 32-bit SRAM Controller Entity
entity sram_controller is

  generic
    (
      M_S_CLK_DIV  : real := USER_M_S_CLK_DIV --! memory/system clock ratio
    );

  port
    (
      sram_in_o    : out sram_i_t;            --! SRAM interface control inputs 
      sram_data_io : inout sram_io_t;         --! SRAM interface data in/out
      we_i         : in std_ulogic;           --! write enable signal
      re_i         : in std_ulogic;           --! read enable signal
      adr_i        : in sram_adr_t;           --! read/write address signal
      sel_i        : in sram_sel_t;           --! byte sel signal
      dat_i        : in sram_data_t;          --! data to write
      dat_o        : out sram_data_t;         --! data read
      ready_o      : out std_ulogic;          --! ready signal
      clk_i        : in std_ulogic;           --! controller clock
      rst_n_i      : in std_ulogic            --! active-low reset signal      
    );
  
end sram_controller;

--! 32-bit ASRAM Controller Architecture
architecture be_sram_controller of sram_controller is

  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////


  signal sram_ctr_state_r      : sram_fsm_ctr_t; --! SRAM fsm reg
  signal sram_adr_r            : sram_adr_t;     --! SRAM address reg
  signal sram_dat_i_r          : sram_data_t;    --! SRAM data in reg
  signal sram_sel_n_r          : sram_sel_t;     --! SRAM byte sel reg
  signal sram_tris_wr_r        : std_ulogic;     --! SRAM tristate write control reg
  signal sram_we_n_r           : std_ulogic;     --! SRAM active low write enable control reg
  signal sram_oe_n_r           : std_ulogic;     --! SRAM active low output enable control reg
  signal sram_dat_o_r          : sram_data_t;    --! SRAM data out reg
  signal sram_ready_r          : std_ulogic;     --! SRAM ready reg
  signal sram_sync_r           : std_ulogic_vector(log2(natural(M_S_CLK_DIV)) - 1 downto 0); --! SRAM memory/system clock sync counter

  -- force synthesizer to pack sram registers into IOB 
  -- avoid sram timing violations!!!
  attribute iob: string;
  attribute iob of sram_adr_r   : signal is "true";
  attribute iob of sram_dat_i_r : signal is "true";
  attribute iob of sram_dat_o_r : signal is "true";
  attribute iob of sram_we_n_r  : signal is "true";
  attribute iob of sram_oe_n_r  : signal is "true";
  attribute iob of sram_sel_n_r : signal is "true";

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////
  
  --
  -- IP SIGNALS
  --

  signal sram_ctr_next_state_s : sram_fsm_ctr_t;                 
  signal sram_tris_wr_s        : std_ulogic;                                        
  signal sram_we_n_s           : std_ulogic;                                        
  signal sram_oe_n_s           : std_ulogic;
  signal sram_ready_s          : std_ulogic;                                        
  signal load_adr_i_s          : std_ulogic;
  signal load_dat_i_s          : std_ulogic;
  signal load_dat_o_s          : std_ulogic;
  signal we_sync_s             : std_ulogic;
  signal re_sync_s             : std_ulogic;
     
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --

  --
  -- SRAM INTERFACE
  --

  sram_in_o.ce1_n_i <= '0';
  sram_in_o.ce2_n_i <= '0';
  sram_in_o.we_n_i  <= sram_we_n_r;
  sram_in_o.ub1_n_i <= sram_sel_n_r(3); -- MSB
  sram_in_o.lb1_n_i <= sram_sel_n_r(2);   
  sram_in_o.ub2_n_i <= sram_sel_n_r(1);   
  sram_in_o.lb2_n_i <= sram_sel_n_r(0); -- LSB
  sram_in_o.a_i     <= sram_adr_r; 
  sram_in_o.oe_n_i  <= sram_oe_n_r;
  sram_data_io      <= std_logic_vector(sram_dat_i_r) when (sram_tris_wr_r = '1') else (others =>'Z');

  --
  -- IP SIGNALS
  --

  ready_o           <= sram_ready_r;
  dat_o             <= sram_dat_o_r; 

  --
  -- ASSIGN INTERNAL SIGNALS
  --
 
  --
  -- SYNC SIGNALS FOR MCLK > SCLK
  --

  GEN_COMB_SRAM_CTR_SYNC_DIV: if(M_S_CLK_DIV > 1.0) generate
  begin

    we_sync_s <= we_i when (to_integer(unsigned(sram_sync_r)) = 0) else '0';
    re_sync_s <= re_i when (to_integer(unsigned(sram_sync_r)) = 0) else '0';

  end generate GEN_COMB_SRAM_CTR_SYNC_DIV;

  --
  -- SYNC SIGNALS FOR MCLK = SCLK
  --

  GEN_COMB_SRAM_CTR_SYNC_NO_DIV: if(M_S_CLK_DIV = 1.0) generate
  begin

    we_sync_s <= we_i;
    re_sync_s <= re_i;

  end generate GEN_COMB_SRAM_CTR_SYNC_NO_DIV;

  --
  -- SRAM CTR FSM
  --
  --! This process implements a standard SRAM controller
  --! using a FSM providing a safe but not optimized 
  --! implementation with large timing margins. 
  COMB_SRAM_FSM: process(sram_ctr_state_r,
                         we_sync_s,
                         re_sync_s)
  begin  

    -- default assignments
    sram_ctr_next_state_s <= sram_ctr_state_r;
    sram_ready_s          <= '1';
    load_dat_i_s          <= '0';
    load_dat_o_s          <= '0';
    load_adr_i_s          <= '0';
    sram_tris_wr_s        <= '0';
    sram_we_n_s           <= '1';
    sram_oe_n_s           <= '1';

    case sram_ctr_state_r is 

      when SRAM_IDLE =>
        
        -- write
        if(we_sync_s = '1') then
          sram_ctr_next_state_s <= SRAM_WRITE_1;
          load_adr_i_s          <= '1'; 
          load_dat_i_s          <= '1'; 
          sram_ready_s          <= '0';
        end if;

        -- read
        if(re_sync_s = '1') then
          sram_ctr_next_state_s <= SRAM_READ_1;
          load_adr_i_s          <= '1';
          sram_ready_s          <= '0';
        end if;

      when SRAM_READ_1 =>
        sram_ctr_next_state_s <= SRAM_READ_2;
        sram_oe_n_s           <= '0'; 
        sram_ready_s          <= '0';

      when SRAM_READ_2 =>
        sram_ctr_next_state_s <= SRAM_IDLE;
        sram_oe_n_s           <= '0'; 
        load_dat_o_s          <= '1';

      when SRAM_WRITE_1 =>
        sram_ctr_next_state_s <= SRAM_WRITE_2;
        sram_tris_wr_s        <= '1'; 
        sram_we_n_s           <= '0'; 
        sram_ready_s          <= '0';
    
      when SRAM_WRITE_2 =>
        sram_ctr_next_state_s <= SRAM_IDLE;
        sram_tris_wr_s        <= '1'; 

      when others =>
        sram_ctr_next_state_s <= SRAM_IDLE; -- force a reset / safe implementation
        report "sram controller fsm process: illegal state" severity warning;

    end case;

  end process COMB_SRAM_FSM;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- SRAM REGISTERED INPUTS
  --
  --! This process implements SRAM input registers.
  CYCLE_SRAM_IN_REG: process(clk_i)		
  begin
        
    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      -- sync reset
      if(rst_n_i = '0') then
        sram_tris_wr_r    <= '0';
        sram_we_n_r       <= '1';
        sram_oe_n_r       <= '1';
        
      else
        if(load_dat_i_s = '1') then 
          sram_dat_i_r    <= dat_i;
        end if;
        if(load_adr_i_s = '1') then 
          sram_adr_r      <= adr_i;
        end if;
        sram_tris_wr_r    <= sram_tris_wr_s;
        sram_we_n_r       <= sram_we_n_s;
        sram_oe_n_r       <= sram_oe_n_s;
        for i in 0 to (sram_sel_t'length - 1) loop
          sram_sel_n_r(i) <= not(sel_i(i));     
        end loop;

      end if;

    end if;
    
  end process CYCLE_SRAM_IN_REG;

  --
  -- SRAM REGISTERED OUTPUTS
  --
  --! This process implements SRAM output registers.
  --! Note that read data are maintained until next
  --! read.
  CYCLE_SRAM_OUT_REG: process(clk_i)		
  begin
        
    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      -- sync reset
      if(rst_n_i = '0') then
        sram_ready_r <= '0';
        
      else
        if(load_dat_o_s = '1') then
          sram_dat_o_r <= std_ulogic_vector(sram_data_io);
        end if;
        sram_ready_r   <= sram_ready_s;
        
      end if;

    end if;

    
  end process CYCLE_SRAM_OUT_REG;

  --
  -- SRAM CTR FSM
  --
  --! This process implements the SRAM control reg.
  CYCLE_SRAM_FSM: process(clk_i)		
  begin
        
    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      -- sync reset
      if(rst_n_i = '0') then
        sram_ctr_state_r <= SRAM_IDLE;
        
      else
        sram_ctr_state_r <= sram_ctr_next_state_s;
        
      end if;

    end if;
    
  end process CYCLE_SRAM_FSM;

  --
  -- MCLK > SCLK
  --

  GEN_CYCLE_SRAM_CTR_SYNC_DIV : if (M_S_CLK_DIV > 1.0) generate
  begin

    --
    -- SYNC COUNTER
    --
    --! This process implements the ack counter used
    --! during the burst process.
    CYCLE_SRAM_SYNC_COUNTER: process(clk_i)
    begin

      -- clock event 
      if(clk_i'event and clk_i = '1') then
      
        -- sync reset
        if(rst_n_i = '0') then
          sram_sync_r <= (others => '0');
          
        elsif(we_i = '1' or re_i = '1') then
          sram_sync_r <= std_ulogic_vector(unsigned(sram_sync_r) + 1);
          
        end if;
      
      end if;   

    end process CYCLE_SRAM_SYNC_COUNTER;

  end generate GEN_CYCLE_SRAM_CTR_SYNC_DIV;  

end be_sram_controller;


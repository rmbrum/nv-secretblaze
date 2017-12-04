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
--! @file dram_slave_wb_bus.vhd                                					
--! @brief DRAM WISHBONE Bus Slave Interface  				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 08/2012 by Lyonel Barthe
-- Stable version
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

library soc_lib;
use soc_lib.dram_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The module implements the WISHBONE bus slave interface of the DRAM
--! controller provided by Xilinx (MIG 3.7). Its purpose is to handle
--! the command, write, and read FIFOs of the controller according to
--! the requests from the WISHBONE bus. Both single and burst memory
--! operations are supported. 
--

--! DRAM WISHBONE Bus Slave Interface Entity
entity dram_slave_wb_bus is

  port
    (
      wb_bus_i                 : in wb_slave_bus_i_t;  --! WISHBONE slave inputs
      wb_bus_o                 : out wb_slave_bus_o_t; --! WISHBONE slave outputs
      c3_p0_cmd_en_in_o        : out std_logic;        --! MIG command FIFO enable signal
      c3_p0_cmd_instr_in_o     : out mig_inst_t;       --! MIG command FIFO instruction signal
      c3_p0_cmd_bl_in_o        : out mig_bl_t;         --! MIG command FIFO burst signal
      c3_p0_cmd_byte_addr_in_o : out mig_adr_t;        --! MIG command FIFO byte address signal
      c3_p0_cmd_full_out_i     : in std_logic;         --! MIG command FIFO full flag signal
      c3_p0_cmd_empty_out_i    : in std_logic;         --! MIG command FIFO full empty signal         
      c3_p0_wr_en_in_o         : out std_logic;        --! MIG write FIFO enable signal
      c3_p0_wr_mask_in_o       : out mig_mask_t;       --! MIG write FIFO mask signal
      c3_p0_wr_data_in_o       : out mig_data_t;       --! MIG write FIFO data signal
      c3_p0_wr_full_out_i      : in std_logic;         --! MIG write FIFO full flag signal
      c3_p0_wr_empty_out_i     : in std_logic;         --! MIG write FIFO empty flag signal
      c3_p0_wr_count_out_i     : in mig_counter_t;     --! MIG write FIFO counter signal
      c3_p0_rd_en_in_o         : out std_logic;        --! MIG read FIFO enable signal
      c3_p0_rd_data_out_i      : in mig_data_t;        --! MIG read FIFO data signal
      c3_p0_rd_full_out_i      : in std_logic;         --! MIG read FIFO full flag signal
      c3_p0_rd_empty_out_i     : in std_logic;         --! MIG read FIFO empty flag signal
      c3_p0_rd_count_out_i     : in mig_counter_t      --! MIG read FIFO counter signal
    );
  
end dram_slave_wb_bus;

--! SRAM WISHBONE Bus Slave Interface Architecture
architecture be_dram_slave_wb_bus of dram_slave_wb_bus is

  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////

  signal wb_ack_o_r               : std_ulogic;        --! WISHBONE read/write ack reg
  signal wb_dat_o_r               : wb_bus_data_t;     --! WISHBONE data out reg
  signal wb_cyc_i_r               : std_ulogic;        --! WISHBONE cyc reg
  signal wb_stb_i_r               : std_ulogic;        --! WISHBONE stb reg
  signal wb_sel_i_r               : wb_bus_sel_t;      --! WISHBONE byte sel reg
  signal wb_dat_i_r               : wb_bus_data_t;     --! WISHBONE data in reg
  signal wb_we_i_r                : std_ulogic;        --! WISHBONE we reg
  signal wb_adr_i_r               : wb_bus_adr_t;      --! WISHBONE adr reg
  signal wb_bte_i_r               : wb_bus_bte_t;      --! WISHBONE burst type reg
  signal wb_cti_i_r               : wb_bus_cti_t;      --! WISHBONE cycle id reg
  signal wb_bl_i_r                : wb_bus_bl_t;       --! WISHBONE burst length reg  
  signal wb_dram_ctr_state_r      : wb_dram_fsm_ctr_t; --! WISHBONE DRAM fsm reg 
  signal dram_cmd_byte_addr_r     : mig_adr_t;         --! DRAM byte addr reg
  signal ack_counter_r            : mig_bl_t;          --! DRAM ack counter reg  
  
  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal wb_dram_ctr_next_state_s : wb_dram_fsm_ctr_t; 
  signal load_byte_adr_i_s        : std_ulogic;  
  signal inc_ack_counter_s        : std_ulogic;  
  signal rst_ack_counter_s        : std_ulogic;  
  signal wb_ack_s                 : std_ulogic;
  signal wb_stall_s               : std_ulogic;
  signal c3_p0_cmd_en_s           : std_logic;
  signal c3_p0_cmd_instr_s        : mig_inst_t;
  signal c3_p0_cmd_bl_s           : mig_bl_t;  
  signal c3_p0_wr_en_s            : std_logic;
  signal c3_p0_rd_en_s            : std_logic;
       
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
  
  wb_bus_o.ack_o           <= wb_ack_o_r;
  wb_bus_o.dat_o           <= wb_dat_o_r;
  wb_bus_o.err_o           <= '0';           
  wb_bus_o.rty_o           <= '0';           
  wb_bus_o.stall_o         <= wb_stall_s;  
  
  --
  -- MIG INTERFACE
  --

  c3_p0_cmd_en_in_o        <= c3_p0_cmd_en_s;
  c3_p0_cmd_instr_in_o     <= c3_p0_cmd_instr_s;  
  c3_p0_cmd_bl_in_o        <= std_logic_vector(wb_bl_i_r);
  c3_p0_cmd_byte_addr_in_o <= std_logic_vector(wb_adr_i_r(29 downto 0));
  c3_p0_wr_en_in_o         <= c3_p0_wr_en_s;
  c3_p0_wr_mask_in_o       <= std_logic_vector(not(wb_sel_i_r));
  c3_p0_wr_data_in_o       <= std_logic_vector(wb_dat_i_r);
  c3_p0_rd_en_in_o         <= c3_p0_rd_en_s; 
    
  --
  -- WISHBONE FSM CONTROL LOGIC
  --
  --! This process implements the control logic between 
  --! WISHBONE requests and the DRAM controller.
  COMB_DRAM_WB_FSM: process(wb_dram_ctr_state_r,
                            wb_cyc_i_r,
                            wb_stb_i_r,
                            wb_we_i_r,
                            wb_cti_i_r,
                            wb_bte_i_r,
                            wb_bl_i_r,
                            ack_counter_r,
                            c3_p0_rd_empty_out_i,
                            c3_p0_wr_empty_out_i,
                            c3_p0_cmd_empty_out_i)
  begin

    -- default assignments
    wb_dram_ctr_next_state_s <= wb_dram_ctr_state_r;
    load_byte_adr_i_s        <= '0';
    inc_ack_counter_s        <= '0';
    rst_ack_counter_s        <= '0';
    wb_ack_s                 <= '0';
    wb_stall_s               <= '0';    
    c3_p0_cmd_en_s           <= '0';
    c3_p0_cmd_instr_s        <= MIG_INST_READ;            
    c3_p0_wr_en_s            <= '0';
    c3_p0_rd_en_s            <= '0';
         
    case wb_dram_ctr_state_r is 

      when WB_DRAM_IDLE =>  
        rst_ack_counter_s                <= '1';
        load_byte_adr_i_s                <= '1';   
           
        -- bus request
        if(wb_cyc_i_r = '1' and wb_stb_i_r = '1') then       
             
          -- busy 
          if(c3_p0_cmd_empty_out_i = '0' or c3_p0_wr_empty_out_i = '0') then
            wb_stall_s                   <= '1';
            
          else             
            -- write
            if(wb_we_i_r = '1') then        
              -- fire
              if(wb_cti_i_r = WB_CLASSIC_CYCLE or 
                 wb_cti_i_r = WB_END_OF_BURST or (wb_cti_i_r = WB_INC_BURST_CYCLE and 
                                                  wb_bte_i_r = WB_LINEAR_BURST)) then
                wb_dram_ctr_next_state_s <= WB_DRAM_WRITE;
                c3_p0_wr_en_s            <= '1';
                wb_ack_s                 <= '1';
                load_byte_adr_i_s        <= '0'; 
                
                -- not supported
              else
                report "wb dram fsm process: wb bus operation not supported in wb_dram_idle state (write)" severity warning;             
                
              end if;                                                                                                                  
              
              -- read
            else
              -- fire            
              if(wb_cti_i_r = WB_CLASSIC_CYCLE or 
                 wb_cti_i_r = WB_END_OF_BURST or (wb_cti_i_r = WB_INC_BURST_CYCLE and 
                                                  wb_bte_i_r = WB_LINEAR_BURST)) then
                wb_dram_ctr_next_state_s <= WB_DRAM_READ;  
                c3_p0_cmd_en_s           <= '1';    
                load_byte_adr_i_s        <= '0';    
                                                                
                -- not supported          
              else
                report "wb dram fsm process: wb bus operation not supported in wb_dram_idle state (read)" severity warning;     
                                    
              end if; 

              -- synthesis translate_off
              if(c3_p0_rd_empty_out_i = '0') then
                report "wb dram fsm process: read fifo is not empty in wb_dram_idle state (read)" severity warning; 
              end if;                        
              -- synthesis translate_on                            
              
            end if;
         
          end if;              

        end if;     

      when WB_DRAM_WRITE =>        
        -- burst
        if(wb_cyc_i_r = '1' and wb_stb_i_r = '1' and wb_we_i_r = '1') then
          c3_p0_wr_en_s            <= '1';
          wb_ack_s                 <= '1';   
  
          -- done
        elsif(wb_cyc_i_r = '1' and wb_stb_i_r = '0' and wb_we_i_r = '1') then 
          wb_dram_ctr_next_state_s <= WB_DRAM_IDLE;  
          c3_p0_cmd_en_s           <= '1'; 
          c3_p0_cmd_instr_s        <= MIG_INST_WRITE;  
          
          -- error
        else  
          wb_dram_ctr_next_state_s <= WB_DRAM_IDLE; -- force a reset / safe implementation        
          report "wb dram fsm process: illegal state in wb_dram_write" severity warning; 
                                       
        end if;

      when WB_DRAM_READ =>
        -- data available
        if(c3_p0_rd_empty_out_i = '0') then 
          wb_ack_s                   <= '1';    
          inc_ack_counter_s          <= '1';    
          c3_p0_rd_en_s              <= '1';    
          
          -- last word
          if(unsigned(ack_counter_r) = unsigned(wb_bl_i_r)) then 
            wb_dram_ctr_next_state_s <= WB_DRAM_IDLE;   
                   
          end if;
                       
        end if;     
        
      when others =>
        wb_dram_ctr_next_state_s <= WB_DRAM_IDLE; -- force a reset / safe implementation
        report "wb dram fsm process: illegal state" severity warning;

    end case;

  end process COMB_DRAM_WB_FSM;  

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- WB SLAVE BUS REGISTERED INPUTS
  --
  --! This process implements WISHBONE slave input registers.
  CYCLE_DRAM_WB_SLV_IN_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_cyc_i_r   <= '0';
        wb_stb_i_r   <= '0';
        
      elsif(wb_stall_s = '0') then
        if(load_byte_adr_i_s = '1') then
          wb_adr_i_r <= wb_bus_i.adr_i;
        end if;
        wb_dat_i_r   <= wb_bus_i.dat_i;
        wb_cyc_i_r   <= wb_bus_i.cyc_i;
        wb_stb_i_r   <= wb_bus_i.stb_i;
        wb_sel_i_r   <= wb_bus_i.sel_i;
        wb_we_i_r    <= wb_bus_i.we_i;
        wb_cti_i_r   <= wb_bus_i.cti_i;
        wb_bte_i_r   <= wb_bus_i.bte_i;
        wb_bl_i_r    <= wb_bus_i.bl_i;
        
      end if;
      
    end if;

  end process CYCLE_DRAM_WB_SLV_IN_REG;

  --
  -- WB SLAVE BUS REGISTERED OUTPUTS
  --
  --! This process implements WISHBONE slave output registers.
  CYCLE_DRAM_WB_SLV_OUT_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_ack_o_r <= '0';
          
      else
        wb_ack_o_r <= wb_ack_s;
        wb_dat_o_r <= std_ulogic_vector(c3_p0_rd_data_out_i);
        
      end if;
      
    end if;

  end process CYCLE_DRAM_WB_SLV_OUT_REG;
  
  --
  -- WB DRAM FSM REGISTER
  -- 
  --! This process implements the WISHBONE DRAM control register.
  CYCLE_DRAM_WB_CTR_FSM_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
    
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_dram_ctr_state_r <= WB_DRAM_IDLE;
        
      else
        wb_dram_ctr_state_r <= wb_dram_ctr_next_state_s;
        
      end if;
    
    end if;

  end process CYCLE_DRAM_WB_CTR_FSM_REG;  
  
  --
  -- WB DRAM ACK COUNTER
  -- 
  --! This process implements the WISHBONE DRAM ack counter.
  CYCLE_DRAM_ACK_COUNTER_REG: process(wb_bus_i.clk_i)
  begin
  
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
    
      -- sync reset
      if(wb_bus_i.rst_i = '1' or rst_ack_counter_s = '1') then
        ack_counter_r <= (others => '0');
        
      elsif(inc_ack_counter_s = '1') then
        ack_counter_r <= std_logic_vector(unsigned(ack_counter_r) + 1);
        
      end if;
    
    end if;  
  
  end process CYCLE_DRAM_ACK_COUNTER_REG;    

end be_dram_slave_wb_bus;


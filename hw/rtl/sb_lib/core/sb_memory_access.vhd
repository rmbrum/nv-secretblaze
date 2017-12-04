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
--! @file sb_memory_access.vhd                                					
--! @brief SecretBlaze Memory Access Stage Implementation                    				
--! @author Lyonel Barthe
--! @version 1.2
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.2 22/02/2010 by Lyonel Barthe
-- Added the support of pipelined MULT or BS instructions
--
-- Version 1.1 23/12/2010 by Lyonel Barthe
-- Added more forwarding trade-offs
--
-- Version 1.0b 1/07/2010 by Lyonel Barthe
-- Minor fix - memory stall signals are now managed in the memory manager entity
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.2 8/04/2010 by Lyonel Barthe
-- Clean up version
--
-- Version 0.1 15/02/2010 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_isa.all;

library config_lib;
use config_lib.sb_config.all;

--
--! As its name suggests, the Memory Access (MA) stage is in charge to 
--! handle the communication between the datapath and the data memory 
--! sub-system of the processor. The fourth stage of the SecretBlaze’s 
--! pipeline provides a data L1-memory interface for standard memory 
--! components, in the same way as the IF stage for the instruction 
--! memory. However, the data interface is a bit more complex than 
--! the instruction one because it requires more control signals to 
--! distinguish read/write operations with byte, half-word, and word 
--! data types. A write enable signal is used to indicate the type of 
--! the memory operation, while a 4-bit selection signal is provided 
--! to access individual bytes.
--! 
--! At last, to improve the overall performance of the processor, the 
--! MA stage can be configured to pipeline critical paths of the ALU. 
--! This optimization was introduced to take advantage of FPGA architectures.
--! More detailed information about its implementation are given in:
--! Lyonel Barthe et al., "Optimizing an Open-Source Processor for FPGAs: 
--! A Case Study," FPL, pp. 551-556, 2011.
--

--! SecretBlaze Memory Access Stage Entity
entity sb_memory_access is

  generic
    (
      USE_BTC       : boolean := USER_USE_BTC;       --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
      USE_MULT      : natural := USER_USE_MULT;      --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
      USE_PIPE_MULT : boolean := USER_USE_PIPE_MULT; --! if true, it will implement a pipelined 32-bit multiplier using 17x17 signed multipliers
      USE_BS        : natural := USER_USE_BS;        --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
      USE_PIPE_BS   : boolean := USER_USE_PIPE_BS;   --! it true, it will implement a pipelined barrel shifter
      USE_CLZ       : boolean := USER_USE_CLZ;       --! if true, it will implement the count leading zeros instruction
      USE_PIPE_CLZ  : boolean := USER_USE_PIPE_CLZ   --! it true, it will implement a pipelined clz instruction
    );  

  port
    (
      ma_i          : in ma_stage_i_t;               --! memory access inputs
      ma_o          : out ma_stage_o_t;              --! memory access outputs
      dm_bus_in_o   : out dm_bus_i_t;                --! data L1 bus inputs
      dm_bus_out_i  : in dm_bus_o_t;                 --! data L1 bus outputs
      wdc_in_o      : out wdc_control_t;             --! wdc control signal input
      wic_in_o      : out wic_control_t;             --! wic control signal input 
      halt_core_i   : in std_ulogic;                 --! halt core signal
      flush_i       : in std_ulogic;                 --! flush memory access signal 
      clk_i         : in std_ulogic;                 --! core clock
      rst_n_i       : in std_ulogic                  --! active-low reset signal    
    );
  
end sb_memory_access;

--! SecretBlaze Memory Access Stage Architecture
architecture be_sb_memory_access of sb_memory_access is

  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////

  signal res_r             : data_t;            --! result reg
  signal rd_r              : op_reg_t;          --! rd address reg
  signal mem_sel_control_r : mem_sel_control_t; --! data memory byte sel control reg
  signal ls_control_r      : ls_control_t;      --! load/store control reg
  signal we_control_r      : we_control_t;      --! write-back enable control reg

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal pipe_bs_res_s     : data_t;
  signal pipe_mult_res_s   : data_t;
  signal pipe_clz_res_s    : data_t;
  signal res_s             : data_t;
  signal sel_s             : dm_bus_sel_t;
  signal ena_s             : std_ulogic;
  signal we_s              : std_ulogic;

begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  GEN_PIPE_MULT: if(USE_MULT > 0 and USE_PIPE_MULT = true) generate
  begin
    
    PIPE_MULT_UNIT_2: entity sb_lib.sb_pipe_mult_2(be_sb_pipe_mult_2)
      generic map
      (
        USE_MULT     => USE_MULT
      )
      port map
      (
        part_res_i   => ma_i.pipe_mult_i,    
        res_o        => pipe_mult_res_s,
        control_i    => ma_i.mult_control_i
      );
  
  end generate GEN_PIPE_MULT;

  GEN_PIPE_BS: if(USE_BS > 0 and USE_PIPE_BS = true) generate
  begin
    
    PIPE_BS_UNIT_2: entity sb_lib.sb_pipe_bs_2(be_sb_pipe_bs_2)
      generic map
      (
        USE_BS       => USE_BS
      )
      port map
      (
        part_res_i   => ma_i.pipe_bs_i.part_res,    
        res_o        => pipe_bs_res_s,
        part_shift_i => ma_i.pipe_bs_i.part_shift,    
        control_i    => ma_i.bs_control_i
      );
  
  end generate GEN_PIPE_BS;

  GEN_PIPE_CLZ: if(USE_CLZ = true and USE_PIPE_CLZ = true) generate
  begin
    
    PIPE_CLZ_UNIT_2: entity sb_lib.sb_pipe_clz_2(be_sb_pipe_clz_2)
      port map
      (
        part_data_i  => ma_i.pipe_clz_i.part_data,    
        part_res_i   => ma_i.pipe_clz_i.part_res, 
        res_o        => pipe_clz_res_s
      );
  
  end generate GEN_PIPE_CLZ;

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  -- 

  -- registered signals
  ma_o.rd_o              <= rd_r;
  ma_o.res_o             <= res_r;
  ma_o.mem_data_o        <= dm_bus_out_i.dat_o;
  ma_o.we_control_o      <= we_control_r;
  ma_o.ls_control_o      <= ls_control_r;
  ma_o.mem_sel_control_o <= mem_sel_control_r;
  
  --
  -- L1 MEMORY 
  --

  -- combinatorial signals
  dm_bus_in_o.ena_i      <= ena_s and not(flush_i);
  dm_bus_in_o.sel_i      <= sel_s;
  dm_bus_in_o.we_i       <= we_s;
  dm_bus_in_o.adr_i      <= ma_i.alu_res_i;
  dm_bus_in_o.dat_i      <= ma_i.op_d_i;        
  
  --
  -- CACHE CONTROLS
  --
  
  wdc_in_o               <= WDC_NOP when (flush_i = '1') else ma_i.wdc_control_i;
  wic_in_o               <= WIC_NOP when (flush_i = '1') else ma_i.wic_control_i;

  --
  -- RESULT MUX
  --
  --! This process handles the data to write-back into
  --! the register file of the processor. The branch 
  --! address to store is handled during this process.  
  --! In case of pipelined BS or MULT implementations,
  --! results of such instructions are also managed here.
  COMB_RES_MUX_MA: process(ma_i,
                           pipe_mult_res_s,
                           pipe_clz_res_s,
                           pipe_bs_res_s)
    
  begin
    
    -- a branch (link PC address into RD)
    if(ma_i.branch_status_i = B_TAKEN) then
      res_s <= std_ulogic_vector(resize(unsigned(ma_i.pc_i),data_t'length));

      -- result from alu or from pipelined MULT or BS 
    elsif((USE_MULT > 0 and USE_PIPE_MULT = true) or (USE_BS > 0 and USE_PIPE_BS = true)) then

      case ma_i.alu_control_i is

        when ALU_ADD | ALU_AND | ALU_OR | ALU_XOR | ALU_SHIFT | ALU_S8 | ALU_S16 | ALU_CMP | ALU_SPR | ALU_DIV | ALU_PAT =>
          res_s   <= ma_i.alu_res_i;

        when ALU_MULT =>    
          if(USE_MULT > 0 and USE_PIPE_MULT = false) then
            res_s <= ma_i.alu_res_i;        
                    
          elsif(USE_MULT > 0 and USE_PIPE_MULT = true) then
            res_s <= pipe_mult_res_s; 

          else
            res_s <= (others =>'X'); -- force X for speed & area optimization 
            report "ma stage: illegal alu op control code because the hardware multiplier is not implemented" severity warning;
            
          end if;

        when ALU_BS =>    
          if(USE_BS > 0 and USE_PIPE_BS = false) then
            res_s <= ma_i.alu_res_i;

          elsif(USE_BS > 0 and USE_PIPE_BS = true) then
            res_s <= pipe_bs_res_s; 

          else
            res_s <= (others =>'X'); -- force X for speed & area optimization 
            report "ma stage: illegal alu op control code because barrel shifter primitives are not implemented" severity warning;
            
          end if;

        when ALU_CLZ =>    
          if(USE_CLZ = true and USE_PIPE_CLZ = false) then
            res_s <= ma_i.alu_res_i;

          elsif(USE_CLZ = true and USE_PIPE_CLZ = true) then
            res_s <= pipe_clz_res_s; 

          else
            res_s <= (others =>'X'); -- force X for speed & area optimization 
            report "ma stage: illegal alu op control code because the clz instruction is not implemented" severity warning;
            
          end if;
                   
        when others =>
          res_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation
          report "ma stage: illegal alu op control code" severity warning;
          
      end case;

      -- result from alu
    else
      res_s <= ma_i.alu_res_i;

    end if;
    
  end process COMB_RES_MUX_MA;
    
  --
  -- MEMORY ACCESS CONTROL LOGIC 
  --
  --! This process controls the interface with the L1 data memory 
  --! for store and load instructions. BYTE, HALFWORD, and WORD 
  --! alignements are supported using the big endian encoding. 
  COMB_L1_MA: process(ma_i)

    alias byte_sel_a : std_ulogic_vector(1 downto 0) is ma_i.alu_res_i(1 downto 0);
    
  begin
    
    case ma_i.mem_sel_control_i is

      when BYTE =>
        
        case byte_sel_a is

          when "00" =>
            sel_s <= "1000";
            
          when "01" =>
            sel_s <= "0100";
            
          when "10" =>
            sel_s <= "0010";
            
          when "11" =>
            sel_s <= "0001";
            
          when others =>
            null; -- complete mux
            
        end case;

      when HALFWORD =>
        
        case byte_sel_a is
          
          when "00" =>
            sel_s <= "1100";
            
          when "10" =>
            sel_s <= "0011";
            
          when others =>
            sel_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation
            -- synthesis translate_off
            if(ma_i.ls_control_i = STORE) then
              report "memory access stage: illegal alignment" severity warning;
            end if;
            -- synthesis translate_on
            
        end case;

      when WORD =>
        sel_s <= "1111";
        
      when others =>
        sel_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation
        report "memory access stage: illegal mem sel control code" severity warning;
        
    end case;

    case ma_i.ls_control_i is

      when LOAD  =>
        ena_s <= '1';
        we_s  <= '0';

      when STORE =>
        ena_s <= '1';
        we_s  <= '1';

      when LS_NOP =>
        ena_s <= '0';
        we_s  <= '0';
        
      when others =>
        ena_s <= 'X'; -- force X for speed & area optimization / unsafe implementation
        we_s  <= 'X'; -- force X for speed & area optimization / unsafe implementation
        report "memory access stage: illegal mem sel control code" severity warning;
        
    end case;
    
  end process COMB_L1_MA;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- MEMORY ACCESS REGISTERS
  --
  --! This process implements the behaviour of all MA pipeline registers.
  CYCLE_MA: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
   
      -- sync reset
      if(rst_n_i = '0' or (flush_i = '1' and halt_core_i = '0')) then
        ls_control_r      <= LS_NOP;
        we_control_r      <= N_WE;
        
      elsif(halt_core_i = '0') then
        res_r             <= res_s;
        rd_r              <= ma_i.rd_i;
        mem_sel_control_r <= ma_i.mem_sel_control_i;
        ls_control_r      <= ma_i.ls_control_i;
        we_control_r      <= ma_i.we_control_i; 
          
      end if;

    end if;

  end process CYCLE_MA;                  
  
end be_sb_memory_access;


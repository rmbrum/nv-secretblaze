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
--! @file sb_execute.vhd                                      					
--! @brief SecretBlaze Execute Stage Implementation
--! @author Lyonel Barthe
--! @version 1.8b
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.8b 01/09/2011 by Lyonel Barthe
-- Fixed the control of SPR 
--
-- Version 1.8 29/03/2011 by Lyonel Barthe
-- Changed the implementation of CMP instructions
-- to fix a bug using signed numbers and to
-- improve performances!
--
-- Version 1.7b 28/03/2011 by Lyonel Barthe
-- Fixed a bug with the CMPU instruction
--
-- Version 1.7 22/02/2011 by Lyonel Barthe
-- Added optional pipelined mult and bs support
--
-- Version 1.6 05/01/2010 by Lyonel Barthe
-- Added divide instructions
--
-- Version 1.5 23/12/2010 by Lyonel Barthe
-- Added support for more forwarding trade-offs
--
-- Version 1.4 20/11/2010 by Lyonel Barthe
-- Added forwarding options for MULT and BS instructions
--
-- Version 1.3 07/11/2010 by Lyonel Barthe
-- More hardware multiplexing to achieve a better 
-- trade-off between speed and area performances 
--
-- Version 1.2 05/11/2010 by Lyonel Barthe
-- Interrupt and MSR instructions are optionals
--
-- Version 1.1 03/11/2010 by Lyonel Barthe
-- Added mult instructions
-- Added pattern instructions
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.3 8/05/2010 by Lyonel Barthe
-- MSR register implementation for special 
-- purpose instructions as well as INT register
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
use sb_lib.sb_isa.all;
use sb_lib.sb_core_pack.all;

library config_lib;
use config_lib.sb_config.all;

--
--! At the heart of the SecretBlaze's pipeline is the
--! EXecute (EX) stage that implements all computations;
--! arithmetic and logical operations, address calculation,
--! and branch condition evaluation. It consists of a branch
--! evaluation unit, a data alignment unit for store 
--! instructions, and an Arithemtic and Logic Unit (ALU),
--! which is composed of several sub-modules, including an
--! integer adder unit, a logic unit, a compare unit, an
--! optional barrel shifter unit, an optional count leading
--! zeros unit, an optional integer multiplier unit, an 
--! optional serial integer divider unit. All sub-modules
--! operate in parallel to deliver better performance, and, 
--! with few exceptions, have one-cycle latency. Like in
--! traditional RISC architectures, the data forwarding logic
--! is directly implemented in the EX stage with additional
--! muxes to reduce the number of pipeline stalls.
--

--! SecretBlaze Execute Stage Entity
entity sb_execute is

  generic
    (
      USE_BTC       : boolean := USER_USE_BTC;       --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
      USE_DCACHE    : boolean := USER_USE_DCACHE;    --! if true, it will implement the data cache
      USE_ICACHE    : boolean := USER_USE_ICACHE;    --! if true, it will implement the instruction cache
      USE_INT       : boolean := USER_USE_INT;       --! if true, it will implement the interrupt mechanism
      USE_SPR       : boolean := USER_USE_SPR;       --! if true, it will implement SPR instructions
      USE_MULT      : natural := USER_USE_MULT;      --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
      USE_PIPE_MULT : boolean := USER_USE_PIPE_MULT; --! if true, it will implement a pipelined 32-bit multiplier using 17x17 signed multipliers
      USE_BS        : natural := USER_USE_BS;        --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
      USE_PIPE_BS   : boolean := USER_USE_PIPE_BS;   --! it true, it will implement a pipelined barrel shifter
      USE_DIV       : boolean := USER_USE_DIV;       --! if true, it will implement divide instructions
      USE_PAT       : boolean := USER_USE_PAT;       --! if true, it will implement pattern instructions
      USE_CLZ       : boolean := USER_USE_CLZ;       --! if true, it will implement the count leading zeros instruction
      USE_PIPE_CLZ  : boolean := USER_USE_PIPE_CLZ;  --! it true, it will implement a pipelined clz instruction
      FW_IN_MULT    : boolean := USER_FW_IN_MULT     --! if true, it will implement the data forwarding for the inputs of the MULT unit
    );  

  port
    (
      ex_i          : in ex_stage_i_t;               --! execute inputs
      ex_o          : out ex_stage_o_t;              --! execute outputs
      int_i         : in int_status_t;               --! external interrupt signal
      halt_core_i   : in std_ulogic;                 --! halt core signal
      stall_i       : in std_ulogic;                 --! stall execute signal  
      flush_i       : in std_ulogic;                 --! flush execute signal
      mci_flush_i   : in std_ulogic;                 --! multi cycle flush execute signal 
      clk_i         : in std_ulogic;                 --! core clock
      rst_n_i       : in std_ulogic                  --! active-low reset signal  
    );  
  
end sb_execute;

--! SecretBlaze Execute Stage Architecture
architecture be_sb_execute of sb_execute is
  
  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////

  signal pc_r                 : pc_t;                 --! ex program counter reg
  signal alu_res_r            : data_t;               --! alu result reg
  signal alu_control_r        : alu_control_t;        --! alu control reg (only if pipelined MULT or BS)
  signal mult_control_r       : mult_control_t;       --! alu control reg (only if pipelined MULT)
  signal bs_control_r         : bs_control_t;         --! alu control reg (only if pipelined BS)
  signal pipe_mult_r          : pipe_mult_t;          --! pipelined mult partial result reg (only if pipelined MULT)
  signal pipe_bs_r            : pipe_bs_t;            --! pipelined bs partial result reg (only if pipelined BS)
  signal pipe_clz_r           : pipe_clz_t;           --! pipelined clz partial result reg (only if pipelined CLZ)
  signal op_d_r               : data_t;               --! rd data reg
  signal rd_r                 : op_reg_t;             --! rd address reg
  signal mem_sel_control_r    : mem_sel_control_t;    --! data memory byte sel control reg
  signal ls_control_r         : ls_control_t;         --! load/store control reg
  signal we_control_r         : we_control_t;         --! write-back enable control reg
  signal branch_delay_r       : branch_delay_t;       --! branch delay control reg
  signal branch_status_r      : branch_status_t;      --! branch status flag reg
  signal branch_control_r     : branch_control_t;     --! branch control reg (only if USE_BTC is true)
  signal int_status_r         : int_status_t;         --! pending interrupt reg (only if USE_INT is true)
  signal wdc_control_r        : wdc_control_t;        --! wdc control reg (only if USE_DCACHE is true)
  signal wic_control_r        : wic_control_t;        --! wic control reg (only if USE_ICACHE is true)
  signal pred_valid_r         : pred_valid_t;         --! pred valid reg (only if USE_BTC is true)
  signal pred_valid_del_r     : pred_valid_t;         --! pred valid del reg (only if USE_BTC is true)
  signal pred_control_r       : pred_control_t;       --! pred control reg (only if USE_BTC is true)
  signal pred_status_r        : pred_status_t;        --! pred status reg (only if USE_BTC is true)
  signal pred_pc_r            : pc_t;                 --! pred pc reg (only if USE_BTC is true) 
  signal pc_plus_plus_r       : pc_t;                 --! pc plus plus reg (only if USE_BTC is true) 

  --
  -- MSR special purpose register 
  --
  -- MSB                                                                   LSB
  -- +-----------------------------------------------------------------------+
  -- |  31 | 30     ...    8 |   7 |   6 |   5 |   4 |   3 |   2 |   1 |   0 |
  -- +-----------------------------------------------------------------------+
  -- |  CC |       N/A       | DCE | DZO | ICE | N/A | N/A |   C |  IE | N/A |
  -- +-----------------------------------------------------------------------+  
  -- 
  -- CC copy carry flag
  -- DCE data cache enable
  -- DZO division by zero or overflow
  -- ICE instruction cache enable
  -- C carry flag
  -- IE interrupt enable
  -- 
 
  signal msr_r                : data_t;               --! msr register

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal op_a_s               : data_t;
  signal op_b_s               : data_t;
  signal op_a_mult_s          : data_t;
  signal op_b_mult_s          : data_t;
  signal pipe_mult_s          : pipe_mult_t; 
  signal pipe_bs_s            : pipe_bs_t;
  signal pipe_clz_s           : pipe_clz_t;
  signal op_a_bs_s            : data_t;
  signal op_b_bs_s            : bs_shift_t;
  signal op_d_s               : data_t;
  signal adder_res_s          : data_t;
  signal adder_cout_s         : std_ulogic;
  signal alu_res_s            : data_t;
  signal cmp_res_s            : data_t;
  signal carry_in_s           : std_ulogic;
  signal branch_status_s      : branch_status_t;
  signal fw_op_a_s            : data_t;
  signal fw_op_b_s            : data_t;
  signal fw_op_d_s            : data_t;
  signal bs_res_s             : data_t;
  signal mult_res_s           : data_t;
  signal div_res_s            : data_t;
  signal pat_res_s            : data_t;
  signal clz_res_s            : data_t;
  signal div_ena_s            : std_ulogic;
  signal dzo_s                : std_ulogic;
  signal div_busy_s           : std_ulogic;     
  signal msr_s                : data_t;        
       
begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  BEVAL_UNIT: entity sb_lib.sb_beval(be_sb_beval)
    port map
    (
      data_i          => fw_op_a_s,
      control_i       => ex_i.branch_control_i,
      status_o        => branch_status_s
    );
  
  ADD_UNIT: entity sb_lib.sb_add(be_sb_add)
    port map
    (
      op_a_i          => op_a_s,
      op_b_i          => op_b_s,
      cin_i           => carry_in_s,
      res_o           => adder_res_s,
      cout_o          => adder_cout_s
    );

  CMP_UNIT: entity sb_lib.sb_cmp(be_sb_cmp)
    port map
    (
      op_a_i          => fw_op_a_s, -- because reg-reg instructions only
      op_b_i          => fw_op_b_s, -- because reg-reg instructions only
      res_o           => cmp_res_s,
      control_i       => ex_i.cmp_control_i
    );
  
  GEN_NO_PIPE_BS: if(USE_BS > 0 and USE_PIPE_BS = false) generate
  begin
    
    BS_UNIT: entity sb_lib.sb_bs(be_sb_bs)
      generic map
      (
        USE_BS        => USE_BS
      )
      port map
      (
        data_i        => op_a_bs_s, 
        res_o         => bs_res_s,    
        shift_i       => op_b_bs_s,  
        control_i     => ex_i.bs_control_i
      );
  
  end generate GEN_NO_PIPE_BS;

  GEN_PIPE_BS: if(USE_BS > 0 and USE_PIPE_BS = true) generate
  begin
    
    PIPE_BS_UNIT_1: entity sb_lib.sb_pipe_bs_1(be_sb_pipe_bs_1)
      generic map
      (
        USE_BS        => USE_BS
      )
      port map
      (
        data_i        => op_a_bs_s, 
        part_res_o    => pipe_bs_s.part_res,    
        part_shift_o  => pipe_bs_s.part_shift,
        shift_i       => op_b_bs_s,  
        control_i     => ex_i.bs_control_i
      );
  
  end generate GEN_PIPE_BS;

  GEN_NO_PIPE_MULT: if(USE_MULT > 0 and USE_PIPE_MULT = false) generate
  begin
    
    MULT_UNIT: entity sb_lib.sb_mult(be_sb_mult)
      generic map
      (
        USE_MULT      => USE_MULT
      )
      port map
      (
        op_a_i        => op_a_mult_s,    
        op_b_i        => op_b_mult_s,   
        res_o         => mult_res_s, 
        control_i     => ex_i.mult_control_i
      );
  
  end generate GEN_NO_PIPE_MULT;

  GEN_PIPE_MULT: if(USE_MULT > 0 and USE_PIPE_MULT = true) generate
  begin
    
    PIPE_MULT_UNIT_1: entity sb_lib.sb_pipe_mult_1(be_sb_pipe_mult_1)
      generic map
      (
        USE_MULT      => USE_MULT
      )
      port map
      (
        op_a_i        => op_a_mult_s,    
        op_b_i        => op_b_mult_s,   
        part_res_o    => pipe_mult_s,
        control_i     => ex_i.mult_control_i
      );
  
  end generate GEN_PIPE_MULT;

  GEN_DIV: if(USE_DIV = true) generate
  begin
 
    DIV_UNIT: entity sb_lib.sb_div(be_sb_div)
      port map
      (
        op_a_i        => fw_op_a_s, -- because reg-reg instructions only
        op_b_i        => fw_op_b_s, -- because reg-reg instructions only
        res_o         => div_res_s,
        dzo_o         => dzo_s,
        ena_i         => div_ena_s, 
        control_i     => ex_i.div_control_i,
        busy_o        => div_busy_s,
        halt_core_i   => halt_core_i,
        flush_i       => mci_flush_i,
        clk_i         => clk_i,
        rst_n_i       => rst_n_i
      );

    div_ena_s <= '1' when (ex_i.alu_control_i = ALU_DIV) else '0';

  end generate GEN_DIV;

  GEN_PAT: if(USE_PAT = true) generate
  begin
    
    PAT_UNIT: entity sb_lib.sb_pat(be_sb_pat)
      port map
      (
        op_a_i        => fw_op_a_s, -- because reg-reg instructions only   
        op_b_i        => fw_op_b_s, -- because reg-reg instructions only
        res_o         => pat_res_s, 
        control_i     => ex_i.pat_control_i
      );
  
  end generate GEN_PAT;

  GEN_NO_PIPE_CLZ: if(USE_CLZ = true and USE_PIPE_CLZ = false) generate
  begin
  
    CLZ_UNIT: entity sb_lib.sb_clz(be_sb_clz)
      port map
      (
        op_a_i        => fw_op_a_s, -- because reg-reg instruction only
        res_o         => clz_res_s 
      );

  end generate GEN_NO_PIPE_CLZ;

  GEN_PIPE_CLZ: if(USE_CLZ = true and USE_PIPE_CLZ = true) generate
  begin
  
    PIPE_CLZ_UNIT_1: entity sb_lib.sb_pipe_clz_1(be_sb_pipe_clz_1)
      port map
      (
        op_a_i        => fw_op_a_s, -- because reg-reg instruction only
        part_data_o   => pipe_clz_s.part_data,
        part_res_o    => pipe_clz_s.part_res
      );

  end generate GEN_PIPE_CLZ;
    
  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  -- registered signals
  ex_o.pc_o              <= pc_r;
  ex_o.rd_o              <= rd_r;
  ex_o.alu_res_o         <= alu_res_r;
  ex_o.alu_control_o     <= alu_control_r;
  ex_o.mult_control_o    <= mult_control_r;
  ex_o.bs_control_o      <= bs_control_r;
  ex_o.pipe_mult_o       <= pipe_mult_r;
  ex_o.pipe_bs_o         <= pipe_bs_r;
  ex_o.pipe_clz_o        <= pipe_clz_r;
  ex_o.op_d_o            <= op_d_r;
  ex_o.branch_status_o   <= branch_status_r;
  ex_o.branch_delay_o    <= branch_delay_r;
  ex_o.branch_control_o  <= branch_control_r;
  ex_o.we_control_o      <= we_control_r;
  ex_o.ls_control_o      <= ls_control_r;
  ex_o.mem_sel_control_o <= mem_sel_control_r;  
  ex_o.int_status_o      <= int_status_r;
  ex_o.wdc_control_o     <= wdc_control_r;
  ex_o.wic_control_o     <= wic_control_r;
  ex_o.pred_valid_o      <= pred_valid_r;
  ex_o.pred_valid_del_o  <= pred_valid_del_r;
  ex_o.pred_status_o     <= pred_status_r;
  ex_o.pred_control_o    <= pred_control_r;
  ex_o.pred_pc_o         <= pred_pc_r;
  ex_o.pc_plus_plus_o    <= pc_plus_plus_r;
  -- combinatorial signal
  ex_o.mci_busy_o        <= div_busy_s; 

  --
  -- REGISTER FORWARDING OP A MUX
  --
  --! This process implements the register forwarding technique for the OP A. 
  COMB_FW_OP_A_MUX: process(ex_i,
                            alu_res_r)
                          
  begin 
  
    --
    -- FORWARD OP A LOGIC  
    --
    
    case ex_i.fw_op_a_control_i is

      -- no forward 
      when FW_NOP =>
        fw_op_a_s <= ex_i.op_a_i;

      -- forward from EX/MA 
      when FW_EX_MA =>
        fw_op_a_s <= alu_res_r;

      -- forward from MA/WB 
      when FW_MA_WB =>
        fw_op_a_s <= ex_i.ma_wb_res_i;

      -- forward from WB/RF 
      when FW_WB_RF =>
        fw_op_a_s <= ex_i.wb_rf_res_a_i;

      when others =>
        fw_op_a_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation 
        report "ex stage: illegal forward mux op a control code" severity warning;
        
    end case; 
    
  end process COMB_FW_OP_A_MUX;
  
  --
  -- OP A MUX
  --
  --! This process sets up the source operand OP A for most ALU operations of the processor.
  COMB_OP_A_MUX: process(ex_i,
                         fw_op_a_s)

  begin

    --
    -- SEL OP A
    --
    
    case ex_i.op_a_control_i is

      -- direct 
      when OP_A_REG_1 =>
        op_a_s <= fw_op_a_s;

      -- inv
      when OP_A_NOT_REG_1 =>
        op_a_s <= not(fw_op_a_s);

      -- pc
      when OP_A_PC =>
        op_a_s <= std_ulogic_vector(resize(unsigned(ex_i.pc_i),data_t'length));

      -- zero
      when OP_A_ZERO =>
        op_a_s <= (others =>'0');

      when others =>
        op_a_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation 
        report "ex stage: illegal mux op a control code" severity warning;
        
    end case;                           

  end process COMB_OP_A_MUX;
  
  --
  -- REGISTER FORWARDING OP B MUX
  --
  --! This process implements the register forwarding technique for the OP B. 
  COMB_FW_OP_B_MUX: process(ex_i,
                            alu_res_r)
                          
  begin 
  
    --
    -- FORWARD OP B LOGIC
    --
    
    case ex_i.fw_op_b_control_i is

      -- no forward 
      when FW_NOP =>
        fw_op_b_s <= ex_i.op_b_i;

      -- forward from EX/MA 
      when FW_EX_MA =>
        fw_op_b_s <= alu_res_r;

      -- forward from MA/WB 
      when FW_MA_WB =>
        fw_op_b_s <= ex_i.ma_wb_res_i;

      -- forward from WB/RF 
      when FW_WB_RF =>
        fw_op_b_s <= ex_i.wb_rf_res_b_i;

      when others =>
        fw_op_b_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation 
        report "ex stage: illegal forward mux op b control code" severity warning;
        
    end case; 
    
  end process COMB_FW_OP_B_MUX;

  --
  -- OP B MUX
  --
  --! This process sets up the source operand OP B for most ALU operations of the processor.
  COMB_OP_B_MUX: process(ex_i,
                         fw_op_b_s)
    
  begin

    --
    -- SEL OP B
    --
    
    case ex_i.op_b_control_i is

      -- direct 
      when OP_B_REG_2 => 
        op_b_s <= fw_op_b_s;

      -- inv
      when OP_B_NOT_REG_2 =>
        op_b_s <= not(fw_op_b_s);

      -- imm
      when OP_B_IMM =>
        op_b_s <= ex_i.imm_i;

      -- inv imm
      when OP_B_NOT_IMM =>
        op_b_s <= not(ex_i.imm_i);

      when others =>
        op_b_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation
        report "ex stage: illegal mux op b control code" severity warning;
        
    end case;

  end process COMB_OP_B_MUX;

  GEN_COMB_OP_MULT_MUX: if(USE_MULT > 0) generate

    --
    -- OP A MULT MUX
    --
    --! This process sets up the source operand OP A for the MULT module of the processor.
    COMB_OP_A_MULT: process(ex_i,
                            fw_op_a_s)
    
    begin

      if(FW_IN_MULT = true) then
        op_a_mult_s <= fw_op_a_s;

      else
        -- partial fw
        if(ex_i.fw_op_a_control_i = FW_WB_RF) then
          op_a_mult_s <= ex_i.wb_rf_res_a_i;

        else
          op_a_mult_s <= ex_i.op_a_i;

        end if;

      end if;

    end process COMB_OP_A_MULT;

    --
    -- OP B MULT MUX
    --
    --! This process sets up the source operand OP B for the MULT module of the processor.
    COMB_OP_B_MULT_MUX: process(ex_i,
                                fw_op_b_s)
      
    begin

      if(FW_IN_MULT = true) then
        if(ex_i.op_b_control_i = OP_B_REG_2) then
          op_b_mult_s   <= fw_op_b_s;
       
        else
          op_b_mult_s   <= ex_i.imm_i;

        end if;

      else
        -- partial fw
        if(ex_i.op_b_control_i = OP_B_REG_2) then
          if(ex_i.fw_op_b_control_i = FW_WB_RF) then
            op_b_mult_s <= ex_i.wb_rf_res_b_i;

          else
            op_b_mult_s <= ex_i.op_b_i;

          end if;
       
        else
          op_b_mult_s   <= ex_i.imm_i;

        end if;

      end if;

    end process COMB_OP_B_MULT_MUX;

  end generate GEN_COMB_OP_MULT_MUX;

  GEN_COMB_OP_BS_MUX: if(USE_BS > 0) generate

    --
    -- OP A BS 
    --
    --! This process sets up the source operand OP A for the BS module of the processor.
    COMB_OP_A_BS: process(fw_op_a_s)
    
    begin

      op_a_bs_s <= fw_op_a_s;

    end process COMB_OP_A_BS;

    --
    -- OP B BS MUX
    --
    --! This process sets up the source operand OP A for the BS module of the processor.
    COMB_OP_B_BS_MUX: process(ex_i,
                              fw_op_b_s)
      
    begin

      if(ex_i.op_b_control_i = OP_B_REG_2) then
        op_b_bs_s <= fw_op_b_s(bs_shift_t'length - 1 downto 0);
     
      else
        op_b_bs_s <= ex_i.imm_i(bs_shift_t'length - 1 downto 0);

      end if;

    end process COMB_OP_B_BS_MUX;

  end generate GEN_COMB_OP_BS_MUX;

  --
  -- CARRY IN MUX
  --
  --! This process sets up the carry in for most ALU operations of the processor.
  COMB_CARRY_IN_MUX: process(ex_i,
                             msr_r,
                             op_a_s)
  begin

    case ex_i.carry_control_i is

      -- null 
      when CARRY_ZERO =>
        carry_in_s <= '0';

      -- one (c2)
      when CARRY_ONE =>
        carry_in_s <= '1';

      -- carry flag register (borrow)
      when CARRY_ALU =>
        carry_in_s <= msr_r(MSR_C_OFF);

      -- arith (for sra instruction)
      when CARRY_ARITH =>
        carry_in_s <= op_a_s(data_t'left);

      when others =>
        carry_in_s <= 'X'; -- force X for speed & area optimization / unsafe implementation
        report "ex stage: illegal mux carry in control code" severity warning;
        
    end case;
    
  end process COMB_CARRY_IN_MUX;

  --
  -- ALU RES MUX
  --
  --! The current process implements the result MUX of the processor's ALU.
  COMB_ALU_RES_MUX: process(ex_i,
                            msr_r,
                            op_a_s,
                            op_b_s,
                            carry_in_s,
                            adder_res_s,
                            adder_cout_s,
                            cmp_res_s,
                            mult_res_s,
                            div_res_s,
                            pat_res_s,
                            bs_res_s)   

  begin

    case ex_i.alu_control_i is

      when ALU_ADD =>
        alu_res_s <= adder_res_s;
        
      when ALU_AND =>
        alu_res_s <= (op_a_s and op_b_s);
	
      when ALU_OR =>
        alu_res_s <= (op_a_s or op_b_s);

      when ALU_XOR =>
        alu_res_s <= (op_a_s xor op_b_s);

      when ALU_SHIFT =>
        alu_res_s <= carry_in_s & op_a_s(data_t'left downto 1);
	   
      when ALU_S8 =>
        alu_res_s <= std_ulogic_vector(resize(signed(op_a_s(7 downto 0)),data_t'length));

      when ALU_S16 =>
        alu_res_s <= std_ulogic_vector(resize(signed(op_a_s(15 downto 0)),data_t'length));

      when ALU_CMP =>
        alu_res_s <= cmp_res_s;
        
      when ALU_SPR =>  
        if(USE_SPR = true) then

          case ex_i.rs_i is

            when OP_PC =>
              alu_res_s <= std_ulogic_vector(resize(unsigned(ex_i.pc_i),data_t'length));

            when OP_MSR =>
              alu_res_s <= msr_r;

            when OP_NOP =>
              alu_res_s <= (others =>'X'); -- force X for speed & area optimization

            when others =>
              alu_res_s <= (others =>'X'); -- force X for speed & area optimization 
              report "ex stage: illegal spr rs op control code" severity warning;

          end case;
           
        else
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because spr instructions are not implemented" severity warning;
          
        end if;

      when ALU_MULT =>    
        if(USE_MULT > 0 and USE_PIPE_MULT = false) then
          alu_res_s <= mult_res_s;        
                  
        elsif(USE_MULT > 0 and USE_PIPE_MULT = true) then
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 

        else
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because the hardware multiplier is not implemented" severity warning;
          
        end if;

      when ALU_DIV =>    
        if(USE_DIV = true) then
          alu_res_s <= div_res_s;        
                  
        else
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because the hardware divider is not implemented" severity warning;
          
        end if;

      when ALU_PAT =>    
        if(USE_PAT = true) then
          alu_res_s <= pat_res_s;
          
        else
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because pattern primitives are not implemented" severity warning;
          
        end if;

      when ALU_CLZ =>    
        if(USE_CLZ = true and USE_PIPE_CLZ = false) then
          alu_res_s <= clz_res_s;
          
        elsif(USE_CLZ = true and USE_PIPE_CLZ = true) then
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 

        else
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because clz instruction is not implemented" severity warning;
          
        end if;

      when ALU_BS =>    
        if(USE_BS > 0 and USE_PIPE_BS = false) then
          alu_res_s <= bs_res_s;

        elsif(USE_BS > 0 and USE_PIPE_BS = true) then
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 

        else
          alu_res_s <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because barrel shifter primitives are not implemented" severity warning;
          
        end if;
                 
      when others =>
        alu_res_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation
        report "ex stage: illegal alu op control code" severity warning;
        
    end case;
    
  end process COMB_ALU_RES_MUX;

  --
  -- MSR LOGIC
  --
  --! The current process implements the MSR dedicated logic. 
  --! Carry and interrupt flags are especially updated in this process. 
  COMB_MSR_CONTROL: process(ex_i,
                            msr_r,
                            dzo_s,
                            op_a_s,
                            op_b_s,
                            carry_in_s,
                            adder_res_s,
                            adder_cout_s)
    
  begin
    
    case ex_i.alu_control_i is

      when ALU_OR | ALU_XOR | ALU_AND | ALU_BS | ALU_S8 | ALU_S16 | ALU_CMP | ALU_MULT | ALU_PAT | ALU_CLZ => 
        msr_s               <= msr_r; 
           
      when ALU_ADD =>
        msr_s               <= msr_r; 
        
        if(ex_i.carry_keep_i = CARRY_N_KEEP) then
          msr_s(MSR_C_OFF)  <= adder_cout_s; 
          msr_s(MSR_CC_OFF) <= adder_cout_s; 
        end if;

        if(USE_INT = true) then
          case ex_i.int_control_i is

            when INT_NOP =>

            when INT_DISABLE =>
              msr_s(MSR_IE_OFF) <= '0'; -- clear IE 

            when INT_ENABLE =>
              msr_s(MSR_IE_OFF) <= '1'; -- set IE
     
            when others =>
              report "msr process: illegal int control code" severity warning;
            
          end case;
        end if;

      when ALU_SHIFT =>
        msr_s                <= msr_r; 
        msr_s(MSR_C_OFF)     <= op_a_s(0);    
        msr_s(MSR_CC_OFF)    <= op_a_s(0);    

      when ALU_DIV =>
        if(USE_DIV = true) then
          msr_s              <= msr_r; 
          msr_s(MSR_DZO_OFF) <= dzo_s;     
                    
        else
          msr_s              <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because the hardware divider is not implemented" severity warning;
            
        end if;
        
      when ALU_SPR =>  
        if(USE_SPR = true) then 
            
          case ex_i.spr_control_i is

            -- force set
            when MSR_SET =>
              msr_s <= (msr_r or op_b_s);

            -- force reset
            when MSR_CLEAR =>
              msr_s <= (msr_r and op_b_s);

            -- move from 
            when MFS =>		
              case ex_i.rs_i is

                when OP_PC | OP_MSR | OP_NOP =>
                  msr_s <= msr_r;

                when others =>
                  msr_s <= (others =>'X'); -- force X for speed & area optimization 
                  report "ex stage: illegal spr rs op control code" severity warning;

              end case;

            -- move to
            when MTS =>
              case ex_i.rs_i is

                when OP_PC | OP_NOP =>
                  msr_s <= msr_r;

                when OP_MSR =>
                  msr_s <= op_a_s;

                when others =>
                  msr_s <= (others =>'X'); -- force X for speed & area optimization 
                  report "ex stage: illegal spr rs op control code" severity warning;

              end case;

            when others => 
              msr_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation
              report "msr process: illegal spr control code" severity warning;

          end case;
          
        else
          msr_s <= (others =>'X'); -- force X for speed & area optimization 
          report "ex stage: illegal alu op control code because spr instructions are not implemented" severity warning;
          
        end if;         
                 
      when others =>
        msr_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation
        report "ex stage: illegal alu op control code" severity warning;
        
    end case;

  end process COMB_MSR_CONTROL;
  
  --
  -- REGISTER FORWARDING OP D
  --
  --! This process implements the register forwarding
  --! technique for the third operand D, which is used
  --! for STORE instructions. 
  COMB_FW_OP_D_MUX: process(ex_i,
                            alu_res_r)
                          
  begin 

    --
    -- FORWARD OP D LOGIC
    --
    
    case ex_i.fw_op_d_control_i is

      -- no forward 
      when FW_NOP =>
        fw_op_d_s <= ex_i.op_d_i;

      -- forward from EX/MA 
      when FW_EX_MA =>
        fw_op_d_s <= alu_res_r;

      -- forward from MA/WB 
      when FW_MA_WB =>
        fw_op_d_s <= ex_i.ma_wb_res_i;

      -- forward from WB/RF 
      when FW_WB_RF =>
        fw_op_d_s <= ex_i.wb_rf_res_d_i;

      when others =>
        fw_op_d_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation 
        report "ex stage: illegal forward mux op d control code" severity warning;
        
    end case; 
    
  end process COMB_FW_OP_D_MUX;

  --
  -- STORE ALIGNMENT
  --
  --! This process implements the data alignement procedure
  --! for STORE instructions. The SecretBlaze supports WORD, 
  --! HALFWORD, and BYTE modes.
  COMB_STORE_ALIGN: process(fw_op_d_s,
                            ex_i)    
							
  begin
	
    case ex_i.mem_sel_control_i is

      when BYTE =>
        op_d_s <= fw_op_d_s(data_t'length/4 - 1 downto 0) &
                  fw_op_d_s(data_t'length/4 - 1 downto 0) &
                  fw_op_d_s(data_t'length/4 - 1 downto 0) &
                  fw_op_d_s(data_t'length/4 - 1 downto 0);

      when HALFWORD =>
        op_d_s <= fw_op_d_s(data_t'length*2/4 - 1 downto 0) &
                  fw_op_d_s(data_t'length*2/4 - 1 downto 0);
        
      when WORD =>
        op_d_s <= fw_op_d_s;

      when others =>
        op_d_s <= (others =>'X'); -- force X for speed & area optimization / unsafe implementation
        report "align store process: illegal mem sel control code" severity warning;

    end case;
    
  end process COMB_STORE_ALIGN;
  
  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- EXECUTE REGISTERS
  --
  --! This process implements the behaviour of all EX pipeline registers.
  CYCLE_EXECUTE: process(clk_i)
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
      
      -- sync reset / flush 
      if(rst_n_i = '0' or (flush_i = '1' and halt_core_i = '0')) then
        branch_status_r             <= B_N_TAKEN;
        branch_delay_r              <= B_N_DELAY;
        ls_control_r                <= LS_NOP;
        we_control_r                <= N_WE;
        if(USE_DCACHE = true) then         
          wdc_control_r             <= WDC_NOP;  
        end if; 
        if(USE_ICACHE = true) then       
          wic_control_r             <= WIC_NOP; 
        end if;  
        if(USE_BTC = true) then
          pred_valid_r              <= P_N_VALID;
          pred_valid_del_r          <= P_N_VALID;
          pred_control_r            <= N_PE;
          branch_control_r          <= B_NOP;
        end if;

      elsif(halt_core_i = '0' and stall_i = '0') then
        pc_r                        <= ex_i.pc_i;
        alu_res_r                   <= alu_res_s;
        op_d_r                      <= op_d_s;
        rd_r                        <= ex_i.rd_i;
        branch_status_r             <= branch_status_s;
        branch_delay_r              <= ex_i.branch_delay_i;
        if((USE_BS > 0 and USE_PIPE_BS = true) or (USE_MULT > 0   and USE_PIPE_MULT = true)
                                               or (USE_CLZ = true and USE_PIPE_CLZ = true)) then
          alu_control_r             <= ex_i.alu_control_i;
        end if;
        if(USE_MULT > 0 and USE_PIPE_MULT = true) then
          mult_control_r            <= ex_i.mult_control_i;
          pipe_mult_r.part_ll_res   <= pipe_mult_s.part_ll_res;
          pipe_mult_r.part_lu_res   <= pipe_mult_s.part_lu_res;
          pipe_mult_r.part_ul_res   <= pipe_mult_s.part_ul_res;
          if(USE_MULT > 1) then
            pipe_mult_r.part_uu_res <= pipe_mult_s.part_uu_res;
          end if;
        end if;
        if(USE_BS > 0 and USE_PIPE_BS = true) then
          bs_control_r              <= ex_i.bs_control_i;
          pipe_bs_r                 <= pipe_bs_s;
        end if;
        if(USE_CLZ = true and USE_PIPE_CLZ = true) then
          pipe_clz_r                <= pipe_clz_s;
        end if;
        ls_control_r                <= ex_i.ls_control_i;
        we_control_r                <= ex_i.we_control_i;
        mem_sel_control_r           <= ex_i.mem_sel_control_i;
        if(USE_DCACHE = true) then       
          wdc_control_r             <= ex_i.wdc_control_i;
        end if; 
        if(USE_ICACHE = true) then       
          wic_control_r             <= ex_i.wic_control_i;
        end if;  
        if(USE_BTC = true) then
          pred_valid_r              <= ex_i.pred_valid_i;
          pred_valid_del_r          <= ex_i.pred_valid_del_i;
          pred_control_r            <= ex_i.pred_control_i;
          pred_status_r             <= ex_i.pred_status_i;
          pred_pc_r                 <= ex_i.pred_pc_i;
          pc_plus_plus_r            <= ex_i.pc_plus_plus_i;
          branch_control_r          <= ex_i.branch_control_i;
        end if;

      end if;
      
    end if;

  end process CYCLE_EXECUTE;    

  --
  -- MSR REGISTER
  --
  --! This process implements the MSR register.
  --! Note that if the execute stage is flushed,
  --! the register keeps the old value.
  CYCLE_MSR: process(clk_i)
  begin
    
    -- clock event
    if(clk_i'event and clk_i = '1') then
      
      -- sync reset
      if(rst_n_i = '0') then
        msr_r <= (others => '0');
        
      elsif(halt_core_i = '0' and stall_i = '0' and flush_i = '0') then
        msr_r(MSR_CC_OFF)    <= msr_s(MSR_CC_OFF); 
        msr_r(MSR_C_OFF)     <= msr_s(MSR_C_OFF); 
        if(USE_DCACHE = true) then
          msr_r(MSR_DCE_OFF) <= msr_s(MSR_DCE_OFF);  
        end if;
        if(USE_ICACHE = true) then
          msr_r(MSR_ICE_OFF) <= msr_s(MSR_ICE_OFF);  
        end if;
        if(USE_INT = true) then
          msr_r(MSR_IE_OFF)  <= msr_s(MSR_IE_OFF);  
        end if;
        if(USE_DIV = true) then
          msr_r(MSR_DZO_OFF) <= msr_s(MSR_DZO_OFF);
        end if;
        
      end if;
      
    end if;

  end process CYCLE_MSR;   

  GEN_INT_REG: if(USE_INT = true) generate 

    --
    -- INT REGISTER
    --
    --! This process implements the interrupt status register.
    --! Note that if the execute stage is flushed, the register 
    --! keeps the old value.
    CYCLE_INT: process(clk_i)
    begin
    
      -- clock event
      if(clk_i'event and clk_i = '1') then
      
        -- sync reset
        if(rst_n_i = '0') then
          int_status_r <= N_INT;
          
        elsif(halt_core_i = '0' and stall_i = '0' and flush_i = '0') then
          if(msr_s(MSR_IE_OFF) = '0') then  
            int_status_r <= N_INT;

          else
            int_status_r <= int_i;  

          end if; 
          
        end if;
      
      end if;

    end process CYCLE_INT;

  end generate GEN_INT_REG;                           
  
end be_sb_execute;


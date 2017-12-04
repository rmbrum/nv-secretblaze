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
--! @file sb_decode.vhd                                       					
--! @brief SecretBlaze Instruction Decode Stage Implementation               				
--! @author Lyonel Barthe
--! @version 1.7c
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.7c 21/06/2012 by Lyonel Barthe
-- Fixed the rsb_type_s signal for the wdc instruction
--
-- Version 1.7b 01/09/2011 by Lyonel Barthe
-- Fixed the control of SPR 
--
-- Version 1.7 12/05/2011 by Lyonel Barthe
-- Optional BTC support
--
-- Version 1.6 29/03/2011 by Lyonel Barthe
-- Changed CMP implementation
--
-- Version 1.5 07/10/2010 by Lyonel Barthe
-- Changed decode coding style for more hardware
-- multiplexing during the execute stage
--
-- Version 1.4 05/10/2010 by Lyonel Barthe
-- Interrupt and MSR instructions are optionals
--
-- Version 1.3 03/10/2010 by Lyonel Barthe
-- Added pattern instructions
-- Added mult instructions
--
-- Version 1.2 11/10/2010 by Lyonel Barthe
-- Added wdc instruction
-- Added wic instruction
-- Changed decode coding style
--
-- Version 1.1 7/10/2010 by Lyonel Barthe
-- Added wdc.flush instruction
--
-- Version 1.0b 18/05/2010 by Lyonel Barthe
-- Fixed BRAM RF implementation 
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.3 3/05/2010 by Lyonel Barthe
-- Added interrupt support as well as SPR instructions 
--
-- Version 0.2 7/04/2010 by Lyonel Barthe
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
--! Once fetched, the instruction is decoded, i.e. the control signals for 
--! the datapath are set: this is the Instruction Decode stage (ID). It is 
--! implemented in this module according to the binary instruction code of 
--! the MicroBlaze. The SecretBlaze also performs the operand fetch from 
--! the register file in this stage, which is done in parallel to the decoding 
--! process for better performance. 
--! 
--! The ID is also the place where interrupts are handled. Indeed, when an 
--! interrupt is pending, the processor must stop the normal execution and 
--! then branch to the interrupt handler address, which is by default 0x0000_0010 
--! for a configuration without an instruction cache or 0x1000_0010 otherwise. 
--! However, owing to a pipelined structure, the following conditions have to be 
--! carefully evaluated before taking the interrupt:
--!   - an interrupt cannot be processed after any control flow instructions such 
--! as branches, breaks, and return instructions, and
--!   - an interrupt cannot be taken in a delay slot instruction.
--! In other cases, it can be safely handled. Note that, like the MicroBlaze, 
--! the SecretBlaze only provides one external interrupt source and does not support 
--! interrupt nesting. To address the single source issue, multiple interrupts can 
--! be nevertheless managed through an external interrupt controller.
--

--! SecretBlaze Decode Stage Entity
entity sb_decode is

  generic
    (
      RF_TYPE       : string  := USER_RF_TYPE;       --! register file implementation type 
      USE_BTC       : boolean := USER_USE_BTC;       --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
      USE_DCACHE    : boolean := USER_USE_DCACHE;    --! if true, it will implement the data cache
      USE_WRITEBACK : boolean := USER_USE_WRITEBACK; --! if true, use write-back policy
      USE_ICACHE    : boolean := USER_USE_ICACHE;    --! if true, it will implement the instruction cache
      USE_INT       : boolean := USER_USE_INT;       --! if true, it will implement the interrupt mechanism
      USE_SPR       : boolean := USER_USE_SPR;       --! if true, it will implement SPR instructions
      USE_MULT      : natural := USER_USE_MULT;      --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
      USE_DIV       : boolean := USER_USE_DIV;       --! if true, it will implement divide instructions
      USE_PAT       : boolean := USER_USE_PAT;       --! if true, it will implement pattern instructions
      USE_CLZ       : boolean := USER_USE_CLZ;       --! if true, it will implement the count leading zeros instruction
      USE_BS        : natural := USER_USE_BS         --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
    );

  port
    (
      id_i          : in id_stage_i_t;               --! decode inputs
      id_o          : out id_stage_o_t;              --! decode outputs 
      halt_core_i   : in std_ulogic;                 --! halt core signal 
      stall_i       : in std_ulogic;                 --! stall decode signal 
      flush_i       : in std_ulogic;                 --! flush decode signal
      clk_i         : in std_ulogic;                 --! core clock
      rst_n_i       : in std_ulogic                  --! active-low reset signal     
    );
  
end sb_decode;

--! SecretBlaze Decode Stage Architecture
architecture be_sb_decode of sb_decode is

  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  --
  -- DATA REGISTERS
  --
  
  signal pc_r              : pc_t;              --! id program counter reg 
  signal imm_r             : data_t;            --! imm data reg
  signal rd_r              : op_reg_t;          --! rd address reg

  --
  -- DECODE CONTROL REGISTERS
  --

  signal alu_control_r     : alu_control_t;     --! alu operation control reg
  signal op_a_control_r    : op_a_control_t;    --! alu op a control reg
  signal op_b_control_r    : op_b_control_t;    --! alu op b control reg
  signal carry_control_r   : carry_control_t;   --! carry control reg
  signal carry_keep_r      : carry_keep_t;      --! carry keep control reg
  signal branch_control_r  : branch_control_t;  --! branch cond control reg
  signal branch_delay_r    : branch_delay_t;    --! branch delay control reg
  signal mem_sel_control_r : mem_sel_control_t; --! data memory byte sel control reg
  signal ls_control_r      : ls_control_t;      --! load/store control reg
  signal we_control_r      : we_control_t;      --! write-back enable control reg
  signal cmp_control_r     : cmp_control_t;     --! compare control reg 
  signal bs_control_r      : bs_control_t;      --! barrel shifter control reg (only if USE_BS > 0)
  signal mult_control_r    : mult_control_t;    --! multiplier control reg (only if USE_MULT > 0)
  signal div_control_r     : div_control_t;     --! divider control reg (only if USE_DIV is true)
  signal pat_control_r     : pat_control_t;     --! pattern control reg (only if USE_PAT is true)
  signal wdc_control_r     : wdc_control_t;     --! wdc control reg (only if USE_DCACHE is true)
  signal wic_control_r     : wic_control_t;     --! wic control reg (only if USE_ICACHE is true) 
  signal imm_buffer_r      : imm_data_t;        --! imm special buffer reg
  signal imm_control_r     : imm_control_t;     --! imm control reg
  signal spr_control_r     : spr_control_t;     --! spr control reg (only if USE_SPR is true)
  signal rs_r              : op_rs_t;           --! spr rs reg (only if USE_SPR is true)
  signal int_control_r     : int_control_t;     --! int control reg (only if USE_INT is true)
  signal int_delay_r       : int_delay_t;       --! int delay control reg (only if USE_INT is true)
  signal pred_valid_r      : pred_valid_t;      --! pred valid reg (only if USE_BTC is true)
  signal pred_valid_del_r  : pred_valid_t;      --! pred valid del reg (only if USE_BTC is true)
  signal pred_control_r    : pred_control_t;    --! pred control reg (only if USE_BTC is true)
  signal pred_status_r     : pred_status_t;     --! pred status reg (only if USE_BTC is true)
  signal pred_pc_r         : pc_t;              --! pred pc del reg (only if USE_BTC is true)
  signal pc_plus_plus_r    : pc_t;              --! pc plus plus reg (only if USE_BTC is true)  

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- DECODE SIGNALS
  --
  
  signal imm_s             : data_t;
  signal ra_s              : op_reg_t;
  signal rb_s              : op_reg_t;
  signal rd_s              : op_reg_t;
  signal alu_control_s     : alu_control_t;
  signal op_a_control_s    : op_a_control_t;
  signal op_b_control_s    : op_b_control_t;
  signal carry_control_s   : carry_control_t;
  signal carry_keep_s      : carry_keep_t;
  signal branch_control_s  : branch_control_t;
  signal branch_delay_s    : branch_delay_t;
  signal mem_sel_control_s : mem_sel_control_t;
  signal ls_control_s      : ls_control_t;
  signal we_control_s      : we_control_t;
  signal imm_buffer_s      : imm_data_t;
  signal imm_control_s     : imm_control_t;
  signal spr_control_s     : spr_control_t;
  signal rs_s              : op_rs_t;
  signal int_delay_s       : int_delay_t;
  signal cmp_control_s     : cmp_control_t;
  signal bs_control_s      : bs_control_t;
  signal mult_control_s    : mult_control_t;
  signal div_control_s     : div_control_t; 
  signal pat_control_s     : pat_control_t;
  signal int_control_s     : int_control_t;
  signal wdc_control_s     : wdc_control_t;
  signal wic_control_s     : wic_control_t;
  signal rsa_type_s        : rsa_type_t;
  signal rsb_type_s        : rsb_type_t;
  signal rsd_type_s        : rsd_type_t;
  signal mult_type_s       : mult_type_t;
  signal pred_control_s    : pred_control_t;

  --
  -- RF SIGNALS
  --
  
  signal rf_i_s            : rf_i_t;
  signal rf_o_s            : rf_o_t;

begin

  -- //////////////////////////////////////////
  --               COMPONENT LINK
  -- //////////////////////////////////////////

  --
  -- REGISTER FILE
  --
    
  REGISTER_FILE: entity sb_lib.sb_rf(be_sb_rf)
    generic map
    (
      RF_TYPE     => RF_TYPE
    )
    port map
    (
      rf_i        => rf_i_s,
      rf_o        => rf_o_s,
      halt_core_i => halt_core_i,
      stall_i     => stall_i,
      clk_i       => clk_i
    );  

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  -- registered signals
  id_o.pc_o              <= pc_r;
  id_o.rd_o              <= rd_r;
  id_o.imm_o             <= imm_r;
  id_o.alu_control_o     <= alu_control_r;
  id_o.op_a_control_o    <= op_a_control_r;
  id_o.op_b_control_o    <= op_b_control_r;
  id_o.carry_control_o   <= carry_control_r;
  id_o.carry_keep_o      <= carry_keep_r;
  id_o.branch_control_o  <= branch_control_r;
  id_o.branch_delay_o    <= branch_delay_r;
  id_o.we_control_o      <= we_control_r;
  id_o.ls_control_o      <= ls_control_r;
  id_o.mem_sel_control_o <= mem_sel_control_r;
  id_o.int_control_o     <= int_control_r;
  id_o.wdc_control_o     <= wdc_control_r; 
  id_o.wic_control_o     <= wic_control_r; 
  id_o.spr_control_o     <= spr_control_r;
  id_o.rs_o              <= rs_r;
  id_o.cmp_control_o     <= cmp_control_r;
  id_o.bs_control_o      <= bs_control_r;
  id_o.mult_control_o    <= mult_control_r;
  id_o.div_control_o     <= div_control_r;  
  id_o.pat_control_o     <= pat_control_r;
  id_o.pred_valid_o      <= pred_valid_r;
  id_o.pred_valid_del_o  <= pred_valid_del_r;
  id_o.pred_control_o    <= pred_control_r;
  id_o.pred_status_o     <= pred_status_r;
  id_o.pred_pc_o         <= pred_pc_r;
  id_o.pc_plus_plus_o    <= pc_plus_plus_r;
  -- combinatorial signals
  id_o.id_rd_o           <= rd_s;
  id_o.id_ra_o           <= ra_s;
  id_o.id_rb_o           <= rb_s;
  id_o.id_rsa_type_o     <= rsa_type_s; 
  id_o.id_rsb_type_o     <= rsb_type_s; 
  id_o.id_rsd_type_o     <= rsd_type_s;
  id_o.id_mult_type_o    <= mult_type_s;
  id_o.id_pred_control_o <= pred_control_s;
  id_o.id_branch_delay_o <= branch_delay_s;

  --
  -- REGISTER FILE INTERFACE
  --
   
  -- registered signals
  id_o.op_a_o            <= rf_o_s.dat_ra_o;  
  id_o.op_b_o            <= rf_o_s.dat_rb_o;  
  id_o.op_d_o            <= rf_o_s.dat_rd_o;  
  -- combinatorial signals
  rf_i_s.adr_ra_i        <= ra_s;   
  rf_i_s.adr_rb_i        <= rb_s;
  rf_i_s.adr_rd_i        <= rd_s;
  rf_i_s.we_i            <= id_i.wb_we_control_i;
  rf_i_s.adr_wr_i        <= id_i.wb_rd_i;
  rf_i_s.dat_i           <= id_i.wb_res_i;  
   
  --
  -- DECODE LOGIC
  --
  --! This process sets up all control signals according to the SB ISA.
  --! External interrupts are also managed in this process. If an interrupt 
  --! is valid, the instruction in the decode stage is replaced by a branch 
  --! to the base interrupt vector address (by default 0x10). Nested interrupts
  --! are not supported, since the processor disables future interrupts by 
  --! clearing the MSR IE bit. 
  --! Note that op code exceptions are not implemented for a faster and smaller 
  --! implementation.
  COMB_DECODE: process(id_i,
                       imm_buffer_r,
                       imm_control_r,
                       branch_delay_r,
                       int_delay_r)

    alias op_code_a             : opcode_t is id_i.inst_i(31 downto 26);
    alias ra_a                  : op_reg_t is id_i.inst_i(20 downto 16); 
    alias rb_a                  : op_reg_t is id_i.inst_i(15 downto 11); 
    alias rd_a                  : op_reg_t is id_i.inst_i(25 downto 21);
    alias imm_a                 : op_imm_t is id_i.inst_i(15 downto 0);
    alias ext_a                 : op_ext_t is id_i.inst_i(9 downto 0);
    alias sub_control_a         : std_ulogic_vector(1 downto 0) is id_i.inst_i(1 downto 0);
    alias bs_control_a          : std_ulogic_vector(1 downto 0) is id_i.inst_i(10 downto 9);
    alias shift_control_a       : std_ulogic_vector(1 downto 0) is id_i.inst_i(6 downto 5);
    alias sext_control_a        : std_ulogic is id_i.inst_i(0);
    alias write_cache_control_a : std_ulogic_vector(1 downto 0) is id_i.inst_i(3 downto 2);
    alias wdc_flush_a           : std_ulogic is id_i.inst_i(4);  
    alias wdc_clear_a           : std_ulogic is id_i.inst_i(1);
    alias clz_a                 : std_ulogic is id_i.inst_i(7);
    alias branch_control_a      : std_ulogic_vector(1 downto 0) is id_i.inst_i(19 downto 18);
    alias branch_delay_a        : std_ulogic is id_i.inst_i(20);
    alias c_branch_control_a    : std_ulogic_vector(2 downto 0) is id_i.inst_i(23 downto 21);
    alias c_branch_delay_a      : std_ulogic is id_i.inst_i(25);
    alias ret_int_a             : std_ulogic is id_i.inst_i(21);   
    alias msr_mts_a             : std_ulogic_vector(1 downto 0) is id_i.inst_i(15 downto 14);
    alias rs_a                  : std_ulogic_vector(13 downto 0) is id_i.inst_i(13 downto 0);
    alias mult_control_a        : std_ulogic_vector(1 downto 0) is id_i.inst_i(1 downto 0); 
    alias div_control_a         : std_ulogic is id_i.inst_i(1);
    alias pat_control_a         : std_ulogic is id_i.inst_i(10);
    variable spr_control_v      : std_ulogic_vector(2 downto 0);
    
  begin

    -- default assignments (~NOP behaviour)
    -- improve code density and avoid latches
    ra_s              <= ra_a;
    rb_s              <= rb_a;
    rd_s              <= rd_a;
    alu_control_s     <= ALU_ADD;       
    op_a_control_s    <= OP_A_REG_1;    
    op_b_control_s    <= OP_B_REG_2;    
    carry_control_s   <= CARRY_ZERO;  
    carry_keep_s      <= CARRY_KEEP; 
    branch_control_s  <= B_NOP;
    branch_delay_s    <= B_N_DELAY;
    mem_sel_control_s <= WORD;
    ls_control_s      <= LS_NOP;
    we_control_s      <= N_WE;
    imm_s             <= std_ulogic_vector(resize(signed(imm_a),data_t'length)); 
    imm_control_s     <= N_IMM;
    imm_buffer_s      <= (others =>'0');
    int_delay_s       <= INT_N_DELAY;
    int_control_s     <= INT_NOP;
    wdc_control_s     <= WDC_NOP;
    wic_control_s     <= WIC_NOP;
    cmp_control_s     <= CMP_S;
    bs_control_s      <= BS_SLL;
    mult_control_s    <= MULT_LSW;
    div_control_s     <= DIV_UU;
    spr_control_v     := id_i.inst_i(20) & id_i.inst_i(16 downto 15);
    spr_control_s     <= MFS;
    rs_s              <= OP_NOP;
    pat_control_s     <= PAT_BYTE;
    rsa_type_s        <= false;
    rsb_type_s        <= false;
    rsd_type_s        <= false;
    mult_type_s       <= false; 
    pred_control_s    <= N_PE;

    -- handle latched interrupt (instructions with delay slots cannot be interrupted)
    -- force a branch absolute and a link immediate instruction to the base 
    -- interrupt vector address
    if(USE_INT = true and id_i.int_status_i = INT and int_delay_r = INT_N_DELAY) then      
      int_control_s    <= INT_DISABLE; -- disable future interrupt
      rd_s             <= REG14_ADR;
      we_control_s     <= WE;
      branch_control_s <= BNC;
      op_a_control_s   <= OP_A_ZERO;
      op_b_control_s   <= OP_B_IMM;
      if(USE_ICACHE = true) then
        imm_s          <= SB_INT_ADR_W_CACHE;
   
      else
        imm_s          <= SB_INT_ADR_WO_CACHE;  
 
      end if;
    else
      
      -- decode logic according to the SB ISA
      case op_code_a is

        --
        -- INTEGER ARITHMETIC INSTRUCTIONS
        --
        
        when op_add =>
          we_control_s    <= WE;
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;
          rsb_type_s      <= true;
          
        when op_addc =>
          we_control_s    <= WE;
          carry_control_s <= CARRY_ALU;
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;
          rsb_type_s      <= true;

        when op_addk =>
          we_control_s    <= WE;
          rsa_type_s      <= true;
          rsb_type_s      <= true;
          
        when op_addkc =>
          we_control_s    <= WE;
          carry_control_s <= CARRY_ALU;
          rsa_type_s      <= true;
          rsb_type_s      <= true;

        when op_rsub =>
          we_control_s    <= WE;
          op_a_control_s  <= OP_A_NOT_REG_1;
          carry_control_s <= CARRY_ONE;
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;
          rsb_type_s      <= true;
          
        when op_rsubc =>
          we_control_s    <= WE;
          op_a_control_s  <= OP_A_NOT_REG_1;
          carry_control_s <= CARRY_ALU;
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;
          rsb_type_s      <= true;

        when op_rsubk => -- or op_cmp or op_cmpu
          rsa_type_s      <= true;
          rsb_type_s      <= true;

          case sub_control_a is

            -- rsubk 
            when "00" =>
              we_control_s    <= WE;
              op_a_control_s  <= OP_A_NOT_REG_1;
              carry_control_s <= CARRY_ONE;

            -- cmp
            when "01" =>
              we_control_s    <= WE; 
              cmp_control_s   <= CMP_S;
              alu_control_s   <= ALU_CMP;

            -- cmpu  
            when others => 
              we_control_s    <= WE; 
              cmp_control_s   <= CMP_U;
              alu_control_s   <= ALU_CMP;
              
          end case;
          
        when op_rsubkc =>
          we_control_s    <= WE;
          op_a_control_s  <= OP_A_NOT_REG_1;             
          carry_control_s <= CARRY_ALU;
          rsa_type_s      <= true;
          rsb_type_s      <= true;

        when op_addi =>
          we_control_s    <= WE;
          op_b_control_s  <= OP_B_IMM;    
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;
          
        when op_addci =>
          we_control_s    <= WE;
          op_b_control_s  <= OP_B_IMM; 
          carry_control_s <= CARRY_ALU;
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;
          
        when op_addki =>
          we_control_s    <= WE;
          op_b_control_s  <= OP_B_IMM; 
          rsa_type_s      <= true;
          
        when op_addkci =>
          we_control_s    <= WE;
          op_b_control_s  <= OP_B_IMM; 
          carry_control_s <= CARRY_ALU;
          rsa_type_s      <= true;

        when op_rsubi =>
          we_control_s    <= WE;
          op_a_control_s  <= OP_A_NOT_REG_1;
          op_b_control_s  <= OP_B_IMM;
          carry_control_s <= CARRY_ONE;
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;
          
        when op_rsubci =>
          we_control_s    <= WE;
          op_a_control_s  <= OP_A_NOT_REG_1;
          op_b_control_s  <= OP_B_IMM; 
          carry_control_s <= CARRY_ALU;
          carry_keep_s    <= CARRY_N_KEEP;
          rsa_type_s      <= true;

        when op_rsubki =>
          we_control_s    <= WE;
          op_a_control_s  <= OP_A_NOT_REG_1;
          op_b_control_s  <= OP_B_IMM; 
          carry_control_s <= CARRY_ONE;
          rsa_type_s      <= true;
          
        when op_rsubkci =>
          we_control_s    <= WE;
          op_a_control_s  <= OP_A_NOT_REG_1;
          op_b_control_s  <= OP_B_IMM; 
          carry_control_s <= CARRY_ALU;
          rsa_type_s      <= true;

        when op_mul => -- or op_mulh or op_mulhu or op_mulhsu
          if(USE_MULT > 0) then
            we_control_s  <= WE;
            alu_control_s <= ALU_MULT;
            rsa_type_s    <= true;
            rsb_type_s    <= true;
            mult_type_s   <= true; 

            if(USE_MULT > 1) then
              case mult_control_a is
  
                -- mul
                when "00" =>        
                  mult_control_s <= MULT_LSW;

                -- mulh
                when "01" =>
                  mult_control_s <= MULT_HSW_SS;

                -- mulhsu
                when "10" =>
                  mult_control_s <= MULT_HSW_SU;
 
                -- mulhu
                when "11" =>
                  mult_control_s <= MULT_HSW_UU;
              
                when others =>
                  null; 

              end case;
            end if;
            
          else
            report "decode stage: illegal op code because the hardware multiplier is not implemented" severity warning;
            
          end if; 

        when op_muli =>
          if(USE_MULT > 0) then
            we_control_s   <= WE;
            alu_control_s  <= ALU_MULT;
            op_b_control_s <= OP_B_IMM; 
            rsa_type_s     <= true;
            mult_type_s    <= true; 

          else
            report "decode stage: illegal op code because the hardware multiplier is not implemented" severity warning;
            
          end if; 

        when op_idiv => -- or op_idivu
          if(USE_DIV = true) then
            we_control_s    <= WE;
            alu_control_s   <= ALU_DIV;
            rsa_type_s      <= true;
            rsb_type_s      <= true;

            -- unsigned div
            if(div_control_a = '1') then
              div_control_s <= DIV_UU;

              -- signed div
            else
              div_control_s <= DIV_SS;

            end if;
 
          else
            report "decode stage: illegal op code because the divider multiplier is not implemented" severity warning;

          end if;

        --
        -- LOGICAL INSTRUCTIONS
        --

        when op_or => -- or op_pcmpbf
          if(USE_PAT = true) then
            -- pcmpbf
            if(pat_control_a = '1') then
              we_control_s  <= WE;
              alu_control_s <= ALU_PAT;
              rsa_type_s    <= true;
              rsb_type_s    <= true;  
 
              -- or           
            else 
              we_control_s  <= WE;
              alu_control_s <= ALU_OR;
              rsa_type_s    <= true;
              rsb_type_s    <= true;  
              
            end if;

            -- or
          else 
            we_control_s  <= WE;
            alu_control_s <= ALU_OR;
            rsa_type_s    <= true;
            rsb_type_s    <= true;  
            
          end if;
          
        when op_and =>
          we_control_s  <= WE;
          alu_control_s <= ALU_AND;
          rsa_type_s    <= true;
          rsb_type_s    <= true;  

        when op_xor => -- or op_pcmpeq
          if(USE_PAT = true) then
            -- pcmpeq
            if(pat_control_a = '1') then
              we_control_s  <= WE;
              alu_control_s <= ALU_PAT;
              pat_control_s <= PAT_EQ;
              rsa_type_s    <= true;
              rsb_type_s    <= true;  
  
              -- xor           
            else 
              we_control_s  <= WE;
              alu_control_s <= ALU_XOR;
              rsa_type_s    <= true;
              rsb_type_s    <= true;  
              
            end if;

           -- xor
          else
            we_control_s  <= WE;
            alu_control_s <= ALU_XOR;
            rsa_type_s    <= true;
            rsb_type_s    <= true;  
            
          end if;
          
        when op_andn => -- or op_pcmpne
          if(USE_PAT = true) then
            -- pcmpne
            if(pat_control_a = '1') then
              we_control_s  <= WE;
              alu_control_s <= ALU_PAT;
              pat_control_s <= PAT_NE;
              rsa_type_s    <= true;
              rsb_type_s    <= true;  

              -- andn           
            else 
              we_control_s   <= WE;
              alu_control_s  <= ALU_AND;
              op_b_control_s <= OP_B_NOT_REG_2;
              rsa_type_s     <= true;
              rsb_type_s     <= true;  
              
            end if;

            -- andn
          else
            we_control_s   <= WE;
            alu_control_s  <= ALU_AND;
            op_b_control_s <= OP_B_NOT_REG_2;
            rsa_type_s     <= true;
            rsb_type_s     <= true;  
            
          end if;

        when op_ori =>
          we_control_s   <= WE;
          alu_control_s  <= ALU_OR;
          op_b_control_s <= OP_B_IMM;
          rsa_type_s     <= true;
          
        when op_andi =>
          we_control_s   <= WE;
          alu_control_s  <= ALU_AND;
          op_b_control_s <= OP_B_IMM;
          rsa_type_s     <= true;
          
        when op_xori =>
          we_control_s   <= WE;
          alu_control_s  <= ALU_XOR;
          op_b_control_s <= OP_B_IMM;
          rsa_type_s     <= true;
          
        when op_andni =>
          we_control_s   <= WE;
          alu_control_s  <= ALU_AND;
          op_b_control_s <= OP_B_NOT_IMM;
          rsa_type_s     <= true;

        --
        -- SHIFT & SIGN & CACHE INSTRUCTIONS
        --

        when op_bsra => -- or op_bsll or op_bsrl
          if(USE_BS > 0) then
            we_control_s  <= WE;       
            alu_control_s <= ALU_BS; 
            rsa_type_s    <= true;
            rsb_type_s    <= true;  

            case bs_control_a is 

              -- bsrl
              when "00" =>
                bs_control_s <= BS_SRL;

              -- bsll
              when "10" =>
                bs_control_s <= BS_SLL;

              -- bsra
              when others =>
                bs_control_s <= BS_SRA;
 
            end case;
 
          else
            report "decode stage: illegal op code because barrel shifter primitives are not implemented" severity warning;
            
          end if;         
          
        when op_bsrli => -- or op_bsrai or bslli
          if(USE_BS > 0) then
            we_control_s   <= WE;
            alu_control_s  <= ALU_BS;
            op_b_control_s <= OP_B_IMM;
            rsa_type_s     <= true;

            case bs_control_a is 

              -- bsrli
              when "00" =>
                bs_control_s <= BS_SRL;

              -- bslli
              when "10" =>
                bs_control_s <= BS_SLL;

              -- bsrai
              when others =>
                bs_control_s <= BS_SRA;
 
            end case;

          else
            report "decode stage: illegal op code because barrel shifter primitives are not implemented" severity warning;
            
          end if;      
          
        when op_sra =>  -- or op_src or op_srl or op_sext8 or op_sext16 or op_wdc or op_wic or op_clz
          we_control_s <= WE;
          rsa_type_s   <= true;
          
          case shift_control_a is

            -- sra
            when "00" =>
              alu_control_s   <= ALU_SHIFT;
              carry_control_s <= CARRY_ARITH;
              
            -- src
            when "01" =>
              alu_control_s   <= ALU_SHIFT;
              carry_control_s <= CARRY_ALU;
              
            -- srl
            when "10" =>
              alu_control_s   <= ALU_SHIFT;
              carry_control_s <= CARRY_ZERO;

            -- sext8 or sext16 or wdc or wic or clz
            when "11" =>
              -- clz
              if(USE_CLZ = true and clz_a = '1') then
                alu_control_s <= ALU_CLZ;

              else
                case write_cache_control_a is

                  -- wdc instructions
                  when "01" =>
                    if(USE_DCACHE = true and USE_WRITEBACK = true) then
                      rsb_type_s      <= true;
                      -- flush
                      if(wdc_flush_a = '1') then
                        wdc_control_s <= WDC_FLUSH;  

                        -- invalid
                      else
                        wdc_control_s <= WDC_INVALID;

                      end if;
                      
                    elsif(USE_DCACHE = true and USE_WRITEBACK = false) then
                        -- invalid
                        wdc_control_s <= WDC_INVALID;

                    else
                      report "decode stage: illegal op code data cache is not implemented" severity warning;
                      
                    end if;

                  -- wic invalid instruction
                  when "10" =>
                    if(USE_ICACHE = true) then
                      wic_control_s <= WIC_INVALID; 
                      
                    else
                      report "decode stage: illegal op code instruction cache is not implemented" severity warning;
                      
                    end if; 

                  -- sext instructions  
                  when others =>
                    -- sext16
                    if(sext_control_a = '1') then 
                      alu_control_s <= ALU_S16;

                      -- sext8
                    else
                      alu_control_s <= ALU_S8;
                      
                    end if;

                end case;

              end if;
              
            when others =>
              null; 
              
          end case;
          
        --
        -- UNCONDITIONAL BRANCHES
        --

        when op_br => -- or op_brd or op_brld or op_bra or op_brad or op_brald 
          branch_control_s <= BNC;
          int_delay_s      <= branch_delay_a;
          branch_delay_s   <= branch_delay_a;
          rsb_type_s       <= true;

          case branch_control_a is

            -- br & brd 
            when "00" =>        
              op_a_control_s <= OP_A_PC;
              
              -- brld
            when "01" => 
              we_control_s   <= WE; 
              op_a_control_s <= OP_A_PC;  

              -- bra & brad
            when "10" =>
              op_a_control_s <= OP_A_ZERO;
              
              -- brald
            when "11" =>
              we_control_s   <= WE; 
              op_a_control_s <= OP_A_ZERO;

            when others =>
              null; 

          end case;

        when op_bri => -- or op_brid or brlid or op_brai or op_braid or bralid 
          branch_control_s <= BNC;
          op_b_control_s   <= OP_B_IMM;
          int_delay_s      <= branch_delay_a;
          branch_delay_s   <= branch_delay_a;
          pred_control_s   <= PE;
          
          case branch_control_a is

            -- bri & brid 
            when "00" =>        
              op_a_control_s <= OP_A_PC;

              -- brlid
            when "01" =>
              we_control_s   <= WE; 
              op_a_control_s <= OP_A_PC;  

              -- brai & braid
            when "10" =>
              op_a_control_s <= OP_A_ZERO;

              -- bralid
            when "11" =>
              we_control_s   <= WE; 
              op_a_control_s <= OP_A_ZERO;
              
            when others =>
              null; 

          end case;
          
        --
        -- CONDITIONAL BRANCHES
        --

        when op_beq => -- or op_bne or op_blt or op_ble or op_bge or op_beqd or op_bned or op_bltd or op_bgtd or op_bged or op_bgt or op_bled
          op_a_control_s <= OP_A_PC;
          int_delay_s    <= c_branch_delay_a;
          branch_delay_s <= c_branch_delay_a;
          rsa_type_s     <= true;
          rsb_type_s     <= true;

          case c_branch_control_a is
            
            -- beq
            when "000" =>
              branch_control_s <= BEQ;

              -- bne
            when "001" =>
              branch_control_s <= BNE;
              
              -- blt
            when "010" =>
              branch_control_s <= BLT;
              
              -- ble
            when "011" =>
              branch_control_s <= BLE;
              
              -- bgt
            when "100" =>
              branch_control_s <= BGT;
              
              -- bge
            when others =>
              branch_control_s <= BGE;
              
          end case;

        when op_beqi => -- or op_bnei or op_blti or op_blei or op_bgei or op_beqid or op_bneid or op_bltid or op_bgtid or op_bgeid or op_bgti or op_bleid
          op_a_control_s <= OP_A_PC;
          op_b_control_s <= OP_B_IMM;
          int_delay_s    <= c_branch_delay_a;
          branch_delay_s <= c_branch_delay_a;
          rsa_type_s     <= true;
          pred_control_s <= PE;
          
          case c_branch_control_a is
            
            -- beqi
            when "000" =>
              branch_control_s <= BEQ;

              -- bnei
            when "001" =>
              branch_control_s <= BNE;
              
              -- blti
            when "010" =>
              branch_control_s <= BLT;
              
              -- blei
            when "011" =>
              branch_control_s <= BLE;
              
              -- bgti
            when "100" =>
              branch_control_s <= BGT;
              
              -- bgei
            when others =>
              branch_control_s <= BGE;
              
          end case;

        --
        -- LOAD/STORE OPERATIONS
        --

        when op_lbu =>
          we_control_s      <= WE;
          ls_control_s      <= LOAD;
          mem_sel_control_s <= BYTE;
          rsa_type_s        <= true;
          rsb_type_s        <= true;

        when op_lhu =>
          we_control_s      <= WE;
          ls_control_s      <= LOAD;          
          mem_sel_control_s <= HALFWORD;
          rsa_type_s        <= true;
          rsb_type_s        <= true;

        when op_lw  =>
          we_control_s      <= WE;
          ls_control_s      <= LOAD;          
          mem_sel_control_s <= WORD;
          rsa_type_s        <= true;
          rsb_type_s        <= true;
          
        when op_sb  =>
          ls_control_s      <= STORE;
          mem_sel_control_s <= BYTE;
          rsa_type_s        <= true;
          rsb_type_s        <= true;
          rsd_type_s        <= true;

        when op_sh  =>
          ls_control_s      <= STORE;
          mem_sel_control_s <= HALFWORD;
          rsa_type_s        <= true;
          rsb_type_s        <= true;
          rsd_type_s        <= true;

        when op_sw =>
          ls_control_s      <= STORE;
          mem_sel_control_s <= WORD;
          rsa_type_s        <= true;
          rsb_type_s        <= true;
          rsd_type_s        <= true;

        when op_lbui =>
          we_control_s      <= WE;
          ls_control_s      <= LOAD;        
          mem_sel_control_s <= BYTE;
          op_b_control_s    <= OP_B_IMM;
          rsa_type_s        <= true;
          
        when op_lhui =>
          we_control_s      <= WE;
          ls_control_s      <= LOAD;        
          mem_sel_control_s <= HALFWORD;
          op_b_control_s    <= OP_B_IMM;
          rsa_type_s        <= true;
          
        when op_lwi =>
          we_control_s      <= WE;
          ls_control_s      <= LOAD;
          mem_sel_control_s <= WORD;
          op_b_control_s    <= OP_B_IMM;
          rsa_type_s        <= true;
          
        when op_sbi =>
          ls_control_s      <= STORE;
          mem_sel_control_s <= BYTE;
          op_b_control_s    <= OP_B_IMM;
          rsa_type_s        <= true;
          rsd_type_s        <= true;
          
        when op_shi =>
          ls_control_s      <= STORE;
          mem_sel_control_s <= HALFWORD;
          op_b_control_s    <= OP_B_IMM;
          rsa_type_s        <= true;
          rsd_type_s        <= true;
          
        when op_swi =>
          ls_control_s      <= STORE;
          mem_sel_control_s <= WORD;
          op_b_control_s    <= OP_B_IMM;
          rsa_type_s        <= true;
          rsd_type_s        <= true;
          
        --
        -- MISC INSTRUCTIONS
        --

        when op_mfs =>  -- or op_mts or op_msrclr or op_msrset
          if(USE_SPR = true) then          
            alu_control_s <= ALU_SPR;

            -- mts instruction
            if(msr_mts_a = "11") then 
              spr_control_s <= MTS;
              rsa_type_s    <= true;
              case rs_a is

                when "00000000000001" =>
                  rs_s <= OP_MSR;

                when others =>
 
              end case;
			
            else
              case spr_control_v is 
              
                -- mfs
                when "001" =>
                  we_control_s   <= WE;
                  spr_control_s  <= MFS;
                  case rs_a is

                    when "00000000000000" =>
                      rs_s <= OP_PC;

                    when "00000000000001" =>
                      rs_s <= OP_MSR;

                    when others =>

                  end case;
                
                -- clear
                when "110" =>
                  we_control_s   <= WE;
                  spr_control_s  <= MSR_CLEAR;
                  op_b_control_s <= OP_B_NOT_IMM;
                
                -- set 
                when others =>
                  we_control_s   <= WE;
                  spr_control_s  <= MSR_SET;
                  op_b_control_s <= OP_B_IMM;            
                
              end case;
              
            end if;

          else
            report "decode stage: illegal op code because spr instructions are not implemented" severity warning;
            
          end if;
          
        when op_rtsd => -- or op_rtid
          op_b_control_s   <= OP_B_IMM;   
          branch_control_s <= BNC;
          int_delay_s      <= INT_DELAY;
          branch_delay_s   <= B_DELAY;
          rsa_type_s       <= true;
          pred_control_s   <= PE;
          
          -- rtid
          if(USE_INT = true and ret_int_a = '1') then
            int_control_s  <= INT_ENABLE; -- enable future interrupt
          end if;
 
        -- imm instruction
        -- when op_imm =>
        when others =>                   
          imm_control_s <= IS_IMM;
          imm_buffer_s  <= imm_a;
          int_delay_s   <= INT_DELAY;

      end case;

      -- handle special imm instruction
      if(imm_control_r = IS_IMM) then 
        imm_s <= imm_buffer_r & imm_a;
      end if;
		
      -- force no write-back for register 0 (always null)
      if(rd_a = REG0_ADR) then
        we_control_s <= N_WE;
      end if;

    end if;
    
  end process COMB_DECODE;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  -- //////////////////////////////////////////
  --              ID/EX REGISTERS
  -- //////////////////////////////////////////

  -- 
  -- DECODE REGISTERS
  --
  --! This process implements the behaviour of most ID pipeline registers.
  CYCLE_I_DECODE: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset / flush
      if(rst_n_i = '0' or (flush_i = '1' and halt_core_i = '0')) then
        if(USE_DIV = true) then
          alu_control_r    <= ALU_ADD; -- avoid MCI hazard 
        end if;
        carry_keep_r       <= CARRY_KEEP;
        branch_control_r   <= B_NOP;    
        branch_delay_r     <= B_N_DELAY; 
        ls_control_r       <= LS_NOP;
        we_control_r       <= N_WE;
        imm_control_r      <= N_IMM;
        if(USE_INT = true) then
          int_delay_r      <= INT_N_DELAY;
          int_control_r    <= INT_NOP;
        end if;
        if(USE_ICACHE = true) then
          wdc_control_r    <= WDC_NOP;
        end if;
        if(USE_ICACHE = true) then
          wic_control_r    <= WIC_NOP;
        end if;
        if(USE_BTC = true) then
          pred_valid_r     <= P_N_VALID;
          pred_valid_del_r <= P_N_VALID;
          pred_control_r   <= N_PE;
        end if;
        
      elsif(halt_core_i = '0' and stall_i = '0') then
        pc_r               <= id_i.pc_i;
        imm_r              <= imm_s;
        rd_r               <= rd_s;
        alu_control_r      <= alu_control_s;
        op_a_control_r     <= op_a_control_s;
        op_b_control_r     <= op_b_control_s;
        carry_control_r    <= carry_control_s;
        carry_keep_r       <= carry_keep_s;
        branch_control_r   <= branch_control_s;       
        branch_delay_r     <= branch_delay_s;
        ls_control_r       <= ls_control_s;
        we_control_r       <= we_control_s;
        mem_sel_control_r  <= mem_sel_control_s;
        imm_buffer_r       <= imm_buffer_s;
        imm_control_r      <= imm_control_s;
        cmp_control_r      <= cmp_control_s;
        if(USE_SPR = true) then
          spr_control_r    <= spr_control_s;
          rs_r             <= rs_s;
        end if;
        if(USE_INT = true) then
          int_delay_r      <= int_delay_s;
          int_control_r    <= int_control_s;
        end if;
        if(USE_DCACHE = true) then
          wdc_control_r    <= wdc_control_s;
        end if;
        if(USE_ICACHE = true) then
          wic_control_r    <= wic_control_s;
        end if;
        if(USE_BS > 0) then
          bs_control_r     <= bs_control_s;
        end if;
        if(USE_MULT > 1) then
          mult_control_r   <= mult_control_s;
        end if;
        if(USE_DIV = true) then
          div_control_r    <= div_control_s;
        end if;
        if(USE_PAT = true) then
          pat_control_r    <= pat_control_s;
        end if;
        if(USE_BTC = true) then
          pred_valid_r     <= id_i.pred_valid_i;
          pred_valid_del_r <= id_i.pred_valid_del_i;
          pred_control_r   <= pred_control_s;
          pred_status_r    <= id_i.pred_status_i;
          pred_pc_r        <= id_i.pred_pc_i;
          pc_plus_plus_r   <= id_i.pc_plus_plus_i;
        end if;
        
      end if;
      
    end if;

  end process CYCLE_I_DECODE;  

end be_sb_decode;


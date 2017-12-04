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
--! @file sb_hazard_controller.vhd                                        					
--! @brief SecretBlaze Hazard Controller     				
--! @author Lyonel Barthe
--! @version 2.1
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 2.1 17/05/2011 by Lyonel Barthe
-- Changed the implementation of MCI hazards
-- in order to keep stable values for MCI
-- units
--
-- Version 2.0 9/02/2011 by Lyonel Barthe
-- New version using a FSM implementation to
-- to improve timing issues
--
-- Version 1.3 05/01/2011 by Lyonel Barthe
-- Added support for multi cycle instructions
--
-- Version 1.2 23/12/2010 by Lyonel Barthe
-- Added more forwarding trade-offs
--
-- Version 1.1 20/11/2010 by Lyonel Barthe
-- Changed coding style with the forward control logic
--
-- Version 1.0 15/07/2010 by Lyonel Barthe
-- New version with simplified stall and flush signals
--
-- Version 0.1 23/02/2010 by Lyonel Barthe
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
--! The task of the hazard controller unit is to handle both branch
--! and data hazards of the SecretBlaze's pipelined datapath. It 
--! provides proper stall, flush, and forward control signals for 
--! each stage of the pipeline. This module was identified as a major
--! performance issue and was finally optimized for FPGA architectures.
--! More detailed information about its implementation are given in:
--! Lyonel Barthe et al., "Optimizing an Open-Source Processor for FPGAs: 
--! A Case Study," FPL, pp. 551-556, 2011.
--

--! SecretBlaze Hazard Controller Entity
entity sb_hazard_controller is
 
  generic
    (
      USE_MULT      : natural := USER_USE_MULT;      --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
      USE_PIPE_MULT : boolean := USER_USE_PIPE_MULT; --! if true, it will implement a pipelined 32-bit multiplier using 17x17 signed multipliers
      USE_BS        : natural := USER_USE_BS;        --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
      USE_PIPE_BS   : boolean := USER_USE_PIPE_BS;   --! it true, it will implement a pipelined barrel shifter
      USE_DIV       : boolean := USER_USE_DIV;       --! if true, it will implement divide instructions
      USE_PAT       : boolean := USER_USE_PAT;       --! if true, it will implement pattern instructions
      USE_CLZ       : boolean := USER_USE_CLZ;       --! if true, it will implement the count leading zeros instruction
      USE_PIPE_CLZ  : boolean := USER_USE_PIPE_CLZ;  --! it true, it will implement a pipelined clz instruction
      STRICT_HAZ    : boolean := USER_STRICT_HAZ;    --! if true, it will implement a strict hazard controller which checks the type of the instruction
      FW_IN_MULT    : boolean := USER_FW_IN_MULT;    --! if true, it will implement the data forwarding for the inputs of the MULT unit
      FW_LD         : boolean := USER_FW_LD          --! if true, it will implement the data forwarding for LOAD instructions
    );
 
  port
    (
      haz_ctr_i     : in haz_ctr_i_t;                --! hazard controller inputs
      haz_ctr_o     : out haz_ctr_o_t;               --! hazard controller outputs
      halt_core_i   : in std_ulogic;                 --! halt core signal 
      clk_i         : in std_ulogic;                 --! core clock
      rst_n_i       : in std_ulogic                  --! active-low reset signal  
    );
  
end sb_hazard_controller;

--! SecretBlaze Hazard Controller Architecture
architecture be_sb_hazard_controller of sb_hazard_controller is

  -- //////////////////////////////////////////
  --             INTERNAL CONSTANT
  -- //////////////////////////////////////////

  -- auto-computed
  constant USE_PIPE_INST : boolean := ((USE_PIPE_MULT = true and USE_MULT > 0) or (USE_PIPE_BS = true and USE_BS > 0) or 
                                                                                  (USE_PIPE_CLZ = true and USE_CLZ = true));
 
  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  signal haz_current_state_r         : haz_fsm_t;       --! haz fsm register
  signal id_ex_fw_op_a_control_r     : fw_control_t;    --! id/ex forward op a control register
  signal id_ex_fw_op_b_control_r     : fw_control_t;    --! id/ex forward op b control register
  signal id_ex_fw_op_d_control_r     : fw_control_t;    --! id/ex forward op d control register
  signal ex_ma_ld_haz_r              : hazard_status_t; --! ex/ma load haz status register
  signal ma_wb_ld_haz_r              : hazard_status_t; --! ma/wb load haz status register (only if FW_LD is false)
  signal ex_ma_pipe_inst_haz_r       : hazard_status_t; --! ex/ma pipelined instruction haz status register (only if pipelined MULT or BS or CLZ)
  signal ex_ma_partial_fw_haz_r      : hazard_status_t; --! ex/ma partial fw haz status register (only if FW_IN_MULT is false)
  signal ma_wb_partial_fw_haz_r      : hazard_status_t; --! ma/wb partial fw haz status register (only if FW_IN_MULT is false)

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal haz_next_state_s            : haz_fsm_t;   
  signal if_stall_s                  : std_ulogic;
  signal id_stall_s                  : std_ulogic;
  signal id_flush_s                  : std_ulogic;
  signal ex_stall_s                  : std_ulogic;
  signal ex_flush_s                  : std_ulogic;
  signal mci_flush_s                 : std_ulogic;
  signal ma_flush_s                  : std_ulogic;
  signal id_fw_op_a_control_s        : fw_control_t;
  signal id_fw_op_b_control_s        : fw_control_t;
  signal id_fw_op_d_control_s        : fw_control_t;
  signal id_fw_op_a_control_wo_haz_s : fw_control_t;
  signal id_fw_op_b_control_wo_haz_s : fw_control_t;
  signal id_fw_op_d_control_wo_haz_s : fw_control_t;
  signal rf_res_a_lock_s             : std_ulogic; 
  signal rf_res_b_lock_s             : std_ulogic; 
  signal rf_res_d_lock_s             : std_ulogic; 
  signal ex_ld_haz_s                 : hazard_status_t; 
  signal ex_pipe_inst_haz_s          : hazard_status_t; 
  signal ma_ld_haz_s                 : hazard_status_t;
  signal ex_partial_fw_haz_s         : hazard_status_t; 
  signal ma_partial_fw_haz_s         : hazard_status_t; 

begin
  
  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  -- registered signals
  haz_ctr_o.id_ex_fw_op_a_control_o <= id_ex_fw_op_a_control_r;
  haz_ctr_o.id_ex_fw_op_b_control_o <= id_ex_fw_op_b_control_r;
  haz_ctr_o.id_ex_fw_op_d_control_o <= id_ex_fw_op_d_control_r;
  -- combinatorial signals
  haz_ctr_o.if_stall_o              <= if_stall_s;
  haz_ctr_o.id_stall_o              <= id_stall_s;
  haz_ctr_o.id_flush_o              <= id_flush_s;
  haz_ctr_o.ex_stall_o              <= ex_stall_s;
  haz_ctr_o.ex_flush_o              <= ex_flush_s;
  haz_ctr_o.mci_flush_o             <= mci_flush_s;
  haz_ctr_o.ma_flush_o              <= ma_flush_s;
  haz_ctr_o.rf_res_a_lock_o         <= rf_res_a_lock_s;
  haz_ctr_o.rf_res_b_lock_o         <= rf_res_b_lock_s;
  haz_ctr_o.rf_res_d_lock_o         <= rf_res_d_lock_s;

  --
  -- FORWARD CONTROL LOGIC 
  --
  --! This process computes the data dependencies of 
  --! the instruction in the decode stage used for
  --! the register forwarding feature implemented
  --! in the execute stage. It is done without 
  --! considering data and branch hazards.
  COMB_ID_FORWARD_CONTROL_LOGIC: process(haz_ctr_i)
  begin

    --
    -- OPERAND A
    --

    -- forward from EX/MA
    if((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsa_type_i = true)) and 
       (haz_ctr_i.id_ra_i = haz_ctr_i.id_ex_rd_i and haz_ctr_i.id_ex_we_control_i = WE)) then
      id_fw_op_a_control_wo_haz_s <= FW_EX_MA;

      -- forward from MA/WB
    elsif((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsa_type_i = true)) and 
       (haz_ctr_i.id_ra_i = haz_ctr_i.ex_ma_rd_i and haz_ctr_i.ex_ma_we_control_i = WE)) then
      id_fw_op_a_control_wo_haz_s <= FW_MA_WB;

      -- forward from WB/RF
    elsif((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsa_type_i = true)) and 
       (haz_ctr_i.id_ra_i = haz_ctr_i.ma_wb_rd_i and haz_ctr_i.ma_wb_we_control_i = WE)) then
      id_fw_op_a_control_wo_haz_s <= FW_WB_RF;

      -- no forward
    else
      id_fw_op_a_control_wo_haz_s <= FW_NOP;

    end if;

    --
    -- OPERAND B
    --

    -- forward from EX/MA
    if((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsb_type_i = true)) and 
       (haz_ctr_i.id_rb_i = haz_ctr_i.id_ex_rd_i and haz_ctr_i.id_ex_we_control_i = WE)) then
      id_fw_op_b_control_wo_haz_s <= FW_EX_MA;

      -- forward from MA/WB
    elsif((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsb_type_i = true)) and 
       (haz_ctr_i.id_rb_i = haz_ctr_i.ex_ma_rd_i and haz_ctr_i.ex_ma_we_control_i = WE)) then
      id_fw_op_b_control_wo_haz_s <= FW_MA_WB;

      -- forward from WB/RF
    elsif((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsb_type_i = true)) and 
       (haz_ctr_i.id_rb_i = haz_ctr_i.ma_wb_rd_i and haz_ctr_i.ma_wb_we_control_i = WE)) then
      id_fw_op_b_control_wo_haz_s <= FW_WB_RF;

      -- no forward
    else
      id_fw_op_b_control_wo_haz_s <= FW_NOP;

    end if;

    --
    -- OPERAND D 
    --

    -- forward from EX/MA
    if((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsd_type_i = true)) and 
       (haz_ctr_i.id_rd_i = haz_ctr_i.id_ex_rd_i and haz_ctr_i.id_ex_we_control_i = WE)) then
      id_fw_op_d_control_wo_haz_s <= FW_EX_MA;

      -- forward from MA/WB
    elsif((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsd_type_i = true)) and 
       (haz_ctr_i.id_rd_i = haz_ctr_i.ex_ma_rd_i and haz_ctr_i.ex_ma_we_control_i = WE)) then
      id_fw_op_d_control_wo_haz_s <= FW_MA_WB;

      -- forward from WB/RF
    elsif((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsd_type_i = true)) and 
       (haz_ctr_i.id_rd_i = haz_ctr_i.ma_wb_rd_i and haz_ctr_i.ma_wb_we_control_i = WE)) then
      id_fw_op_d_control_wo_haz_s <= FW_WB_RF;

      -- no forward
    else
      id_fw_op_d_control_wo_haz_s <= FW_NOP;

    end if;

  end process COMB_ID_FORWARD_CONTROL_LOGIC;

  --
  -- DATA HAZARD CONTROL LOGIC
  --
  --! This process detects data hazards for an instruction
  --! that cannot be solved using the forward control logic.
  --! Note such hazards are detected during the decode
  --! stage but are managed during the execute stage.
  COMB_ID_DATA_HAZARD_CONTROL_LOGIC: process(haz_ctr_i)
 
    variable ex_op_a_cond_v : boolean;
    variable ex_op_b_cond_v : boolean;
    variable ma_op_a_cond_v : boolean;
    variable ma_op_b_cond_v : boolean;

  begin

    --
    -- COMPUTE LOAD STALL CONDITIONS
    --

    -- LOAD stall conditions (always true for a 5-stage pipeline) 
    -- Example: Add Rx, Rx, R2 in decode / Load R2, Rx, Rx in execute
    if(((haz_ctr_i.id_ex_ls_control_i = LOAD) and 
       (((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsa_type_i = true)) and haz_ctr_i.id_ra_i = haz_ctr_i.id_ex_rd_i) or 
        ((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsb_type_i = true)) and haz_ctr_i.id_rb_i = haz_ctr_i.id_ex_rd_i) or 
        ((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsd_type_i = true)) and haz_ctr_i.id_rd_i = haz_ctr_i.id_ex_rd_i)))) then
      ex_ld_haz_s <= HAZARD_DETECTED;

    else
      ex_ld_haz_s <= HAZARD_N_DETECTED;

    end if;

    -- LOAD stall conditions (optional)
    -- Example: Add Rx, Rx, R2 in decode / Load R2, Rx, Rx in memory access
    if(((FW_LD = false and haz_ctr_i.ex_ma_ls_control_i = LOAD) and
       (((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsa_type_i = true)) and haz_ctr_i.id_ra_i = haz_ctr_i.ex_ma_rd_i) or 
        ((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsb_type_i = true)) and haz_ctr_i.id_rb_i = haz_ctr_i.ex_ma_rd_i) or 
        ((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsd_type_i = true)) and haz_ctr_i.id_rd_i = haz_ctr_i.ex_ma_rd_i)))) then  
      ma_ld_haz_s <= HAZARD_DETECTED;

    else
      ma_ld_haz_s <= HAZARD_N_DETECTED;

    end if;

    --
    -- COMPUTE PIPELINED INSTRUCTION STALL CONDITIONS
    --

    -- pipelined BS or MULT or CLZ stall conditions (optional) 
    -- Example: Add Rx, Rx, R2 in decode / MULT R2, Rx, Rx in execute 
    if(((USE_PIPE_INST = true and (haz_ctr_i.id_ex_alu_control_i = ALU_MULT or 
                                   haz_ctr_i.id_ex_alu_control_i = ALU_BS or 
                                   haz_ctr_i.id_ex_alu_control_i = ALU_CLZ)) and 
       (((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsa_type_i = true)) and haz_ctr_i.id_ra_i = haz_ctr_i.id_ex_rd_i) or 
        ((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsb_type_i = true)) and haz_ctr_i.id_rb_i = haz_ctr_i.id_ex_rd_i) or 
        ((STRICT_HAZ = false or (STRICT_HAZ = true and haz_ctr_i.id_rsd_type_i = true)) and haz_ctr_i.id_rd_i = haz_ctr_i.id_ex_rd_i)))) then
      ex_pipe_inst_haz_s <= HAZARD_DETECTED;

    else
      ex_pipe_inst_haz_s <= HAZARD_N_DETECTED;

    end if;

    --
    -- COMPUTE PARTIAL FORWARDING CONDITIONS
    --

    --
    -- MULT without full forwarding stall conditions (optional)
    -- Example: Mult/Bs Rx, Rx, R2 in decode / Add R2, Rx, Rx in execute or memory access or write-back
    if((USE_MULT > 0 and FW_IN_MULT = false)) then

      if((STRICT_HAZ = false or (STRICT_HAZ = true  and haz_ctr_i.id_rsa_type_i = true)) and
         ((haz_ctr_i.id_ra_i = haz_ctr_i.id_ex_rd_i and haz_ctr_i.id_ex_we_control_i = WE))) then
        ex_op_a_cond_v := true;      

      else
        ex_op_a_cond_v := false;

      end if;

      if((STRICT_HAZ = false or (STRICT_HAZ = true  and haz_ctr_i.id_rsa_type_i = true)) and
         ((haz_ctr_i.id_ra_i = haz_ctr_i.ex_ma_rd_i and haz_ctr_i.ex_ma_we_control_i = WE))) then
        ma_op_a_cond_v := true;      

      else
        ma_op_a_cond_v := false;

      end if;

      if((STRICT_HAZ = false or (STRICT_HAZ = true  and haz_ctr_i.id_rsb_type_i = true)) and
         ((haz_ctr_i.id_rb_i = haz_ctr_i.id_ex_rd_i and haz_ctr_i.id_ex_we_control_i = WE))) then
        ex_op_b_cond_v := true;      

      else
        ex_op_b_cond_v := false;

      end if;

      if((STRICT_HAZ = false or (STRICT_HAZ = true  and haz_ctr_i.id_rsb_type_i = true)) and
         ((haz_ctr_i.id_rb_i = haz_ctr_i.ex_ma_rd_i and haz_ctr_i.ex_ma_we_control_i = WE))) then
        ma_op_b_cond_v := true;      

      else
        ma_op_b_cond_v := false;

      end if;

      if((USE_MULT > 0 and FW_IN_MULT = false) and (haz_ctr_i.id_mult_type_i = true) and ((ex_op_a_cond_v = true) or 
                                                                                          (ex_op_b_cond_v = true))) then
        ex_partial_fw_haz_s <= HAZARD_DETECTED;

      else
        ex_partial_fw_haz_s <= HAZARD_N_DETECTED;

      end if;

      if((USE_MULT > 0 and FW_IN_MULT = false) and (haz_ctr_i.id_mult_type_i = true) and ((ma_op_a_cond_v = true) or 
                                                                                          (ma_op_b_cond_v = true))) then
        ma_partial_fw_haz_s <= HAZARD_DETECTED;

      else
        ma_partial_fw_haz_s <= HAZARD_N_DETECTED;

      end if;

    end if;

  end process COMB_ID_DATA_HAZARD_CONTROL_LOGIC;

  --
  -- HAZARD FSM CONTROL LOGIC
  --
  --! This process implements the hazard controller using a FSM with 7 states: 
  --!   - HAZ_CHECK_ALL defauft state, all hazards must be checked,
  --!   - HAZ_BRANCH_DEL a data hazard was cleared in the delay slot 
  --!     and a branch hazard is pending,
  --!   - HAZ_BRANCH_MCI a mci hazard is being cleared in the delay slot
  --!     and a branch hazard is pending,
  --!   - HAZ_BRANCH_DONE a branch hazard was cleared,
  --!   - HAZ_DATA_DEL a data hazard was delayed, it can be handled during
  --!     the next clock cycle,
  --!   - HAZ_DATA_DONE a data hazard was cleared, and
  --!   - HAZ_MCI a mci hazard is being cleared.
  COMB_HAZ_FSM: process(haz_ctr_i,
                        haz_current_state_r,
                        ex_ma_pipe_inst_haz_r,
                        ex_ma_ld_haz_r,
                        ma_wb_ld_haz_r,
                        ex_ma_partial_fw_haz_r,
                        ma_wb_partial_fw_haz_r,
                        id_fw_op_a_control_wo_haz_s,
                        id_fw_op_b_control_wo_haz_s,
                        id_fw_op_d_control_wo_haz_s,
                        id_ex_fw_op_a_control_r,
                        id_ex_fw_op_b_control_r,
                        id_ex_fw_op_d_control_r)
  begin

    -- default assignments (no hazards)
    id_fw_op_a_control_s <= id_fw_op_a_control_wo_haz_s;  
    id_fw_op_b_control_s <= id_fw_op_b_control_wo_haz_s; 
    id_fw_op_d_control_s <= id_fw_op_d_control_wo_haz_s; 
    if_stall_s           <= '0';
    id_stall_s           <= '0';
    id_flush_s           <= '0';
    ex_stall_s           <= '0';
    ex_flush_s           <= '0';
    mci_flush_s          <= '0';
    ma_flush_s           <= '0';
    rf_res_a_lock_s      <= '0';
    rf_res_b_lock_s      <= '0';
    rf_res_d_lock_s      <= '0';
    haz_next_state_s     <= haz_current_state_r;

    case haz_current_state_r is

      -- CHECK ALL HAZARDS
      when HAZ_CHECK_ALL =>

        -- BRANCH
        if(haz_ctr_i.ma_branch_valid_i = B_N_VALID) then
          -- STD BRANCH 
          if(haz_ctr_i.ex_ma_branch_delay_i = B_N_DELAY) then
            haz_next_state_s <= HAZ_BRANCH_DONE; -- finish branch hazard
            id_flush_s       <= '1';             -- flush decode
            ex_flush_s       <= '1';             -- flush execute
            mci_flush_s      <= '1';             -- flush mci 
           
            -- BRANCH WITH A DATA HAZARD IN THE DELAY SLOT 
          elsif((FW_LD = false and ma_wb_ld_haz_r = HAZARD_DETECTED) or 
                (FW_IN_MULT = false and USE_MULT > 0 and ma_wb_partial_fw_haz_r = HAZARD_DETECTED)) then 
            haz_next_state_s <= HAZ_BRANCH_DEL; -- branch hazard delayed
            if_stall_s       <= '1';            -- stall fetch
            id_stall_s       <= '1';            -- stall decode
            ex_stall_s       <= '1';            -- stall execute
            mci_flush_s      <= '1';            -- flush mci 
            ma_flush_s       <= '1';            -- flush memory access

            -- UPDATE FW DEPENDENCIES
            case id_ex_fw_op_a_control_r is

              when FW_NOP =>
                id_fw_op_a_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_a_control_s <= FW_EX_MA;      

              when FW_MA_WB =>
                id_fw_op_a_control_s <= FW_WB_RF;

              when FW_WB_RF =>
                id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op a control code (1)" severity warning;

            end case;     

            case id_ex_fw_op_b_control_r is

              when FW_NOP =>
                id_fw_op_b_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_b_control_s <= FW_EX_MA;  

              when FW_MA_WB =>
                id_fw_op_b_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op b control code (1)" severity warning;

            end case;   

            case id_ex_fw_op_d_control_r is

              when FW_NOP =>
                id_fw_op_d_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_d_control_s <= FW_EX_MA;   

              when FW_MA_WB =>
                id_fw_op_d_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op d control code (1)!" severity warning;

            end case;

            -- BRANCH WITH A MCI HAZARD IN THE DELAY SLOT
          elsif(USE_DIV = true and haz_ctr_i.ex_mci_busy_i = '1') then
            haz_next_state_s <= HAZ_BRANCH_MCI; -- finish MCI 
            if_stall_s       <= '1';            -- stall fetch
            id_stall_s       <= '1';            -- stall decode
            ex_stall_s       <= '1';            -- stall execute
            ma_flush_s       <= '1';            -- flush memory access

            -- UPDATE FW DEPENDENCIES
            case id_ex_fw_op_a_control_r is

              when FW_NOP =>
                id_fw_op_a_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_a_control_s <= FW_EX_MA;      

              when FW_MA_WB =>
                id_fw_op_a_control_s <= FW_WB_RF;

              when FW_WB_RF =>
                id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op a control code (2)" severity warning;

            end case;     

            case id_ex_fw_op_b_control_r is

              when FW_NOP =>
                id_fw_op_b_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_b_control_s <= FW_EX_MA;  

              when FW_MA_WB =>
                id_fw_op_b_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op b control code (2)" severity warning;

            end case;   

            case id_ex_fw_op_d_control_r is

              when FW_NOP =>
                id_fw_op_d_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_d_control_s <= FW_EX_MA;   

              when FW_MA_WB =>
                id_fw_op_d_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op d control code (2)" severity warning;

            end case;

            -- BRANCH WITH NO HAZARD IN THE DELAY SLOT
          else
            haz_next_state_s <= HAZ_BRANCH_DONE; -- finish branch hazard
            id_flush_s       <= '1';             -- flush decode

          end if;

          -- DATA HAZARD FROM EX/MA
        elsif((ex_ma_ld_haz_r = HAZARD_DETECTED) or 
              (USE_PIPE_INST = true and ex_ma_pipe_inst_haz_r = HAZARD_DETECTED) or 
              (FW_IN_MULT = false and USE_MULT > 0 and ex_ma_partial_fw_haz_r = HAZARD_DETECTED)) then
          if((FW_LD = false and ex_ma_ld_haz_r = HAZARD_DETECTED) or
             (FW_IN_MULT = false and USE_MULT > 0 and ex_ma_partial_fw_haz_r = HAZARD_DETECTED)) then
            haz_next_state_s <= HAZ_DATA_DEL;  -- data hazard delayed
 
          else
            haz_next_state_s <= HAZ_DATA_DONE; -- finish data hazard 

          end if;
          if_stall_s         <= '1';           -- stall fetch
          id_stall_s         <= '1';           -- stall decode
          ex_flush_s         <= '1';           -- flush execute
          mci_flush_s        <= '1';           -- flush mci 

          -- UPDATE FW DEPENDENCIES
          case id_ex_fw_op_a_control_r is

            when FW_NOP =>
              id_fw_op_a_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_a_control_s <= FW_MA_WB;           

            when FW_MA_WB =>
              id_fw_op_a_control_s <= FW_WB_RF;

            when FW_WB_RF =>
              id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op a control code (3)" severity warning;

          end case;     

          case id_ex_fw_op_b_control_r is

            when FW_NOP =>
              id_fw_op_b_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_b_control_s <= FW_MA_WB;          

            when FW_MA_WB =>
              id_fw_op_b_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op b control code (3)" severity warning;

          end case;   

          case id_ex_fw_op_d_control_r is

            when FW_NOP =>
              id_fw_op_d_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_d_control_s <= FW_MA_WB;          

            when FW_MA_WB =>
              id_fw_op_d_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op d control code (3)" severity warning;

          end case;

          -- DATA HAZARD FROM MA/WB
        elsif((FW_LD = false and ma_wb_ld_haz_r = HAZARD_DETECTED) or
              (FW_IN_MULT = false and USE_MULT > 0 and ma_wb_partial_fw_haz_r = HAZARD_DETECTED)) then
          haz_next_state_s <= HAZ_DATA_DONE; -- finish data hazard 
          if_stall_s       <= '1';           -- stall fetch
          id_stall_s       <= '1';           -- stall decode
          ex_stall_s       <= '1';           -- stall execute
          mci_flush_s      <= '1';           -- flush mci 
          ma_flush_s       <= '1';           -- flush memory access

          -- UPDATE FW DEPENDENCIES
          case id_ex_fw_op_a_control_r is

            when FW_NOP =>
              id_fw_op_a_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_a_control_s <= FW_EX_MA;      

            when FW_MA_WB =>
              id_fw_op_a_control_s <= FW_WB_RF;

            when FW_WB_RF =>
              id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op a control code (4)" severity warning;

          end case;     

          case id_ex_fw_op_b_control_r is

            when FW_NOP =>
              id_fw_op_b_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_b_control_s <= FW_EX_MA;  

            when FW_MA_WB =>
              id_fw_op_b_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op b control code (4)!" severity warning;

          end case;   

          case id_ex_fw_op_d_control_r is

            when FW_NOP =>
              id_fw_op_d_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_d_control_s <= FW_EX_MA;   

            when FW_MA_WB =>
              id_fw_op_d_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op d control code (4)" severity warning;

          end case;  

          -- MCI HAZARD
        elsif(USE_DIV = true and haz_ctr_i.ex_mci_busy_i = '1') then
          haz_next_state_s <= HAZ_MCI; -- finish MCI
          if_stall_s       <= '1';     -- stall fetch
          id_stall_s       <= '1';     -- stall decode
          ex_stall_s       <= '1';     -- stall execute
          ma_flush_s       <= '1';     -- flush memory access

          -- UPDATE FW DEPENDENCIES
          case id_ex_fw_op_a_control_r is

            when FW_NOP =>
              id_fw_op_a_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_a_control_s <= FW_EX_MA;      

            when FW_MA_WB =>
              id_fw_op_a_control_s <= FW_WB_RF;

            when FW_WB_RF =>
              id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op a control code (5)" severity warning;

          end case;     

          case id_ex_fw_op_b_control_r is

            when FW_NOP =>
              id_fw_op_b_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_b_control_s <= FW_EX_MA;  

            when FW_MA_WB =>
              id_fw_op_b_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op b control code (5)!" severity warning;

          end case;   

          case id_ex_fw_op_d_control_r is

            when FW_NOP =>
              id_fw_op_d_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_d_control_s <= FW_EX_MA;   

            when FW_MA_WB =>
              id_fw_op_d_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op d control code (5)" severity warning;

          end case;

        end if;
		  
        -- BRANCH DELAYED DUE TO A DATA HAZARD IN THE DELAY SLOT
      when HAZ_BRANCH_DEL =>
		    -- MCI HAZARD IN THE DELAY SLOT 
        if(USE_DIV = true and haz_ctr_i.ex_mci_busy_i = '1') then
          haz_next_state_s <= HAZ_BRANCH_MCI; -- finish MCI 
          if_stall_s       <= '1';            -- stall fetch
          id_stall_s       <= '1';            -- stall decode
          ex_stall_s       <= '1';            -- stall execute
          ma_flush_s       <= '1';            -- flush memory access       

          -- UPDATE FW DEPENDENCIES
          case id_ex_fw_op_a_control_r is

            when FW_NOP =>
              id_fw_op_a_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_a_control_s <= FW_EX_MA;      

            when FW_MA_WB =>
              id_fw_op_a_control_s <= FW_WB_RF;

            when FW_WB_RF =>
              id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op a control code (6)" severity warning;

          end case;     

          case id_ex_fw_op_b_control_r is

            when FW_NOP =>
              id_fw_op_b_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_b_control_s <= FW_EX_MA;  

            when FW_MA_WB =>
              id_fw_op_b_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op b control code (6)!" severity warning;

          end case;   

          case id_ex_fw_op_d_control_r is

            when FW_NOP =>
              id_fw_op_d_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_d_control_s <= FW_EX_MA;   

            when FW_MA_WB =>
              id_fw_op_d_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op d control code (6)" severity warning;

          end case;             

			   -- FINISH BRANCH
		    else
			    haz_next_state_s <= HAZ_BRANCH_DONE; -- finish branch hazard
			    id_flush_s       <= '1';             -- flush decode

		    end if; 

        -- MCI HAZARD IN A BRANCH DELAY SLOT
      when HAZ_BRANCH_MCI =>
        if(USE_DIV = true) then
          if(haz_ctr_i.ex_mci_busy_i = '1') then
            if_stall_s       <= '1';             -- stall fetch
            id_stall_s       <= '1';             -- stall decode
            ex_stall_s       <= '1';             -- stall execute
            ma_flush_s       <= '1';             -- flush memory access

            -- UPDATE FW DEPENDENCIES
            case id_ex_fw_op_a_control_r is

              when FW_NOP =>
                id_fw_op_a_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_a_control_s <= FW_EX_MA;      

              when FW_MA_WB =>
                id_fw_op_a_control_s <= FW_WB_RF;

              when FW_WB_RF =>
                id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op a control code (7)" severity warning;

            end case;     

            case id_ex_fw_op_b_control_r is

              when FW_NOP =>
                id_fw_op_b_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_b_control_s <= FW_EX_MA;  

              when FW_MA_WB =>
                id_fw_op_b_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op b control code (7)" severity warning;

            end case;   

            case id_ex_fw_op_d_control_r is

              when FW_NOP =>
                id_fw_op_d_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_d_control_s <= FW_EX_MA;   

              when FW_MA_WB =>
                id_fw_op_d_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op d control code (7)" severity warning;

            end case;

            -- FINISH BRANCH
          else
            haz_next_state_s <= HAZ_BRANCH_DONE; -- finish branch hazard
            id_flush_s       <= '1';             -- flush decode

          end if; 
        end if;

        -- BRANCH DONE
      when HAZ_BRANCH_DONE =>
        -- HAZARD CLEARED
        haz_next_state_s   <= HAZ_CHECK_ALL;

        -- HAZARD DELAYED IN MA/WB STAGE
      when HAZ_DATA_DEL =>
        if(FW_LD = false or (FW_IN_MULT = false and USE_MULT > 0)) then
          haz_next_state_s <= HAZ_DATA_DONE; -- finish data hazard 
          if_stall_s       <= '1';           -- stall fetch
          id_stall_s       <= '1';           -- stall decode
          ex_flush_s       <= '1';           -- flush execute
          mci_flush_s      <= '1';           -- flush mci 

          -- UPDATE FW DEPENDENCIES
          case id_ex_fw_op_a_control_r is

            when FW_NOP =>
              id_fw_op_a_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_a_control_s <= FW_MA_WB;           

            when FW_MA_WB =>
              id_fw_op_a_control_s <= FW_WB_RF;

            when FW_WB_RF =>
              id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op a control code (8)" severity warning;

          end case;     

          case id_ex_fw_op_b_control_r is

            when FW_NOP =>
              id_fw_op_b_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_b_control_s <= FW_MA_WB;          

            when FW_MA_WB =>
              id_fw_op_b_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op b control code (8)" severity warning;

          end case;   

          case id_ex_fw_op_d_control_r is

            when FW_NOP =>
              id_fw_op_d_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_d_control_s <= FW_MA_WB;          

            when FW_MA_WB =>
              id_fw_op_d_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op d control code (8)" severity warning;

          end case;

        end if;

        -- DATA HAZARD DONE 
      when HAZ_DATA_DONE =>
        -- MCI HAZARD
        if(USE_DIV = true and haz_ctr_i.ex_mci_busy_i = '1') then
          haz_next_state_s <= HAZ_MCI;
          if_stall_s       <= '1'; -- stall fetch
          id_stall_s       <= '1'; -- stall decode
          ex_stall_s       <= '1'; -- stall execute
          ma_flush_s       <= '1'; -- flush memory access

          -- UPDATE FW DEPENDENCIES
          case id_ex_fw_op_a_control_r is

            when FW_NOP =>
              id_fw_op_a_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_a_control_s <= FW_EX_MA;      

            when FW_MA_WB =>
              id_fw_op_a_control_s <= FW_WB_RF;

            when FW_WB_RF =>
              id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op a control code (9)!" severity warning;

          end case;     

          case id_ex_fw_op_b_control_r is

            when FW_NOP =>
              id_fw_op_b_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_b_control_s <= FW_EX_MA;  

            when FW_MA_WB =>
              id_fw_op_b_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op b control code (9)" severity warning;

          end case;   

          case id_ex_fw_op_d_control_r is

            when FW_NOP =>
              id_fw_op_d_control_s <= FW_NOP;

            when FW_EX_MA =>
              id_fw_op_d_control_s <= FW_EX_MA;   

            when FW_MA_WB =>
              id_fw_op_d_control_s <= FW_WB_RF;      

            when FW_WB_RF =>
              id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
              rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

            when others =>
              report "haz controller: illegal forward mux op d control code (9)" severity warning;

          end case;

          -- HAZARD CLEARED
        else
          haz_next_state_s <= HAZ_CHECK_ALL;

        end if;

        -- MCI HAZARD
      when HAZ_MCI =>
        if(USE_DIV = true) then
          -- MCI HAZARD
          if(haz_ctr_i.ex_mci_busy_i = '1') then
            if_stall_s       <= '1'; -- stall fetch
            id_stall_s       <= '1'; -- stall decode
            ex_stall_s       <= '1'; -- stall execute
            ma_flush_s       <= '1'; -- flush memory access

            -- UPDATE FW DEPENDENCIES
            case id_ex_fw_op_a_control_r is

              when FW_NOP =>
                id_fw_op_a_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_a_control_s <= FW_EX_MA;      

              when FW_MA_WB =>
                id_fw_op_a_control_s <= FW_WB_RF;

              when FW_WB_RF =>
                id_fw_op_a_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_a_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op a control code (10)" severity warning;

            end case;     

            case id_ex_fw_op_b_control_r is

              when FW_NOP =>
                id_fw_op_b_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_b_control_s <= FW_EX_MA;  

              when FW_MA_WB =>
                id_fw_op_b_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_b_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_b_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op b control code (10)" severity warning;

            end case;   

            case id_ex_fw_op_d_control_r is

              when FW_NOP =>
                id_fw_op_d_control_s <= FW_NOP;

              when FW_EX_MA =>
                id_fw_op_d_control_s <= FW_EX_MA;   

              when FW_MA_WB =>
                id_fw_op_d_control_s <= FW_WB_RF;      

              when FW_WB_RF =>
                id_fw_op_d_control_s <= FW_WB_RF; -- force forward from WB/RF 
                rf_res_d_lock_s      <= '1';      -- keep old WB/RF result value

              when others =>
                report "haz controller: illegal forward mux op d control code (10)" severity warning;

            end case;

            -- HAZARD CLEARED
          else
            haz_next_state_s <= HAZ_CHECK_ALL;

          end if;
        end if;

        -- DEFAULT
      when others => 
		    haz_next_state_s <= HAZ_CHECK_ALL; -- force a reset / safe implementation
        report "hazard controller: illegal state" severity warning;

    end case;  

  end process COMB_HAZ_FSM;    

  -- //////////////////////////////////////////
  --                CYCLE PROCESS
  -- //////////////////////////////////////////

  -- 
  -- HAZARD CONTROL REGISTERS
  --
  --! This process implements hazard control registers. 
  CYCLE_HAZ_REG: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then

      -- sync reset 
      if(rst_n_i = '0') then
        haz_current_state_r      <= HAZ_CHECK_ALL;
        ex_ma_ld_haz_r           <= HAZARD_N_DETECTED;
        if(FW_LD = false) then
          ma_wb_ld_haz_r         <= HAZARD_N_DETECTED;
        end if;
        if(USE_PIPE_INST = true) then
          ex_ma_pipe_inst_haz_r  <= HAZARD_N_DETECTED;
        end if;
        if(FW_IN_MULT = false and USE_MULT > 0) then
          ex_ma_partial_fw_haz_r <= HAZARD_N_DETECTED;
          ma_wb_partial_fw_haz_r <= HAZARD_N_DETECTED;
        end if; 

      elsif(halt_core_i = '0') then
        haz_current_state_r      <= haz_next_state_s;
        id_ex_fw_op_a_control_r  <= id_fw_op_a_control_s;
        id_ex_fw_op_b_control_r  <= id_fw_op_b_control_s;
        id_ex_fw_op_d_control_r  <= id_fw_op_d_control_s;
        ex_ma_ld_haz_r           <= ex_ld_haz_s;
        if(FW_LD = false) then
          ma_wb_ld_haz_r         <= ma_ld_haz_s;
        end if;
        if(USE_PIPE_INST = true) then
          ex_ma_pipe_inst_haz_r  <= ex_pipe_inst_haz_s;
        end if;
        if(FW_IN_MULT = false and USE_MULT > 0) then
          ex_ma_partial_fw_haz_r <= ex_partial_fw_haz_s;
          ma_wb_partial_fw_haz_r <= ma_partial_fw_haz_s;
        end if;  

      end if;
      
    end if;

  end process CYCLE_HAZ_REG;  
  
end be_sb_hazard_controller;
  

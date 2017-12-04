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
--! @file sb_core.vhd                                         					
--! @brief SecretBlaze Core Implementation
--! @author Lyonel Barthe
--! @version 1.0b
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0b 13/05/2010 by Lyonel Barthe
-- Changed coding style
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.2 9/04/2010 by Lyonel Barthe
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

library config_lib;
use config_lib.sb_config.all;

--
--! The entity implements the core unit of the SecretBlaze processor.
--

--! SecretBlaze Core Entity
entity sb_core is

  generic
    (
      RF_TYPE       : string  := USER_RF_TYPE;       --! register file implementation type 
      USE_BTC       : boolean := USER_USE_BTC;       --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
      BTC_MEM_TYPE  : string  := USER_BTC_MEM_TYPE;  --! BTC memory implementation type
      BTC_MEM_FILE  : string  := USER_BTC_MEM_FILE;  --! BTC memory init file 
      BTC_TAG_FILE  : string  := USER_BTC_TAG_FILE;  --! BTC tag memory init file 
      USE_PC_RET    : boolean := USER_USE_PC_RET;    --! if true, use program counter with retiming 
      USE_DCACHE    : boolean := USER_USE_DCACHE;    --! if true, it will implement the data cache
      USE_WRITEBACK : boolean := USER_USE_WRITEBACK; --! if true, use write-back policy
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
      STRICT_HAZ    : boolean := USER_STRICT_HAZ;    --! if true, it will implement a strict hazard controller which checks the type of the instruction
      FW_IN_MULT    : boolean := USER_FW_IN_MULT;    --! if true, it will implement the data forwarding for the inputs of the MULT unit
      FW_LD         : boolean := USER_FW_LD          --! if true, it will implement the full data forwarding for LOAD instructions
    );
  
  port
    (
      im_bus_in_o   : out im_bus_i_t;                --! instruction L1 bus inputs
      im_bus_out_i  : in im_bus_o_t;                 --! instruction L1 bus outputs
      dm_bus_in_o   : out dm_bus_i_t;                --! data L1 bus inputs
      dm_bus_out_i  : in dm_bus_o_t;                 --! data L1 bus outputs
      int_i         : in int_status_t;               --! external interrupt signal
      wdc_in_o      : out wdc_control_t;             --! wdc control signal input
      wic_in_o      : out wic_control_t;             --! wic control signal input       
      halt_core_i   : in std_ulogic;                 --! halt core signal 
      clk_i         : in std_ulogic;                 --! core clock
      rst_n_i       : in std_ulogic                  --! active-low reset signal 
    );

end sb_core;

--! SecretBlaze Core Architecture 
architecture be_sb_core of sb_core is
  
  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  signal if_i_s           : if_stage_i_t;
  signal if_o_s           : if_stage_o_t;
  signal id_i_s           : id_stage_i_t;
  signal id_o_s           : id_stage_o_t;
  signal ex_i_s           : ex_stage_i_t;
  signal ex_o_s           : ex_stage_o_t;
  signal ma_i_s           : ma_stage_i_t;
  signal ma_o_s           : ma_stage_o_t;
  signal wb_i_s           : wb_stage_i_t;
  signal wb_o_s           : wb_stage_o_t;
  signal im_bus_in_o_s    : im_bus_i_t; 
  signal im_bus_out_i_s   : im_bus_o_t; 
  signal dm_bus_in_o_s    : dm_bus_i_t; 
  signal dm_bus_out_i_s   : dm_bus_o_t; 
  signal wdc_in_o_s       : wdc_control_t;
  signal wic_in_o_s       : wic_control_t;
  signal haz_ctr_i_s      : haz_ctr_i_t;
  signal haz_ctr_o_s      : haz_ctr_o_t;
  signal branch_ctr_i_s   : branch_ctr_i_t;
  signal branch_ctr_o_s   : branch_ctr_o_t;
  signal btc_i_s          : btc_i_t;
  signal btc_o_s          : btc_o_t;
 
begin

  -- //////////////////////////////////////////
  --             COMPONENTS LINK
  -- //////////////////////////////////////////

  -- //////////////////////////////////////////
  --                FETCH STAGE 
  -- //////////////////////////////////////////
  
  FETCH: entity sb_lib.sb_fetch(be_sb_fetch)
    generic map
    (
      USE_PC_RET   => USE_PC_RET
    )
    port map 
    (
      if_i         => if_i_s,
      if_o         => if_o_s,
      im_bus_out_i => im_bus_out_i_s,
      im_bus_in_o  => im_bus_in_o_s,
      halt_core_i  => halt_core_i,
      stall_i      => haz_ctr_o_s.if_stall_o,
      clk_i        => clk_i,
      rst_n_i      => rst_n_i
    );

  -- L1 memory signals
  im_bus_in_o             <= im_bus_in_o_s;
  im_bus_out_i_s          <= im_bus_out_i;
  -- registered IF/ID signal
  if_i_s.pred_pc_i        <= btc_o_s.pred_pc_o;
  -- combinatorial ID signal
  if_i_s.pred_valid_i     <= branch_ctr_o_s.id_pred_valid_o;
  -- registered ID/EX signal
  if_i_s.pred_pc_del_i    <= id_o_s.pred_pc_o;
  if_i_s.pred_valid_del_i <= id_o_s.pred_valid_del_o;
  -- combinatorial MA signals
  if_i_s.branch_pc_i      <= branch_ctr_o_s.ma_branch_pc_o;
  if_i_s.branch_valid_i   <= branch_ctr_o_s.ma_branch_valid_o;
  
  -- //////////////////////////////////////////
  --               DECODE STAGE 
  -- //////////////////////////////////////////
  
  DECODE: entity sb_lib.sb_decode(be_sb_decode)
    generic map
    (
      RF_TYPE       => RF_TYPE,
      USE_DCACHE    => USE_DCACHE,
      USE_WRITEBACK => USE_WRITEBACK,
      USE_ICACHE    => USE_ICACHE,
      USE_INT       => USE_INT,
      USE_SPR       => USE_SPR,
      USE_MULT      => USE_MULT,
      USE_DIV       => USE_DIV,
      USE_PAT       => USE_PAT,
      USE_CLZ       => USE_CLZ,
      USE_BS        => USE_BS
    )
    port map
    (
      id_i          => id_i_s,
      id_o          => id_o_s,
      halt_core_i   => halt_core_i,
      stall_i       => haz_ctr_o_s.id_stall_o,
      flush_i       => haz_ctr_o_s.id_flush_o,
      clk_i         => clk_i,
      rst_n_i       => rst_n_i
    );

  -- registered IF/ID signals
  id_i_s.pc_i             <= if_o_s.pc_o;
  id_i_s.inst_i           <= if_o_s.inst_o;
  id_i_s.pred_status_i    <= btc_o_s.pred_status_o;
  id_i_s.pred_pc_i        <= btc_o_s.pred_pc_o;
  -- registered/combinatorial IF signal
  id_i_s.pc_plus_plus_i   <= if_o_s.pc_plus_plus_o;
  -- combinatorial ID signal
  id_i_s.pred_valid_del_i <= branch_ctr_o_s.id_pred_valid_del_o;
  id_i_s.pred_valid_i     <= branch_ctr_o_s.id_pred_valid_o;
  -- registered EX/MA signal
  id_i_s.int_status_i     <= ex_o_s.int_status_o; 
  -- combinatorial WB signals
  id_i_s.wb_res_i         <= wb_o_s.res_o;
  id_i_s.wb_rd_i          <= wb_o_s.rd_o;
  id_i_s.wb_we_control_i  <= wb_o_s.we_control_o;

  -- //////////////////////////////////////////
  --               EXECUTE STAGE 
  -- //////////////////////////////////////////
  
  EXECUTE: entity sb_lib.sb_execute(be_sb_execute)
    generic map
    (
      USE_BTC       => USE_BTC,
      USE_DCACHE    => USE_DCACHE,
      USE_ICACHE    => USE_ICACHE,
      USE_INT       => USE_INT,
      USE_SPR       => USE_SPR,
      USE_MULT      => USE_MULT,
      USE_PIPE_MULT => USE_PIPE_MULT,
      USE_BS        => USE_BS,
      USE_PIPE_BS   => USE_PIPE_BS,
      USE_DIV       => USE_DIV,
      USE_PAT       => USE_PAT,
      USE_CLZ       => USE_CLZ,
      USE_PIPE_CLZ  => USE_PIPE_CLZ,
      FW_IN_MULT    => FW_IN_MULT
    )
    port map
    (
      ex_i          => ex_i_s,
      ex_o          => ex_o_s,
      int_i         => int_i,
      halt_core_i   => halt_core_i,
      stall_i       => haz_ctr_o_s.ex_stall_o,
      flush_i       => haz_ctr_o_s.ex_flush_o,
      mci_flush_i   => haz_ctr_o_s.mci_flush_o,
      clk_i         => clk_i,
      rst_n_i       => rst_n_i
    );

  -- registered ID/EX signals
  ex_i_s.pc_i              <= id_o_s.pc_o;
  ex_i_s.rd_i              <= id_o_s.rd_o;
  ex_i_s.op_a_i            <= id_o_s.op_a_o;
  ex_i_s.op_b_i            <= id_o_s.op_b_o;
  ex_i_s.op_d_i            <= id_o_s.op_d_o;
  ex_i_s.imm_i             <= id_o_s.imm_o;
  ex_i_s.alu_control_i     <= id_o_s.alu_control_o;
  ex_i_s.op_a_control_i    <= id_o_s.op_a_control_o;
  ex_i_s.op_b_control_i    <= id_o_s.op_b_control_o;
  ex_i_s.carry_control_i   <= id_o_s.carry_control_o;
  ex_i_s.carry_keep_i      <= id_o_s.carry_keep_o;
  ex_i_s.branch_control_i  <= id_o_s.branch_control_o;
  ex_i_s.branch_delay_i    <= id_o_s.branch_delay_o;
  ex_i_s.ls_control_i      <= id_o_s.ls_control_o;
  ex_i_s.mem_sel_control_i <= id_o_s.mem_sel_control_o;
  ex_i_s.we_control_i      <= id_o_s.we_control_o;
  ex_i_s.spr_control_i     <= id_o_s.spr_control_o;
  ex_i_s.rs_i              <= id_o_s.rs_o;
  ex_i_s.cmp_control_i     <= id_o_s.cmp_control_o;
  ex_i_s.bs_control_i      <= id_o_s.bs_control_o;
  ex_i_s.mult_control_i    <= id_o_s.mult_control_o;
  ex_i_s.div_control_i     <= id_o_s.div_control_o;
  ex_i_s.pat_control_i     <= id_o_s.pat_control_o;
  ex_i_s.int_control_i     <= id_o_s.int_control_o;
  ex_i_s.wdc_control_i     <= id_o_s.wdc_control_o;
  ex_i_s.wic_control_i     <= id_o_s.wic_control_o;
  ex_i_s.pred_valid_i      <= id_o_s.pred_valid_o;
  ex_i_s.pred_valid_del_i  <= id_o_s.pred_valid_del_o;
  ex_i_s.pred_control_i    <= id_o_s.pred_control_o;
  ex_i_s.pred_status_i     <= id_o_s.pred_status_o;  
  ex_i_s.pred_pc_i         <= id_o_s.pred_pc_o;   
  ex_i_s.pc_plus_plus_i    <= id_o_s.pc_plus_plus_o;
  -- forwarding signals
  ex_i_s.fw_op_a_control_i <= haz_ctr_o_s.id_ex_fw_op_a_control_o;
  ex_i_s.fw_op_b_control_i <= haz_ctr_o_s.id_ex_fw_op_b_control_o;
  ex_i_s.fw_op_d_control_i <= haz_ctr_o_s.id_ex_fw_op_d_control_o;
  -- MA/WB result
  GEN_FW_LOAD : if(FW_LD = true) generate 
    ex_i_s.ma_wb_res_i     <= wb_o_s.res_o; -- full
  end generate GEN_FW_LOAD;
  GEN_NO_FW_LOAD : if(FW_LD = false) generate 
    ex_i_s.ma_wb_res_i     <= ma_o_s.res_o; -- partial
  end generate GEN_NO_FW_LOAD;
  -- WB/RF result
  ex_i_s.wb_rf_res_a_i     <= wb_o_s.rf_res_a_o; 
  ex_i_s.wb_rf_res_b_i     <= wb_o_s.rf_res_b_o; 
  ex_i_s.wb_rf_res_d_i     <= wb_o_s.rf_res_d_o; 
  
  -- //////////////////////////////////////////
  --             MEMORY ACCESS STAGE
  -- //////////////////////////////////////////
    
  MEMORY_ACCESS: entity sb_lib.sb_memory_access(be_sb_memory_access)
    generic map
    (
      USE_MULT      => USE_MULT,
      USE_PIPE_MULT => USE_PIPE_MULT,
      USE_BS        => USE_BS,
      USE_PIPE_BS   => USE_PIPE_BS,
      USE_CLZ       => USE_CLZ,
      USE_PIPE_CLZ  => USE_PIPE_CLZ
    )
    port map
    (
      ma_i          => ma_i_s,
      ma_o          => ma_o_s,
      dm_bus_in_o   => dm_bus_in_o_s,
      dm_bus_out_i  => dm_bus_out_i_s,
      wdc_in_o      => wdc_in_o_s,
      wic_in_o      => wic_in_o_s,
      halt_core_i   => halt_core_i,
      flush_i       => haz_ctr_o_s.ma_flush_o,
      clk_i         => clk_i,
      rst_n_i       => rst_n_i
    );

  -- L1 memory signals
  dm_bus_in_o              <= dm_bus_in_o_s;
  dm_bus_out_i_s           <= dm_bus_out_i;
  -- cache memory signals
  wic_in_o                 <= wic_in_o_s;
  wdc_in_o                 <= wdc_in_o_s;
  -- registered EX/MA signals
  ma_i_s.pc_i              <= ex_o_s.pc_o;
  ma_i_s.branch_status_i   <= ex_o_s.branch_status_o;
  ma_i_s.rd_i              <= ex_o_s.rd_o;
  ma_i_s.alu_res_i         <= ex_o_s.alu_res_o;
  ma_i_s.op_d_i            <= ex_o_s.op_d_o;
  ma_i_s.alu_control_i     <= ex_o_s.alu_control_o;
  ma_i_s.mult_control_i    <= ex_o_s.mult_control_o;
  ma_i_s.bs_control_i      <= ex_o_s.bs_control_o;
  ma_i_s.pipe_mult_i       <= ex_o_s.pipe_mult_o;
  ma_i_s.pipe_bs_i         <= ex_o_s.pipe_bs_o;
  ma_i_s.pipe_clz_i        <= ex_o_s.pipe_clz_o;
  ma_i_s.we_control_i      <= ex_o_s.we_control_o;
  ma_i_s.ls_control_i      <= ex_o_s.ls_control_o;
  ma_i_s.mem_sel_control_i <= ex_o_s.mem_sel_control_o;
  ma_i_s.wdc_control_i     <= ex_o_s.wdc_control_o;
  ma_i_s.wic_control_i     <= ex_o_s.wic_control_o;
  
  -- //////////////////////////////////////////
  --              WRITE BACK STAGE
  -- //////////////////////////////////////////

  WRITE_BACK: entity sb_lib.sb_write_back(be_sb_write_back)
    port map
    (
      wb_i        => wb_i_s,
      wb_o        => wb_o_s,
      halt_core_i => halt_core_i,
      clk_i       => clk_i
    );

  -- registered MA/WB signals
  wb_i_s.res_i             <= ma_o_s.res_o;
  wb_i_s.rd_i              <= ma_o_s.rd_o;
  wb_i_s.we_control_i      <= ma_o_s.we_control_o;
  wb_i_s.ls_control_i      <= ma_o_s.ls_control_o;
  wb_i_s.mem_data_i        <= ma_o_s.mem_data_o;
  wb_i_s.mem_sel_control_i <= ma_o_s.mem_sel_control_o;
  -- HAZ signals
  wb_i_s.rf_res_a_lock_i   <= haz_ctr_o_s.rf_res_a_lock_o;
  wb_i_s.rf_res_b_lock_i   <= haz_ctr_o_s.rf_res_b_lock_o;
  wb_i_s.rf_res_d_lock_i   <= haz_ctr_o_s.rf_res_d_lock_o;

  -- //////////////////////////////////////////
  --             HAZARD CONTROLLER
  -- //////////////////////////////////////////

  HAZARD_CTR: entity sb_lib.sb_hazard_controller(be_sb_hazard_controller) 
    generic map
    (
      USE_MULT      => USE_MULT,
      USE_PIPE_MULT => USE_PIPE_MULT,
      USE_BS        => USE_BS,
      USE_PIPE_BS   => USE_PIPE_BS,
      USE_CLZ       => USE_CLZ,
      USE_PIPE_CLZ  => USE_PIPE_CLZ,
      USE_DIV       => USE_DIV,
      STRICT_HAZ    => STRICT_HAZ,
      FW_IN_MULT    => FW_IN_MULT,
      FW_LD         => FW_LD
    )
    port map
    (
      haz_ctr_i     => haz_ctr_i_s,
      haz_ctr_o     => haz_ctr_o_s,
      halt_core_i   => halt_core_i,
      clk_i         => clk_i,
      rst_n_i       => rst_n_i
    );
	
  -- combinatorial ID signals
  haz_ctr_i_s.id_rd_i              <= id_o_s.id_rd_o; 
  haz_ctr_i_s.id_ra_i              <= id_o_s.id_ra_o;
  haz_ctr_i_s.id_rb_i              <= id_o_s.id_rb_o;
  haz_ctr_i_s.id_rsa_type_i        <= id_o_s.id_rsa_type_o;
  haz_ctr_i_s.id_rsb_type_i        <= id_o_s.id_rsb_type_o;
  haz_ctr_i_s.id_rsd_type_i        <= id_o_s.id_rsd_type_o;
  haz_ctr_i_s.id_mult_type_i       <= id_o_s.id_mult_type_o;
  -- registered ID/EX signals
  haz_ctr_i_s.id_ex_rd_i           <= id_o_s.rd_o;
  haz_ctr_i_s.id_ex_ls_control_i   <= id_o_s.ls_control_o;
  haz_ctr_i_s.id_ex_alu_control_i  <= id_o_s.alu_control_o;
  haz_ctr_i_s.id_ex_we_control_i   <= id_o_s.we_control_o;
  -- combinatorial EX signal
  haz_ctr_i_s.ex_mci_busy_i        <= ex_o_s.mci_busy_o;
  -- registered EX/MA signals
  haz_ctr_i_s.ex_ma_ls_control_i   <= ex_o_s.ls_control_o;
  haz_ctr_i_s.ex_ma_branch_delay_i <= ex_o_s.branch_delay_o;  
  haz_ctr_i_s.ex_ma_rd_i           <= ex_o_s.rd_o;
  haz_ctr_i_s.ex_ma_we_control_i   <= ex_o_s.we_control_o;
  -- combinatorial MA signal
  haz_ctr_i_s.ma_branch_valid_i    <= branch_ctr_o_s.ma_branch_valid_o;  
  -- registered MA/WB signals
  haz_ctr_i_s.ma_wb_rd_i           <= ma_o_s.rd_o;
  haz_ctr_i_s.ma_wb_we_control_i   <= ma_o_s.we_control_o;

  -- //////////////////////////////////////////
  --             BRANCH CONTROLLER
  -- //////////////////////////////////////////

  BRANCH_CTR: entity sb_lib.sb_branch_controller(be_sb_branch_controller) 
    generic map
    (
      USE_BTC       => USE_BTC
    )
    port map
    (
      branch_ctr_i  => branch_ctr_i_s,
      branch_ctr_o  => branch_ctr_o_s
    );

  -- registered IF/ID signal
  branch_ctr_i_s.if_id_pred_status_i    <= btc_o_s.pred_status_o;
  -- combinatorial ID signals
  branch_ctr_i_s.id_btc_tag_status_i    <= btc_o_s.tag_status_o;
  branch_ctr_i_s.id_pred_control_i      <= id_o_s.id_pred_control_o;
  branch_ctr_i_s.id_branch_delay_i      <= id_o_s.id_branch_delay_o;
  -- registered ID/EX signal
  branch_ctr_i_s.id_ex_pc_plus_plus_i   <= id_o_s.pc_plus_plus_o;
  -- registered EX/MA signals
  branch_ctr_i_s.ex_ma_branch_status_i  <= ex_o_s.branch_status_o;
  branch_ctr_i_s.ex_ma_branch_control_i <= ex_o_s.branch_control_o;
  branch_ctr_i_s.ex_ma_alu_res_i        <= ex_o_s.alu_res_o;
  branch_ctr_i_s.ex_ma_pred_valid_i     <= ex_o_s.pred_valid_o;
  branch_ctr_i_s.ex_ma_pred_valid_del_i <= ex_o_s.pred_valid_del_o;
  branch_ctr_i_s.ex_ma_pred_control_i   <= ex_o_s.pred_control_o;
  branch_ctr_i_s.ex_ma_pred_status_i    <= ex_o_s.pred_status_o;  
  branch_ctr_i_s.ex_ma_pred_pc_i        <= ex_o_s.pred_pc_o;
  branch_ctr_i_s.ex_ma_pc_plus_plus_i   <= ex_o_s.pc_plus_plus_o;

  -- //////////////////////////////////////////
  --             BRANCH TARGET CACHE
  -- //////////////////////////////////////////

  GEN_BTC: if(USE_BTC = true) generate

    BTC_UNIT: entity sb_lib.sb_btc(be_sb_btc)
      generic map
      (
        BTC_MEM_TYPE => BTC_MEM_TYPE,
        BTC_MEM_FILE => BTC_MEM_FILE,
        BTC_TAG_FILE => BTC_TAG_FILE
      )
      port map
      (
        btc_i        => btc_i_s,
        btc_o        => btc_o_s,
        halt_core_i  => halt_core_i,
        clk_i        => clk_i
      ); 

  end generate GEN_BTC;
           
  -- combinatorial IF signal
  btc_i_s.fetch_adr_i       <= im_bus_in_o_s.adr_i;
  -- registered EX/MA signal
  btc_i_s.new_inst_pc_i     <= ex_o_s.pc_o;
  -- combinatorial MA signals
  btc_i_s.we_i              <= branch_ctr_o_s.ma_btc_we_o;
  btc_i_s.new_pred_pc_i     <= branch_ctr_o_s.ma_branch_pc_o;
  btc_i_s.new_pred_status_i <= branch_ctr_o_s.ma_pred_status_o;

end be_sb_core;


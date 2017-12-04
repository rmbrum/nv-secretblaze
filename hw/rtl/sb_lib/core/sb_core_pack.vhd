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
--! @file sb_core_pack.vhd                                          					
--! @brief SecretBlaze Core Package                                         				
--! @author Lyonel Barthe
--! @version 1.3
--                                                              
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.3 16/05/2011 by Lyonel Barthe
-- Added support for BTC and branch prediction
--
-- Version 1.2 04/01/2011 by Lyonel Barthe
-- Added support for div instructions
--
-- Version 1.1 07/11/2010 by Lyonel Barthe
-- New types for new instructions
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
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

library sb_lib;
use sb_lib.sb_isa.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.sb_config.all;

--
--! The package implements useful defines and settings of the SecretBlaze's core.
--

-- //////////////////////////////////////////
--                 CONVENTIONS
-- //////////////////////////////////////////
-- sb  => SecretBlaze
-- _i  => input
-- _o  => output
-- _n  => negation
-- _s  => signal/wire
-- _r  => signal/reg
-- _t  => type/subtype/record
-- _a  => alias
--
-- if  => instruction fetch
-- id  => instruction decode
-- ex  => execute
-- ma  => memory access 
-- wb  => write-back
-- ls  => load/store
-- int => interrupt
-- msr => machine status register
-- ie  => interrupt enable
-- im  => instruction memory
-- dm  => data memory
-- mem => memory
-- dc  => data cache
-- ic  => inst cache
-- mci => multi cycle instruction(s)
--
-- _W  => WIDTH for general constants
-- _S  => SIZE for general constants
-- //////////////////////////////////////////

--! SecretBlaze Core Package
package sb_core_pack is 

  -- //////////////////////////////////////////
  --          SECRETBLAZE CORE DEFINES
  -- //////////////////////////////////////////

  --
  -- SB CONSTANTS
  --
      
  constant SB_DATA_BUS_W    : natural := 32;                                     --! 32-bit data processor
  constant SB_INST_BUS_W    : natural := 32;                                     --! 32-bit instruction word processor
  constant L1_IM_ADR_BUS_W  : natural := 32;                                     --! L1 IM address bus width (=max inst addressable memory)
  constant L1_DM_ADR_BUS_W  : natural := 32;                                     --! L1 DM address bus width (=max data addressable memory)
  constant L1_IM_DATA_BUS_W : natural := 32;                                     --! L1 IM data bus width
  constant L1_DM_DATA_BUS_W : natural := 32;                                     --! L1 DM data bus width
  constant PC_W             : natural := USER_PC_W;                              --! program counter width
  constant PC_LOW_W         : natural := USER_PC_LOW_W;                          --! program counter low address width (retiming)
  constant PC_HIGH_W        : natural := USER_PC_W - PC_LOW_W;                   --! program counter high address width (retiming)
  constant WORD_ADR_OFF     : natural := 2;                                      --! 32-bit word offset for addressing
  constant WORD_0_PADDING   : std_ulogic_vector(WORD_ADR_OFF - 1 downto 0)       --! 32-bit null padding
    := (others =>'0'); 
  
  --
  -- SB DATA TYPES/SUBTYPES
  --
  
  subtype data_t          is std_ulogic_vector(SB_DATA_BUS_W - 1 downto 0);       --! data type
  subtype inst_t          is std_ulogic_vector(SB_INST_BUS_W - 1 downto 0);       --! instruction type
  subtype pc_t            is std_ulogic_vector(PC_W - 1 downto 0);                --! pc type 
  subtype pc_low_t        is std_ulogic_vector(PC_LOW_W - 1 downto 0);            --! pc low type (retiming)
  subtype pc_high_t       is std_ulogic_vector(PC_HIGH_W - 1 downto 0);           --! pc high type (retiming)
  subtype imm_data_t      is std_ulogic_vector(SB_DATA_BUS_W/2 - 1 downto 0);     --! imm data type
  subtype bs_shift_t      is std_ulogic_vector(4 downto 0);                       --! barrel shifter shift type
  subtype bs_part_shift_t is std_ulogic_vector(1 downto 0);                       --! barrel shifter partial shift type
  subtype im_bus_adr_t    is std_ulogic_vector(L1_IM_ADR_BUS_W - 1 downto 0);     --! L1 IM address bus type
  subtype dm_bus_adr_t    is std_ulogic_vector(L1_DM_ADR_BUS_W - 1 downto 0);     --! L1 DM address bus type
  subtype im_bus_data_t   is std_ulogic_vector(L1_IM_DATA_BUS_W - 1 downto 0);    --! L1 IM data bus type
  subtype dm_bus_data_t   is std_ulogic_vector(L1_DM_DATA_BUS_W - 1 downto 0);    --! L1 DM data bus type
  subtype im_bus_sel_t    is std_ulogic_vector(L1_IM_DATA_BUS_W/8 - 1 downto 0);  --! L1 IM byte addressable memory type
  subtype dm_bus_sel_t    is std_ulogic_vector(L1_DM_DATA_BUS_W/8 - 1 downto 0);  --! L1 DM byte addressable memory type
  type reg_file_t         is array(0 to (2**op_reg_t'length) - 1) of data_t;      --! register file type 
  subtype bs_data_ext_t   is std_ulogic_vector(SB_DATA_BUS_W downto 0);           --! bs ext data type
  subtype cmp_data_ext_t  is std_ulogic_vector(SB_DATA_BUS_W downto 0);           --! cmp ext data type
  subtype cmp_res_ext_t   is std_ulogic_vector(SB_DATA_BUS_W downto 0);           --! cmp ext res type
  subtype mult_data_ext_t is std_ulogic_vector(SB_DATA_BUS_W downto 0);           --! mult ext data type
  subtype mult_res_ext_t  is std_ulogic_vector(SB_DATA_BUS_W*2 + 1 downto 0);     --! mult result ext data type 
  subtype mult_res_t      is std_ulogic_vector(SB_DATA_BUS_W*2 - 1 downto 0);     --! mult result data type
  subtype mult_part_data_ext_t is std_ulogic_vector(SB_DATA_BUS_W/2 downto 0);    --! mult partial product ext data type
  subtype mult_part_res_t is std_ulogic_vector(SB_DATA_BUS_W + 1 downto 0);       --! mult partial product result type
  subtype clz_part_data_t is std_ulogic_vector(15 downto 0);                      --! clz partial data type
  subtype clz_part_res_t  is std_ulogic_vector(5 downto 0);                       --! clz partial res type
  subtype pat_byte_cmp_t  is std_ulogic_vector(SB_DATA_BUS_W/8 - 1 downto 0);     --! pattern byte comparator type
  subtype div_data_ext_t  is std_ulogic_vector(SB_DATA_BUS_W downto 0);           --! div ext data type 
  subtype div_counter_t   is std_ulogic_vector(log2(SB_DATA_BUS_W) - 1 downto 0); --! div counter type

  subtype msr_data_t      is std_ulogic_vector(31 downto 0);                      --! msr data type
  constant MSR_CC_OFF          : natural   := 31;
  constant MSR_DCE_OFF         : natural   := 7;
  constant MSR_DZO_OFF         : natural   := 6;
  constant MSR_ICE_OFF         : natural   := 5;
  constant MSR_C_OFF           : natural   := 2;
  constant MSR_IE_OFF          : natural   := 1;
  
  constant SB_BOOT_ADR         : pc_t          := USER_SB_BOOT_ADR;
  constant SB_INT_ADR_WO_CACHE : data_t        := USER_SB_INT_ADR_WO_CACHE; 
  constant SB_INT_ADR_W_CACHE  : data_t        := USER_SB_INT_ADR_W_CACHE; 
  constant REG0_ADR            : op_reg_t      := "00000";
  constant REG14_ADR           : op_reg_t      := "01110";
  constant DIV_COUNT_END       : div_counter_t := (others => '1');                      
  constant SIGNED_MIN_VAL      : data_t        := X"1000_0000";
  -- Special Note: pc_t, xxx_adr_t (...) keep byte-addressing bits for a better readability.
  
  --
  -- SB CONTROL/STATUS TYPES/SUBTYPES
  --
  
  type alu_control_t     is (ALU_ADD,ALU_OR,ALU_XOR,ALU_AND,ALU_S8,ALU_S16,ALU_SHIFT,ALU_BS,ALU_CMP,ALU_SPR,ALU_MULT,ALU_PAT,ALU_DIV,ALU_CLZ); --! alu general control type
  type branch_control_t  is (B_NOP,BNC,BEQ,BNE,BLT,BLE,BGT,BGE);                      --! branch control type
  type op_a_control_t    is (OP_A_REG_1,OP_A_NOT_REG_1,OP_A_PC,OP_A_ZERO);            --! alu op a control type
  type op_b_control_t    is (OP_B_REG_2,OP_B_NOT_REG_2,OP_B_IMM,OP_B_NOT_IMM);        --! alu op b control type
  type carry_control_t   is (CARRY_ZERO,CARRY_ONE,CARRY_ALU,CARRY_ARITH);             --! carry control type
  type mem_sel_control_t is (BYTE,HALFWORD,WORD);                                     --! data memory control type
  type ls_control_t      is (LS_NOP,LOAD,STORE);                                      --! load/store control type
  type spr_control_t     is (MSR_SET,MSR_CLEAR,MFS,MTS);                              --! spr instructions control type
  type op_rs_t           is (OP_MSR,OP_PC,OP_NOP);                                    --! spr rs operand type
  type bs_control_t      is (BS_SLL,BS_SRL,BS_SRA);                                   --! barrel shifter control type
  type cmp_control_t     is (CMP_S,CMP_U);                                            --! compare control type
  type mult_control_t    is (MULT_LSW,MULT_HSW_SS,MULT_HSW_UU,MULT_HSW_SU);           --! multiplier control type
  type mult_fsm_t        is (MULT_IDLE,MULT_DONE);                                    --! multiplier fsm control type
  type div_control_t     is (DIV_UU,DIV_SS);                                          --! div control type
  type div_fsm_t         is (DIV_IDLE,DIV_BUSY,DIV_POS,DIV_NEG,DIV_ZERO,DIV_OVF);     --! div fsm control type
  type pat_control_t     is (PAT_BYTE,PAT_EQ,PAT_NE);                                 --! pattern control type
  type int_control_t     is (INT_NOP,INT_ENABLE,INT_DISABLE);                         --! int control type
  type wdc_control_t     is (WDC_NOP,WDC_FLUSH,WDC_INVALID);                          --! wdc control type
  type wic_control_t     is (WIC_NOP,WIC_INVALID);                                    --! wic control type
  type fw_control_t      is (FW_NOP,FW_EX_MA,FW_MA_WB,FW_WB_RF);                      --! forward control type
  type haz_fsm_t         is (HAZ_CHECK_ALL,HAZ_BRANCH_DONE,HAZ_BRANCH_DEL,HAZ_BRANCH_MCI,HAZ_MCI,HAZ_DATA_DEL,HAZ_DATA_DONE); --! hazard fsm type

  subtype imm_control_t   is std_ulogic;        --! imm special instruction control type
  constant IS_IMM        : imm_control_t := '1';
  constant N_IMM         : imm_control_t := '0';
  
  subtype carry_keep_t    is std_ulogic;        --! carry keep control type
  constant CARRY_KEEP    : carry_keep_t := '1';
  constant CARRY_N_KEEP  : carry_keep_t := '0';

  subtype we_control_t    is std_ulogic;        --! write (back) enable control type
  constant WE            : we_control_t := '1';
  constant N_WE          : we_control_t := '0';
 
  subtype branch_delay_t  is std_ulogic;        --! branch delay type
  constant B_DELAY       : branch_delay_t := '1';
  constant B_N_DELAY     : branch_delay_t := '0';

  subtype branch_status_t is std_ulogic;        --! branch status type
  constant B_TAKEN       : branch_status_t := '1';
  constant B_N_TAKEN     : branch_status_t := '0'; 

  subtype branch_valid_t  is std_ulogic;        --! branch valid type 
  constant B_VALID       : branch_status_t := '1';
  constant B_N_VALID     : branch_status_t := '0';

  subtype pred_status_t   is std_ulogic_vector(1 downto 0); --! pred status type (2-bit saturing counter)
  constant P_S_N_TAKEN   : pred_status_t := "00";
  constant P_W_N_TAKEN   : pred_status_t := "01";
  constant P_W_TAKEN     : pred_status_t := "10";
  constant P_S_TAKEN     : pred_status_t := "11";

  subtype pred_valid_t is std_ulogic;           --! pred valid type 
  constant P_VALID       : pred_valid_t := '1';
  constant P_N_VALID     : pred_valid_t := '0';

  subtype pred_control_t is std_ulogic;         --! pred control type 
  constant PE            : pred_control_t := '1';
  constant N_PE          : pred_control_t := '0';

  subtype int_delay_t     is std_ulogic;        --! interrupt delay type
  constant INT_DELAY     : int_delay_t := '1';
  constant INT_N_DELAY   : int_delay_t := '0';

  subtype int_status_t    is std_ulogic;        --! pending interrupt flag type
  constant INT           : int_status_t := '1';
  constant N_INT         : int_status_t := '0';

  subtype hazard_status_t is std_ulogic;        --! hazard status type
  constant HAZARD_DETECTED   : hazard_status_t := '1';
  constant HAZARD_N_DETECTED : hazard_status_t := '0';

  subtype rsa_type_t is boolean;                --! source operand ra type 
  subtype rsb_type_t is boolean;                --! source operand rb type 
  subtype rsd_type_t is boolean;                --! source operand rd type (store instructions only)
  subtype mult_type_t  is boolean;              --! inst mult type


  -- //////////////////////////////////////////
  --             MEMORY STRUCTURES
  -- //////////////////////////////////////////
  
  --
  -- REGISTER FILE BUSSES
  --
      
  type rf_i_t is record
    we_i     : we_control_t;
    adr_ra_i : op_reg_t;
    adr_rb_i : op_reg_t;
    adr_rd_i : op_reg_t;
    adr_wr_i : op_reg_t;
    dat_i    : data_t;
  end record;

  type rf_o_t is record
    dat_ra_o : data_t;
    dat_rb_o : data_t;
    dat_rd_o : data_t;
  end record;
  
  --
  -- L1 MEMORY BUSSES
  --
   
  type im_bus_i_t is record
    ena_i   : std_ulogic;
    adr_i   : im_bus_adr_t;
  end record; 
  
  type im_bus_o_t is record  
    dat_o   : im_bus_data_t;
--    ack_o   : std_ulogic; 
  end record;
  
  type dm_bus_i_t is record
    ena_i   : std_ulogic;
    we_i    : std_ulogic;
    sel_i   : dm_bus_sel_t;
    adr_i   : dm_bus_adr_t;
    dat_i   : dm_bus_data_t;
  end record; 
  
  type dm_bus_o_t is record
    dat_o   : dm_bus_data_t;
--    ack_o   : std_ulogic;
  end record;

  -- //////////////////////////////////////////
  --         BRANCH TARGET CACHE SETTINGS
  -- //////////////////////////////////////////

  --
  -- CACHE FORMAT         
  --            
  -- ADR
  -- +-----------------------------------------------------------+         
  -- |                   Tag                  |      Index       |
  -- +-----------------------------------------------------------+
  --
  -- BTC RAM
  -- +-----------------------------------------------------------+         
  -- |                       Predicted PC                        |
  -- +-----------------------------------------------------------+
  --
  -- TAG RAM
  -- +-----------------------------------------------------------+         
  -- | BHT Status Bits |                  Tag                    |
  -- +-----------------------------------------------------------+
  -- The branch history table contains a 2-bit saturing counter.
  -- 

  --
  -- BTC DEFINES
  --  

  constant BTC_S                : natural := USER_BTC_S;                                   --! BTC size
  constant BTC_W                : natural := log2(BTC_S);                                  --! BTC size width
  constant BTC_TAG_W            : natural := PC_W - WORD_ADR_OFF - BTC_W;                  --! BTC tag width
  constant BTC_FLAG_W           : natural := 2;                                            --! BTC tag flag width (2-bit saturing counter)
  constant BTC_PC_W             : natural := PC_W - WORD_ADR_OFF;                          --! BTC pc width (LSB bits are skipped)
  constant BTC_TAG_RAM_W        : natural := BTC_TAG_W + BTC_FLAG_W;                       --! BTC tag ram width  
  constant BTC_STATUS_BASE_OFF  : natural := BTC_TAG_W;                                    --! BTC status base offset
  constant BTC_STATUS_HIGH_OFF  : natural := BTC_TAG_W + 1;                                --! BTC status high offset

  --
  -- BTC DATA TYPES/SUBTYPES
  --

  subtype btc_pc_t           is std_ulogic_vector(BTC_PC_W - 1 downto 0);                   --! BTC pc type 
  subtype btc_tag_t          is std_ulogic_vector(BTC_TAG_W - 1 downto 0);                  --! BTC tag type
  subtype btc_tag_ram_data_t is std_ulogic_vector(BTC_TAG_RAM_W - 1 downto 0);              --! BTC ram data type 
  subtype btc_index_adr_t    is std_ulogic_vector(BTC_W - 1 downto 0);                      --! BTC index type

  subtype btc_tag_status_t is std_ulogic;
  constant BTC_HIT  : btc_tag_status_t := '1';
  constant BTC_MISS : btc_tag_status_t := '0';

  --
  -- BTC BUSSES
  --

  type btc_i_t is record
    fetch_adr_i       : im_bus_adr_t;
    we_i              : std_ulogic;
    new_inst_pc_i     : pc_t;
    new_pred_pc_i     : pc_t;
    new_pred_status_i : pred_status_t;
  end record;

  type btc_o_t is record
    pred_pc_o         : pc_t;
    pred_status_o     : pred_status_t;
    tag_status_o      : btc_tag_status_t;
  end record;

  -- //////////////////////////////////////////
  --             PIPELINE STRUCTURES
  -- //////////////////////////////////////////

  --
  -- When the name of the signal is ambiguous, 
  -- a prefix is used to specify the origin and 
  -- the type of the signal.
  -- Ex: - ex_signal: combinatorial signal from 
  --        execute stage
  --     - ex_ma_signal: registered signal from
  --        output of the execute stage / input 
  --        of the memory access stage   
  --

  --
  -- PIPELINED MULTIPLIER 
  --

  type pipe_mult_t is record
    part_ll_res : mult_part_res_t;
    part_lu_res : mult_part_res_t;
    part_ul_res : mult_part_res_t;
    part_uu_res : mult_part_res_t;
  end record;

  --
  -- PIPELINED BS
  --

  type pipe_bs_t is record
    part_res   : bs_data_ext_t;
    part_shift : bs_part_shift_t;
  end record;

  --
  -- PIPELINED CLZ
  --

  type pipe_clz_t is record
    part_res  : clz_part_res_t;
    part_data : clz_part_data_t;
  end record;

  --
  -- INSTRUCTION FETCH STAGE
  --
  
  type if_stage_i_t is record
    -- registered IF/ID signals
    pred_pc_i        : pc_t;
    pred_pc_del_i    : pc_t;
    -- combinatorial ID signals
    pred_valid_i     : pred_valid_t;
    pred_valid_del_i : pred_valid_t;
    -- combinatorial MA signals 
    branch_pc_i      : pc_t;
    branch_valid_i   : branch_valid_t;
  end record; 

  type if_stage_o_t is record
    -- registered IF/ID signals
    pc_o             : pc_t;
    inst_o           : inst_t;
    -- registered/combinatorial IF signal
    pc_plus_plus_o   : pc_t;
  end record;

  --
  -- INSTRUCTION DECODE STAGE
  --
  
  type id_stage_i_t is record
    -- registered IF/ID signals
    pc_i              : pc_t;
    inst_i            : inst_t;
    pred_pc_i         : pc_t;
    -- registered/combinatorial IF signal
    pc_plus_plus_i    : pc_t;
    -- combinatorial ID signals
    pred_valid_i      : pred_valid_t;
    pred_valid_del_i  : pred_valid_t;
    pred_status_i     : pred_status_t;
    -- registered EX/MA signal
    int_status_i      : int_status_t;
    -- combinatorial WB signals
    wb_res_i          : data_t; 
    wb_rd_i           : op_reg_t;
    wb_we_control_i   : we_control_t;
  end record;

  type id_stage_o_t is record
    -- registered ID/EX signals
    pc_o              : pc_t;
    rd_o              : op_reg_t;
    op_a_o            : data_t;
    op_b_o            : data_t;
    op_d_o            : data_t;
    imm_o             : data_t;
    alu_control_o     : alu_control_t;
    op_a_control_o    : op_a_control_t;
    op_b_control_o    : op_b_control_t;
    carry_control_o   : carry_control_t;
    carry_keep_o      : carry_keep_t; 
    branch_control_o  : branch_control_t;
    branch_delay_o    : branch_delay_t;
    we_control_o      : we_control_t;  
    ls_control_o      : ls_control_t;
    mem_sel_control_o : mem_sel_control_t;
    spr_control_o     : spr_control_t;    
    rs_o              : op_rs_t;  
    cmp_control_o     : cmp_control_t;
    bs_control_o      : bs_control_t;
    mult_control_o    : mult_control_t;
    div_control_o     : div_control_t;
    pat_control_o     : pat_control_t;
    int_control_o     : int_control_t;
    wdc_control_o     : wdc_control_t;
    wic_control_o     : wic_control_t;
    pred_valid_o      : pred_valid_t;
    pred_valid_del_o  : pred_valid_t;
    pred_control_o    : pred_control_t;
    pred_status_o     : pred_status_t;
    pred_pc_o         : pc_t;
    pc_plus_plus_o    : pc_t;
    -- combinatorial ID signals
    id_rd_o           : op_reg_t;         
    id_ra_o           : op_reg_t;
    id_rb_o           : op_reg_t;
    id_rsa_type_o     : rsa_type_t;
    id_rsb_type_o     : rsb_type_t;
    id_rsd_type_o     : rsd_type_t;
    id_mult_type_o    : mult_type_t;
    id_pred_control_o : pred_control_t;
    id_branch_delay_o : branch_delay_t;
  end record;

  --
  -- EXECUTE STAGE
  --
  
  type ex_stage_i_t is record
    -- registered ID/EX signals
    pc_i              : pc_t;
    rd_i              : op_reg_t;
    op_a_i            : data_t;
    op_b_i            : data_t;
    op_d_i            : data_t;
    imm_i             : data_t;
    alu_control_i     : alu_control_t;
    op_a_control_i    : op_a_control_t;
    op_b_control_i    : op_b_control_t;
    carry_control_i   : carry_control_t;
    carry_keep_i      : carry_keep_t; 
    branch_control_i  : branch_control_t;
    branch_delay_i    : branch_delay_t;
    we_control_i      : we_control_t;
    ls_control_i      : ls_control_t;
    mem_sel_control_i : mem_sel_control_t;
    spr_control_i     : spr_control_t;    
    rs_i              : op_rs_t;  
    cmp_control_i     : cmp_control_t;
    bs_control_i      : bs_control_t;
    mult_control_i    : mult_control_t;
    div_control_i     : div_control_t;
    pat_control_i     : pat_control_t;
    wdc_control_i     : wdc_control_t;
    wic_control_i     : wic_control_t;
    int_control_i     : int_control_t;
    pred_valid_i      : pred_valid_t;
    pred_valid_del_i  : pred_valid_t;
    pred_control_i    : pred_control_t;
    pred_status_i     : pred_status_t;
    pred_pc_i         : pc_t;
    pc_plus_plus_i    : pc_t;
    -- forwarding signals
    fw_op_a_control_i : fw_control_t;
    fw_op_b_control_i : fw_control_t;
    fw_op_d_control_i : fw_control_t;
    ma_wb_res_i       : data_t;
    wb_rf_res_a_i     : data_t;
    wb_rf_res_b_i     : data_t;
    wb_rf_res_d_i     : data_t;
  end record;

  type ex_stage_o_t is record
    -- registered EX/MA signals
    pc_o              : pc_t;
    alu_res_o         : data_t;
    op_d_o            : data_t;
    rd_o              : op_reg_t;
    alu_control_o     : alu_control_t;
    bs_control_o      : bs_control_t;
    mult_control_o    : mult_control_t;
    pipe_mult_o       : pipe_mult_t;
    pipe_bs_o         : pipe_bs_t;
    pipe_clz_o        : pipe_clz_t;
    we_control_o      : we_control_t;
    ls_control_o      : ls_control_t;
    mem_sel_control_o : mem_sel_control_t;
    branch_status_o   : branch_status_t;
    branch_delay_o    : branch_delay_t;
    branch_control_o  : branch_control_t;
    int_status_o      : int_status_t;
    wdc_control_o     : wdc_control_t;
    wic_control_o     : wic_control_t;
    mci_busy_o        : std_ulogic;
    pred_valid_o      : pred_valid_t;
    pred_valid_del_o  : pred_valid_t;
    pred_control_o    : pred_control_t;
    pred_status_o     : pred_status_t;
    pred_pc_o         : pc_t;
    pc_plus_plus_o    : pc_t;
  end record;

  --
  -- MEMORY ACCESS STAGE 
  --
  
  type ma_stage_i_t is record
    -- registered EX/MA signals
    pc_i              : pc_t;
    alu_res_i         : data_t;
    op_d_i            : data_t;
    rd_i              : op_reg_t; 
    alu_control_i     : alu_control_t;
    bs_control_i      : bs_control_t;
    mult_control_i    : mult_control_t;
    pipe_mult_i       : pipe_mult_t;
    pipe_bs_i         : pipe_bs_t;
    pipe_clz_i        : pipe_clz_t;
    we_control_i      : we_control_t;
    ls_control_i      : ls_control_t;
    mem_sel_control_i : mem_sel_control_t;
    branch_status_i   : branch_status_t;
    wdc_control_i     : wdc_control_t;
    wic_control_i     : wic_control_t;
  end record;

  type ma_stage_o_t is record
    -- registered MA/WB signals
    res_o             : data_t;
    rd_o              : op_reg_t;
    we_control_o      : we_control_t;
    ls_control_o      : ls_control_t;
    mem_data_o        : data_t;  
    mem_sel_control_o : mem_sel_control_t;
  end record;

  --
  -- WRITE BACK STAGE
  --

  type wb_stage_i_t is record
    -- registered MA/WB signals
    res_i             : data_t;
    rd_i              : op_reg_t; 
    we_control_i      : we_control_t;
    ls_control_i      : ls_control_t;
    mem_data_i        : data_t;  
    mem_sel_control_i : mem_sel_control_t;
    -- forwarding signals
    rf_res_a_lock_i   : std_ulogic;
    rf_res_b_lock_i   : std_ulogic;
    rf_res_d_lock_i   : std_ulogic;
  end record;

  type wb_stage_o_t is record
    -- registered WB/RF signals
    rf_res_a_o        : data_t;
    rf_res_b_o        : data_t;
    rf_res_d_o        : data_t;
    -- combinatorial WB signals
    rd_o              : op_reg_t;
    res_o             : data_t;
    we_control_o      : we_control_t;
  end record;

  --
  -- HAZARD CONTROLLER
  --

  type haz_ctr_i_t is record
    -- combinatorial ID signals
    id_rd_i                 : op_reg_t;
    id_ra_i                 : op_reg_t;
    id_rb_i                 : op_reg_t;
    id_rsa_type_i           : rsa_type_t;
    id_rsb_type_i           : rsb_type_t;
    id_rsd_type_i           : rsd_type_t;
    id_mult_type_i          : mult_type_t;
    -- registered ID/EX signals
    id_ex_alu_control_i     : alu_control_t;
    id_ex_ls_control_i      : ls_control_t;
    id_ex_rd_i              : op_reg_t;
    id_ex_we_control_i      : we_control_t;
    -- combinatorial EX signal 
    ex_mci_busy_i           : std_ulogic;
    -- registered EX/MA signals
    ex_ma_ls_control_i      : ls_control_t;
    ex_ma_branch_delay_i    : branch_delay_t;
    ex_ma_rd_i              : op_reg_t;
    ex_ma_we_control_i      : we_control_t;
    -- combinatorial MA signal
    ma_branch_valid_i       : branch_valid_t;
    -- registered MA/WB signals
    ma_wb_rd_i              : op_reg_t;
    ma_wb_we_control_i      : we_control_t;
  end record;

  type haz_ctr_o_t is record
    -- combinatorial IF signal
    if_stall_o              : std_ulogic;
    -- combinatorial ID signals
    id_stall_o              : std_ulogic;
    id_flush_o              : std_ulogic;
    -- registered ID/EX signals
    id_ex_fw_op_a_control_o : fw_control_t;
    id_ex_fw_op_b_control_o : fw_control_t;
    id_ex_fw_op_d_control_o : fw_control_t;
    -- combinatorial EX signals
    ex_stall_o              : std_ulogic;
    ex_flush_o              : std_ulogic;
    mci_flush_o             : std_ulogic;
    -- combinatorial MA signal
    ma_flush_o              : std_ulogic;
    -- combinatorial WB signals
    rf_res_a_lock_o         : std_ulogic;
    rf_res_b_lock_o         : std_ulogic;
    rf_res_d_lock_o         : std_ulogic;
  end record; 

  type branch_ctr_i_t is record
    -- registered IF/ID signal
    if_id_pred_status_i    : pred_status_t;
    -- combinatorial ID signals
    id_btc_tag_status_i    : btc_tag_status_t;
    id_pred_control_i      : pred_control_t;
    id_branch_delay_i      : branch_delay_t;
    -- registered ID/EX signal
    id_ex_pc_plus_plus_i   : pc_t;
    -- registered EX/MA signals
    ex_ma_branch_status_i  : branch_status_t;
    ex_ma_branch_control_i : branch_control_t;
    ex_ma_alu_res_i        : data_t;
    ex_ma_pred_valid_i     : pred_valid_t;
    ex_ma_pred_valid_del_i : pred_valid_t;
    ex_ma_pred_control_i   : pred_control_t;
    ex_ma_pred_status_i    : pred_status_t;
    ex_ma_pred_pc_i        : pc_t;
    ex_ma_pc_plus_plus_i   : pc_t;
  end record;

  type branch_ctr_o_t is record
    -- combinatorial ID signal
    id_pred_valid_o        : pred_valid_t;
    id_pred_valid_del_o    : pred_valid_t;
    -- combinatorial MA signals
    ma_branch_pc_o         : pc_t;
    ma_branch_valid_o      : branch_valid_t;
    ma_btc_we_o            : std_ulogic;
    ma_pred_status_o       : pred_status_t;
  end record;
  
end package sb_core_pack;


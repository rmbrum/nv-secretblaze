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
--! @file sb_fetch.vhd                                        					
--! @brief SecretBlaze Instruction Fetch Stage Implementation                				
--! @author Lyonel Barthe
--! @version 1.2
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.2 12/05/2011 by Lyonel Barthe
-- Optional BTC support
--
-- Version 1.1 23/12/2010 by Lyonel Barthe
-- Optional PC retiming implementation
--
-- Version 1.0b 1/07/2010 by Lyonel Barthe
-- Minor fix - memory stall signals are now managed in the memory unit entity
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version 
--
-- Version 0.2 7/04/2010 by Lyonel Barthe
-- Clean up version  
--
-- Version 0.1 23/02/2010 by Lyonel Barthe
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
--! The Instruction Fetch (IF) stage manages the control of new instructions 
--! from the instruction memory. For that, it implements two registers; the
--! Program Counter (PC) that indicates the address of the instruction being 
--! fetched from the memory, and the next Program Counter (PC++) that holds 
--! the address of the next instruction to be executed in the sequence. The 
--! latter is obtained by incrementing the current PC by 4, since all 
--! instructions are 4 byte-length. The stage is connected to the memory 
--! through a standard instruction L1-memory bus with enable, address, and 
--! data signals, assuming that the instruction fetched is available during 
--! the next clock cycle. If not, the fetch stage as well as all other modules 
--! of the datapath are halted until the data is ready. The synchronization 
--! between the memory and the datapath is managed by a control signal provided 
--! by the memory unit controller of the processor.
--!
--! On system reset, the processor starts fetching instructions from a configurable 
--! boot reset vector, which is by default set to 0x0000_0000. For the next positive
--! clock edges, the PC is updated in the following ways:
--!   - if a data hazard occurs, then the PC is stalled,
--!   - else if a branch hazard occurs, then the PC is changed to the branch target 
--! address computed in the third stage (EX),
--!   - else if the BTC is implemented and if an entry is found in the BTC, then the 
--! PC is set to the predicted PC,
--!   - else the PC is updated to the PC++.
--!
--! Note that the PC can be retimed for better synthesis results. More detailed 
--! information about its implementation are given in:
--! Lyonel Barthe et al., "Optimizing an Open-Source Processor for FPGAs: A Case Study," 
--! FPL, pp. 551-556, 2011.
--

--! SecretBlaze Fetch Stage Entity
entity sb_fetch is
   
  generic
    (
      USE_BTC      : boolean := USER_USE_BTC;   --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
      USE_PC_RET   : boolean := USER_USE_PC_RET --! if true, use program counter with retiming 
    );

  port
    (
      if_i         : in if_stage_i_t;           --! fetch inputs
      if_o         : out if_stage_o_t;          --! fetch outputs
      im_bus_in_o  : out im_bus_i_t;            --! L1 instruction bus inputs
      im_bus_out_i : in im_bus_o_t;             --! L1 instruction bus outputs
      halt_core_i  : in std_ulogic;             --! halt core signal 
      stall_i      : in std_ulogic;             --! stall fetch signal 
      clk_i        : in std_ulogic;             --! core clock
      rst_n_i      : in std_ulogic              --! active-low reset signal    
    );

end sb_fetch;

--! SecretBlaze Fetch Stage Architecture
architecture be_sb_fetch of sb_fetch is

  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////

  signal pc_r                     : pc_t;       --! program counter reg
  signal pc_plus_plus_r           : pc_t;       --! program counter++ reg (only if USE_PC_RET is false)
  signal pc_plus_plus_low_r       : pc_low_t;   --! program counter++ low reg (only if USE_PC_RET is true)
  signal pc_plus_plus_low_carry_r : std_ulogic; --! program counter++ low carry reg (only if USE_PC_RET is true)

  -- //////////////////////////////////////////
  --                INTERNAL WIRES
  -- //////////////////////////////////////////

  signal pc_s                     : pc_t;  
  signal pc_plus_plus_s           : pc_t;
  signal pc_plus_plus_low_s       : pc_low_t;
  signal pc_plus_plus_low_carry_s : std_ulogic;  
  signal pc_plus_plus_high_s      : pc_high_t;

begin
  
  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  -- registered signals
  if_o.pc_o           <= pc_r;  
  if_o.inst_o         <= im_bus_out_i.dat_o;    
  -- registered/combinatorial signal
  if_o.pc_plus_plus_o <= (pc_plus_plus_high_s & pc_plus_plus_low_r) when (USE_PC_RET = true) else pc_plus_plus_r;  

  --
  -- L1 MEMORY 
  --

  -- combinatorial signals
  im_bus_in_o.ena_i   <= '1'; -- not used anymore, for legacy purpose
  im_bus_in_o.adr_i   <= std_ulogic_vector(resize(unsigned(pc_s),im_bus_adr_t'length)); 

  --
  -- NEXT PC MUX 
  -- 
  --! This process updates the program counter.
  --! STALL:          PC <- OLD PC
  --! BRANCH INVALID: PC <- BRANCH PC
  --! PREDICTED:      PC <- PRED PC
  --! DEFAULT:        PC <- PC++
  COMB_NEXT_PC_MUX: process(if_i,
                            stall_i,
                            pc_r,
                            pc_plus_plus_r,
                            pc_plus_plus_low_r,
                            pc_plus_plus_high_s)

  begin

    -- stall (hazard)
    if(stall_i = '1') then
      pc_s <= pc_r;

      -- incorrect branch 
    elsif(if_i.branch_valid_i = B_N_VALID) then
      pc_s <= if_i.branch_pc_i;

      -- delayed predicted branch
    elsif(USE_BTC = true and if_i.pred_valid_del_i = P_VALID) then
      pc_s <= if_i.pred_pc_del_i;

      -- predicted branch
    elsif(USE_BTC = true and if_i.pred_valid_i = P_VALID) then
      pc_s <= if_i.pred_pc_i;

      -- pc++ 
    else
      if(USE_PC_RET = true) then
        pc_s <= pc_plus_plus_high_s & pc_plus_plus_low_r;

      else
        pc_s <= pc_plus_plus_r;

      end if;

    end if;
    
  end process COMB_NEXT_PC_MUX;

  GEN_COMB_NO_PC_RET : if(USE_PC_RET = false) generate
 
    --
    -- PC PLUS PLUS ADDER
    --
    --! This process implements the PC adder, which is required to implement the pc 
    --! plus plus address.
    COMB_PC_PLUS_PLUS : process(pc_s)
    begin

      pc_plus_plus_s <= (std_ulogic_vector(unsigned(pc_s(pc_t'length - 1 downto WORD_ADR_OFF)) + 1) & WORD_0_PADDING);

    end process COMB_PC_PLUS_PLUS;

  end generate GEN_COMB_NO_PC_RET;

  GEN_COMB_PC_RET : if(USE_PC_RET = true) generate

    --
    -- PC PLUS PLUS HIGH ADDER
    --
    --! This process implements the PC adder, which is required to implement the pc 
    --! plus plus high address.
    COMB_PC_PLUS_PLUS_HIGH : process(pc_r,
                                     pc_plus_plus_low_carry_r)

      variable pc_plus_plus_low_carry_v : std_ulogic_vector(0 downto 0);

    begin

      pc_plus_plus_low_carry_v(0) := pc_plus_plus_low_carry_r;
      pc_plus_plus_high_s         <= std_ulogic_vector(unsigned(pc_r(pc_t'length - 1 downto pc_low_t'length)) + unsigned(pc_plus_plus_low_carry_v));

    end process COMB_PC_PLUS_PLUS_HIGH;

    --
    -- PC PLUS PLUS LOW ADDER
    --
    --! This process implements the PC adder, which is required to implement the pc 
    --! plus plus low address.
    COMB_PC_PLUS_PLUS_LOW : process(pc_s)

      variable adder_res_v : std_ulogic_vector(pc_low_t'length downto WORD_ADR_OFF);
      variable op_a_v      : unsigned(pc_low_t'length - 1 downto WORD_ADR_OFF);
      variable op_b_v      : unsigned(pc_low_t'length - 1 downto WORD_ADR_OFF);
      constant one_c       : std_ulogic_vector(0 downto 0) := "1"; 

    begin

      -- use a n-bit adder with carry out 
      op_a_v                   := resize(unsigned(pc_s(pc_low_t'length - 1 downto WORD_ADR_OFF)),(pc_low_t'length - WORD_ADR_OFF));
      op_b_v                   := resize(unsigned(one_c),(pc_low_t'length - WORD_ADR_OFF));
      adder_res_v              := std_ulogic_vector(('0' & op_a_v) + ('0' & op_b_v)); 

      pc_plus_plus_low_s       <= adder_res_v(pc_low_t'length - 1 downto WORD_ADR_OFF) & WORD_0_PADDING;
      pc_plus_plus_low_carry_s <= adder_res_v(pc_low_t'length);

    end process COMB_PC_PLUS_PLUS_LOW;

  end generate GEN_COMB_PC_RET;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- FETCH CYCLE LOGIC
  --
  --! This process manages PC registers. 
  CYCLE_PC: process(clk_i) 
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
      
      -- sync reset
      if(rst_n_i = '0') then
        pc_r                       <= SB_BOOT_ADR;                               -- reset vector
        if(USE_PC_RET = true) then
          pc_plus_plus_low_r       <= SB_BOOT_ADR(pc_low_t'length - 1 downto 0); -- reset vector
          pc_plus_plus_low_carry_r <= SB_BOOT_ADR(pc_low_t'length);              -- reset vector

        else
          pc_plus_plus_r           <= SB_BOOT_ADR;                               -- reset vector

        end if;
        
      elsif(halt_core_i = '0') then
        pc_r                       <= pc_s;  
        if(USE_PC_RET = true) then
          pc_plus_plus_low_r       <= pc_plus_plus_low_s; 
          pc_plus_plus_low_carry_r <= pc_plus_plus_low_carry_s;

        else
          pc_plus_plus_r           <= pc_plus_plus_s;

        end if;    

      end if;
      
    end if;

  end process CYCLE_PC;                  
  
end be_sb_fetch;
  

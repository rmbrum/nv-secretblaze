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
--! @file sb_branch_controller.vhd                                        					
--! @brief SecretBlaze Branch Controller     				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 12/05/2011 by Lyonel Barthe
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
--! The branch controller sets the branch policy of the processor. 
--! It is declined in two configurations:
--!   - one based on a static prediction model, and
--!   - one based on a dynamic prediction model. 
--!
--! The static prediction model is the simplest form of branch 
--! prediction techniques because it does not rely on information 
--! about the dynamic execution context of a program. In the proposed 
--! implementation, the branch controller assumes that all control 
--! flow instructions should not be taken, i.e. the processor keeps 
--! fetching instructions sequentially after branches. If the branch 
--! being evaluated during the execute stage is determined to be not-taken, 
--! a correct prediction is made, otherwise, a branch hazard occurs.
--!
--! For more aggressive performance, the SecretBlaze can be implemented 
--! with a dynamic prediction model that records information of the past 
--! branch history at run-time. When using this alternative approach, a 
--! branch is always predicted not-taken the first time it is encountered. 
--! The next time it is encountered, a more complex prediction scheme is 
--! implemented. In that case, unconditional branches are always predicted 
--! taken, while conditional branch predictions are based on a bimodal 
--! predictor, which is particularly effective to predict conditional 
--! branches controlling the iteration of loops. 
--

--! SecretBlaze Branch Controller Entity
entity sb_branch_controller is
 
  generic
    (
      USE_BTC       : boolean := USER_USE_BTC --! if true, it will implement the branch target cache with a dynamic branch prediction scheme
    );
 
  port
    (
      branch_ctr_i  : in branch_ctr_i_t;      --! branch controller inputs
      branch_ctr_o  : out branch_ctr_o_t      --! branch controller outputs
    );
  
end sb_branch_controller;

--! SecretBlaze Branch Controller Architecture
architecture be_sb_branch_controller of sb_branch_controller is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal pred_valid_s     : pred_valid_t;
  signal pred_valid_del_s : pred_valid_t;
  signal branch_pc_s      : pc_t;
  signal branch_valid_s   : branch_valid_t;  
  signal btc_we_s         : std_ulogic;
  signal pred_status_s    : pred_status_t;

begin
  
  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  -- combinatorial signals
  branch_ctr_o.id_pred_valid_o     <= pred_valid_s;
  branch_ctr_o.id_pred_valid_del_o <= pred_valid_del_s;
  branch_ctr_o.ma_branch_pc_o      <= branch_pc_s;
  branch_ctr_o.ma_branch_valid_o   <= branch_valid_s;
  branch_ctr_o.ma_btc_we_o         <= btc_we_s;
  branch_ctr_o.ma_pred_status_o    <= pred_status_s;

  --
  -- STATIC BRANCH CONTROLLER
  --

  GEN_STATIC_BRANCH_CONTROL: if(USE_BTC = false) generate

    --
    -- ASSIGN INTERNAL SIGNAL
    --

    branch_pc_s <= branch_ctr_i.ex_ma_alu_res_i(pc_t'length - 1 downto 0); 

    --
    -- STATIC BRANCH COMB
    --
    --! This process implements the control logic required
    --! for a static not-taken branch prediction scheme.
    --! If the branch is acually taken, the branch decision
    --! is not valid.
    COMB_STATIC_BRANCH_CONTROL: process(branch_ctr_i)
    begin

      if(branch_ctr_i.ex_ma_branch_status_i = B_TAKEN) then
        branch_valid_s <= B_N_VALID;

      else
        branch_valid_s <= B_VALID;

      end if;


    end process COMB_STATIC_BRANCH_CONTROL;

  end generate GEN_STATIC_BRANCH_CONTROL;

  --
  -- DYNAMIC BRANCH CONTROLLER
  --

  GEN_DYNAMIC_BRANCH_CONTROL: if(USE_BTC = true) generate

    --
    -- DYNAMIC BRANCH COMB
    --
    --! This process implements the control logic required
    --! for a dynamic branch prediction scheme. A branch
    --! prediction can cause a mispredict if: 
    --!   - a conditional branch that should not have been
    --! taken, is actually taken,
    --!   - a conditional branch that should have been taken, 
    --! is actually not taken,
    --!   - the target address is incorrect.
    --! The bimodal predictor is also updated in this process.
    COMB_DYNAMIC_BRANCH_CONTROL: process(branch_ctr_i)

      alias branch_pc_a : std_ulogic_vector(pc_t'length - 1 downto WORD_ADR_OFF) is branch_ctr_i.ex_ma_alu_res_i(pc_t'length - 1 downto WORD_ADR_OFF);
      alias pred_pc_a   : std_ulogic_vector(pc_t'length - 1 downto WORD_ADR_OFF) is branch_ctr_i.ex_ma_pred_pc_i(pc_t'length - 1 downto WORD_ADR_OFF);

    begin

      -- was predicted 
      if(branch_ctr_i.ex_ma_pred_valid_i = P_VALID or branch_ctr_i.ex_ma_pred_valid_del_i = P_VALID) then
        -- mispredicted (invalid branch or invalid target address)
        if(branch_ctr_i.ex_ma_branch_status_i = B_N_TAKEN or pred_pc_a /= branch_pc_a) then
          -- FIRST CASE: branch not taken but predicted taken
          if(branch_ctr_i.ex_ma_branch_status_i = B_N_TAKEN) then
            -- FIX BRANCH
            branch_valid_s <= B_N_VALID;
            if(branch_ctr_i.ex_ma_pred_valid_del_i = P_VALID) then
              branch_pc_s  <= branch_ctr_i.id_ex_pc_plus_plus_i;

            else
              branch_pc_s  <= branch_ctr_i.ex_ma_pc_plus_plus_i;

            end if;

            -- UPDATE SATURING COUNTER 
            btc_we_s <= '1';
            if(branch_ctr_i.ex_ma_branch_control_i = BNC) then
              pred_status_s <= P_W_TAKEN;

            else
              case branch_ctr_i.ex_ma_pred_status_i is

                when P_W_TAKEN =>
                  pred_status_s <= P_S_N_TAKEN;

                when P_S_TAKEN =>
                  pred_status_s <= P_W_TAKEN;

                when others =>
                  report "branch controller: invalid pred status state (1)" severity warning;
                  pred_status_s <= (others => 'X'); -- force X for speed & area optimization

              end case;

            end if;

            -- SECOND CASE: invalid target address 
          else
            -- FIX BRANCH
            branch_valid_s <= B_N_VALID;
            branch_pc_s    <= (branch_pc_a & WORD_0_PADDING);

            -- UPDATE SATURING COUNTER 
            btc_we_s <= '1';
            if(branch_ctr_i.ex_ma_branch_control_i = BNC) then
              pred_status_s <= P_W_TAKEN;

            else
              case branch_ctr_i.ex_ma_pred_status_i is

                when P_W_TAKEN | P_S_TAKEN =>
                  pred_status_s <= P_S_TAKEN;

                when others =>
                  report "branch controller: invalid pred status state (2)" severity warning;
                  pred_status_s <= (others => 'X'); -- force X for speed & area optimization

              end case;

            end if;

          end if;

          -- correctly predicted
        else
          -- BRANCH VALID
          branch_valid_s <= B_VALID;
          branch_pc_s    <= (branch_pc_a & WORD_0_PADDING); 

          -- UPDATE SATURING COUNTER 
          btc_we_s <= '1';
          if(branch_ctr_i.ex_ma_branch_control_i = BNC) then
            pred_status_s <= P_W_TAKEN;

          else
            case branch_ctr_i.ex_ma_pred_status_i is

              when P_W_TAKEN | P_S_TAKEN =>
                pred_status_s <= P_S_TAKEN;

              when others =>
                report "branch controller: invalid pred status state (3)" severity warning;
                pred_status_s <= (others => 'X'); -- force X for speed & area optimization

            end case;

          end if;

        end if;

        -- was not predicted 
      else
        -- branch 
        if(branch_ctr_i.ex_ma_branch_status_i = B_TAKEN) then
          -- FIX BRANCH 
          branch_valid_s <= B_N_VALID;
          branch_pc_s    <= (branch_pc_a & WORD_0_PADDING);

          -- UPDATE SATURING COUNTER 
          if(branch_ctr_i.ex_ma_pred_control_i = PE) then
            btc_we_s <= '1';
            if(branch_ctr_i.ex_ma_branch_control_i = BNC) then
              pred_status_s <= P_W_TAKEN;

            else
              case branch_ctr_i.ex_ma_pred_status_i is

                when P_W_N_TAKEN =>
                  pred_status_s <= P_S_TAKEN;

                when P_S_N_TAKEN =>
                  pred_status_s <= P_W_N_TAKEN;

                -- collision 
                when others => 
                  pred_status_s <= P_S_TAKEN;

              end case;    
            end if;
 
            -- type of branch never predicted
          else
            btc_we_s      <= '0';
            pred_status_s <= (others => 'X'); -- force X for speed & area optimization

          end if;

         -- no branch (default state)
        else
          branch_valid_s <= B_VALID;
          branch_pc_s    <= (others => 'X'); -- force X for speed & area optimization
          btc_we_s       <= '0';
          pred_status_s  <= (others => 'X'); -- force X for speed & area optimization

        end if;

      end if;

    end process COMB_DYNAMIC_BRANCH_CONTROL;

    --
    -- PRED CONTROL LOGIC
    --
    --! This process implements the pred control logic
    --! of the dynamic prediction scheme. A valid
    --! prediction is made if the entry is found 
    --! in the BTC and if the status bits predicts 
    --! a taken branch. 
    COMB_PRED_CONTROL: process(branch_ctr_i)
    begin

      -- predicted
      if((branch_ctr_i.if_id_pred_status_i = P_W_TAKEN or branch_ctr_i.if_id_pred_status_i = P_S_TAKEN) 
                                                      and branch_ctr_i.id_btc_tag_status_i = BTC_HIT
                                                      and branch_ctr_i.id_pred_control_i = PE) then
        -- delay slot branch / pred delayed
        if(branch_ctr_i.id_branch_delay_i = B_DELAY) then
          pred_valid_s     <= P_N_VALID;
          pred_valid_del_s <= P_VALID;

        else
          pred_valid_s     <= P_VALID;
          pred_valid_del_s <= P_N_VALID;

        end if;

        -- not predicted
      else
        pred_valid_s     <= P_N_VALID;
        pred_valid_del_s <= P_N_VALID;

      end if;

    end process COMB_PRED_CONTROL;

 end generate GEN_DYNAMIC_BRANCH_CONTROL;
  
end be_sb_branch_controller;
  

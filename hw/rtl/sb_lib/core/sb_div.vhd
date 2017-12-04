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
--! @file sb_div.vhd                                      					
--! @brief SecretBlaze Divider Unit
--! @author Lyonel Barthe
--! @version 1.2
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.2 22/02/2011 by Lyonel Barthe
-- Changed the signal start_div_process_s to 
-- improve timing performances
-- TODO: handle signed values in a better way?
--
-- Version 1.1 05/01/2011 by Lyonel Barthe
-- Changed the FSM coding style to avoid 
-- timing problems with the pipeline
--
-- Version 1.0 03/01/2011 by Lyonel Barthe
-- Initial Release 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

--
--! This module implements a serial 32-bit unsigned/signed divider using 
--! the non-restoring algorithm. The divider uses a 33-bit accumulator to
--! prevent the overflow.
--! Latency: 2 or 34 cycles.
--

--! SecretBlaze Divider Entity
entity sb_div is

  port
    (
      op_a_i      : in data_t;        --! div first operand input (divisor)
      op_b_i      : in data_t;        --! div second operand input (dividend)
      res_o       : out data_t;       --! div result output (quotient)
      dzo_o       : out std_ulogic;   --! div by zero or overflow flag
      ena_i       : in std_ulogic;    --! div enable input
      control_i   : in div_control_t; --! div control input
      busy_o      : out std_ulogic;   --! div busy flag output
      halt_core_i : in std_ulogic;    --! halt core signal 
      flush_i     : in std_ulogic;    --! flush control signal
      clk_i       : in std_ulogic;    --! core clock
      rst_n_i     : in std_ulogic     --! active-low reset signal     
    );  
  
end sb_div;

--! SecretBlaze Divider Architecture
architecture be_sb_div of sb_div is

  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- ////////////////////////////////////////// 

  signal div_current_state_r : div_fsm_t;      --! div fsm reg
  signal div_counter_r       : div_counter_t;  --! div counter reg
  signal divisor_r           : data_t;         --! divisor reg
  signal q_r                 : data_t;         --! quotient reg
  signal rem_r               : div_data_ext_t; --! remainder reg
  signal dzo_r               : std_ulogic;     --! div by zero or overflow flag reg
   
  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- ////////////////////////////////////////// 

  --
  -- CONTROL SIGNALS
  -- 

  signal div_next_state_s    : div_fsm_t;
  signal start_div_process_s : std_ulogic;
  signal busy_s              : std_ulogic;
  signal dzo_s               : std_ulogic;

  --
  -- DATA SIGNALS
  --

  signal res_s               : data_t;
  signal q_s                 : data_t;
  signal rem_s               : div_data_ext_t;
  signal acc_op_a_s          : div_data_ext_t;
  signal acc_op_b_s          : div_data_ext_t;
  signal acc_carry_in_s      : std_ulogic;
  signal acc_res_s           : div_data_ext_t;

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  res_o  <= res_s;
  dzo_o  <= dzo_r;
  busy_o <= busy_s;

  --
  -- DIV RESULT LOGIC
  --
  --! This process implements the output mux giving the result of the division.
  COMB_DIV_MUX_RES: process(div_current_state_r,
                            q_r)

  begin

    case div_current_state_r is

      when DIV_IDLE  =>
        res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation         
		  
      when DIV_ZERO =>
        res_s <= (others => '0');

      when DIV_OVF =>
        res_s <= SIGNED_MIN_VAL;

      when DIV_BUSY =>
        res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 

      when DIV_POS =>
        res_s <= q_r; 

      when DIV_NEG  =>
        res_s <= std_ulogic_vector(unsigned(not(q_r)) + 1); 

      when others =>
        res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
        report "div fsm process: illegal state" severity warning;
    
    end case;

  end process COMB_DIV_MUX_RES;

  --
  -- DIV FSM CONTROL LOGIC 
  --
  --! This process implements the control logic of the serial divider.
  COMB_DIV_CONTROL: process(div_current_state_r,
                            div_counter_r,
                            control_i,
                            acc_res_s,
                            op_a_i,
                            op_b_i,
                            ena_i)

    alias sign_dividend_a : std_ulogic is op_b_i(data_t'left);
    alias sign_divisor_a  : std_ulogic is op_a_i(data_t'left);

    constant zero_c       : data_t := (others =>'0');
    constant minus_one_c  : data_t := (others =>'1');
	 
  begin

    -- default assignments 
    -- improve code density and avoid latches
    div_next_state_s    <= div_current_state_r;
    start_div_process_s <= '0';
    dzo_s               <= '0';
    busy_s              <= '0';

    case div_current_state_r is

      when DIV_IDLE =>
        if(ena_i = '1') then
          busy_s                <= '1';
          start_div_process_s   <= '1';

          -- divisor is 0 / res <- 0
          if(op_a_i = zero_c) then
            dzo_s               <= '1';
            div_next_state_s    <= DIV_ZERO;          

          -- signed division overflow / res <- -2147483648
          elsif(control_i = DIV_SS and op_a_i = minus_one_c and op_b_i = SIGNED_MIN_VAL) then
            dzo_s               <= '1';
            div_next_state_s    <= DIV_OVF;                    

          -- res <- E( dividend / divisor )
          else        
            div_next_state_s    <= DIV_BUSY;
   
          end if;

        end if;

      when DIV_BUSY =>
        busy_s               <= '1';

        -- end of the serial process 
        if(div_counter_r = DIV_COUNT_END) then
          -- division done
          if(control_i = DIV_UU or 
            (control_i = DIV_SS and (sign_dividend_a = sign_divisor_a))) then
            div_next_state_s <= DIV_POS;

            -- c2 correction 
          else
            div_next_state_s <= DIV_NEG;

          end if;

        end if;

      when DIV_ZERO | DIV_OVF | DIV_POS | DIV_NEG =>
        div_next_state_s <= DIV_IDLE;

      when others =>
        div_next_state_s <= DIV_IDLE; -- force a reset / safe implementation
        report "div fsm process: illegal state" severity warning;

    end case;

  end process COMB_DIV_CONTROL;

  --
  -- DIV ACC OP A 
  --
  --! This process sets up the operand A of the accumulator used to 
  --! implement the non-restoring algorithm.
  COMB_DIV_ACC_OP_A: process(rem_r,
                             q_r)
  begin
 
    acc_op_a_s <= rem_r(div_data_ext_t'length - 2 downto 0) & q_r(data_t'left);  

  end process COMB_DIV_ACC_OP_A; 

  --
  -- DIV ACC OP B MUX
  --
  --! This process sets up the operand B of the accumulator used to 
  --! implement the non-restoring algorithm.
  COMB_DIV_ACC_OP_B_MUX: process(rem_r,
                                 divisor_r)

    alias sign_rem_a : std_ulogic is rem_r(div_data_ext_t'left);

  begin

    case sign_rem_a is 

      when '0' =>
        acc_op_b_s <= not('0' & divisor_r);   

      when '1' =>
        acc_op_b_s <= '0' & divisor_r;   

      when others =>
        acc_op_b_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
        report "div entity: illegal accumulator control code" severity warning;

    end case;

  end process COMB_DIV_ACC_OP_B_MUX; 

  --
  -- DIV ADD CARRY IN MUX
  --
  --! This process sets up the carry in of the accumulator used to implement
  --! the non-restoring algorithm.
  COMB_DIV_ACC_OP_CARRY_MUX: process(rem_r)

    alias sign_rem_a : std_ulogic is rem_r(div_data_ext_t'left);

  begin

    case sign_rem_a is 

      when '0' =>
        acc_carry_in_s <= '1'; 

      when '1' =>
        acc_carry_in_s <= '0';       

      when others =>
        acc_carry_in_s <= 'X'; -- force X for speed & area optimization / unsafe implementation 
        report "div entity: illegal accumulator control code" severity warning;

    end case;

  end process COMB_DIV_ACC_OP_CARRY_MUX; 

  --
  -- DIV ACCUMULATOR
  --
  --! This process implements the accumulator of the non-restoring algorithm.
  COMB_DIV_ACC: process(acc_op_a_s,
                        acc_op_b_s,
                        acc_carry_in_s)
								
    variable acc_carry_in_v : std_ulogic_vector(0 downto 0);
	 
  begin

    -- use a 33-bit adder with carry in
    acc_carry_in_v(0) := acc_carry_in_s;
    acc_res_s         <= std_ulogic_vector(unsigned(acc_op_a_s) + unsigned(acc_op_b_s) + unsigned(acc_carry_in_v));

  end process COMB_DIV_ACC;
  
  --
  -- PARTIAL RESULTS
  --
  --! This process implements partial remainder and quotient results.
  COMB_DIV_PARTIAL_RESULTS: process(acc_res_s,
                                    q_r)

    alias sign_rem_a : std_ulogic is acc_res_s(div_data_ext_t'left);

  begin

    -- next remainder 
    rem_s <= acc_res_s;

    -- next quotient 
    q_s   <= q_r(data_t'length - 2 downto 0) & not(sign_rem_a);
  
  end process COMB_DIV_PARTIAL_RESULTS;        

  -- //////////////////////////////////////////
  --                CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- DIV FSM REG
  --
  --! This process implements the div fsm register.
  CYCLE_DIV_FSM: process(clk_i)
  begin


    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      -- sync reset
      if(rst_n_i = '0' or (halt_core_i = '0' and flush_i = '1')) then
        div_current_state_r <= DIV_IDLE;
		 
      elsif(halt_core_i = '0') then
        div_current_state_r <= div_next_state_s;
        
      end if;

    end if;

  end process CYCLE_DIV_FSM;

  --
  -- DIV COUNTER
  --
  --! This process implements the div counter used to implement the 
  --! serialize process for the non-restoring algorithm.
  CYCLE_DIV_COUNTER: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      -- sync reset
      if(rst_n_i = '0' or (halt_core_i = '0' and start_div_process_s = '1')
                       or (halt_core_i = '0' and flush_i = '1')) then
        div_counter_r <= (others => '0');
		 
      elsif(halt_core_i = '0') then
        div_counter_r <= std_ulogic_vector(unsigned(div_counter_r) + 1);
        
      end if;

    end if;

  end process CYCLE_DIV_COUNTER;  

  --
  -- DIV DATA REG
  --
  --! This process implements div data registers. When the serial process 
  --! starts, registers are initialized according to data inputs. Note that
  --! in case of signed division, negative operands are converted into 
  --! positive ones using c2 form.
  CYCLE_DIV_DATA_REG: process(clk_i)

    alias sign_dividend_a : std_ulogic is op_b_i(data_t'left);
    alias sign_divisor_a  : std_ulogic is op_a_i(data_t'left);

  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      if(halt_core_i = '0') then

        -- load init values
        if(start_div_process_s = '1') then
          rem_r         <= (others => '0');

          if(control_i = DIV_UU) then
            divisor_r   <= op_a_i;
            q_r         <= op_b_i;
 
          else
            -- c2 correction
            if(sign_divisor_a = '1') then
              divisor_r <= std_ulogic_vector(unsigned(not(op_a_i)) + 1);

            else
              divisor_r <= op_a_i; 

            end if;
            -- c2 correction
            if(sign_dividend_a = '1') then
              q_r       <= std_ulogic_vector(unsigned(not(op_b_i)) + 1);

            else
              q_r       <= op_b_i; 

            end if;
          end if;

        else
          q_r           <= q_s;
          rem_r         <= rem_s;

        end if;
        
      end if;

    end if;

  end process CYCLE_DIV_DATA_REG; 

  --
  -- DIV DZO
  --
  --! This process implements the div dzo register.
  CYCLE_DIV_DZO: process(clk_i)
  begin


    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      -- sync reset
      if(rst_n_i = '0') then
        dzo_r <= '0';
		 
      elsif(halt_core_i = '0' and flush_i = '0') then
        dzo_r <= dzo_s;
        
      end if;

    end if;

  end process CYCLE_DIV_DZO;
           
end be_sb_div;


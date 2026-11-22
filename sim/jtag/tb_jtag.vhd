-------------------------------------------------------------------------------
-- Title      : tb_jtag
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of jtag_tap and of the test data registers, driven by the
--  JTAG BFM of asylum_uvvm (TCK 100 ns) : jtag_tap, a user decoder (one
--  opcode per TDR, user_tdo_en_i = 1 for these opcodes) and one
--  jtag_tdr_in, jtag_tdr_out and jtag_tdr_inout of TDR_*_WIDTH bits.
--  Monitors : reference model of the TAP controller (capture_dr_o,
--  shift_dr_o, update_dr_o, tlr_o and tdo_en checked at each rising edge
--  of TCK), TDO and tdo_en change on the falling edge of TCK only, ir_o
--  changes in Update-IR / Test-Logic-Reset only, bits shifted out by each
--  IR scan, number of TCK cycles with tdo_en = 1 in each scan, the shift
--  register of a TDR (its tdo_o) does not change while it is not selected,
--  data_o of a TDR changes on the falling edge of TCK in Update-DR while it
--  is selected or in Test-Logic-Reset only.
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_jtag_tests_pkg), each one after a power-on reset pulse, then one TCK
--  with TMS = 0 (Run-Test/Idle) ; "" : build and elaboration only.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.jtag_pkg.all;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;
use     work.tb_jtag_tests_pkg.all;

entity tb_jtag is
  generic (
    TESTS_LIST      : string   := ""                       -- Scenarios, e.g. "idcode,bypass" (tb_jtag_tests_pkg)
   ;IR_WIDTH        : positive := 5                        -- Width of the instruction register (2 to 32)
   ;TRST_ENABLE     : boolean  := true                     -- TRST* used by the TAP
   ;TDR_IN_WIDTH    : positive := 8                        -- Width of jtag_tdr_in (1 to 64)
   ;TDR_OUT_WIDTH   : positive := 12                       -- Width of jtag_tdr_out (1 to 64)
   ;TDR_INOUT_WIDTH : positive := 16                       -- Width of jtag_tdr_inout (1 to 64)
  );
end entity tb_jtag;

architecture sim of tb_jtag is

  constant C_SCOPE        : string    := "TB_JTAG";

  -- Power-on reset
  signal   arst_b         : std_logic := '0';

  -- BFM and JTAG pins
  signal   jtag_if        : t_jtag_if := init_jtag_if_signals;
  signal   jtag_ini       : jtag_ini_t;
  signal   jtag_tgt       : jtag_tgt_t;

  -- TAP outputs
  signal   tap_tck        : std_logic;
  signal   tap_trst_b     : std_logic;
  signal   tap_tlr        : std_logic;
  signal   tap_ir         : std_logic_vector(IR_WIDTH-1 downto 0);
  signal   tap_capture_dr : std_logic;
  signal   tap_shift_dr   : std_logic;
  signal   tap_update_dr  : std_logic;
  signal   tap_tdi        : std_logic;

  -- User decoder of the testbench
  signal   sel_in         : std_logic;
  signal   sel_out        : std_logic;
  signal   sel_inout      : std_logic;
  signal   user_tdo_en    : std_logic;
  signal   user_tdo       : std_logic;

  -- Test data registers
  signal   tdr_in_data_i  : std_logic_vector(TDR_IN_WIDTH   -1 downto 0);
  signal   tdr_in_tdo     : std_logic;
  signal   tdr_out_data_o : std_logic_vector(TDR_OUT_WIDTH  -1 downto 0);
  signal   tdr_out_tdo    : std_logic;
  signal   tdr_io_data_i  : std_logic_vector(TDR_INOUT_WIDTH-1 downto 0);
  signal   tdr_io_data_o  : std_logic_vector(TDR_INOUT_WIDTH-1 downto 0);
  signal   tdr_io_tdo     : std_logic;

  -- Scenarios
  signal   tb_req         : tb_req_t  := C_TB_REQ_IDLE;
  signal   tb_rsp         : tb_rsp_t;

  -- Reference model of the TAP controller
  signal   model_state    : tap_state_t;
  signal   model_rst      : boolean;

begin  -- architecture sim

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  jtag_ini    <= (tck    => jtag_if.tck
                 ,trst_n => jtag_if.trst_b
                 ,tms    => jtag_if.tms
                 ,tdi    => jtag_if.tdi
                 );

  -- TDO tri-state at the pad
  jtag_if.tdo <= jtag_tgt.tdo when jtag_tgt.tdo_en = '1' else
                 'Z';

  dut : entity asylum.jtag_tap
    generic map
    (IR_WIDTH        => IR_WIDTH
    ,IDCODE_VALUE    => C_IDCODE
    ,TRST_ENABLE     => TRST_ENABLE
    )
    port map
    (arst_b_i        => arst_b
    ,jtag_ini_i      => jtag_ini
    ,jtag_tgt_o      => jtag_tgt
    ,tck_o           => tap_tck
    ,trst_b_o        => tap_trst_b
    ,tlr_o           => tap_tlr
    ,ir_o            => tap_ir
    ,capture_dr_o    => tap_capture_dr
    ,shift_dr_o      => tap_shift_dr
    ,update_dr_o     => tap_update_dr
    ,tdi_o           => tap_tdi
    ,user_tdo_en_i   => user_tdo_en
    ,user_tdo_i      => user_tdo
    );

  -----------------------------------------------------------------------------
  -- User decoder : one opcode per TDR
  -----------------------------------------------------------------------------
  sel_in      <= '1' when unsigned(tap_ir) = C_IR_TDR_IN    else '0';
  sel_out     <= '1' when unsigned(tap_ir) = C_IR_TDR_OUT   else '0';
  sel_inout   <= '1' when unsigned(tap_ir) = C_IR_TDR_INOUT else '0';

  user_tdo_en <= sel_in or sel_out or sel_inout;
  user_tdo    <= tdr_in_tdo  when sel_in  = '1' else
                 tdr_out_tdo when sel_out = '1' else
                 tdr_io_tdo;

  -----------------------------------------------------------------------------
  -- Test data registers
  -----------------------------------------------------------------------------
  tdr_in_data_i <= tb_req.tdr_in_data   (TDR_IN_WIDTH   -1 downto 0);
  tdr_io_data_i <= tb_req.tdr_inout_data(TDR_INOUT_WIDTH-1 downto 0);

  ins_tdr_in : entity asylum.jtag_tdr_in
    port map
    (tck_i           => tap_tck
    ,trst_b_i        => tap_trst_b
    ,sel_i           => sel_in
    ,capture_dr_i    => tap_capture_dr
    ,shift_dr_i      => tap_shift_dr
    ,update_dr_i     => tap_update_dr
    ,tdi_i           => tap_tdi
    ,tdo_o           => tdr_in_tdo
    ,data_i          => tdr_in_data_i
    );

  ins_tdr_out : entity asylum.jtag_tdr_out
    port map
    (tck_i           => tap_tck
    ,trst_b_i        => tap_trst_b
    ,tlr_i           => tap_tlr
    ,sel_i           => sel_out
    ,capture_dr_i    => tap_capture_dr
    ,shift_dr_i      => tap_shift_dr
    ,update_dr_i     => tap_update_dr
    ,tdi_i           => tap_tdi
    ,tdo_o           => tdr_out_tdo
    ,data_o          => tdr_out_data_o
    );

  ins_tdr_inout : entity asylum.jtag_tdr_inout
    port map
    (tck_i           => tap_tck
    ,trst_b_i        => tap_trst_b
    ,tlr_i           => tap_tlr
    ,sel_i           => sel_inout
    ,capture_dr_i    => tap_capture_dr
    ,shift_dr_i      => tap_shift_dr
    ,update_dr_i     => tap_update_dr
    ,tdi_i           => tap_tdi
    ,tdo_o           => tdr_io_tdo
    ,data_i          => tdr_io_data_i
    ,data_o          => tdr_io_data_o
    );

  -----------------------------------------------------------------------------
  -- Outputs of the DUT to the scenarios
  -----------------------------------------------------------------------------
  tb_rsp.ir             <= std_logic_vector(resize(unsigned(tap_ir        ), 32));
  tb_rsp.tlr            <= tap_tlr;
  tb_rsp.tdo_en         <= jtag_tgt.tdo_en;
  tb_rsp.tdr_out_data   <= std_logic_vector(resize(unsigned(tdr_out_data_o), C_MAX_WIDTH));
  tb_rsp.tdr_inout_data <= std_logic_vector(resize(unsigned(tdr_io_data_o ), C_MAX_WIDTH));

  -----------------------------------------------------------------------------
  -- Reference model of the TAP controller (reset : power-on reset and TRST*)
  -----------------------------------------------------------------------------
  model_rst <= arst_b = '0' or (TRST_ENABLE and jtag_if.trst_b = '0');

  p_model : process(jtag_if.tck, model_rst)
  begin
    if model_rst
    then
      model_state <= TEST_LOGIC_RESET;
    elsif rising_edge(jtag_if.tck)
    then
      model_state <= tap_next(model_state, jtag_if.tms);
    end if;
  end process p_model;

  -----------------------------------------------------------------------------
  -- Rising edge of TCK (before the TAP changes state) : outputs of the TAP
  -- against the model, IR capture and tdo_en count of each scan
  -----------------------------------------------------------------------------
  p_check : process
    variable v_ir_capture : std_logic_vector(32-1 downto 0);
    variable v_ir_len     : natural;
    variable v_tdo_en_cnt : natural;

    procedure check_output(name : string; value : std_logic; exp : boolean) is
    begin
      if (value = '1') /= exp
      then
        alert(ERROR, name & " = " & to_string(value) & " in state " & tap_state_t'image(model_state), C_SCOPE);
      end if;
    end procedure check_output;
  begin
    wait until rising_edge(jtag_if.tck) and not model_rst;

    check_output("capture_dr_o", tap_capture_dr , model_state = CAPTURE_DR);
    check_output("shift_dr_o"  , tap_shift_dr   , model_state = SHIFT_DR);
    check_output("update_dr_o" , tap_update_dr  , model_state = UPDATE_DR);
    check_output("tlr_o"       , tap_tlr        , model_state = TEST_LOGIC_RESET);
    check_output("tdo_en"      , jtag_tgt.tdo_en, model_state = SHIFT_IR or model_state = SHIFT_DR);

    case model_state is
      when CAPTURE_IR | CAPTURE_DR =>
        v_ir_capture := (others => '0');
        v_ir_len     := 0;
        v_tdo_en_cnt := 0;
      when SHIFT_IR =>
        v_ir_capture(v_ir_len) := jtag_tgt.tdo;
        v_ir_len               := v_ir_len + 1;
      when UPDATE_IR =>
        tb_rsp.ir_capture      <= v_ir_capture;
        tb_rsp.ir_len          <= v_ir_len;
      when others =>
        null;
    end case;

    if jtag_tgt.tdo_en = '1'
    then
      v_tdo_en_cnt := v_tdo_en_cnt + 1;
    end if;
    if model_state = UPDATE_IR or model_state = UPDATE_DR
    then
      tb_rsp.tdo_en_cnt <= v_tdo_en_cnt;
    end if;
  end process p_check;

  -----------------------------------------------------------------------------
  -- TDO and tdo_en change on the falling edge of TCK only
  -----------------------------------------------------------------------------
  p_tdo : process
  begin
    wait on jtag_tgt;
    if not model_rst and jtag_if.tck /= '0'
    then
      alert(ERROR, "TDO / tdo_en changed while TCK is high", C_SCOPE);
    end if;
  end process p_tdo;

  -----------------------------------------------------------------------------
  -- ir_o changes on the falling edge of TCK in Update-IR or
  -- Test-Logic-Reset only
  -----------------------------------------------------------------------------
  p_ir : process
  begin
    wait on tap_ir;
    if not model_rst and
       not (jtag_if.tck = '0' and (model_state = UPDATE_IR or model_state = TEST_LOGIC_RESET))
    then
      alert(ERROR, "ir_o changed in state " & tap_state_t'image(model_state), C_SCOPE);
    end if;
  end process p_ir;

  -----------------------------------------------------------------------------
  -- Shift register of a TDR (its tdo_o) unchanged while it is not selected
  -----------------------------------------------------------------------------
  p_tdr_shift : process
  begin
    wait on tdr_in_tdo, tdr_out_tdo, tdr_io_tdo;
    if tap_trst_b = '1'
    then
      if (tdr_in_tdo'event  and sel_in    = '0') or
         (tdr_out_tdo'event and sel_out   = '0') or
         (tdr_io_tdo'event  and sel_inout = '0')
      then
        alert(ERROR, "Shift register of a TDR changed while not selected", C_SCOPE);
      end if;
    end if;
  end process p_tdr_shift;

  -----------------------------------------------------------------------------
  -- data_o of a TDR changes on the falling edge of TCK in Update-DR while it
  -- is selected, or in Test-Logic-Reset, only
  -----------------------------------------------------------------------------
  p_tdr_update : process
  begin
    wait on tdr_out_data_o, tdr_io_data_o;
    if tap_trst_b = '1'
    then
      if (tdr_out_data_o'event and
          not (jtag_if.tck = '0' and (model_state = TEST_LOGIC_RESET or (model_state = UPDATE_DR and sel_out = '1')))) or
         (tdr_io_data_o'event  and
          not (jtag_if.tck = '0' and (model_state = TEST_LOGIC_RESET or (model_state = UPDATE_DR and sel_inout = '1'))))
      then
        alert(ERROR, "data_o of a TDR changed in state " & tap_state_t'image(model_state), C_SCOPE);
      end if;
    end if;
  end process p_tdr_update;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
    variable v_cfg : tb_cfg_t;
  begin
    v_cfg.ir_width        := IR_WIDTH;
    v_cfg.trst_enable     := TRST_ENABLE;
    v_cfg.tdr_in_width    := TDR_IN_WIDTH;
    v_cfg.tdr_out_width   := TDR_OUT_WIDTH;
    v_cfg.tdr_inout_width := TDR_INOUT_WIDTH;
    v_cfg.bfm             := C_JTAG_BFM_CONFIG_DEFAULT;
    v_cfg.bfm.ir_width    := IR_WIDTH;
    v_cfg.bfm.tck_period  := C_TCK_PERIOD;
    log(ID_LOG_HDR, "IR " & to_string(IR_WIDTH) & " bits, TRST_ENABLE " & to_string(TRST_ENABLE) &
        ", TDRs " & to_string(TDR_IN_WIDTH) & " / " & to_string(TDR_OUT_WIDTH) & " / " & to_string(TDR_INOUT_WIDTH) &
        " bits, TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    if IR_WIDTH > 32 or IR_WIDTH < 3 or maximum(TDR_IN_WIDTH, maximum(TDR_OUT_WIDTH, TDR_INOUT_WIDTH)) > C_MAX_WIDTH
    then
      alert(TB_ERROR, "IR_WIDTH (3 to 32) or TDR_*_WIDTH (up to 64) not supported by the testbench", C_SCOPE);
    end if;

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- Stimuli idle, power-on reset pulse (released with TCK low), then
      -- Run-Test/Idle : each scenario starts from reset
      jtag_if <= init_jtag_if_signals;
      tb_req  <= C_TB_REQ_IDLE;
      arst_b  <= '0';
      wait for 2*C_TCK_PERIOD;
      arst_b  <= '1';
      wait for C_TCK_PERIOD;
      tb_idle(1, "Test-Logic-Reset -> Run-Test/Idle", jtag_if, v_cfg);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), jtag_if, tb_req, tb_rsp, v_cfg);
      wait for 2*C_TCK_PERIOD;
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;

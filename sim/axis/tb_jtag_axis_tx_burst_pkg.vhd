-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_tx_burst_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_tx_burst_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-27
-- Last update: 2026-11-27
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tx_burst : TX bursts, back-to-back scans (no idle cycle between
--  them), s_axis continuous (tvalid held high while words are left) : the
--  system fills the whole TX FIFO, CONFIG TX full, DEPTH_TX scans drain it
--  (every one valid), then an empty scan ; then 3 x DEPTH_TX words written
--  while the debugger reads them back to back (a scan that finds the FIFO
--  empty is not a word), every word in order
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-27  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.jtag_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_axis_bfm_pkg.all;

package tb_jtag_axis_tx_burst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_tx_burst_pkg;

package body tb_jtag_axis_tx_burst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant N        : natural := 3*cfg.depth_tx;
    variable v_popped : natural := 0;
    variable v_scans  : natural := 0;
    variable v_valid  : boolean;
    variable v_word   : std_logic_vector(cfg.data_width-1 downto 0);
  begin
    if not cfg.tx_enable
    then
      alert(TB_ERROR, "tx_burst needs TX_ENABLE", C_TB_SCOPE);
    end if;

    -- Whole FIFO filled, then drained
    tb_req.tx_target <= cfg.depth_tx;
    tb_wait_tx_sent(cfg.depth_tx, tb_rsp, cfg);
    tb_idle(4, jtag_if, cfg);
    tb_check_config('0', '1', '1', not to_sl(cfg.rx_enable), "TX full", jtag_if, cfg);
    tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
    for i in 0 to cfg.depth_tx-1
    loop
      tb_pop(true, i, "drain, back-to-back scans", jtag_if, cfg);
    end loop;
    tb_pop(false, 0, "drained", jtag_if, cfg);

    -- Continuous stream : the system writes while the debugger reads
    tb_req.tx_target <= cfg.depth_tx + N;
    while v_popped < N
    loop
      v_scans := v_scans + 1;
      if v_scans > 10*N
      then
        alert(TB_ERROR, "tx_burst : " & to_string(v_popped) & " words read", C_TB_SCOPE);
        exit;
      end if;
      tb_pop_read(v_valid, v_word, jtag_if, cfg);
      if v_valid
      then
        check_value(v_word, tx_word(cfg.depth_tx + v_popped, cfg.data_width), ERROR, "tx_burst : TX word " & to_string(cfg.depth_tx + v_popped), C_TB_SCOPE);
        v_popped := v_popped + 1;
      end if;
    end loop;
    log(ID_SEQUENCER, "tx_burst : " & to_string(N) & " words in " & to_string(v_scans) & " back-to-back scans", C_TB_SCOPE);
    tb_pop(false, 0, "empty at the end", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_axis_tx_burst_pkg;

-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_rx_burst_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_rx_burst_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-27
-- Last update: 2026-11-27
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario rx_burst : RX bursts, back-to-back scans (no idle cycle between
--  them) : the system does not read, DEPTH_RX scans fill the whole RX FIFO
--  (every one accepted), the next one is refused, CONFIG RX full ; the
--  system reads with m_axis_tready_i held high, then 3 x DEPTH_RX words
--  written back to back while it reads (a refused word is written again),
--  every word read in order
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

package tb_jtag_axis_rx_burst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_rx_burst_pkg;

package body tb_jtag_axis_rx_burst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant N        : natural := 3*cfg.depth_rx;
    variable v_pushed : natural := 0;
    variable v_scans  : natural := 0;
    variable v_acc    : boolean;
  begin
    if not cfg.rx_enable
    then
      alert(TB_ERROR, "rx_burst needs RX_ENABLE", C_TB_SCOPE);
    end if;

    -- Whole FIFO filled, then read by the system
    tb_req.rx_mode <= RX_NEVER;
    tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
    for i in 0 to cfg.depth_rx-1
    loop
      tb_push(i, true, "fill, back-to-back scans", jtag_if, cfg);
    end loop;
    tb_push(cfg.depth_rx, false, "full", jtag_if, cfg);
    tb_check_config('1', not to_sl(cfg.tx_enable), '0', '1', "RX full", jtag_if, cfg);
    tb_req.rx_mode <= RX_ALWAYS;
    tb_wait_rx_cnt(cfg.depth_rx, tb_rsp, cfg);

    -- Continuous stream : the debugger writes while the system reads
    tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
    while v_pushed < N
    loop
      v_scans := v_scans + 1;
      if v_scans > 10*N
      then
        alert(TB_ERROR, "rx_burst : " & to_string(v_pushed) & " words written", C_TB_SCOPE);
        exit;
      end if;
      tb_push_try(cfg.depth_rx + v_pushed, v_acc, jtag_if, cfg);
      if v_acc
      then
        v_pushed := v_pushed + 1;
      end if;
    end loop;
    log(ID_SEQUENCER, "rx_burst : " & to_string(N) & " words in " & to_string(v_scans) & " back-to-back scans", C_TB_SCOPE);
    tb_wait_rx_cnt(cfg.depth_rx + N, tb_rsp, cfg);
  end procedure run;

end package body tb_jtag_axis_rx_burst_pkg;

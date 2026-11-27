-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_duplex_burst_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_duplex_burst_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-27
-- Last update: 2026-11-27
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario duplex_burst : both directions at the same time (each enabled
--  one), the AXI-Stream sides continuous (s_axis_tvalid_i held high while
--  words are left, m_axis_tready_i held high), 3 x DEPTH words each way :
--  the debugger alternates TX scans and RX scans with no idle cycle, every
--  word read in order on both sides
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

package tb_jtag_axis_duplex_burst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_duplex_burst_pkg;

package body tb_jtag_axis_duplex_burst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant N_TX     : natural := 3*cfg.depth_tx;
    constant N_RX     : natural := 3*cfg.depth_rx;
    variable v_popped : natural := 0;
    variable v_pushed : natural := 0;
    variable v_scans  : natural := 0;
    variable v_valid  : boolean;
    variable v_acc    : boolean;
    variable v_word   : std_logic_vector(cfg.data_width-1 downto 0);
  begin
    if cfg.tx_enable
    then
      tb_req.tx_target <= N_TX;
    else
      v_popped := N_TX;
    end if;
    if cfg.rx_enable
    then
      tb_req.rx_mode   <= RX_ALWAYS;
    else
      v_pushed := N_RX;
    end if;

    while v_popped < N_TX or v_pushed < N_RX
    loop
      v_scans := v_scans + 1;
      if v_scans > 10*(N_TX + N_RX)
      then
        alert(TB_ERROR, "duplex_burst : " & to_string(v_popped) & " words read, " & to_string(v_pushed) & " words written", C_TB_SCOPE);
        exit;
      end if;
      if v_popped < N_TX
      then
        tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
        tb_pop_read(v_valid, v_word, jtag_if, cfg);
        if v_valid
        then
          check_value(v_word, tx_word(v_popped, cfg.data_width), ERROR, "duplex_burst : TX word " & to_string(v_popped), C_TB_SCOPE);
          v_popped := v_popped + 1;
        end if;
      end if;
      if v_pushed < N_RX
      then
        tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
        tb_push_try(v_pushed, v_acc, jtag_if, cfg);
        if v_acc
        then
          v_pushed := v_pushed + 1;
        end if;
      end if;
    end loop;

    if cfg.rx_enable
    then
      tb_wait_rx_cnt(N_RX, tb_rsp, cfg);
    end if;
  end procedure run;

end package body tb_jtag_axis_duplex_burst_pkg;

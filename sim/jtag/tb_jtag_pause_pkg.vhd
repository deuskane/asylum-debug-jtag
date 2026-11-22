-------------------------------------------------------------------------------
-- Title      : tb_jtag_pause_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_pause_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario pause of tb_jtag : Paths of the TAP controller that the BFM does not use, so that every
--  transition of the 16 states is taken (outputs checked against the model of
--  the testbench at each TCK) : IR scan of BYPASS through Pause-IR twice
--  (Exit2-IR -> Shift-IR, then Exit2-IR -> Update-IR), zero-length IR scan
--  (Capture-IR -> Exit1-IR -> Update-IR loads "0...01", IDCODE), Update-IR ->
--  Select-DR-Scan, DR scan of IDCODE in two halves through Pause-DR,
--  Update-DR -> Select-DR-Scan, zero-length DR scan (Capture-DR ->
--  Exit1-DR), then a BFM scan from Run-Test/Idle.
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

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_pause_pkg is

  -- Pause-IR / Pause-DR, Exit2, zero-length scans
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_pause_pkg;

package body tb_jtag_pause_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    constant W           : positive := cfg.ir_width;
    constant H           : positive := W/2;
    variable v_tdo       : std_logic;
    variable v_tms       : std_logic;
    variable v_ir        : std_logic_vector(W-1 downto 0);
    variable v_dr        : std_logic_vector(32-1 downto 0);
    variable v_idcode_ir : std_logic_vector(W-1 downto 0);

    -- One TCK cycle, TDO ignored
    procedure clk(tms : std_logic) is
    begin
      tb_clock(tms, '0', v_tdo, jtag_if, cfg);
    end procedure clk;
  begin
    v_idcode_ir := std_logic_vector(to_unsigned(1, W));

    -- IR scan of BYPASS (all ones) with two passes through Pause-IR
    clk('1'); clk('1'); clk('0'); clk('0');                       -- Select-DR, Select-IR, Capture-IR, Shift-IR
    for i in 0 to W-1 loop
      v_tms := '1' when i = H-1 or i = W-1 else '0';
      tb_clock(v_tms, '1', v_ir(i), jtag_if, cfg);
      if i = H-1
      then
        clk('0'); clk('0'); clk('1'); clk('0');                   -- Pause-IR, Pause-IR, Exit2-IR, Shift-IR
      end if;
    end loop;
    clk('0'); clk('1'); clk('1'); clk('0');                       -- Pause-IR, Exit2-IR, Update-IR, Run-Test/Idle
    check_value(v_ir, v_idcode_ir, ERROR, "Capture-IR value shifted out through Pause-IR", C_TB_SCOPE);
    check_value(tb_rsp.ir(W-1 downto 0), (W-1 downto 0 => '1'), ERROR, "ir_o = BYPASS after the IR scan through Pause-IR", C_TB_SCOPE);

    -- Zero-length IR scan, then Update-IR -> Select-DR-Scan
    clk('1'); clk('1'); clk('0'); clk('1'); clk('1');             -- Select-DR, Select-IR, Capture-IR, Exit1-IR, Update-IR
    clk('1');                                                     -- Select-DR (ir_o updated on the falling edge)
    check_value(tb_rsp.ir(W-1 downto 0), v_idcode_ir, ERROR, "ir_o = IDCODE after a zero-length IR scan", C_TB_SCOPE);

    -- DR scan of IDCODE in two halves through Pause-DR
    clk('0'); clk('0');                                           -- Capture-DR, Shift-DR
    for i in 0 to 32-1 loop
      v_tms := '1' when i = 15 or i = 31 else '0';
      tb_clock(v_tms, '0', v_dr(i), jtag_if, cfg);
      if i = 15
      then
        clk('0'); clk('0'); clk('1'); clk('0');                   -- Pause-DR, Pause-DR, Exit2-DR, Shift-DR
      end if;
    end loop;
    clk('0'); clk('1'); clk('1');                                 -- Pause-DR, Exit2-DR, Update-DR
    check_value(v_dr, C_IDCODE, ERROR, "IDCODE shifted out in two halves through Pause-DR", C_TB_SCOPE);

    -- Update-DR -> Select-DR-Scan, zero-length DR scan, Run-Test/Idle
    clk('1'); clk('0'); clk('1'); clk('1'); clk('0');             -- Select-DR, Capture-DR, Exit1-DR, Update-DR, Run-Test/Idle
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE scan by the BFM from Run-Test/Idle", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_pause_pkg;

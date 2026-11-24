-------------------------------------------------------------------------------
-- Title      : tb_bitbang_bfm_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants, types and helpers shared by the scenarios of tb_bitbang :
--  configuration of the TAP and of the TDR of the testbench, records between
--  the scenarios and the testbench (tb_req_t : stimuli, tb_rsp_t : outputs
--  of the DUT and answers collected by the monitor), and one call of the
--  remote_bitbang BFM rbb_bfm_pkg of asylum-verification-uvvm per helper
--  (the bytes OpenOCD 0.12 sends) : one command (tb_send, tb_write : on
--  s_axis, or through the UART with tb_req.uart), TMS sequence (tb_tms),
--  TDO read (tb_read), IR scan (tb_write_ir), DR scan (tb_scan_dr,
--  tb_check_dr).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-24  1.2.0    mrosiere Byte encoder replaced by rbb_bfm_pkg
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_uart;
use     bitvis_vip_uart.uart_bfm_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;
use     asylum_uvvm.rbb_bfm_pkg.all;

package tb_bitbang_bfm_pkg is

  constant C_TB_SCOPE     : string   := "TB_BITBANG";    -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)

  constant C_CLK_PERIOD   : time     := 10 ns;
  constant C_TIMEOUT      : time     := 1 ms;            -- Wait of s_axis_tready and of the answers to 'R'

  -- TAP of the testbench : IR of 5 bits, IDCODE ("00001"), BYPASS (all
  -- ones), one jtag_tdr_inout of 8 bits selected by C_IR_TDR
  constant C_IDCODE       : std_logic_vector(32-1 downto 0) := x"4A7C0E35";
  constant C_IR_WIDTH     : positive := 5;
  constant C_IR_IDCODE    : natural  := 1;
  constant C_IR_TDR       : natural  := 2;
  constant C_IR_BYPASS    : natural  := 2**C_IR_WIDTH-1;
  constant C_TDR_WIDTH    : positive := 8;

  -- UART of the scenario uart : 8 data bits, no parity, one stop bit, 16
  -- clock cycles per bit (cfg_baud_tick_cnt_max_i of uart_baud_rate_gen)
  constant C_UART_CNT_MAX : natural  := 15;
  constant C_UART_BIT     : time     := (C_UART_CNT_MAX+1)*C_CLK_PERIOD;
  constant C_UART_CONFIG  : t_uart_bfm_config;

  -- remote_bitbang BFM : commands on s_axis (C_RBB_CONFIG) or through the
  -- UART (C_RBB_UART_CONFIG) ; the TAP alone in the chain (C_JTAG_CONFIG)
  constant C_RBB_CONFIG      : t_rbb_bfm_config;
  constant C_RBB_UART_CONFIG : t_rbb_bfm_config;
  constant C_JTAG_CONFIG     : t_jtag_bfm_config;

  -- Stimuli of the scenarios
  type tb_req_t is record
    rbb             : t_rbb_if;                                     -- Commands to the DUT (s_axis), or to the UART (rbb.tx)
    m_tready        : std_logic;                                    -- Answers taken from the DUT
    tdr_data        : std_logic_vector(C_TDR_WIDTH-1 downto 0);     -- data_i of the TDR
    uart            : boolean;                                      -- true : commands and answers through the UART
  end record tb_req_t;

  constant C_TB_REQ_IDLE  : tb_req_t := (rbb      => init_rbb_if_signals,
                                         m_tready => '1',
                                         tdr_data => (others => '0'),
                                         uart     => false);

  -- Outputs of the DUT, of the TAP and of the monitor
  type tb_rsp_t is record
    s_tready        : std_logic;
    m_tdata         : std_logic_vector(8-1 downto 0);
    m_tvalid        : std_logic;
    pins            : std_logic_vector(3-1 downto 0);               -- TCK, TMS, TDI
    trst_n          : std_logic;
    srst            : std_logic;
    blink           : std_logic;
    tlr             : std_logic;                                    -- tlr_o of the TAP
    ir              : std_logic_vector(C_IR_WIDTH-1 downto 0);      -- ir_o of the TAP
    tdr_data        : std_logic_vector(C_TDR_WIDTH-1 downto 0);     -- data_o of the TDR
    answers         : t_rbb_answers;                                -- Answers to 'R' (count since the start of the simulation)
  end record tb_rsp_t;

  -- Byte of a character
  function to_byte(cmd : character) return std_logic_vector;

  -- One command : byte on s_axis, returns after the handshake (the outputs
  -- of the DUT change one delta cycle later) ; with tb_req.uart, UART frame,
  -- returns after the stop bit
  procedure tb_send(
    constant cmd          : in    character;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- '0'..'7' : write TCK, TMS, TDI
  procedure tb_write(
    constant tck          : in    std_logic;
    constant tms          : in    std_logic;
    constant tdi          : in    std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- 'R', then wait for its answer
  procedure tb_read(
    variable tdo          : out   std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- TCK cycles with the TMS sequence (left first), then TCK low
  procedure tb_tms(
    constant tms          : in    std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- DR scan from Run-Test/Idle back to Run-Test/Idle ; data_out : the
  -- answers to 'R' (TDO)
  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- IR scan of opcode, then check of ir_o (the Capture-IR value "00001" is
  -- checked by jtag_ir_capture_monitor in tb_bitbang)
  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- DR scan of data, then check of the bits shifted out
  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

end package tb_bitbang_bfm_pkg;

package body tb_bitbang_bfm_pkg is

  function uart_config return t_uart_bfm_config is
    variable v_config : t_uart_bfm_config := C_UART_BFM_CONFIG_DEFAULT;
  begin
    v_config.bit_time := C_UART_BIT;
    v_config.parity   := PARITY_NONE;
    return v_config;
  end function uart_config;

  constant C_UART_CONFIG  : t_uart_bfm_config := uart_config;

  function rbb_config(uart : boolean) return t_rbb_bfm_config is
    variable v_config : t_rbb_bfm_config := C_RBB_BFM_CONFIG_DEFAULT;
  begin
    v_config.uart        := uart;
    v_config.uart_config := C_UART_CONFIG;
    v_config.timeout     := C_TIMEOUT;
    return v_config;
  end function rbb_config;

  constant C_RBB_CONFIG      : t_rbb_bfm_config := rbb_config(false);
  constant C_RBB_UART_CONFIG : t_rbb_bfm_config := rbb_config(true);

  function jtag_config return t_jtag_bfm_config is
    variable v_config : t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT;
  begin
    v_config.ir_width := C_IR_WIDTH;
    return v_config;
  end function jtag_config;

  constant C_JTAG_CONFIG     : t_jtag_bfm_config := jtag_config;

  -- Configuration of the BFM for the transport of the scenario
  function tb_config(tb_req : tb_req_t) return t_rbb_bfm_config is
  begin
    if tb_req.uart
    then
      return C_RBB_UART_CONFIG;
    end if;
    return C_RBB_CONFIG;
  end function tb_config;

  function to_byte(cmd : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(cmd), 8));
  end function to_byte;

  procedure tb_send(
    constant cmd          : in    character;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    -- ext_proc_call : no log per byte (the ignored bytes are not printable)
    rbb_command(cmd           => (1 => cmd),
                msg           => "Command x" & to_hstring(to_byte(cmd)),
                clk           => clk,
                rbb_if        => tb_req.rbb,
                scope         => C_TB_SCOPE,
                config        => tb_config(tb_req),
                ext_proc_call => "tb_send");
  end procedure tb_send;

  procedure tb_write(
    constant tck          : in    std_logic;
    constant tms          : in    std_logic;
    constant tdi          : in    std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    tb_send(rbb_write_cmd(tck, tms, tdi)(1), tb_req, tb_rsp, clk);
  end procedure tb_write;

  procedure tb_read(
    variable tdo          : out   std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    rbb_read(tdo          => tdo,
             msg          => "TDO",
             clk          => clk,
             rbb_if       => tb_req.rbb,
             answers      => tb_rsp.answers,
             scope        => C_TB_SCOPE,
             config       => tb_config(tb_req));
  end procedure tb_read;

  procedure tb_tms(
    constant tms          : in    std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    rbb_tms(tms           => tms,
            msg           => "TMS",
            clk           => clk,
            rbb_if        => tb_req.rbb,
            scope         => C_TB_SCOPE,
            config        => tb_config(tb_req));
  end procedure tb_tms;

  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    rbb_scan_dr(data_value  => data,
                data_out    => data_out,
                msg         => "DR scan",
                clk         => clk,
                rbb_if      => tb_req.rbb,
                answers     => tb_rsp.answers,
                scope       => C_TB_SCOPE,
                config      => tb_config(tb_req),
                jtag_config => C_JTAG_CONFIG);
  end procedure tb_scan_dr;

  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
    constant C_OPCODE     : std_logic_vector(C_IR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(opcode, C_IR_WIDTH));
  begin
    rbb_write_ir(ir_value    => C_OPCODE,
                 msg         => "IR scan " & msg,
                 clk         => clk,
                 rbb_if      => tb_req.rbb,
                 answers     => tb_rsp.answers,
                 scope       => C_TB_SCOPE,
                 config      => tb_config(tb_req),
                 jtag_config => C_JTAG_CONFIG);
    check_value(tb_rsp.ir, C_OPCODE, ERROR, "ir_o after the IR scan " & msg, C_TB_SCOPE);
  end procedure tb_write_ir;

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    rbb_check_dr(data_value  => data,
                 data_exp    => data_exp,
                 msg         => "DR scan read by 'R' : " & msg,
                 clk         => clk,
                 rbb_if      => tb_req.rbb,
                 answers     => tb_rsp.answers,
                 scope       => C_TB_SCOPE,
                 config      => tb_config(tb_req),
                 jtag_config => C_JTAG_CONFIG);
  end procedure tb_check_dr;

end package body tb_bitbang_bfm_pkg;

-------------------------------------------------------------------------------
-- Title      : rbb_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : rbb_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  GHDL VHPIDIRECT binding of rbb_server.c (built as ./librbb.so in the
--  simulation directory by the pre_build hook of sim_openocd) : bytes
--  between OpenOCD (remote_bitbang adapter, TCP) and the simulation.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

package rbb_pkg is

  -- Values of rbb_recv that are not a byte
  constant RBB_NONE   : integer := -1;                            -- No byte yet
  constant RBB_CLOSED : integer := -2;                            -- OpenOCD closed the connection

  -- Next byte sent by OpenOCD (the first call waits for OpenOCD)
  impure function rbb_recv return integer;
  attribute foreign of rbb_recv : function is "VHPIDIRECT ./librbb.so rbb_recv";

  -- One byte to OpenOCD
  procedure rbb_send(c : integer);
  attribute foreign of rbb_send : procedure is "VHPIDIRECT ./librbb.so rbb_send";

end package rbb_pkg;

package body rbb_pkg is

  impure function rbb_recv return integer is
  begin
    report "rbb_recv : VHPIDIRECT function not bound (./librbb.so)" severity failure;
    return RBB_CLOSED;
  end function rbb_recv;

  procedure rbb_send(c : integer) is
  begin
    report "rbb_send : VHPIDIRECT procedure not bound (./librbb.so)" severity failure;
  end procedure rbb_send;

end package body rbb_pkg;

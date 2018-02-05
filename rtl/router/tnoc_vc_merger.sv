module tnoc_vc_merger
  import  tnoc_config_pkg::*;
#(
  parameter   tnoc_config CONFIG    = TNOC_DEFAULT_CONFIG,
  localparam  int         CHANNELS  = CONFIG.virtual_channels
)(
  input logic                 clk,
  input logic                 rst_n,
  input logic [CHANNELS-1:0]  i_vc_grant,
  tnoc_flit_if.target         flit_in_if[CHANNELS],
  tnoc_flit_if.initiator      flit_out_if
);
  tnoc_flit_if #(CONFIG)  flit_fifo_if();

  tnoc_vc_mux #(
    .CONFIG   (CONFIG )
  ) u_vc_mux (
    .i_vc_grant   (i_vc_grant   ),
    .flit_in_if   (flit_in_if   ),
    .flit_out_if  (flit_fifo_if )
  );

  tnoc_flit_if_fifo #(
    .CONFIG (CONFIG ),
    .DEPTH  (2      )
  ) u_output_fifo (
    .clk            (clk          ),
    .rst_n          (rst_n        ),
    .i_clear        ('0           ),
    .o_empty        (),
    .o_almost_full  (),
    .o_full         (),
    .flit_in_if     (flit_fifo_if ),
    .flit_out_if    (flit_out_if  )
  );
endmodule
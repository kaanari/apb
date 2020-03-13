// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// APB Read-Write Registers
// This module exposes a number of registers (provided on the `reg_i` input) writable on an
// APB interface.  It responds to accesses that are out of range with a slave error.
`include "common_cells/registers.svh"

module apb_rw_regs #(
  parameter int unsigned NoRegs = 0,
  parameter int unsigned AddrWidth = 32'd0,
  parameter int unsigned DataWidth = 32'd0,
  // DEPENDENT PARAMETERS DO NOT OVERWRITE!
  parameter int unsigned StrbWidth = cf_math_pkg::ceil_div(DataWidth, 8),
  parameter type         addr_t    = logic[AddrWidth-1:0],
  parameter type         data_t    = logic[DataWidth-1:0],
  parameter type         strb_t    = logic[StrbWidth-1:0]
) (
  // APB Interface
  input  logic           pclk_i,
  input  logic           preset_ni,
  input  addr_t          paddr_i,
  input  apb_pkg::prot_t pprot_i,
  input  logic           psel_i,
  input  logic           penable_i,
  input  logic           pwrite_i,
  input  data_t          pwdata_i,
  input  strb_t          pstrb_i,
  output logic           pready_o,
  output data_t          prdata_o,
  output logic           pslverr_o,

  // Register Interface
  input  data_t [NoRegs-1:0] init_i,
  output data_t [NoRegs-1:0] q_o
);
  // if StrbWidth = 1 we want Word Offset = 0
  localparam int unsigned WordOffset = $clog2(StrbWidth);

  data_t [NoRegs-1:0] reg_d,      reg_q;
  logic               reg_update;

  always_comb begin
    reg_d      = reg_q;
    reg_update = 1'b0;
    prdata_o   = data_t'(32'h0BAD_B10C);
    pslverr_o  = apb_pkg::RESP_OKAY;
    if (psel_i) begin
      automatic logic [AddrWidth-WordOffset-1:0] word_addr = paddr_i >> WordOffset;
      if (word_addr >= NoRegs) begin
        // Error response to accesses that are out of range
        pslverr_o = apb_pkg::RESP_SLVERR;
      end else begin
        if (pwrite_i) begin
          for (int unsigned i = 0; i < DataWidth; i++) begin
            if (pstrb_i[i/8]) begin
              reg_d[word_addr][i] = pwdata_i[i];
            end
          end
          reg_update = |pstrb_i; // only update register when a write strobe is set
        end else begin
          prdata_o = reg_q[word_addr];
        end
      end
    end
  end
  assign pready_o = psel_i & penable_i;

  assign q_o = reg_q;

  `FFLARN(reg_q, reg_d, reg_update, init_i, pclk_i, preset_ni)

// Validate parameters.
// pragma translate_off
`ifndef VERILATOR
  initial begin: p_assertions
    assert (NoRegs    > 0)          else $fatal(1, "The number of registers must be at least 1!");
    assert (AddrWidth > WordOffset) else $fatal(1, "AddrWidth is not wide enough!");
    assert (DataWidth > 0)          else $fatal(1, "DataWidth has to be > 0!");
  end
`endif
// pragma translate_on

endmodule

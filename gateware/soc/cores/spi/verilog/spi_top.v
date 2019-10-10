/////////////////////////////////////////////////////////////////////
////                                                             ////
////  OpenCores                    MC68HC11E based SPI interface ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2002 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////


//
// Motorola MC68HC11E based SPI interface, with large fifo.
//
// Currently only MASTER mode is supported
//

module zsipos_spi #(
  parameter SS_WIDTH = 1
)(
  // 8bit WISHBONE bus slave interface
  input  wire       clk_i,         // clock
  input  wire       rst_i,         // reset (synchronous active high)
  input  wire       cyc_i,         // cycle
  input  wire       stb_i,         // strobe
  input  wire [2:0] adr_i,         // address
  input  wire       we_i,          // write enable
  input  wire [7:0] dat_i,         // data input
  output reg  [7:0] dat_o,         // data output
  output reg        ack_o,         // normal bus termination
  output reg        inta_o,        // interrupt output

  // SPI port
  output reg        sck_o,         // serial clock output
  output [SS_WIDTH-1:0] ss_o,      // slave select (active low)
  output wire       mosi_o,        // MasterOut SlaveIN
  input  wire       miso_i         // MasterIn SlaveOut
);

    reg  [7:0]          spcr;       // Serial Peripheral Control   Register ('HC11 naming)
    wire [7:0]          spsr;       // Serial Peripheral Status    Register ('HC11 naming)
    reg  [7:0]          sper;       // Serial Peripheral Extension Register
    reg  [7:0]          treg;       // Transmit Register
    reg  [SS_WIDTH-1:0] ss_r;       // Slave Select Register

    assign mosi_o = treg[7];

// fifo signals
    wire [7:0] rfdout;
    reg        wfre, rfwe;
    wire       rfre, rffull, rfempty;
    wire [7:0] wfdout;
    wire       wfwe, wffull, wfempty;

// misc signals
    wire      tirq;     // transfer interrupt (selected number of transfers done)
    wire      wfov;     // write fifo overrun (writing while fifo full)
    reg [1:0] state;    // statemachine state
    reg [2:0] bcnt;

// count number of transfers (for interrupt generation)
    reg [7:0] icnt; // interrupt on transfer count
    reg [7:0] tcnt; // transfer count

// Wishbone interface
    wire wb_acc = cyc_i & stb_i;       // WISHBONE access
    wire wb_wr  = wb_acc & we_i;       // WISHBONE write access

    // dat_i
    always @(posedge clk_i)
        if (rst_i)
            begin
                spcr <= 8'h10;  // set master bit
                sper <= 8'h00;
                ss_r <= 0;
            end
        else if (wb_wr)
            begin
                if (adr_i == 3'd0)
                    spcr <= dat_i | 8'h10; // always set master bit

                if (adr_i == 3'd3)
                    sper <= dat_i;

                if (adr_i == 3'd4)
                    ss_r <= dat_i[SS_WIDTH-1:0];

                if (adr_i == 3'd5)
                    icnt <= dat_i;
            end

    // slave select (active low)
    assign ss_o = ~ss_r;

    // write fifo
    assign wfwe = wb_acc & (adr_i == 3'd2) & ack_o &  we_i;
    assign wfov = wfwe & wffull;

    // dat_o
    always @(posedge clk_i)
        case(adr_i) // synopsys full_case parallel_case
            3'd0 : dat_o <= spcr;
            3'd1 : dat_o <= spsr;
            3'd2 : dat_o <= rfdout;
            3'd3 : dat_o <= sper;
            3'd4 : dat_o <= {{ (8-SS_WIDTH){1'b0} }, ss_r};
            3'd5 : dat_o <= icnt;
            3'd6 : dat_o <= tcnt;
        endcase

// read fifo
    assign rfre = wb_acc & (adr_i == 3'd2) & ack_o & ~we_i;

// ack_o
    always @(posedge clk_i)
        if (rst_i)
            ack_o <= 1'b0;
        else
            ack_o <= wb_acc & !ack_o;

// decode Serial Peripheral Control Register
    wire       spie = spcr[7];   // Interrupt enable bit
    wire       spe  = spcr[6];   // System Enable bit
    wire       dwom = spcr[5];   // Port D Wired-OR Mode Bit
    wire       mstr = spcr[4];   // Master Mode Select Bit
    wire       cpol = spcr[3];   // Clock Polarity Bit
    wire       cpha = spcr[2];   // Clock Phase Bit
    wire [1:0] spr  = spcr[1:0]; // Clock Rate Select Bits

// decode Serial Peripheral Extension Register
    wire [1:0] spre = sper[1:0]; // extended clock rate select

    wire [3:0] espr = {spre, spr};

// generate status register
    wire wr_spsr = wb_wr & (adr_i == 3'd1);

    reg wcol;
    always @(posedge clk_i)
        if (~spe | rst_i)
            wcol <= 1'b0;
        else
            wcol <= (wfov | wcol) & ~(wr_spsr & dat_i[6]);

    reg spif;

    assign spsr[7]   = spif;
    assign spsr[6]   = wcol;
    assign spsr[5:4] = 2'b00;
    assign spsr[3]   = wffull;
    assign spsr[2]   = wfempty;
    assign spsr[1]   = rffull;
    assign spsr[0]   = rfempty;


// generate IRQ output (inta_o)
    always @(posedge clk_i)
        inta_o <= spif & spie;

// hookup read/write buffer fifo
    zsipos_spififo #(8)
    rfifo(
        .clk   ( clk_i   ),
        .rst   ( ~rst_i  ),
        .clr   ( ~spe    ),
        .din   ( treg    ),
        .we    ( rfwe    ),
        .dout  ( rfdout  ),
        .re    ( rfre    ),
        .full  ( rffull  ),
        .empty ( rfempty )
    ),
    wfifo(
        .clk   ( clk_i   ),
        .rst   ( ~rst_i  ),
        .clr   ( ~spe    ),
        .din   ( dat_i   ),
        .we    ( wfwe    ),
        .dout  ( wfdout  ),
        .re    ( wfre    ),
        .full  ( wffull  ),
        .empty ( wfempty )
    );

    //
    // generate clk divider
    reg [11:0] clkcnt;
    always @(posedge clk_i)
        if(spe & (|clkcnt & |state))
            clkcnt <= clkcnt - 11'h1;
        else
            case (espr) // synopsys full_case parallel_case
                4'b0000: clkcnt <= 12'h0;   // 2   -- original M68HC11 coding
                4'b0001: clkcnt <= 12'h1;   // 4   -- original M68HC11 coding
                4'b0010: clkcnt <= 12'h3;   // 16  -- original M68HC11 coding
                4'b0011: clkcnt <= 12'hf;   // 32  -- original M68HC11 coding
                4'b0100: clkcnt <= 12'h1f;  // 8
                4'b0101: clkcnt <= 12'h7;   // 64
                4'b0110: clkcnt <= 12'h3f;  // 128
                4'b0111: clkcnt <= 12'h7f;  // 256
                4'b1000: clkcnt <= 12'hff;  // 512
                4'b1001: clkcnt <= 12'h1ff; // 1024
                4'b1010: clkcnt <= 12'h3ff; // 2048
                4'b1011: clkcnt <= 12'h7ff; // 4096
            endcase

// generate clock enable signal
    wire ena = !clkcnt;
    reg  ibit;

// transfer statemachine
    always @(posedge clk_i)
        if (~spe | rst_i)  begin
            state <= 2'b00; // idle
            bcnt  <= 3'h0;
            treg  <= 1'b0;
            wfre  <= 1'b0;
            rfwe  <= 1'b0;
            sck_o <= 1'b0;
            spif  <= 1'b0;
        end
        else begin

            if (wb_wr & adr_i == 3'd5)
                tcnt <= dat_i;

            if (wr_spsr & dat_i[7])
                spif <= 0;

            wfre <= 1'b0;
            rfwe <= 1'b0;

            case (state)
                2'b00: // idle state
                    begin
                        bcnt  <= 3'h7;   // set transfer counter
                        treg  <= wfdout; // load transfer register
                        sck_o <= cpol;   // set sck

                        if (~wfempty) begin
                            wfre  <= 1'b1;
                            state <= 2'b01;
                            if (cpha) sck_o <= ~sck_o;
                        end
                    end

                2'b01: // clock phase2, next data
                    if (ena) begin
                        ibit  <= miso_i;
                        sck_o <= ~sck_o;
                        state <= 2'b11;
                    end

                2'b11: // clock phase1
                    if (ena) begin
                        treg <= {treg[6:0], ibit};
                        bcnt <= bcnt - 3'h1;
                        if (!bcnt) begin
                            if (tcnt)
                                tcnt <= tcnt - 8'h1;
                            else
                                spif = 1'b1;
                            state <= 2'b00;
                            sck_o <= cpol;
                            rfwe  <= 1'b1;
                        end
                        else begin
                            state <= 2'b01;
                            sck_o <= ~sck_o;
                        end
                    end
            endcase
        end


endmodule : zsipos_spi


/////////////////////////////////////////////////////////////////////
////                                                             ////
//// FIFO 1024 entries deep                                      ////
////                                                             ////
//// Authors: Rudolf Usselmann, Richard Herveille                ////
////          rudi@asics.ws     richard@asics.ws                 ////
////                                                             ////
////                                                             ////
//// Download from: http://www.opencores.org/projects/sasc       ////
////                http://www.opencores.org/projects/simple_spi ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2000-2002 Rudolf Usselmann, Richard Herveille ////
////                         www.asics.ws                        ////
////                         rudi@asics.ws, richard@asics.ws     ////
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

module zsipos_spififo(clk, rst, clr,  din, we, dout, re, full, empty);

    parameter dw = 8;

    input             clk, rst;
    input             clr;
    input   [dw:1]    din;
    input             we;
    output  [dw:1]    dout;
    input             re;
    output            full, empty;


////////////////////////////////////////////////////////////////////
//
// Local Wires
//

    reg     [dw:1]  mem[0:1023];
    reg     [10:0]  wp;
    reg     [10:0]  rp;
    wire    [10:0]  wp_p1;
    wire    [10:0]  rp_p1;
    wire            full, empty;
    reg             gb;

////////////////////////////////////////////////////////////////////
//
// Misc Logic
//

    always @(posedge clk or negedge rst)
        if(!rst)     wp <= 8'h0;
        else if(clr) wp <= 8'h0;
        else if(we)  wp <= wp_p1;

    assign wp_p1 = wp + 8'h1;

    always @(posedge clk or negedge rst)
        if(!rst)     rp <= 8'h0;
        else if(clr) rp <= 8'h0;
        else if(re)  rp <= rp_p1;

    assign rp_p1 = rp + 8'h1;

// Fifo Output
    assign  dout = mem[ rp ];

// Fifo Input
    always @(posedge clk)
        if(we) mem[ wp ] <=  din;

// Status
    assign empty = (wp == rp) & !gb;
    assign full  = (wp == rp) &  gb;

// Guard Bit ...
    always @(posedge clk)
        if(!rst)                    gb <= 1'b0;
        else if(clr)                gb <= 1'b0;
        else if((wp_p1 == rp) & we) gb <= 1'b1;
        else if(re)                 gb <= 1'b0;

endmodule

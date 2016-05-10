import DDR3Controller::*;
import AuroraExtImport::*;
import AuroraCommon::*;
import Vector::*;

interface Top_Pins;
   `ifndef BSIM
   interface Aurora_Pins#(4) aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1;
         
   interface Vector#(AuroraExtPerQuad, Aurora_Pins#(1)) aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119;
   //interface Aurora_Clock_Pins aurora_quad117;
// `ifndef BSIM
//    interface DDR3_Pins_VC707 pins_ddr3;
// `endif

   interface DDR3_Pins_VC707_1GB pins_ddr3;
   `endif
endinterface

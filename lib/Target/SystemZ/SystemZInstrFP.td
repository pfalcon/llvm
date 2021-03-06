//==- SystemZInstrFP.td - Floating-point SystemZ instructions --*- tblgen-*-==//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Select instructions
//===----------------------------------------------------------------------===//

// C's ?: operator for floating-point operands.
def SelectF32  : SelectWrapper<FP32>;
def SelectF64  : SelectWrapper<FP64>;
def SelectF128 : SelectWrapper<FP128>;

defm CondStoreF32 : CondStores<FP32, nonvolatile_store,
                               nonvolatile_load, bdxaddr20only>;
defm CondStoreF64 : CondStores<FP64, nonvolatile_store,
                               nonvolatile_load, bdxaddr20only>;

//===----------------------------------------------------------------------===//
// Move instructions
//===----------------------------------------------------------------------===//

// Load zero.
let neverHasSideEffects = 1, isAsCheapAsAMove = 1, isMoveImm = 1 in {
  def LZER : InherentRRE<"lzer", 0xB374, FP32,  (fpimm0)>;
  def LZDR : InherentRRE<"lzdr", 0xB375, FP64,  (fpimm0)>;
  def LZXR : InherentRRE<"lzxr", 0xB376, FP128, (fpimm0)>;
}

// Moves between two floating-point registers.
let neverHasSideEffects = 1 in {
  def LER : UnaryRR <"ler", 0x38,   null_frag, FP32,  FP32>;
  def LDR : UnaryRR <"ldr", 0x28,   null_frag, FP64,  FP64>;
  def LXR : UnaryRRE<"lxr", 0xB365, null_frag, FP128, FP128>;
}

// Moves between 64-bit integer and floating-point registers.
def LGDR : UnaryRRE<"lgdr", 0xB3CD, bitconvert, GR64, FP64>;
def LDGR : UnaryRRE<"ldgr", 0xB3C1, bitconvert, FP64, GR64>;

// fcopysign with an FP32 result.
let isCodeGenOnly = 1 in {
  def CPSDRss : BinaryRRF<"cpsdr", 0xB372, fcopysign, FP32, FP32>;
  def CPSDRsd : BinaryRRF<"cpsdr", 0xB372, fcopysign, FP32, FP64>;
}

// The sign of an FP128 is in the high register.
def : Pat<(fcopysign FP32:$src1, FP128:$src2),
          (CPSDRsd FP32:$src1, (EXTRACT_SUBREG FP128:$src2, subreg_high))>;

// fcopysign with an FP64 result.
let isCodeGenOnly = 1 in
  def CPSDRds : BinaryRRF<"cpsdr", 0xB372, fcopysign, FP64, FP32>;
def CPSDRdd : BinaryRRF<"cpsdr", 0xB372, fcopysign, FP64, FP64>;

// The sign of an FP128 is in the high register.
def : Pat<(fcopysign FP64:$src1, FP128:$src2),
          (CPSDRdd FP64:$src1, (EXTRACT_SUBREG FP128:$src2, subreg_high))>;

// fcopysign with an FP128 result.  Use "upper" as the high half and leave
// the low half as-is.
class CopySign128<RegisterOperand cls, dag upper>
  : Pat<(fcopysign FP128:$src1, cls:$src2),
        (INSERT_SUBREG FP128:$src1, upper, subreg_high)>;

def : CopySign128<FP32,  (CPSDRds (EXTRACT_SUBREG FP128:$src1, subreg_high),
                                  FP32:$src2)>;
def : CopySign128<FP64,  (CPSDRdd (EXTRACT_SUBREG FP128:$src1, subreg_high),
                                  FP64:$src2)>;
def : CopySign128<FP128, (CPSDRdd (EXTRACT_SUBREG FP128:$src1, subreg_high),
                                  (EXTRACT_SUBREG FP128:$src2, subreg_high))>;

//===----------------------------------------------------------------------===//
// Load instructions
//===----------------------------------------------------------------------===//

let canFoldAsLoad = 1, SimpleBDXLoad = 1 in {
  defm LE : UnaryRXPair<"le", 0x78, 0xED64, load, FP32>;
  defm LD : UnaryRXPair<"ld", 0x68, 0xED65, load, FP64>;

  // These instructions are split after register allocation, so we don't
  // want a custom inserter.
  let Has20BitOffset = 1, HasIndex = 1, Is128Bit = 1 in {
    def LX : Pseudo<(outs FP128:$dst), (ins bdxaddr20only128:$src),
                     [(set FP128:$dst, (load bdxaddr20only128:$src))]>;
  }
}

//===----------------------------------------------------------------------===//
// Store instructions
//===----------------------------------------------------------------------===//

let SimpleBDXStore = 1 in {
  defm STE : StoreRXPair<"ste", 0x70, 0xED66, store, FP32>;
  defm STD : StoreRXPair<"std", 0x60, 0xED67, store, FP64>;

  // These instructions are split after register allocation, so we don't
  // want a custom inserter.
  let Has20BitOffset = 1, HasIndex = 1, Is128Bit = 1 in {
    def STX : Pseudo<(outs), (ins FP128:$src, bdxaddr20only128:$dst),
                     [(store FP128:$src, bdxaddr20only128:$dst)]>;
  }
}

//===----------------------------------------------------------------------===//
// Conversion instructions
//===----------------------------------------------------------------------===//

// Convert floating-point values to narrower representations, rounding
// according to the current mode.  The destination of LEXBR and LDXBR
// is a 128-bit value, but only the first register of the pair is used.
def LEDBR : UnaryRRE<"ledbr", 0xB344, fround,    FP32,  FP64>;
def LEXBR : UnaryRRE<"lexbr", 0xB346, null_frag, FP128, FP128>;
def LDXBR : UnaryRRE<"ldxbr", 0xB345, null_frag, FP128, FP128>;

def : Pat<(f32 (fround FP128:$src)),
          (EXTRACT_SUBREG (LEXBR FP128:$src), subreg_32bit)>;
def : Pat<(f64 (fround FP128:$src)),
          (EXTRACT_SUBREG (LDXBR FP128:$src), subreg_high)>;

// Extend register floating-point values to wider representations.
def LDEBR : UnaryRRE<"ldebr", 0xB304, fextend, FP64,  FP32>;
def LXEBR : UnaryRRE<"lxebr", 0xB306, fextend, FP128, FP32>;
def LXDBR : UnaryRRE<"lxdbr", 0xB305, fextend, FP128, FP64>;

// Extend memory floating-point values to wider representations.
def LDEB : UnaryRXE<"ldeb", 0xED04, extloadf32, FP64>;
def LXEB : UnaryRXE<"lxeb", 0xED06, extloadf32, FP128>;
def LXDB : UnaryRXE<"lxdb", 0xED05, extloadf64, FP128>;

// Convert a signed integer register value to a floating-point one.
let Defs = [CC] in {
  def CEFBR : UnaryRRE<"cefbr", 0xB394, sint_to_fp, FP32,  GR32>;
  def CDFBR : UnaryRRE<"cdfbr", 0xB395, sint_to_fp, FP64,  GR32>;
  def CXFBR : UnaryRRE<"cxfbr", 0xB396, sint_to_fp, FP128, GR32>;

  def CEGBR : UnaryRRE<"cegbr", 0xB3A4, sint_to_fp, FP32,  GR64>;
  def CDGBR : UnaryRRE<"cdgbr", 0xB3A5, sint_to_fp, FP64,  GR64>;
  def CXGBR : UnaryRRE<"cxgbr", 0xB3A6, sint_to_fp, FP128, GR64>;
}

// Convert a floating-point register value to a signed integer value,
// with the second operand (modifier M3) specifying the rounding mode.
let Defs = [CC] in {
  def CFEBR : UnaryRRF<"cfebr", 0xB398, GR32, FP32>;
  def CFDBR : UnaryRRF<"cfdbr", 0xB399, GR32, FP64>;
  def CFXBR : UnaryRRF<"cfxbr", 0xB39A, GR32, FP128>;

  def CGEBR : UnaryRRF<"cgebr", 0xB3A8, GR64, FP32>;
  def CGDBR : UnaryRRF<"cgdbr", 0xB3A9, GR64, FP64>;
  def CGXBR : UnaryRRF<"cgxbr", 0xB3AA, GR64, FP128>;
}

// fp_to_sint always rounds towards zero, which is modifier value 5.
def : Pat<(i32 (fp_to_sint FP32:$src)),  (CFEBR 5, FP32:$src)>;
def : Pat<(i32 (fp_to_sint FP64:$src)),  (CFDBR 5, FP64:$src)>;
def : Pat<(i32 (fp_to_sint FP128:$src)), (CFXBR 5, FP128:$src)>;

def : Pat<(i64 (fp_to_sint FP32:$src)),  (CGEBR 5, FP32:$src)>;
def : Pat<(i64 (fp_to_sint FP64:$src)),  (CGDBR 5, FP64:$src)>;
def : Pat<(i64 (fp_to_sint FP128:$src)), (CGXBR 5, FP128:$src)>;

//===----------------------------------------------------------------------===//
// Unary arithmetic
//===----------------------------------------------------------------------===//

// Negation (Load Complement).
let Defs = [CC] in {
  def LCEBR : UnaryRRE<"lcebr", 0xB303, fneg, FP32,  FP32>;
  def LCDBR : UnaryRRE<"lcdbr", 0xB313, fneg, FP64,  FP64>;
  def LCXBR : UnaryRRE<"lcxbr", 0xB343, fneg, FP128, FP128>;
}

// Absolute value (Load Positive).
let Defs = [CC] in {
  def LPEBR : UnaryRRE<"lpebr", 0xB300, fabs, FP32,  FP32>;
  def LPDBR : UnaryRRE<"lpdbr", 0xB310, fabs, FP64,  FP64>;
  def LPXBR : UnaryRRE<"lpxbr", 0xB340, fabs, FP128, FP128>;
}

// Negative absolute value (Load Negative).
let Defs = [CC] in {
  def LNEBR : UnaryRRE<"lnebr", 0xB301, fnabs, FP32,  FP32>;
  def LNDBR : UnaryRRE<"lndbr", 0xB311, fnabs, FP64,  FP64>;
  def LNXBR : UnaryRRE<"lnxbr", 0xB341, fnabs, FP128, FP128>;
}

// Square root.
def SQEBR : UnaryRRE<"sqebr", 0xB314, fsqrt, FP32,  FP32>;
def SQDBR : UnaryRRE<"sqdbr", 0xB315, fsqrt, FP64,  FP64>;
def SQXBR : UnaryRRE<"sqxbr", 0xB316, fsqrt, FP128, FP128>;

def SQEB : UnaryRXE<"sqeb", 0xED14, loadu<fsqrt>, FP32>;
def SQDB : UnaryRXE<"sqdb", 0xED15, loadu<fsqrt>, FP64>;

// Round to an integer, with the second operand (modifier M3) specifying
// the rounding mode.
//
// These forms always check for inexact conditions.  z196 added versions
// that allow this to suppressed (as for fnearbyint), but we don't yet
// support -march=z196.
let Defs = [CC] in {
  def FIEBR : UnaryRRF<"fiebr", 0xB357, FP32,  FP32>;
  def FIDBR : UnaryRRF<"fidbr", 0xB35F, FP64,  FP64>;
  def FIXBR : UnaryRRF<"fixbr", 0xB347, FP128, FP128>;
}

// frint rounds according to the current mode (modifier 0) and detects
// inexact conditions.
def : Pat<(frint FP32:$src),  (FIEBR 0, FP32:$src)>;
def : Pat<(frint FP64:$src),  (FIDBR 0, FP64:$src)>;
def : Pat<(frint FP128:$src), (FIXBR 0, FP128:$src)>;

//===----------------------------------------------------------------------===//
// Binary arithmetic
//===----------------------------------------------------------------------===//

// Addition.
let Defs = [CC] in {
  let isCommutable = 1 in {
    def AEBR : BinaryRRE<"aebr", 0xB30A, fadd, FP32,  FP32>;
    def ADBR : BinaryRRE<"adbr", 0xB31A, fadd, FP64,  FP64>;
    def AXBR : BinaryRRE<"axbr", 0xB34A, fadd, FP128, FP128>;
  }
  def AEB : BinaryRXE<"aeb", 0xED0A, fadd, FP32, load>;
  def ADB : BinaryRXE<"adb", 0xED1A, fadd, FP64, load>;
}

// Subtraction.
let Defs = [CC] in {
  def SEBR : BinaryRRE<"sebr", 0xB30B, fsub, FP32,  FP32>;
  def SDBR : BinaryRRE<"sdbr", 0xB31B, fsub, FP64,  FP64>;
  def SXBR : BinaryRRE<"sxbr", 0xB34B, fsub, FP128, FP128>;

  def SEB : BinaryRXE<"seb",  0xED0B, fsub, FP32, load>;
  def SDB : BinaryRXE<"sdb",  0xED1B, fsub, FP64, load>;
}

// Multiplication.
let isCommutable = 1 in {
  def MEEBR : BinaryRRE<"meebr", 0xB317, fmul, FP32,  FP32>;
  def MDBR  : BinaryRRE<"mdbr",  0xB31C, fmul, FP64,  FP64>;
  def MXBR  : BinaryRRE<"mxbr",  0xB34C, fmul, FP128, FP128>;
}
def MEEB : BinaryRXE<"meeb", 0xED17, fmul, FP32, load>;
def MDB  : BinaryRXE<"mdb",  0xED1C, fmul, FP64, load>;

// f64 multiplication of two FP32 registers.
def MDEBR : BinaryRRE<"mdebr", 0xB30C, null_frag, FP64, FP32>;
def : Pat<(fmul (f64 (fextend FP32:$src1)), (f64 (fextend FP32:$src2))),
          (MDEBR (INSERT_SUBREG (f64 (IMPLICIT_DEF)),
                                FP32:$src1, subreg_32bit), FP32:$src2)>;

// f64 multiplication of an FP32 register and an f32 memory.
def MDEB : BinaryRXE<"mdeb", 0xED0C, null_frag, FP64, load>;
def : Pat<(fmul (f64 (fextend FP32:$src1)),
                (f64 (extloadf32 bdxaddr12only:$addr))),
          (MDEB (INSERT_SUBREG (f64 (IMPLICIT_DEF)), FP32:$src1, subreg_32bit),
                bdxaddr12only:$addr)>;

// f128 multiplication of two FP64 registers.
def MXDBR : BinaryRRE<"mxdbr", 0xB307, null_frag, FP128, FP64>;
def : Pat<(fmul (f128 (fextend FP64:$src1)), (f128 (fextend FP64:$src2))),
          (MXDBR (INSERT_SUBREG (f128 (IMPLICIT_DEF)),
                                FP64:$src1, subreg_high), FP64:$src2)>;

// f128 multiplication of an FP64 register and an f64 memory.
def MXDB : BinaryRXE<"mxdb", 0xED07, null_frag, FP128, load>;
def : Pat<(fmul (f128 (fextend FP64:$src1)),
                (f128 (extloadf64 bdxaddr12only:$addr))),
          (MXDB (INSERT_SUBREG (f128 (IMPLICIT_DEF)), FP64:$src1, subreg_high),
                bdxaddr12only:$addr)>;

// Fused multiply-add.
def MAEBR : TernaryRRD<"maebr", 0xB30E, z_fma, FP32>;
def MADBR : TernaryRRD<"madbr", 0xB31E, z_fma, FP64>;

def MAEB : TernaryRXF<"maeb", 0xED0E, z_fma, FP32, load>;
def MADB : TernaryRXF<"madb", 0xED1E, z_fma, FP64, load>;

// Fused multiply-subtract.
def MSEBR : TernaryRRD<"msebr", 0xB30F, z_fms, FP32>;
def MSDBR : TernaryRRD<"msdbr", 0xB31F, z_fms, FP64>;

def MSEB : TernaryRXF<"mseb", 0xED0F, z_fms, FP32, load>;
def MSDB : TernaryRXF<"msdb", 0xED1F, z_fms, FP64, load>;

// Division.
def DEBR : BinaryRRE<"debr", 0xB30D, fdiv, FP32,  FP32>;
def DDBR : BinaryRRE<"ddbr", 0xB31D, fdiv, FP64,  FP64>;
def DXBR : BinaryRRE<"dxbr", 0xB34D, fdiv, FP128, FP128>;

def DEB : BinaryRXE<"deb", 0xED0D, fdiv, FP32, load>;
def DDB : BinaryRXE<"ddb", 0xED1D, fdiv, FP64, load>;

//===----------------------------------------------------------------------===//
// Comparisons
//===----------------------------------------------------------------------===//

let Defs = [CC] in {
  def CEBR : CompareRRE<"cebr", 0xB309, z_cmp, FP32,  FP32>;
  def CDBR : CompareRRE<"cdbr", 0xB319, z_cmp, FP64,  FP64>;
  def CXBR : CompareRRE<"cxbr", 0xB349, z_cmp, FP128, FP128>;

  def CEB : CompareRXE<"ceb", 0xED09, z_cmp, FP32, load>;
  def CDB : CompareRXE<"cdb", 0xED19, z_cmp, FP64, load>;
}

//===----------------------------------------------------------------------===//
// Peepholes
//===----------------------------------------------------------------------===//

def : Pat<(f32  fpimmneg0), (LCEBR (LZER))>;
def : Pat<(f64  fpimmneg0), (LCDBR (LZDR))>;
def : Pat<(f128 fpimmneg0), (LCXBR (LZXR))>;

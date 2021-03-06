; RUN: opt < %s -basicaa -slp-vectorizer -S -mtriple=i386-apple-macosx10.8.0 -mcpu=corei7-avx | FileCheck %s

target datalayout = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:128:128-n8:16:32-S128"
target triple = "i386-apple-macosx10.8.0"

;int test(double *G) {
;  G[0] = 1+G[5]*4;
;  G[1] = 6+G[6]*3;
;  G[2] = 7+G[5]*4;
;  G[3] = 8+G[6]*4;
;}

;CHECK: @test
;CHECK: insertelement <2 x double> undef
;CHECK-NEXT: insertelement <2 x double>
;CHECK-NEXT: fadd <2 x double>
;CHECK: store <2 x double>
;CHECK:  insertelement <2 x double>
;CHECK-NEXT:  fadd <2 x double>
;CHECK:  store <2 x double>
;CHECK: ret i32

define i32 @test(double* nocapture %G) {
entry:
  %arrayidx = getelementptr inbounds double* %G, i64 5
  %0 = load double* %arrayidx, align 8
  %mul = fmul double %0, 4.000000e+00
  %add = fadd double %mul, 1.000000e+00
  store double %add, double* %G, align 8
  %arrayidx2 = getelementptr inbounds double* %G, i64 6
  %1 = load double* %arrayidx2, align 8
  %mul3 = fmul double %1, 3.000000e+00
  %add4 = fadd double %mul3, 6.000000e+00
  %arrayidx5 = getelementptr inbounds double* %G, i64 1
  store double %add4, double* %arrayidx5, align 8
  %add8 = fadd double %mul, 7.000000e+00
  %arrayidx9 = getelementptr inbounds double* %G, i64 2
  store double %add8, double* %arrayidx9, align 8
  %mul11 = fmul double %1, 4.000000e+00
  %add12 = fadd double %mul11, 8.000000e+00
  %arrayidx13 = getelementptr inbounds double* %G, i64 3
  store double %add12, double* %arrayidx13, align 8
  ret i32 undef
}

;int foo(double *A, int n) {
;  A[0] = A[0] * 7.9 * n + 6.0;
;  A[1] = A[1] * 7.7 * n + 2.0;
;  A[2] = A[2] * 7.6 * n + 3.0;
;  A[3] = A[3] * 7.4 * n + 4.0;
;}
;CHECK: @foo
;CHECK: insertelement <2 x double>
;CHECK: insertelement <2 x double>
;CHECK-NOT: insertelement <2 x double>
;CHECK: ret
define i32 @foo(double* nocapture %A, i32 %n) {
entry:
  %0 = load double* %A, align 8
  %mul = fmul double %0, 7.900000e+00
  %conv = sitofp i32 %n to double
  %mul1 = fmul double %conv, %mul
  %add = fadd double %mul1, 6.000000e+00
  store double %add, double* %A, align 8
  %arrayidx3 = getelementptr inbounds double* %A, i64 1
  %1 = load double* %arrayidx3, align 8
  %mul4 = fmul double %1, 7.700000e+00
  %mul6 = fmul double %conv, %mul4
  %add7 = fadd double %mul6, 2.000000e+00
  store double %add7, double* %arrayidx3, align 8
  %arrayidx9 = getelementptr inbounds double* %A, i64 2
  %2 = load double* %arrayidx9, align 8
  %mul10 = fmul double %2, 7.600000e+00
  %mul12 = fmul double %conv, %mul10
  %add13 = fadd double %mul12, 3.000000e+00
  store double %add13, double* %arrayidx9, align 8
  %arrayidx15 = getelementptr inbounds double* %A, i64 3
  %3 = load double* %arrayidx15, align 8
  %mul16 = fmul double %3, 7.400000e+00
  %mul18 = fmul double %conv, %mul16
  %add19 = fadd double %mul18, 4.000000e+00
  store double %add19, double* %arrayidx15, align 8
  ret i32 undef
}

; int test2(double *G, int k) {
;   if (k) {
;     G[0] = 1+G[5]*4;
;     G[1] = 6+G[6]*3;
;   } else {
;     G[2] = 7+G[5]*4;
;     G[3] = 8+G[6]*3;
;   }
; }

; We can't merge the gather sequences because one does not dominate the other.
; CHECK: test2
; CHECK: insertelement
; CHECK: insertelement
; CHECK: insertelement
; CHECK: insertelement
; CHECK: ret
define i32 @test2(double* nocapture %G, i32 %k) {
  %1 = icmp eq i32 %k, 0
  %2 = getelementptr inbounds double* %G, i64 5
  %3 = load double* %2, align 8
  %4 = fmul double %3, 4.000000e+00
  br i1 %1, label %12, label %5

; <label>:5                                       ; preds = %0
  %6 = fadd double %4, 1.000000e+00
  store double %6, double* %G, align 8
  %7 = getelementptr inbounds double* %G, i64 6
  %8 = load double* %7, align 8
  %9 = fmul double %8, 3.000000e+00
  %10 = fadd double %9, 6.000000e+00
  %11 = getelementptr inbounds double* %G, i64 1
  store double %10, double* %11, align 8
  br label %20

; <label>:12                                      ; preds = %0
  %13 = fadd double %4, 7.000000e+00
  %14 = getelementptr inbounds double* %G, i64 2
  store double %13, double* %14, align 8
  %15 = getelementptr inbounds double* %G, i64 6
  %16 = load double* %15, align 8
  %17 = fmul double %16, 3.000000e+00
  %18 = fadd double %17, 8.000000e+00
  %19 = getelementptr inbounds double* %G, i64 3
  store double %18, double* %19, align 8
  br label %20

; <label>:20                                      ; preds = %12, %5
  ret i32 undef
}


;int foo(double *A, int n) {
;  A[0] = A[0] * 7.9 * n + 6.0;
;  A[1] = A[1] * 7.9 * n + 6.0;
;  A[2] = A[2] * 7.9 * n + 6.0;
;  A[3] = A[3] * 7.9 * n + 6.0;
;}
;CHECK: @foo4
;CHECK: insertelement <2 x double>
;CHECK: insertelement <2 x double>
;CHECK-NOT: insertelement <2 x double>
;CHECK: ret
define i32 @foo4(double* nocapture %A, i32 %n) {
entry:
  %0 = load double* %A, align 8
  %mul = fmul double %0, 7.900000e+00
  %conv = sitofp i32 %n to double
  %mul1 = fmul double %conv, %mul
  %add = fadd double %mul1, 6.000000e+00
  store double %add, double* %A, align 8
  %arrayidx3 = getelementptr inbounds double* %A, i64 1
  %1 = load double* %arrayidx3, align 8
  %mul4 = fmul double %1, 7.900000e+00
  %mul6 = fmul double %conv, %mul4
  %add7 = fadd double %mul6, 6.000000e+00
  store double %add7, double* %arrayidx3, align 8
  %arrayidx9 = getelementptr inbounds double* %A, i64 2
  %2 = load double* %arrayidx9, align 8
  %mul10 = fmul double %2, 7.900000e+00
  %mul12 = fmul double %conv, %mul10
  %add13 = fadd double %mul12, 6.000000e+00
  store double %add13, double* %arrayidx9, align 8
  %arrayidx15 = getelementptr inbounds double* %A, i64 3
  %3 = load double* %arrayidx15, align 8
  %mul16 = fmul double %3, 7.900000e+00
  %mul18 = fmul double %conv, %mul16
  %add19 = fadd double %mul18, 6.000000e+00
  store double %add19, double* %arrayidx15, align 8
  ret i32 undef
}

;int partial_mrg(double *A, int n) {
;  A[0] = A[0] * n;
;  A[1] = A[1] * n;
;  if (n < 4) return 0;
;  A[2] = A[2] * n;
;  A[3] = A[3] * (n+4);
;}
;CHECK: @partial_mrg
;CHECK: insertelement <2 x double>
;CHECK: insertelement <2 x double>
;CHECK: insertelement <2 x double>
;CHECK-NOT: insertelement <2 x double>
;CHECK: ret
define i32 @partial_mrg(double* nocapture %A, i32 %n) {
entry:
  %0 = load double* %A, align 8
  %conv = sitofp i32 %n to double
  %mul = fmul double %conv, %0
  store double %mul, double* %A, align 8
  %arrayidx2 = getelementptr inbounds double* %A, i64 1
  %1 = load double* %arrayidx2, align 8
  %mul4 = fmul double %conv, %1
  store double %mul4, double* %arrayidx2, align 8
  %cmp = icmp slt i32 %n, 4
  br i1 %cmp, label %return, label %if.end

if.end:                                           ; preds = %entry
  %arrayidx7 = getelementptr inbounds double* %A, i64 2
  %2 = load double* %arrayidx7, align 8
  %mul9 = fmul double %conv, %2
  store double %mul9, double* %arrayidx7, align 8
  %arrayidx11 = getelementptr inbounds double* %A, i64 3
  %3 = load double* %arrayidx11, align 8
  %add = add nsw i32 %n, 4
  %conv12 = sitofp i32 %add to double
  %mul13 = fmul double %conv12, %3
  store double %mul13, double* %arrayidx11, align 8
  br label %return

return:                                           ; preds = %entry, %if.end
  ret i32 0
}


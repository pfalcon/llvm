; RUN: opt < %s  -loop-vectorize -force-vector-unroll=1 -force-vector-width=4 -dce -instcombine -S | FileCheck %s

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; A tricky loop:
;
; void loop(int *a, int *b) {
;    for (int i = 0; i < 512; ++i) {
;        a[a[i]] = b[i];
;        a[i] = b[i+1];
;    }
;}

;CHECK: @loop
;CHECK-NOT: <4 x i32>
define void @loop(i32* nocapture %a, i32* nocapture %b) nounwind uwtable {
entry:
  br label %for.body

for.body:                                         ; preds = %for.body, %entry
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32* %b, i64 %indvars.iv
  %0 = load i32* %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds i32* %a, i64 %indvars.iv
  %1 = load i32* %arrayidx2, align 4
  %idxprom3 = sext i32 %1 to i64
  %arrayidx4 = getelementptr inbounds i32* %a, i64 %idxprom3
  store i32 %0, i32* %arrayidx4, align 4
  %indvars.iv.next = add i64 %indvars.iv, 1
  %arrayidx6 = getelementptr inbounds i32* %b, i64 %indvars.iv.next
  %2 = load i32* %arrayidx6, align 4
  store i32 %2, i32* %arrayidx2, align 4
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond = icmp eq i32 %lftr.wideiv, 512
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body
  ret void
}

; The same loop with parallel loop metadata added to the loop branch
; and the memory instructions.

;CHECK: @parallel_loop
;CHECK: <4 x i32>
define void @parallel_loop(i32* nocapture %a, i32* nocapture %b) nounwind uwtable {
entry:
  br label %for.body

for.body:                                         ; preds = %for.body, %entry
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32* %b, i64 %indvars.iv
  %0 = load i32* %arrayidx, align 4, !llvm.mem.parallel_loop_access !3
  %arrayidx2 = getelementptr inbounds i32* %a, i64 %indvars.iv
  %1 = load i32* %arrayidx2, align 4, !llvm.mem.parallel_loop_access !3
  %idxprom3 = sext i32 %1 to i64
  %arrayidx4 = getelementptr inbounds i32* %a, i64 %idxprom3
  ; This store might have originated from inlining a function with a parallel
  ; loop. Refers to a list with the "original loop reference" (!4) also included.
  store i32 %0, i32* %arrayidx4, align 4, !llvm.mem.parallel_loop_access !5
  %indvars.iv.next = add i64 %indvars.iv, 1
  %arrayidx6 = getelementptr inbounds i32* %b, i64 %indvars.iv.next
  %2 = load i32* %arrayidx6, align 4, !llvm.mem.parallel_loop_access !3
  store i32 %2, i32* %arrayidx2, align 4, !llvm.mem.parallel_loop_access !3
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond = icmp eq i32 %lftr.wideiv, 512
  br i1 %exitcond, label %for.end, label %for.body, !llvm.loop !3

for.end:                                          ; preds = %for.body
  ret void
}

; The same loop with an illegal parallel loop metadata: the memory
; accesses refer to a different loop's identifier.

;CHECK: @mixed_metadata
;CHECK-NOT: <4 x i32>

define void @mixed_metadata(i32* nocapture %a, i32* nocapture %b) nounwind uwtable {
entry:
  br label %for.body

for.body:                                         ; preds = %for.body, %entry
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32* %b, i64 %indvars.iv
  %0 = load i32* %arrayidx, align 4, !llvm.mem.parallel_loop_access !6
  %arrayidx2 = getelementptr inbounds i32* %a, i64 %indvars.iv
  %1 = load i32* %arrayidx2, align 4, !llvm.mem.parallel_loop_access !6
  %idxprom3 = sext i32 %1 to i64
  %arrayidx4 = getelementptr inbounds i32* %a, i64 %idxprom3
  ; This refers to the loop marked with !7 which we are not in at the moment.
  ; It should prevent detecting as a parallel loop.
  store i32 %0, i32* %arrayidx4, align 4, !llvm.mem.parallel_loop_access !7
  %indvars.iv.next = add i64 %indvars.iv, 1
  %arrayidx6 = getelementptr inbounds i32* %b, i64 %indvars.iv.next
  %2 = load i32* %arrayidx6, align 4, !llvm.mem.parallel_loop_access !6
  store i32 %2, i32* %arrayidx2, align 4, !llvm.mem.parallel_loop_access !6
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond = icmp eq i32 %lftr.wideiv, 512
  br i1 %exitcond, label %for.end, label %for.body, !llvm.loop !6

for.end:                                          ; preds = %for.body
  ret void
}

!3 = metadata !{metadata !3}
!4 = metadata !{metadata !4}
!5 = metadata !{metadata !3, metadata !4}
!6 = metadata !{metadata !6}
!7 = metadata !{metadata !7}

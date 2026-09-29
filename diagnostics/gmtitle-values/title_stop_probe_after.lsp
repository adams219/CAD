;;; Second script line of title_stop_probe.lsp: checks what the SWCADRUN *error*
;;; handler left after the injected error unwound.

(setq *swt3-log* (open (getenv "SWT_STEP3_LOG") "a"))
(swt3-check "swcadrun-error-status" *swcad-title-last-apply-status* "ERROR_SWCADRUN_INTERRUPTED")
(swt3-check "swcadrun-error-osmode" (getvar "OSMODE") 37)
(swt3-check "swcadrun-error-performance-ended" *swapp-command-performance-active* nil)
(swt3-check "swcadrun-error-recommendation" (swapp-recommended-next-action "TITLE" *swcad-title-last-apply-status*) "SWCADRUN 반복 금지 - 현재 도면을 저장하지 말고 오류 원인을 확인하세요")
(setq swapp-workflow-stage *swt3-orig-stage*)
(setq swapp-run-title-next *swt3-orig-title-next*)
(write-line "Step3 probe completed: yes" *swt3-log*)
(close *swt3-log*)
(princ)

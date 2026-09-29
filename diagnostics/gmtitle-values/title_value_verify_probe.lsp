;;; Read-only probe: runs the SWTITLEVERIFY final summary (as SWCADVERIFY does) on a
;;; throw-away copy and records its status and the title value problems it found.
;;; Environment: SWT_VERIFY_LOG = log path, SWT_PLAN_MODULE = swcad_title_scale.lsp path.

(vl-load-com)
(load (getenv "SWT_PLAN_MODULE"))

(defun swt-v-main (/ result log title problems problem)
  (setq *swcad-title-log-file-suffix* "_valueprobe")
  (setq *swcad-title-legacy-count-compatibility-enabled* T)
  (setq result (vl-catch-all-apply 'swcad-title-integrated-verify-final-summary nil))
  (setq log (open (getenv "SWT_VERIFY_LOG") "w"))
  (write-line
    (strcat
      "STATUS|"
      (if (vl-catch-all-error-p result)
        (strcat "ERROR " (vl-catch-all-error-message result))
        (swcad-title-string result)
      )
    )
    log
  )
  (write-line (strcat "RESULT_CODE|" (swcad-title-string *swcad-title-last-apply-status*)) log)
  (foreach title (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))
    (setq problems (swcad-title-title-value-problems (swcad-title-title-attribute-pairs (swcad-title-safe-vla-object title))))
    (foreach problem problems
      (write-line
        (strcat "PROBLEM|" (swcad-title-ename-handle title) "|" (car problem) "|" (cadr problem) "|" (caddr problem))
        log
      )
    )
  )
  (write-line "Verify probe completed: yes" log)
  (close log)
  (princ)
)

(swt-v-main)

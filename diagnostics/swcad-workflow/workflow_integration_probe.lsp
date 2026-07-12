;;; End-to-end runtime probe for the SWCAD Workflow public commands.

(vl-load-com)

(defun swapp-int-env (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= value "")) fallback value)
)

(setq *swapp-int-log-path* nil)

(defun swapp-int-write (ignored text / path handle)
  (setq path (getenv "SWCAD_WORKFLOW_LOG"))
  (if (or (not path) (= path "")) (setq path *swapp-int-log-path*))
  (if path
    (progn
      (setq path (vl-string-translate "\\" "/" path))
      (setq handle (open path "a"))
      (if handle
        (progn
          (write-line (if text text "") handle)
          (close handle)
        )
      )
    )
  )
)

(defun swapp-int-bool (value)
  (if value "yes" "no")
)

(defun swapp-int-attach (source / result)
  (setq result
    (vl-catch-all-apply
      'vla-AttachExternalReference
      (list
        (swapp-model)
        source
        "SWCAD_WORKFLOW_TEST_XREF"
        (vlax-3d-point '(1000.0 2000.0 0.0))
        1.0 1.0 1.0 0.0
        :vlax-false
      )
    )
  )
  (if (vl-catch-all-error-p result) nil result)
)

(defun swapp-int-command-ok (command / result)
  (setq result (vl-catch-all-apply command nil))
  (not (vl-catch-all-error-p result))
)

(defun swapp-int-main (/ root mode source output log-path handle load-result load-ok attached command-ok summary xrefs dimensions source-titles source-frames evidence native-targets stage dim-state layouts title-status dim-ok layout-ok verify-command-ok pass unmatched-before unmatched-after unmatched-handle same-handle-after same-handle-before)
  (setq root (vl-string-translate "\\" "/" (swapp-int-env "SWCAD_WORKFLOW_ROOT" "C:/Users/DR-DESIGN/Documents/CAD tool")))
  (setq mode (strcase (swapp-int-env "SWCAD_WORKFLOW_MODE" "MATERIALIZE_RAW")))
  (setq source (vl-string-translate "\\" "/" (swapp-int-env "SWCAD_WORKFLOW_SOURCE" "")))
  (setq output (vl-string-translate "\\" "/" (swapp-int-env "SWCAD_WORKFLOW_OUTPUT" "")))
  (setq log-path (vl-string-translate "\\" "/" (swapp-int-env "SWCAD_WORKFLOW_LOG" (strcat root "/work/swcad_workflow_integration_probe.txt"))))
  (setq *swapp-int-log-path* log-path)
  (setq handle (open log-path "w"))
  (if handle (close handle))
  (if handle
    (progn
      (setq handle T)
      (swapp-int-write handle "SWCAD Workflow integration probe")
      (swapp-int-write handle (strcat "Mode: " mode))
      (swapp-int-write handle "Milestone: before app loader")
      (setq load-result
        (vl-catch-all-apply
          'load
          (list (strcat root "/apps/swcad-workflow/swcad_workflow_load.lsp"))
        )
      )
      (setq load-ok (not (vl-catch-all-error-p load-result)))
      (swapp-int-write handle (strcat "Milestone: after app loader=" (if load-ok "OK" "ERROR")))
    )
    (setq handle nil)
  )
  (if handle
    (progn
      (swapp-int-write handle (strcat "Load result: " (if load-ok "OK" "ERROR")))
      (if load-ok
        (cond
          ((equal mode "MATERIALIZE_RAW")
            (swapp-int-write handle "Milestone: before XREF attach")
            (setq attached (swapp-int-attach source))
            (swapp-int-write handle (strcat "Milestone: after XREF attach=" (swapp-int-bool attached)))
            (setq *swcad-title-work-copy-saveas-path-override* output)
            (swapp-int-write handle "Milestone: before public SWCADRUN")
            (setq command-ok (if attached (swapp-int-command-ok 'c:SWCADRUN) nil))
            (swapp-int-write handle (strcat "Milestone: after public SWCADRUN=" (swapp-int-bool command-ok)))
            (setq summary (swcad-title-fast-sheet-summary))
            (setq xrefs (length (swapp-top-xref-references)))
            (setq dimensions (swapp-top-dimension-count))
            (setq source-titles (swcad-title-fast-summary-value summary "source-title-count"))
            (setq source-frames (swcad-title-fast-summary-value summary "source-frame-count"))
            (setq stage (swapp-workflow-stage))
            (swapp-int-write handle (strcat "Attach result: " (swapp-int-bool attached)))
            (swapp-int-write handle (strcat "Public SWCADRUN result: " (swapp-int-bool command-ok)))
            (swapp-int-write handle (strcat "Remaining XREF count: " (itoa xrefs)))
            (swapp-int-write handle (strcat "Top dimension count: " (itoa dimensions)))
            (swapp-int-write handle (strcat "Source title count: " (itoa source-titles)))
            (swapp-int-write handle (strcat "Source frame count: " (itoa source-frames)))
            (swapp-int-write handle (strcat "Materialized state: " (if (swapp-state-value "MATERIALIZED") (swapp-state-value "MATERIALIZED") "<none>")))
            (swapp-int-write handle (strcat "Workflow stage: " stage))
            (setq pass
              (and
                attached command-ok
                (= xrefs 0)
                (= dimensions 143)
                (= source-titles 15)
                (= source-frames 15)
                (equal (swapp-state-value "MATERIALIZED") "OK")
                (equal stage "TITLE")
                (findfile output)
              )
            )
          )
          ((equal mode "NATIVE_GUARD")
            (setq attached (swapp-int-attach source))
            (setq evidence (if attached (swapp-xref-deep-evidence (swapp-top-xref-references)) nil))
            (setq native-targets (if evidence (swapp-evidence-value evidence "target-references") 0))
            (setq command-ok (if attached (swapp-int-command-ok 'c:SWCADRUN) nil))
            (setq xrefs (length (swapp-top-xref-references)))
            (setq stage (swapp-workflow-stage))
            (swapp-int-write handle (strcat "Attach result: " (swapp-int-bool attached)))
            (swapp-int-write handle (strcat "Public SWCADRUN returned without error: " (swapp-int-bool command-ok)))
            (swapp-int-write handle (strcat "Detected deep native target references: " (itoa native-targets)))
            (swapp-int-write handle (strcat "Remaining XREF count: " (itoa xrefs)))
            (swapp-int-write handle (strcat "Materialized state: " (if (swapp-state-value "MATERIALIZED") (swapp-state-value "MATERIALIZED") "<none>")))
            (swapp-int-write handle (strcat "Workflow stage: " stage))
            (setq pass
              (and
                attached command-ok
                (> native-targets 0)
                (= xrefs 1)
                (not (equal (swapp-state-value "MATERIALIZED") "OK"))
                (equal stage "XREF")
              )
            )
          )
          ((equal mode "DOWNSTREAM")
            (setq evidence (swapp-title-evidence))
            (setq command-ok (and (swapp-title-complete-p evidence) (swapp-int-command-ok 'c:SWCADRUN)))
            (setq dim-state (swapp-state-value "DIMSTYLE"))
            (setq stage (swapp-workflow-stage))
            (setq command-ok (and command-ok (equal stage "LAYOUT") (swapp-int-command-ok 'c:SWCADRUN)))
            (setq stage (swapp-workflow-stage))
            (setq layouts (length (swapp-with-layout-prefix-names)))
            (if command-ok
              (progn
                (setq title-status (swcad-title-integrated-verify-final-summary))
                (setq dim-ok (swapp-dimstyle-verify))
                (setq layout-ok (swapp-layouts-valid-p (length (swcad-title-frame-records))))
                (swapp-save-current)
              )
              (progn
                (setq title-status "SKIPPED_AFTER_STAGE_FAILURE")
                (setq dim-ok nil)
                (setq layout-ok nil)
              )
            )
            (swapp-int-write handle (strcat "Public SWCADRUN sequence: " (swapp-int-bool command-ok)))
            (swapp-int-write handle (strcat "DIMSTYLE state: " (if dim-state dim-state "<none>")))
            (swapp-int-write handle (strcat "Dimension semantics: " (if (swapp-state-value "DIMENSION_SEMANTICS") (swapp-state-value "DIMENSION_SEMANTICS") "<none>")))
            (swapp-int-write handle (strcat "Dimension restore count: " (if (swapp-state-value "DIMENSION_RESTORE_COUNT") (swapp-state-value "DIMENSION_RESTORE_COUNT") "<none>")))
            (if (equal (swapp-state-value "DIMENSION_SEMANTICS") "CHANGED")
              (progn
                (setq unmatched-before (swapp-first-unmatched-semantic *swapp-last-dimension-semantics-before* *swapp-last-dimension-semantics-after*))
                (setq unmatched-after (swapp-first-unmatched-semantic *swapp-last-dimension-semantics-after* *swapp-last-dimension-semantics-before*))
                (setq unmatched-handle (swapp-semantic-record-handle unmatched-before))
                (setq same-handle-after (swapp-semantic-by-handle unmatched-handle *swapp-last-dimension-semantics-after*))
                (setq same-handle-before (swapp-semantic-by-handle (swapp-semantic-record-handle unmatched-after) *swapp-last-dimension-semantics-before*))
                (swapp-int-write handle (strcat "Dimension records before: " (itoa (length *swapp-last-dimension-semantics-before*))))
                (swapp-int-write handle (strcat "Dimension records after: " (itoa (length *swapp-last-dimension-semantics-after*))))
                (swapp-int-write handle (strcat "Unmatched before: " (if unmatched-before unmatched-before "<none>")))
                (swapp-int-write handle (strcat "Same handle after: " (if same-handle-after same-handle-after "<none>")))
                (swapp-int-write handle (strcat "Unmatched after: " (if unmatched-after unmatched-after "<none>")))
                (swapp-int-write handle (strcat "Same handle before: " (if same-handle-before same-handle-before "<none>")))
              )
            )
            (swapp-int-write handle (strcat "Layout count: " (itoa layouts)))
            (swapp-int-write handle (strcat "Title verify status: " title-status))
            (swapp-int-write handle (strcat "DIMSTYLE audit: " (swapp-int-bool dim-ok)))
            (swapp-int-write handle (strcat "Layout audit: " (swapp-int-bool layout-ok)))
            (swapp-int-write handle (strcat "Workflow stage: " stage))
            (setq pass
              (and
                command-ok
                (equal dim-state "OK")
                (equal (swapp-state-value "DIMENSION_SEMANTICS") "PRESERVED")
                (= layouts 15)
                (equal title-status "OK")
                dim-ok layout-ok
                (equal stage "COMPLETE")
              )
            )
          )
          ((equal mode "REOPEN")
            (setq stage (swapp-workflow-stage))
            (setq layouts (length (swapp-with-layout-prefix-names)))
            (setq title-status (swcad-title-integrated-verify-final-summary))
            (setq dim-ok (swapp-dimstyle-verify))
            (setq layout-ok (swapp-layouts-valid-p (length (swcad-title-frame-records))))
            (setq verify-command-ok (swapp-int-command-ok 'c:SWCADVERIFY))
            (swapp-int-write handle (strcat "DIMSTYLE state: " (if (swapp-state-value "DIMSTYLE") (swapp-state-value "DIMSTYLE") "<none>")))
            (swapp-int-write handle (strcat "Dimension semantics: " (if (swapp-state-value "DIMENSION_SEMANTICS") (swapp-state-value "DIMENSION_SEMANTICS") "<none>")))
            (swapp-int-write handle (strcat "Dimension restore count: " (if (swapp-state-value "DIMENSION_RESTORE_COUNT") (swapp-state-value "DIMENSION_RESTORE_COUNT") "<none>")))
            (swapp-int-write handle (strcat "LAYOUT state: " (if (swapp-state-value "LAYOUT") (swapp-state-value "LAYOUT") "<none>")))
            (swapp-int-write handle (strcat "Layout count: " (itoa layouts)))
            (swapp-int-write handle (strcat "Title verify status: " title-status))
            (swapp-int-write handle (strcat "DIMSTYLE audit: " (swapp-int-bool dim-ok)))
            (swapp-int-write handle (strcat "Layout audit: " (swapp-int-bool layout-ok)))
            (swapp-int-write handle (strcat "Public SWCADVERIFY returned without error: " (swapp-int-bool verify-command-ok)))
            (swapp-int-write handle (strcat "Workflow stage: " stage))
            (swapp-int-write handle (strcat "DBMOD after: " (itoa (getvar "DBMOD"))))
            (setq pass
              (and
                (equal (swapp-state-value "DIMSTYLE") "OK")
                (equal (swapp-state-value "DIMENSION_SEMANTICS") "PRESERVED")
                (equal (swapp-state-value "LAYOUT") "OK")
                (= layouts 15)
                (equal title-status "OK")
                dim-ok layout-ok verify-command-ok
                (equal stage "COMPLETE")
                (= (getvar "DBMOD") 0)
              )
            )
          )
          (T
            (swapp-int-write handle "Unknown integration probe mode.")
            (setq pass nil)
          )
        )
        (progn
          (swapp-int-write handle (strcat "Load error: " (vl-catch-all-error-message load-result)))
          (setq pass nil)
        )
      )
      (swapp-int-write handle (strcat "Runtime check completed: " (swapp-int-bool pass)))
    )
  )
  (princ)
)

(swapp-int-main)

;;; Runtime probe for rebasing legacy expected sheet/title counts on a copied DWG.

(vl-load-com)

(defun swapp-rebase-env (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= value "")) fallback value)
)

(setq *swapp-rebase-log-path* nil)

(defun swapp-rebase-write (text / handle)
  (if *swapp-rebase-log-path*
    (progn
      (setq handle (open *swapp-rebase-log-path* "a"))
      (if handle
        (progn
          (write-line (if text text "") handle)
          (close handle)
        )
      )
    )
  )
)

(defun swapp-rebase-bool (value)
  (if value "yes" "no")
)

(defun swapp-rebase-counts-text (counts / result sheet)
  (setq result "")
  (foreach sheet '("A2" "A3" "A4")
    (if (> (strlen result) 0)
      (setq result (strcat result ","))
    )
    (setq result
      (strcat
        result
        sheet
        "="
        (itoa (swcad-title-count-value sheet counts))
      )
    )
  )
  result
)

(defun swapp-rebase-pair-signature (/ records result record title frame title-data frame-data attrs)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq result nil)
  (foreach record records
    (setq title (car record))
    (setq frame (cadr record))
    (setq title-data
      (swcad-title-remove-xdata-app-from-data
        (entget title '("*"))
        *swcad-title-exemplar-xdata-app*
      )
    )
    (setq frame-data
      (swcad-title-remove-xdata-app-from-data
        (entget frame '("*"))
        *swcad-title-exemplar-xdata-app*
      )
    )
    (setq attrs
      (swcad-title-title-attribute-pairs
        (swcad-title-safe-vla-object title)
      )
    )
    (setq result
      (append
        result
        (list
          (strcat
            (vl-prin1-to-string title-data)
            "|"
            (vl-prin1-to-string frame-data)
            "|"
            (vl-prin1-to-string attrs)
          )
        )
      )
    )
  )
  result
)

(defun swapp-rebase-classifier-entity-count (/ records count record)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (setq count 0)
  (foreach record records
    (if (swcad-title-exemplar-current-count-classifier-p (car record))
      (setq count (+ count 1))
    )
    (if (swcad-title-exemplar-current-count-classifier-p (cadr record))
      (setq count (+ count 1))
    )
  )
  count
)

(defun swapp-rebase-main
  (
    / root loader load-result load-ok before-frame before-title actual-frame
      actual-title before-mismatch before-status before-signature pair-records pair-count
      native-like-count pair-record xref-count wrapper-count dimension-count
      old-frame-override old-title-override old-log-suffix old-compat-enabled
      compat-status compat-dbmod-before compat-dbmod-after compat-readonly
      public-result public-status public-dbmod-before public-dbmod-after
      public-readonly
      safe-preflight
      rebase-result rebase-status after-frame after-title after-match
      classifier-count classifier-complete after-signature native-unchanged
      after-status save-result dbmod pass handle
  )
  (setq root (vl-string-translate "\\" "/" (swapp-rebase-env "SWCAD_WORKFLOW_ROOT" "")))
  (setq *swapp-rebase-log-path*
    (vl-string-translate
      "\\"
      "/"
      (swapp-rebase-env "SWCAD_WORKFLOW_LOG" (strcat root "/work/legacy_count_rebase_probe.txt"))
    )
  )
  (setq handle (open *swapp-rebase-log-path* "w"))
  (if handle (close handle))
  (swapp-rebase-write "SWCAD legacy expected-count rebase probe")
  (setq loader (strcat root "/apps/swcad-workflow/swcad_workflow_load.lsp"))
  (setq load-result (vl-catch-all-apply 'load (list loader)))
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (swapp-rebase-write (strcat "Load result: " (if load-ok "OK" "ERROR")))
  (if load-ok
    (progn
      (setq before-frame (swcad-title-stored-expected-sheet-counts))
      (setq before-title (swcad-title-stored-expected-title-counts))
      (setq actual-frame (swcad-title-target-frame-sheet-counts))
      (setq actual-title (swcad-title-target-title-sheet-counts))
      (setq pair-records (swcad-title-target-gmtitle-pair-records))
      (setq pair-count (length pair-records))
      (setq native-like-count 0)
      (foreach pair-record pair-records
        (if (swcad-title-target-pair-native-like-p pair-record)
          (setq native-like-count (1+ native-like-count))
        )
      )
      (setq xref-count (length (swapp-top-xref-references)))
      (setq wrapper-count (length (swapp-sheet-wrapper-records)))
      (setq dimension-count (swapp-top-dimension-count))
      (setq before-mismatch
        (or
          (not (swcad-title-a2a3a4-counts-equal-p before-frame actual-frame))
          (not (swcad-title-a2a3a4-counts-equal-p before-title actual-title))
        )
      )
      (setq before-signature (swapp-rebase-pair-signature))
      (setq old-compat-enabled *swcad-title-legacy-count-compatibility-enabled*)
      (setq *swcad-title-legacy-count-compatibility-enabled* nil)
      (setq before-status (swcad-title-integrated-verify-final-summary))
      (setq *swcad-title-legacy-count-compatibility-enabled* T)
      (setq compat-dbmod-before (getvar "DBMOD"))
      (setq compat-status (swcad-title-integrated-verify-final-summary))
      (setq compat-dbmod-after (getvar "DBMOD"))
      (setq compat-readonly
        (and
          (= compat-dbmod-before compat-dbmod-after)
          (swcad-title-a2a3a4-counts-equal-p
            before-frame
            (swcad-title-stored-expected-sheet-counts)
          )
          (swcad-title-a2a3a4-counts-equal-p
            before-title
            (swcad-title-stored-expected-title-counts)
          )
          (equal before-signature (swapp-rebase-pair-signature))
        )
      )
      (setq *swcad-title-legacy-count-compatibility-enabled* old-compat-enabled)
      (setq public-dbmod-before (getvar "DBMOD"))
      (setq public-result (vl-catch-all-apply 'c:SWCADVERIFY nil))
      (setq public-status
        (if (vl-catch-all-error-p public-result)
          "ERROR"
          *swcad-title-last-apply-status*
        )
      )
      (setq public-dbmod-after (getvar "DBMOD"))
      (setq public-readonly
        (and
          (= public-dbmod-before public-dbmod-after)
          (swcad-title-a2a3a4-counts-equal-p
            before-frame
            (swcad-title-stored-expected-sheet-counts)
          )
          (swcad-title-a2a3a4-counts-equal-p
            before-title
            (swcad-title-stored-expected-title-counts)
          )
          (equal before-signature (swapp-rebase-pair-signature))
        )
      )
      (setq old-frame-override *swcad-title-expected-sheet-counts-override*)
      (setq old-title-override *swcad-title-expected-title-counts-override*)
      (setq old-log-suffix *swcad-title-log-file-suffix*)
      (setq *swcad-title-expected-sheet-counts-override* actual-frame)
      (setq *swcad-title-expected-title-counts-override* actual-title)
      (setq *swcad-title-log-file-suffix* "legacy_count_rebase_preflight")
      (setq safe-preflight (swcad-title-integrated-verify-final-summary))
      (setq *swcad-title-expected-sheet-counts-override* old-frame-override)
      (setq *swcad-title-expected-title-counts-override* old-title-override)
      (setq *swcad-title-log-file-suffix* old-log-suffix)
      (swapp-rebase-write (strcat "Before stored frame counts: " (swapp-rebase-counts-text before-frame)))
      (swapp-rebase-write (strcat "Before stored title counts: " (swapp-rebase-counts-text before-title)))
      (swapp-rebase-write (strcat "Actual frame counts: " (swapp-rebase-counts-text actual-frame)))
      (swapp-rebase-write (strcat "Actual title counts: " (swapp-rebase-counts-text actual-title)))
      (swapp-rebase-write (strcat "Remaining XREF/wrappers: " (itoa xref-count) "/" (itoa wrapper-count)))
      (swapp-rebase-write (strcat "Top dimension count: " (itoa dimension-count)))
      (swapp-rebase-write (strcat "Target pair/native-like count: " (itoa pair-count) "/" (itoa native-like-count)))
      (swapp-rebase-write (strcat "Before mismatch: " (swapp-rebase-bool before-mismatch)))
      (swapp-rebase-write (strcat "Before title verify: " before-status))
      (swapp-rebase-write (strcat "Legacy compatibility title verify: " compat-status))
      (swapp-rebase-write (strcat "Legacy compatibility read-only: " (swapp-rebase-bool compat-readonly)))
      (swapp-rebase-write (strcat "Public SWCADVERIFY legacy compatibility: " public-status))
      (swapp-rebase-write (strcat "Public SWCADVERIFY read-only: " (swapp-rebase-bool public-readonly)))
      (swapp-rebase-write (strcat "Direct safe preflight: " safe-preflight))
      (setq rebase-result
        (vl-catch-all-apply
          'swcad-title-rebase-expected-counts-for-complete-targets
          nil
        )
      )
      (if (vl-catch-all-error-p rebase-result)
        (setq rebase-result nil)
      )
      (setq rebase-status *swcad-title-last-apply-status*)
      (setq after-frame (swcad-title-stored-expected-sheet-counts))
      (setq after-title (swcad-title-stored-expected-title-counts))
      (setq after-match
        (and
          (swcad-title-a2a3a4-counts-equal-p after-frame actual-frame)
          (swcad-title-a2a3a4-counts-equal-p after-title actual-title)
        )
      )
      (setq classifier-count (swapp-rebase-classifier-entity-count))
      (setq classifier-complete (= classifier-count (* pair-count 2)))
      (setq after-signature (swapp-rebase-pair-signature))
      (setq native-unchanged (equal before-signature after-signature))
      (setq after-status (swcad-title-integrated-verify-final-summary))
      (setq save-result
        (vl-catch-all-apply
          'vla-Save
          (list (vla-get-ActiveDocument (vlax-get-acad-object)))
        )
      )
      (setq save-result (not (vl-catch-all-error-p save-result)))
      (setq dbmod (getvar "DBMOD"))
      (swapp-rebase-write (strcat "Rebase result: " (swapp-rebase-bool rebase-result)))
      (swapp-rebase-write (strcat "Rebase status: " rebase-status))
      (swapp-rebase-write (strcat "After stored frame counts: " (swapp-rebase-counts-text after-frame)))
      (swapp-rebase-write (strcat "After stored title counts: " (swapp-rebase-counts-text after-title)))
      (swapp-rebase-write (strcat "After counts match actual: " (swapp-rebase-bool after-match)))
      (swapp-rebase-write (strcat "Classifier markers complete: " (swapp-rebase-bool classifier-complete)))
      (swapp-rebase-write (strcat "Native structure unchanged: " (swapp-rebase-bool native-unchanged)))
      (swapp-rebase-write (strcat "After title verify: " after-status))
      (swapp-rebase-write (strcat "Save result: " (swapp-rebase-bool save-result)))
      (swapp-rebase-write (strcat "DBMOD after save: " (itoa dbmod)))
      (setq pass
        (and
          before-mismatch
          (= xref-count 0)
          (= wrapper-count 0)
          (= dimension-count 254)
          (= pair-count 30)
          (= native-like-count pair-count)
          (equal before-status "FAIL")
          (equal compat-status "OK")
          compat-readonly
          (equal public-status "SWTITLEVERIFY_FINAL_OK")
          public-readonly
          rebase-result
          (equal rebase-status "OK_EXPECTED_COUNTS_REBASED")
          after-match
          classifier-complete
          native-unchanged
          (equal after-status "OK")
          save-result
          (= dbmod 0)
        )
      )
    )
    (setq pass nil)
  )
  (swapp-rebase-write (strcat "Runtime check completed: " (swapp-rebase-bool pass)))
  (princ)
)

(swapp-rebase-main)

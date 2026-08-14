;;; Read-only phase timing probe for a completed 30+ sheet SWCAD drawing.

(vl-load-com)

(defun swapp-perf-probe-elapsed-ms (start / finish elapsed)
  (setq finish (getvar "DATE"))
  (setq elapsed (fix (+ 0.5 (* 86400000.0 (- finish start)))))
  (if (< elapsed 0) 0 elapsed)
)

(defun swapp-perf-probe-write (handle text)
  (if handle (write-line text handle))
)

(defun swapp-perf-probe-value-text (result)
  (cond
    ((eq result T) "T")
    ((not result) "NIL")
    ((= (type result) 'STR) result)
    ((numberp result) (vl-princ-to-string result))
    (T "<DATA>")
  )
)

(defun swapp-perf-probe-call (handle round label fn args / start result elapsed ok)
  (setq start (getvar "DATE"))
  (setq result (vl-catch-all-apply fn args))
  (setq elapsed (swapp-perf-probe-elapsed-ms start))
  (setq ok (not (vl-catch-all-error-p result)))
  (swapp-perf-probe-write
    handle
    (strcat
      "ROUND=" (itoa round)
      " PHASE=" label
      " ELAPSED_MS=" (itoa elapsed)
      " RESULT=" (if ok "OK" "ERROR")
      (if ok (strcat " VALUE=" (swapp-perf-probe-value-text result)) "")
      (if ok "" (strcat " DETAIL=" (vl-catch-all-error-message result)))
    )
  )
  (setq result nil)
  ok
)

(defun swapp-perf-probe-run (/ path handle before-dbmod after-dbmod round ok)
  (setq path
    (strcat (getvar "DWGPREFIX") "swcad_workflow_performance_phase_probe.txt")
  )
  (setq handle (open path "w"))
  (if (not handle)
    (progn
      (princ "\nPerformance phase probe could not open its output file.")
      nil
    )
    (progn
      (setq before-dbmod (getvar "DBMOD"))
      (swapp-perf-probe-write handle "SWCAD_WORKFLOW_PERFORMANCE_PHASE_PROBE_V2")
      (swapp-perf-probe-write
        handle
        (strcat "DWG=" (getvar "DWGPREFIX") (getvar "DWGNAME"))
      )
      (swapp-perf-probe-write handle (strcat "CTAB=" (getvar "CTAB")))
      (swapp-perf-probe-write
        handle
        (strcat
          "APP_VERSION="
          (if (and (boundp '*swapp-version*) *swapp-version*)
            *swapp-version*
            "<not-loaded>"
          )
        )
      )
      (swapp-perf-probe-write
        handle
        (strcat "DBMOD_BEFORE=" (itoa before-dbmod))
      )
      (setq round 1)
      (setq ok T)
      (while (and ok (<= round 3))
        (swapp-perf-probe-write handle (strcat "ROUND_BEGIN=" (itoa round)))
        (setq ok
          (and ok
            (swapp-perf-probe-call handle round "MODEL_OBJECT_COUNT" 'swapp-model-object-count nil)
            (swapp-perf-probe-call handle round "MODEL_BBOX" 'swapp-model-bbox nil)
            (swapp-perf-probe-call handle round "DIMENSION_SEMANTICS" 'swapp-dimension-semantics nil)
            (swapp-perf-probe-call handle round "TITLE_INTEGRITY" 'swapp-title-integrity-snapshot nil)
            (swapp-perf-probe-call handle round "LAYOUT_INTEGRITY" 'swapp-layout-integrity-snapshot nil)
            (swapp-perf-probe-call handle round "STATE_INTEGRITY" 'swapp-state-integrity-snapshot nil)
            (swapp-perf-probe-call handle round "WORKFLOW_INTEGRITY" 'swapp-workflow-integrity-snapshot nil)
            (swapp-perf-probe-call handle round "SYMBOL_TABLE_DEFINITIONS" 'swapp-symbol-table-definition-snapshot nil)
            (swapp-perf-probe-call
              handle round "NOD_DEFINITIONS"
              'swapp-dictionary-definition-snapshot-rec
              (list (namedobjdict) "NOD" nil)
            )
            (swapp-perf-probe-call handle round "ALL_NAMED_DEFINITIONS" 'swapp-named-definition-snapshot nil)
            (swapp-perf-probe-call handle round "CLEANUP_VERIFY" 'swapp-resource-cleanup-verify nil)
            (swapp-perf-probe-call handle round "WORKFLOW_STAGE" 'swapp-workflow-stage nil)
          )
        )
        (swapp-perf-probe-write handle (strcat "ROUND_END=" (itoa round)))
        (setq round (1+ round))
      )
      (setq after-dbmod (getvar "DBMOD"))
      (swapp-perf-probe-write
        handle
        (strcat "DBMOD_AFTER=" (itoa after-dbmod))
      )
      (swapp-perf-probe-write
        handle
        (strcat "DBMOD_UNCHANGED=" (if (= before-dbmod after-dbmod) "YES" "NO"))
      )
      (swapp-perf-probe-write handle (strcat "RESULT=" (if ok "OK" "FAIL")))
      (close handle)
      (princ (strcat "\nPerformance phase probe: " path))
      ok
    )
  )
)

(swapp-perf-probe-run)
(princ)

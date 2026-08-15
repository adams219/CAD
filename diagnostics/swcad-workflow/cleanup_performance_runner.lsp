;;; One-shot cleanup benchmark runner. Load only in a dedicated test copy.

(vl-load-com)

(defun swapp-cleanup-benchmark-elapsed-ms (start / finish elapsed)
  (setq finish (getvar "DATE"))
  (setq elapsed (fix (+ 0.5 (* 86400000.0 (- finish start)))))
  (if (< elapsed 0) 0 elapsed)
)

(defun swapp-cleanup-benchmark-write (handle key value)
  (if handle
    (write-line
      (strcat key "=" (if value (vl-princ-to-string value) "<nil>"))
      handle
    )
  )
)

(defun swapp-cleanup-benchmark-run
  (
    / path handle before-dbmod start result elapsed snapshot definitions
      workflow-signature stored-workflow-signature stable-identity-signature
      stored-stable-identity-signature audit-ok after-dbmod
  )
  (setq path
    (if (and (boundp 'swapp-benchmark-output) swapp-benchmark-output)
      swapp-benchmark-output
      (strcat (getvar "DWGPREFIX") "swcad_cleanup_performance_result.txt")
    )
  )
  (setq handle (open path "w"))
  (if (not handle)
    (progn
      (princ "\nCleanup benchmark could not open its output file.")
      nil
    )
    (progn
      (setq before-dbmod (getvar "DBMOD"))
      (write-line "SWCAD_CLEANUP_PERFORMANCE_V1" handle)
      (swapp-cleanup-benchmark-write
        handle "LABEL"
        (if (and (boundp 'swapp-benchmark-label) swapp-benchmark-label)
          swapp-benchmark-label
          "<unlabeled>"
        )
      )
      (swapp-cleanup-benchmark-write handle "DWG" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swapp-cleanup-benchmark-write handle "APP_VERSION" *swapp-version*)
      (swapp-cleanup-benchmark-write handle "DBMOD_BEFORE" before-dbmod)
      (setq start (getvar "DATE"))
      (setq result (vl-catch-all-apply 'c:SWCADRUN nil))
      (setq elapsed (swapp-cleanup-benchmark-elapsed-ms start))
      (swapp-cleanup-benchmark-write handle "WALL_ELAPSED_MS" elapsed)
      (swapp-cleanup-benchmark-write
        handle "COMMAND_ERROR"
        (if (vl-catch-all-error-p result)
          (vl-catch-all-error-message result)
          "<none>"
        )
      )
      (swapp-cleanup-benchmark-write handle "COMMAND_REPORTED_MS" *swapp-last-command-elapsed-ms*)
      (swapp-cleanup-benchmark-write handle "RESOURCE_CLEANUP" (swapp-state-value "RESOURCE_CLEANUP"))
      (swapp-cleanup-benchmark-write handle "RESOURCE_CLEANUP_ZERO_PASS" (swapp-state-value "RESOURCE_CLEANUP_ZERO_PASS"))
      (swapp-cleanup-benchmark-write handle "RESOURCE_CLEANUP_PASSES" (swapp-state-value "RESOURCE_CLEANUP_PASSES"))
      (swapp-cleanup-benchmark-write handle "RESOURCE_CLEANUP_REMOVED" (swapp-state-value "RESOURCE_CLEANUP_REMOVED"))
      (setq snapshot (swapp-workflow-integrity-snapshot))
      (setq definitions (swapp-named-definition-snapshot))
      (setq workflow-signature (swapp-workflow-integrity-signature snapshot))
      (setq stored-workflow-signature (swapp-state-value "RESOURCE_CLEANUP_INTEGRITY"))
      (setq stable-identity-signature
        (swapp-named-definition-stable-identity-signature definitions)
      )
      (setq stored-stable-identity-signature
        (swapp-state-value "RESOURCE_CLEANUP_STABLE_DEFINITION_IDENTITY_SIGNATURE")
      )
      (setq audit-ok
        (and
          (equal (swapp-state-value "RESOURCE_CLEANUP") "OK")
          (equal workflow-signature stored-workflow-signature)
          (equal stable-identity-signature stored-stable-identity-signature)
        )
      )
      (swapp-cleanup-benchmark-write handle "WORKFLOW_SIGNATURE" workflow-signature)
      (swapp-cleanup-benchmark-write handle "STORED_WORKFLOW_SIGNATURE" stored-workflow-signature)
      (swapp-cleanup-benchmark-write handle "STABLE_IDENTITY_SIGNATURE" stable-identity-signature)
      (swapp-cleanup-benchmark-write handle "STORED_STABLE_IDENTITY_SIGNATURE" stored-stable-identity-signature)
      (swapp-cleanup-benchmark-write handle "AUDIT_RESULT" (if audit-ok "OK" "FAIL"))
      (setq after-dbmod (getvar "DBMOD"))
      (swapp-cleanup-benchmark-write handle "DBMOD_AFTER" after-dbmod)
      (close handle)
      (princ (strcat "\nCleanup benchmark result: " path))
      audit-ok
    )
  )
)

(swapp-cleanup-benchmark-run)
(princ)

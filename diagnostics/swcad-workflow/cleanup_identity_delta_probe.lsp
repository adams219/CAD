;;; Read-only identity dump for cross-session cleanup delta analysis.

(vl-load-com)

(if
  (and
    (boundp 'swapp-cleanup-delta-handle)
    swapp-cleanup-delta-handle
  )
  (vl-catch-all-apply 'close (list swapp-cleanup-delta-handle))
)

(setq swapp-cleanup-delta-path
  (strcat (getvar "DWGPREFIX") "swcad_cleanup_identity_delta_probe.txt")
)
(setq swapp-cleanup-delta-handle (open swapp-cleanup-delta-path "w"))

(if swapp-cleanup-delta-handle
  (progn
    ;; Reproduce policy V3 exactly: APPID is volatile, VPORT is included.
    (setq swapp-cleanup-delta-snapshot (swapp-named-definition-snapshot))
    (setq swapp-cleanup-delta-identities
      (swapp-definition-record-identities
        (swapp-definition-records-filter-appid
          (nth 2 swapp-cleanup-delta-snapshot)
          nil
        )
      )
    )
    (setq swapp-cleanup-delta-text
      (vl-princ-to-string swapp-cleanup-delta-identities)
    )
    (write-line "TARGET=1003:610255:70585" swapp-cleanup-delta-handle)
    (write-line
      (strcat
        "CURRENT=" (itoa (length swapp-cleanup-delta-identities)) ":"
        (itoa
          (swapp-text-rolling-hash
            swapp-cleanup-delta-text 1000003 53
          )
        )
        ":"
        (itoa
          (swapp-text-rolling-hash
            swapp-cleanup-delta-text 1000033 79
          )
        )
      )
      swapp-cleanup-delta-handle
    )
    (write-line
      (strcat "FULL=" swapp-cleanup-delta-text)
      swapp-cleanup-delta-handle
    )
    (foreach swapp-cleanup-delta-candidate swapp-cleanup-delta-identities
      (if
        (and
          (equal 0
            (vl-string-search
              "TABLE|" (strcase swapp-cleanup-delta-candidate)
            )
          )
          (not
            (equal 0
              (vl-string-search
                "TABLE|APPID|" (strcase swapp-cleanup-delta-candidate)
              )
            )
          )
        )
        (write-line
          (strcat
            "CANDIDATE="
            (vl-princ-to-string swapp-cleanup-delta-candidate)
          )
          swapp-cleanup-delta-handle
        )
      )
    )
    (close swapp-cleanup-delta-handle)
    (setq swapp-cleanup-delta-handle nil)
    (princ
      (strcat
        "\nCleanup identity delta probe: "
        swapp-cleanup-delta-path
      )
    )
  )
  (princ "\nCleanup identity delta probe failed to open its output file.")
)

(princ)
